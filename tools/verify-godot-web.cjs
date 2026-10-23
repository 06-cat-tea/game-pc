// Exercise the exported game through player controls. No engine test hooks are shipped.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {once} = require('node:events');
const {createHash} = require('node:crypto');
const {chromium, firefox} = require('playwright');
const sharp = require('sharp');
const {startServer} = require('./serve-godot-web.cjs');

const root = path.resolve(__dirname, '..');
function option(name, fallback) {
  const inline = process.argv.find(value => value.startsWith(name + '='));
  if (inline) return inline.slice(name.length + 1);
  const index = process.argv.indexOf(name);
  return index < 0 ? fallback : process.argv[index + 1];
}
const browserName = option('--browser', 'chromium');
assert(['chromium', 'chrome', 'msedge', 'firefox'].includes(browserName), 'Unsupported --browser');
const directory = path.join(root, 'artifacts/godot/web-acceptance-' + browserName);
fs.mkdirSync(directory, {recursive: true});
const profile = fs.mkdtempSync(path.join(directory, 'profile-'));
const checks = [], screenshots = [], errors = [], warnings = [], responses = [];
const reportPath = path.join(directory, 'report.json');
let context, page, server, url, browserVersion, stage = 'launch';
const wait = ms => page.waitForTimeout(ms);
// Firefox's first software-WebGL scene upload may finish several frames after
// the engine promise, especially when multiple browser channels run together.
const sceneWait = ms => wait(browserName === 'firefox' ? Math.max(ms, 4500) : ms);
function check(ok, label, details) {
  assert(ok, label);
  checks.push({label, ...(details ? {details} : {})});
  console.log('PASS ' + label);
}
function attach(target) {
  target.on('console', message => {
    const value = message.text();
    // Software WebGL is normal on CI. Never suppress script/runtime or asset errors.
    const benign = /(?:SwiftShader|GPU stall due to ReadPixels|software WebGL|deprecated parameters for the initialization function)/i.test(value);
    if ((message.type() === 'error' || /SCRIPT ERROR:|(?:^|\n)ERROR:|Parse Error|Failed to load resource/i.test(value)) && !benign) errors.push({stage, type: 'console', message: value});
    else if (message.type() === 'warning') warnings.push({stage, message: value});
  });
  target.on('pageerror', error => errors.push({stage, type: 'pageerror', message: error.stack || error.message}));
  target.on('requestfailed', request => {
    const message = request.failure()?.errorText || '';
    if (!/ERR_ABORTED|NS_BINDING_ABORTED|NS_ERROR_ABORT/i.test(message)) errors.push({stage, type: 'request', url: request.url(), message});
  });
  target.on('response', response => {
    if (response.status() >= 400) errors.push({stage, type: 'http', status: response.status(), url: response.url()});
    if (/\.(?:wasm|pck)(?:\?|$)/.test(response.url())) responses.push({url: response.url(), status: response.status()});
  });
}
async function launch() {
  const engine = browserName === 'firefox' ? firefox : chromium;
  context = await engine.launchPersistentContext(profile, {
    headless: true,
    viewport: {width: 1280, height: 720},
    deviceScaleFactor: 1,
    acceptDownloads: true,
    ...(browserName === 'chrome' || browserName === 'msedge' ? {channel: browserName} : {}),
    ...(browserName === 'firefox' ? {} : {args: ['--enable-unsafe-swiftshader', '--disable-dev-shm-usage']}),
  });
  browserVersion = context.browser()?.version() || browserVersion;
  context.on('page', attach);
  page = context.pages()[0] || await context.newPage();
  attach(page);
  page.setDefaultTimeout(15000);
  await boot();
}
async function boot() {
  await page.goto(url, {waitUntil: 'domcontentloaded', timeout: 60000});
  await page.waitForFunction(() => document.documentElement.dataset.gameState === 'ready', null, {timeout: 180000});
  await page.locator('#canvas').waitFor({state: 'visible'});
  await sceneWait(2000);
  await page.locator('#canvas').focus();
}
async function click(x, y) {
  const box = await page.locator('#canvas').boundingBox();
  assert(box && box.width > 0 && box.height > 0, 'Game canvas is visible');
  await page.mouse.click(box.x + x * box.width / 1920, box.y + y * box.height / 1080);
  await wait(450);
}
async function move(x, y) {
  const box = await page.locator('#canvas').boundingBox();
  await page.mouse.move(box.x + x * box.width / 1920, box.y + y * box.height / 1080, {steps: 4});
  await wait(100);
}
async function shot(name) {
  const filename = path.join(directory, name + '.png');
  const buffer = await page.locator('#canvas').screenshot({path: filename, timeout: 30000});
  screenshots.push(filename);
  return buffer;
}
async function difference(before, after, region) {
  async function pixels(buffer) {
    let pipeline = sharp(buffer);
    if (region) pipeline = pipeline.extract(region);
    return pipeline.resize(320, 180).removeAlpha().raw().toBuffer();
  }
  const [a, b] = await Promise.all([pixels(before), pixels(after)]);
  assert.equal(a.length, b.length);
  let changed = 0;
  for (let index = 0; index < a.length; index += 3) {
    if (Math.abs(a[index] - b[index]) + Math.abs(a[index + 1] - b[index + 1]) + Math.abs(a[index + 2] - b[index + 2]) > 75) changed++;
  }
  return changed / (a.length / 3);
}
async function closeMenu() { await click(1830, 84); }
async function openSaves() {
  await page.keyboard.press('Escape');
  await wait(300);
  await click(1540, 594); // Terminal: row 3, middle entry, 存档.
}
async function saveJSON(name) {
  const downloaded = page.waitForEvent('download');
  await click(279, 853);
  const download = await downloaded;
  assert.equal(download.suggestedFilename(), 'ashen-frontier-godot-desktop.json');
  const filename = path.join(directory, name + '.json');
  await download.saveAs(filename);
  const bytes = fs.readFileSync(filename);
  const state = JSON.parse(bytes.toString('utf8'));
  assert.equal(state.format, 'ashen-frontier-godot-desktop');
  assert.equal(state.version, 1);
  return {filename, state, bytes, sha256: createHash('sha256').update(bytes).digest('hex')};
}
async function transfer(status) {
  await page.waitForFunction(expected => window.AshenFrontierSaveFiles?.lastResult?.operation === 'import' && window.AshenFrontierSaveFiles.lastResult.status === expected, status);
  return page.evaluate(() => window.AshenFrontierSaveFiles.lastResult);
}
async function importJSON(input, expected) {
  const choosing = page.waitForEvent('filechooser');
  await click(733, 853);
  const chooser = await choosing;
  await chooser.setFiles(input);
  const result = await transfer(expected);
  await wait(500);
  return result;
}
async function loadManual(slot) {
  await click(278 + slot * 450, 630);
  await sceneWait(1200);
}
async function wheelSelect(index) {
  await move(1800, 500);
  await page.keyboard.down('Tab');
  await wait(200);
  const angle = index * Math.PI / 4 - Math.PI / 2;
  await move(960 + Math.cos(angle) * 200, 540 + Math.sin(angle) * 200);
  await page.keyboard.up('Tab');
  await wait(500);
}
async function loseFocus() {
  // Use the shell's real link: headless Chrome keeps document.hasFocus() true
  // on background pages, but moving keyboard focus off the canvas emits the
  // native canvas blur notification used by Godot's Web DisplayServer.
  const opening = page.waitForEvent('popup');
  await page.locator('#licenses').click();
  const other = await opening;
  await other.waitForLoadState('domcontentloaded');
  await other.bringToFront();
  await wait(350);
  assert.equal(await page.evaluate(() => document.activeElement?.id === 'canvas'), false, 'Game canvas actually lost keyboard focus');
  await other.keyboard.up('Tab');
  await other.keyboard.up('d');
  await page.bringToFront();
  await page.locator('#canvas').focus();
  await wait(300);
  await other.close();
}
async function main() {
  url = option('--url');
  if (!url) {
    server = await startServer();
    url = `http://127.0.0.1:${server.address().port}/game-pc/`;
  }
  assert(/^https?:\/\//.test(url), 'Web acceptance requires an HTTP(S) URL');
  await launch();
  check(true, '发布路径下的引擎、WASM、PCK 正常加载', {url, version: browserVersion});
  const title = await shot('01-title');

  stage = 'new-journey';
  await click(380, 839);
  const choices = await shot('02-new-journey');
  check(await difference(title, choices) > 0.15, '标题可打开职业选择');
  await click(1545, 867); // Third card: warden.
  await sceneWait(1800);
  await shot('03-town');
  await openSaves();
  const initial = await saveJSON('initial');
  check(initial.state.location.scene === 'town' && initial.state.members.hero.job === 'warden', '可开始守望者旅程并下载原生 JSON');

  stage = 'manual-save';
  for (let slot = 1; slot <= 3; slot++) {
    await click(278 + slot * 450, 701);
    await shot('04-save-confirm-' + slot);
    await click(1172, 680);
  }
  await shot('05-save-slots');
  await closeMenu();
  await page.keyboard.down('d');
  await wait(650);
  await page.keyboard.up('d');
  await wait(250);
  await openSaves();
  const moved = await saveJSON('after-movement');
  check(Math.hypot(moved.state.location.x - initial.state.location.x, moved.state.location.y - initial.state.location.y) > 0.25, '键盘移动实际改变旅人位置');

  stage = 'import-rejection';
  const incomplete = structuredClone(initial.state);
  delete incomplete.formation;
  for (const fixture of [
    {name: 'damaged.json', mimeType: 'application/json', buffer: Buffer.from('{broken'), message: /JSON|损坏/},
    {name: 'oversized.json', mimeType: 'application/json', buffer: Buffer.alloc(2 * 1024 * 1024 + 1, 32), message: /2MB/},
    {name: 'legacy-web.json', mimeType: 'application/json', buffer: Buffer.from('{"version":7,"player":{"level":1}}'), message: /旧|原生/},
    {name: 'missing-formation.json', mimeType: 'application/json', buffer: Buffer.from(JSON.stringify(incomplete)), message: /数据|格式|阵型|无效|缺少/},
  ]) {
    const result = await importJSON({name: fixture.name, mimeType: fixture.mimeType, buffer: fixture.buffer}, 'error');
    check(fixture.message.test(result.message), '拒绝 ' + fixture.name + ' 并提示原因', result);
    const after = await saveJSON('preserved-' + fixture.name.replace('.json', ''));
    assert.deepEqual(after.state, moved.state, 'Rejected import must not alter progress');
  }
  const canceled = await importJSON([], 'canceled');
  check(/取消/.test(canceled.message), '取消文件选择后保留进度');
  assert.deepEqual((await saveJSON('after-cancel')).state, moved.state);
  await shot('06-import-preserved');

  stage = 'json-roundtrip';
  await importJSON(initial.filename, 'complete');
  await openSaves();
  assert.deepEqual((await saveJSON('roundtrip')).state, initial.state);
  check(true, '下载的 JSON 可通过上传恢复完整原生状态');
  await importJSON(moved.filename, 'complete');
  await wait(2700); // Let Godot's user:// filesystem synchronization reach IndexedDB.

  stage = 'reload-persistence';
  await page.reload({waitUntil: 'domcontentloaded'});
  await page.waitForFunction(() => document.documentElement.dataset.gameState === 'ready', null, {timeout: 180000});
  await sceneWait(2000);
  await click(380, 752);
  await sceneWait(1500);
  await openSaves();
  assert.deepEqual((await saveJSON('after-reload')).state, moved.state);
  check(true, '刷新页面后可继续读取 IndexedDB 自动档');

  stage = 'restart-persistence';
  await context.close();
  context = null;
  await launch();
  await click(380, 752);
  await sceneWait(1500);
  await openSaves();
  assert.deepEqual((await saveJSON('after-browser-restart')).state, moved.state);
  for (let slot = 1; slot <= 3; slot++) {
    await loadManual(slot);
    await openSaves();
    assert.deepEqual((await saveJSON('restored-manual-' + slot)).state, initial.state);
  }
  check(true, '关闭并重启浏览器后自动档与三个手动档均可读取');
  await importJSON(moved.filename, 'complete');

  stage = 'wheel-and-focus';
  await move(1800, 500);
  const world = await shot('07-before-wheel');
  await page.keyboard.down('Tab');
  await wait(250);
  const neutral = await shot('08-wheel-neutral');
  await page.keyboard.up('Tab');
  await wait(300);
  const canceledWheel = await shot('09-wheel-canceled');
  check(await difference(world, neutral) > 0.03 && await difference(neutral, canceledWheel) > 0.03, '轮盘初始无选择，鼠标未移动时松开 Tab 取消');
  await wheelSelect(0); // Backpack is the top wedge.
  const backpack = await shot('10-wheel-backpack');
  check(await difference(canceledWheel, backpack) > 0.15, '移动指针并松开 Tab 可打开背包');
  await closeMenu();
  await page.keyboard.down('Tab');
  await wait(200);
  await loseFocus();
  const afterBlur = await shot('11-wheel-focus-recovered');
  check(await difference(neutral, afterBlur) > 0.03, '浏览器失焦会取消轮盘，恢复焦点后可继续操作');
  await openSaves();
  assert.deepEqual((await saveJSON('after-wheel')).state, moved.state);
  check(true, '轮盘取消与失焦不会改写游戏进度');
  await closeMenu();
  await page.keyboard.down('d');
  await wait(180);
  await loseFocus();
  await openSaves();
  const stopped = await saveJSON('after-held-key-blur');
  await closeMenu();
  await wait(900);
  await openSaves();
  assert.deepEqual((await saveJSON('after-focus-idle')).state.location, stopped.state.location);
  check(true, '移动时切换标签页可释放按键，恢复后不会持续行走');
  await closeMenu();

  stage = 'map-and-interaction';
  await page.keyboard.press('m');
  await wait(400);
  await shot('12-map');
  await click(1553, 765); // Default town landmark: clocktower, enter interior.
  await sceneWait(1300);
  await shot('13-clocktower');
  await openSaves();
  const interior = await saveJSON('inside-clocktower');
  check(interior.state.location.scene === 'room-clocktower', '地图可进入钟塔内室并切换场景');
  await closeMenu();
  await page.keyboard.press('f'); // Interior spawn is next to the exit.
  await sceneWait(1200);
  await openSaves();
  const beforeTraining = await saveJSON('before-training');
  check(beforeTraining.state.location.scene === 'town', 'F 交互可从内室返回晨星镇');
  await closeMenu();

  stage = 'training-and-battle';
  await click(1710, 914); // Nearby actions.
  await click(700, 460); // 公会战术训练.
  await shot('14-training-options');
  // Every menu starts on its back button. Shift+Tab selects its final action.
  await page.keyboard.press('Shift+Tab');
  await page.keyboard.press('Enter');
  await sceneWait(900);
  await shot('15-training-camp');
  // Back, close, adjust skills, adjust tactics, restore, exit, first encounter.
  for (let index = 0; index < 6; index++) await page.keyboard.press('Tab');
  await page.keyboard.press('Enter');
  await sceneWait(1500);
  const battle = await shot('16-battle');
  // Guard advances combat without a random critical hit killing the weak
  // first enemy before the following pause and exit controls are exercised.
  await click(1376, 840);
  await page.keyboard.press('Enter');
  await wait(500);
  await wait(1000);
  const acted = await shot('17-battle-after-actions');
  check(await difference(battle, acted) > 0.004, '训练场可进入战斗并用 Enter 推进行动');
  await page.keyboard.press('Escape');
  await wait(200);
  await shot('18-battle-paused');
  await page.keyboard.press('Escape');
  await wait(200);
  await click(116, 1027); // The normal battle exit-training control.
  await sceneWait(700);
  await openSaves();
  assert.deepEqual((await saveJSON('after-training')).state, beforeTraining.state);
  check(true, '退出训练战斗后恢复剧情状态与物资');
  await closeMenu();

  stage = 'settings-and-title';
  await wheelSelect(7);
  await shot('19-settings');
  await page.keyboard.press('Tab');
  await page.keyboard.press('Tab');
  await page.keyboard.press('Enter');
  await page.waitForFunction(() => !!document.fullscreenElement);
  await shot('20-fullscreen');
  await page.keyboard.press('Enter');
  await page.waitForFunction(() => !document.fullscreenElement);
  check(true, '用户点击设置可进入和退出浏览器全屏');
  // Two Tabs moved to fullscreen; Shift+Tab twice returns to Back, a third
  // wraps to the last control, 返回标题.
  for (let index = 0; index < 3; index++) await page.keyboard.press('Shift+Tab');
  await page.keyboard.press('Enter');
  await wait(700);
  await shot('21-returned-title');
  await click(380, 752);
  await sceneWait(1300);
  await openSaves();
  assert.deepEqual((await saveJSON('after-title-continue')).state, beforeTraining.state);
  check(true, '返回标题后可继续原旅程');

  stage = 'legacy-url';
  const legacy = new URL('frontier.html', url).href;
  await page.goto(legacy, {waitUntil: 'domcontentloaded', timeout: 60000});
  await page.waitForFunction(() => document.documentElement.dataset.gameState === 'ready', null, {timeout: 180000});
  await sceneWait(1500);
  check(!new URL(page.url()).pathname.endsWith('frontier.html'), '旧 frontier.html 链接进入新版游戏');
  await shot('22-legacy-url');
  check(responses.some(response => response.url.includes('.wasm')) && responses.some(response => response.url.includes('.pck')), '实际请求包含 WASM 和 PCK 发布资源');
  check(errors.length === 0, '无脚本错误、缺失资源或失败的网络请求', errors);
}
main().catch(async error => {
  errors.push({stage, type: 'assertion', message: error.stack || error.message});
  console.error(error.stack || error);
  if (page && !page.isClosed()) await shot('failure-' + stage).catch(() => {});
  process.exitCode = 1;
}).finally(async () => {
  await context?.close().catch(() => {});
  if (server) { server.close(); server.closeAllConnections?.(); await once(server, 'close').catch(() => {}); }
  fs.writeFileSync(reportPath, JSON.stringify({passed: !process.exitCode && errors.length === 0, created: new Date().toISOString(), browser: browserName, browserVersion, url, checks, errors, warnings, resources: responses, screenshots, profile}, null, 2) + '\n');
  console.log('Web acceptance report: ' + reportPath);
});
