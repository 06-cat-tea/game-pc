const fs=require('fs'),path=require('path'),assert=require('assert/strict');
const {chromium}=require('playwright');
const url=process.argv[2]||'file:///'+path.resolve('frontier.html').replaceAll('\\','/');
(async()=>{
  fs.mkdirSync('artifacts',{recursive:true});const browser=await chromium.launch({executablePath:process.env.CHROME_PATH,headless:true}),errors=[],checks=[];
  const ready=p=>p.waitForFunction(()=>window.GameLoading&&!GameLoading.blocked());
  const create=async(options={})=>{const p=await browser.newPage(options);p.on('pageerror',e=>errors.push(e.message));return p;};
  // The new key art must decode before the loading screen reveals the main menu.
  const p=await create({viewport:{width:1440,height:810}});let release;const held=new Promise(r=>release=r);
  await p.route('**/art-v2/title.webp*',async r=>{await held;await r.continue();});await p.goto(url,{waitUntil:'domcontentloaded'});await p.waitForFunction(()=>window.AshenGame&&GameLoading.diagnostics().completed>0);
  assert(await p.evaluate(()=>GameLoading.blocked()&&document.querySelector('#panelLayer').inert));release();await ready(p);assert.equal(await p.evaluate(()=>GameUI.getCurrent()),'title');checks.push('Loading waits for generated title artwork');
  // Seed a real v6 save; the menu should use its place/day/level without changing it.
  const saved=await p.evaluate(()=>AshenGame.getState());Object.assign(saved,{place:'fen',day:13,phase:2});saved.player.level=6;saved.location={sceneId:null,...await p.evaluate(()=>WorldRegions.spawn('fen')),zoom:1,stack:[]};
  await p.evaluate(s=>{localStorage.setItem('ashen-frontier-save-v3-desktop',JSON.stringify(s));AshenGame.command('load');},saved);await ready(p);await p.evaluate(()=>AshenGame.showScreen('title'));
  assert.match(await p.locator('.launch-continue').innerText(),/月沼遗境.*Lv\.6.*第 13 日/s);assert.match(await p.locator('.launch-save').innerText(),/黄昏/);
  await p.screenshot({path:'artifacts/title-desktop.png'});
  await p.locator('[data-screen=settings]').click();assert.equal(await p.evaluate(()=>GameUI.getCurrent()),'settings');assert(!(await p.evaluate(()=>document.querySelector('#gameViewport').classList.contains('at-title'))));await p.locator('[data-screen=title]').click();checks.push('Live save summary, settings and return to title');
  await p.locator('[data-command=continue]').focus();await p.keyboard.press('Enter');assert.equal(await p.evaluate(()=>GameUI.getCurrent()),'adventure');assert.equal(await p.evaluate(()=>AshenGame.getState().place),'fen');assert.equal(await p.evaluate(()=>AshenGame.getState().player.level),6);await p.evaluate(()=>AshenGame.showScreen('title'));checks.push('Keyboard continue preserves progress');
  p.once('dialog',d=>d.dismiss());await p.locator('[data-command=new-game]').click();assert.equal(await p.evaluate(()=>GameUI.getCurrent()),'title');assert.equal(await p.evaluate(()=>AshenGame.getState().player.level),6);
  p.once('dialog',d=>d.accept());await p.locator('[data-command=new-game]').click();await ready(p);assert.equal(await p.evaluate(()=>AshenGame.getState().player.level),1);assert.equal(await p.evaluate(()=>AshenGame.getState().schema),6);await p.evaluate(()=>AshenGame.showScreen('title'));checks.push('New journey keeps existing overwrite confirmation');
  await p.evaluate(()=>{window.fullscreenCalls=0;document.documentElement.requestFullscreen=()=>{window.fullscreenCalls++;return Promise.reject(new Error('unsupported'));};});await p.locator('.launch-fullscreen').click();assert.equal(await p.evaluate(()=>window.fullscreenCalls),1);assert.equal(await p.evaluate(()=>GameUI.getCurrent()),'title');checks.push('Fullscreen action and rejection fallback');
  for(const [width,height,touch]of require('./client-fixture.cjs').viewports){
    const page=await create({viewport:{width,height},hasTouch:touch,isMobile:touch});await page.goto(url);await ready(page);
    const result=await page.evaluate(()=>{
      const size=GameViewport.size(),buttons=[...document.querySelectorAll('.launch-screen button')].map(e=>{const r=GameViewport.localRect(e),at=GameViewport.localToClient(r.width/2,r.height/2,e);return {r,hit:e.contains(document.elementFromPoint(at.x,at.y))};}),main=GameViewport.localRect(document.querySelector('.launch-content')),header=GameViewport.localRect(document.querySelector('.launch-brand')),footer=GameViewport.localRect(document.querySelector('.launch-footer'));
      const content=[...document.querySelector('.launch-content').children].map(e=>GameViewport.localRect(e)).filter(r=>r.height>0);
      return {size,buttons,main,header,footer,content,scroll:document.documentElement.scrollWidth};
    });
    assert.equal(result.size.rotated,(require('./client-fixture.cjs').mobile&&height>width));assert(result.scroll<=width);
    assert(result.main.y>=result.header.y+result.header.height-1,'header overlap '+width+'x'+height);assert(result.main.y+result.main.height<=result.footer.y+1,'footer overlap '+width+'x'+height);
    for(const r of result.content)assert(r.y>=result.header.y+result.header.height-1&&r.y+r.height<=result.footer.y+1,'title content overflow '+width+'x'+height);
    for(const {r,hit}of result.buttons){assert(r.width>=44&&r.height>=44);assert(r.x>=0&&r.y>=0&&r.x+r.width<=result.size.width+1&&r.y+r.height<=result.size.height+1);assert(hit);}
    await page.screenshot({path:'artifacts/title-'+width+'x'+height+'.png'});await page.locator('[data-command=continue]').click();assert.equal(await page.evaluate(()=>GameUI.getCurrent()),'adventure');assert(!(await page.evaluate(()=>document.querySelector('#gameViewport').classList.contains('at-title'))));await page.close();checks.push(width+'x'+height+' title layout, hit testing and continue');
  }
  const reduced=await create({viewport:{width:1280,height:720},reducedMotion:'reduce'});await reduced.goto(url);await ready(reduced);assert(await reduced.evaluate(()=>getComputedStyle(document.querySelector('.launch-art')).animationName==='none'&&getComputedStyle(document.querySelector('.launch-atmosphere i')).animationName==='none'));checks.push('System reduced motion');
  // A missing illustration must still yield a usable title through explicit fallback.
  const failed=await create({viewport:{width:1280,height:720}});await failed.route('**/art-v2/title.webp*',r=>r.abort());await failed.goto(url);await failed.waitForFunction(()=>window.GameLoading&&GameLoading.diagnostics().status==='failed');await failed.locator('[data-loading-fallback]').click();await ready(failed);await failed.locator('[data-command=continue]').click();assert.equal(await failed.evaluate(()=>GameUI.getCurrent()),'adventure');checks.push('Missing title art fallback');
  assert.deepEqual(errors,[]);await browser.close();fs.writeFileSync('artifacts/title-acceptance.json',JSON.stringify({url,checks,errors,passed:true},null,2));console.log('PASS '+checks.join('\nPASS '));
})().catch(e=>{console.error(e);process.exit(1);});
