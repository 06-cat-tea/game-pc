const fs=require('fs'),path=require('path'),assert=require('assert/strict');
const {chromium}=require('playwright');
const url=process.argv[2]||'file:///'+path.resolve('frontier.html').replaceAll('\\','/');
(async()=>{
  fs.mkdirSync('artifacts',{recursive:true});
  const browser=await chromium.launch({executablePath:process.env.CHROME_PATH,headless:true}),errors=[],checks=[];
  const create=async(options={})=>{const page=await browser.newPage({viewport:{width:1440,height:810},...options});page.on('pageerror',e=>errors.push(e.message));return page;};
  const ready=page=>page.waitForFunction(()=>window.GameLoading&&!GameLoading.blocked()&&GameLoading.diagnostics().status==='ready');
  const page=await create(),startupRequests=[];page.on('request',r=>startupRequests.push(r.url()));let release;const hold=new Promise(r=>release=r);
  await page.route('**/portraits/hero-256.png*',async route=>{await hold;await route.continue();});
  await page.goto(url,{waitUntil:'domcontentloaded'});await ready(page);
  assert(startupRequests.every(url=>!url.includes('/art-v2/environment/')&&!url.includes('/art-v2/scenes/')&&!url.includes('/vendor/live2d/')&&!url.includes('/art-v2/buildings/')));
  assert.equal(await page.evaluate(()=>GameLoading.diagnostics().key),'title');checks.push('Title does not fetch the map, interiors or Live2D SDK');
  await page.evaluate(()=>AshenGame.command('continue'));
  const before=await page.evaluate(()=>PixelWorld.getPosition());await page.keyboard.press('d');await page.evaluate(()=>PixelWorld.move(2,0));
  assert.deepEqual(await page.evaluate(()=>PixelWorld.getPosition()),before);
  assert(await page.evaluate(()=>GameHUD.blocked()&&document.querySelector('#hudLayer').inert));
  assert(await page.evaluate(()=>GameLoading.diagnostics().percent<100));
  await page.screenshot({path:'artifacts/loading-desktop.png'});release();await ready(page);
  assert(await page.evaluate(()=>PixelWorld.assetDiagnostics().scene&&!document.querySelector('#hudLayer').inert));checks.push('Real progress and blocked input until images decode and terrain renders');
  for(const place of ['town','wood','pass','fen','coast','city']){
    await page.evaluate(place=>AshenGame.travel(place),place);await ready(page);
    const result=await page.evaluate(()=>({loading:GameLoading.diagnostics(),scene:PixelWorld.assetDiagnostics().scene,position:PixelWorld.getPosition()}));
    assert.equal(result.loading.failed.length,0,place);assert.equal(result.loading.completed,result.loading.total);assert(result.scene,place);checks.push(place+' complete region');
  }
  // A newer region wins even if the earlier preparation is still pending.
  await page.evaluate(()=>{AshenGame.travel('wood');AshenGame.travel('coast');});await ready(page);
  assert.equal(await page.evaluate(()=>GameLoading.diagnostics().key),'coast:outdoor');checks.push('Rapid region changes');
  const room=await page.evaluate(()=>Object.values(SceneSystem.scenes||{}).find(r=>r.place==='town'&&!r.procedural)?.id);
  // Use a valid interior exposed through the building system, and persist it for boot restore.
  const sceneId=room||await page.evaluate(()=>BuildingSystem.at('town').find(b=>b.interior)?.interior);
  assert(sceneId,'town interior');
  await page.evaluate(id=>{const s=AshenGame.getState();s.place='town';s.location={sceneId:id,x:8.3,y:8.3,zoom:1,stack:[]};localStorage.setItem('ashen-frontier-save-v3-desktop',JSON.stringify(s));AshenGame.command('load');},sceneId);
  await ready(page);assert(await page.evaluate(()=>!!PixelWorld.getInterior()));await page.reload();await ready(page);
  assert.equal(await page.evaluate(()=>GameLoading.diagnostics().key),'title');
  await page.locator('[data-command=continue]').click();await ready(page);assert(await page.evaluate(()=>!!PixelWorld.getInterior()&&PixelWorld.assetDiagnostics().scene));
  assert(await page.evaluate(()=>GameLoading.manifest(AshenGame.getState()).every(r=>!['scenes','environment','buildings'].includes(r.kind))));checks.push('Saved interior waits only for its own artwork');
  const slow=await create();let deliver;const delayed=new Promise(r=>deliver=r);
  await slow.route('**/portraits/hero-256.png*',async r=>{await delayed;await r.continue();});
  await slow.goto(url,{waitUntil:'domcontentloaded'});await ready(slow);
  await slow.evaluate(()=>{const original=window.setTimeout;window.setTimeout=(fn,ms,...args)=>original(fn,ms===45000?150:ms,...args);AshenGame.command('continue');});
  await slow.waitForFunction(()=>GameLoading.diagnostics().status==='failed');
  assert(await slow.evaluate(()=>GameLoading.diagnostics().failed.some(r=>r.id==='hero'&&r.reason==='timeout'&&r.url.includes('hero-256.png'))));
  deliver();await ready(slow);assert.equal(await slow.evaluate(()=>GameLoading.diagnostics().failed.length),0);checks.push('Delayed image automatically clears the error and enters the map');
  const flaky=await create();let attempts=0;const retryUrls=[],interrupted=new Set();
  await flaky.route(/\/art-v[23]\/environment\//,r=>{
    const file=new URL(r.request().url()).pathname;
    if(!interrupted.has(file)&&interrupted.size<13){interrupted.add(file);return r.abort();}
    return r.continue();
  });
  await flaky.route('**/portraits/hero-256.png*',r=>{retryUrls.push(r.request().url());return ++attempts===1?r.abort():r.continue();});
  await flaky.goto(url,{waitUntil:'domcontentloaded'});await ready(flaky);await flaky.locator('[data-command=continue]').click();await ready(flaky);
  assert.equal(attempts,2);assert.equal(interrupted.size,13);if(url.startsWith('http'))assert(retryUrls[1].includes('asset-retry='));else assert.equal(retryUrls[1],retryUrls[0]);checks.push('Thirteen interrupted scene images recover automatically with fresh requests');
  // Failed art stays gated until the user retries; successful assets remain cached.
  const retry=await create();let fail=true;await retry.route('**/portraits/hero-256.png*',r=>fail?r.abort():r.continue());
  await retry.goto(url);await ready(retry);await retry.locator('[data-command=continue]').click();await retry.waitForFunction(()=>window.GameLoading&&GameLoading.diagnostics().status==='failed');
  assert(await retry.evaluate(()=>GameLoading.blocked()));await retry.screenshot({path:'artifacts/loading-error.png'});fail=false;await retry.locator('[data-loading-retry]').click();await ready(retry);checks.push('Asset failure and retry');
  const fallback=await create();await fallback.route('**/art-v2/environment/**',r=>r.abort());await fallback.goto(url);await ready(fallback);await fallback.locator('[data-command=continue]').click();await fallback.waitForFunction(()=>window.GameLoading&&GameLoading.diagnostics().status==='failed');await fallback.locator('[data-loading-fallback]').click();await ready(fallback);assert(await fallback.evaluate(()=>PixelWorld.assetDiagnostics().scene));checks.push('Explicit procedural fallback');
  for(const [width,height] of require('./client-fixture.cjs').viewports.map(([width,height])=>[width,height])){
    const mobile=await create({viewport:{width,height},hasTouch:false,isMobile:false});let unblock;const pending=new Promise(r=>unblock=r);await mobile.route('**/portraits/hero-256.png*',async r=>{await pending;await r.continue();});await mobile.goto(url,{waitUntil:'domcontentloaded'});await mobile.waitForFunction(()=>window.AshenGame);await mobile.evaluate(()=>AshenGame.command('continue'));await mobile.waitForTimeout(500);await mobile.screenshot({path:'artifacts/loading-'+width+'x'+height+'.png'});
    const fits=await mobile.evaluate(()=>{const rect=GameViewport.localRect(document.querySelector('.loading-content')),size=GameViewport.size();return rect.x>=0&&rect.y>=0&&rect.x+rect.width<=size.width&&rect.y+rect.height<=size.height;});assert(fits);unblock();await ready(mobile);assert(await mobile.evaluate(()=>!GameHUD.blocked()));await mobile.close();checks.push(width+'x'+height+' loading fits rotated viewport');
  }
  assert.deepEqual(errors,[]);await browser.close();fs.writeFileSync('artifacts/loading-acceptance.json',JSON.stringify({url,checks,errors,passed:true},null,2));console.log('PASS '+checks.join('\nPASS '));
})().catch(e=>{console.error(e);process.exit(1);});
