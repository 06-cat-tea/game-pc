// Each project runs this suite independently, with no sibling-project imports.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {pathToFileURL}=require('node:url');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const {id,mobile,saveKey,viewports}=require('./client-fixture.cjs');
const sceneReady=require('./scene-ready.cjs');
const url=process.argv[2]||pathToFileURL(path.resolve('frontier.html')).href;
const ready=p=>p.waitForFunction(()=>window.GameLoading&&!GameLoading.blocked(),null,{timeout:60000});
let browser;
(async()=>{
  fs.mkdirSync('artifacts',{recursive:true});
  browser=await chromium.launch({executablePath:process.env.CHROME_PATH,headless:true});
  const errors=[],checks=[];
  const page=async(options={})=>{
    const p=sceneReady(await browser.newPage(options));p.on('pageerror',e=>errors.push(e.message));
    await p.goto(url);await ready(p);return p;
  };
  for(const [width,height,touch]of [...viewports,[1280,720,!mobile]]){
    const p=await page({viewport:{width,height},isMobile:touch,hasTouch:touch});
    const frame=await p.evaluate(()=>({client:GameClient.id,size:GameViewport.size(),scroll:document.documentElement.scrollWidth}));
    assert.equal(frame.client,id);assert.equal(frame.size.touch,mobile);assert.equal(frame.size.rotated,mobile&&height>width);
    assert(Math.abs(frame.size.width/frame.size.height-16/9)<.001);assert(frame.scroll<=width);
    const switcher=p.locator('.launch-header [data-switch-client]');assert(await switcher.isVisible());
    await p.screenshot({path:`artifacts/client-title-${width}x${height}-${touch?'touch':'mouse'}.png`});
    await p.locator('[data-command=continue]').click();await ready(p);
    assert.equal(await p.locator('[data-stick]').isVisible(),mobile);
    const original=await p.evaluate(()=>{window.clientTestCanvas=document.querySelector('#pixelWorld');return PixelWorld.getPosition();});
    if(mobile){
      const point=await p.evaluate(()=>{const stick=document.querySelector('[data-stick]'),r=GameViewport.localRect(stick);return GameViewport.localToClient(r.width*.5,r.height-3,stick);});
      await p.locator('[data-stick]').dispatchEvent('pointerdown',{pointerId:31,pointerType:'touch',button:0,clientX:point.x,clientY:point.y});
      await p.locator('[data-sprint]').dispatchEvent('pointerdown',{pointerId:32,pointerType:'touch',button:0});
      await p.waitForTimeout(140);assert(await p.evaluate(()=>PixelWorld.movementDiagnostics().sprint));
      await p.locator('[data-sprint]').dispatchEvent('pointercancel',{pointerId:32,pointerType:'touch'});
      assert.equal(await p.evaluate(()=>PixelWorld.movementDiagnostics().sprint),false);
      await p.locator('[data-stick]').dispatchEvent('pointercancel',{pointerId:31,pointerType:'touch'});
    }else{
      await p.keyboard.down('Shift');await p.keyboard.down('d');await p.waitForTimeout(140);
      assert(await p.evaluate(()=>PixelWorld.movementDiagnostics().sprint));
      await p.keyboard.up('d');await p.keyboard.up('Shift');
      await p.keyboard.down('Tab');assert.equal(await p.locator('.quick-wheel').count(),1);
      await p.keyboard.press('Escape');await p.keyboard.up('Tab');
    }
    const stopped=await p.evaluate(()=>PixelWorld.getPosition());assert.notDeepEqual(stopped,original);
    await p.evaluate(()=>window.dispatchEvent(new Event('blur')));await p.waitForTimeout(100);
    assert.deepEqual(await p.evaluate(()=>PixelWorld.getPosition()),stopped);
    const round=await p.evaluate(()=>{const s=GameViewport.size(),p=GameViewport.localToClient(s.width*.3,s.height*.7),q=GameViewport.clientToLocal(p.x,p.y);return Math.hypot(q.x-s.width*.3,q.y-s.height*.7);});assert(round<.001);
    for(const screen of ['inventory','journal','party','crafting','codex','settings','more']){
      await p.evaluate(screen=>AshenGame.showScreen(screen),screen);
      assert(await p.evaluate(()=>document.querySelector('#pixelWorld')===window.clientTestCanvas));
      if(screen==='settings')assert(await p.locator('#screen-settings [data-switch-client]').isVisible());
      await p.keyboard.press('Escape');
    }
    await p.screenshot({path:`artifacts/client-${width}x${height}-${touch?'touch':'mouse'}.png`});
    await p.close();checks.push(`${width}x${height}: fixed ${id} layout, controls, panel navigation and coordinate conversion`);
  }
  const p=await page({viewport:{width:1280,height:720},hasTouch:mobile,isMobile:mobile,acceptDownloads:true});
  await p.locator('[data-command=continue]').click();await ready(p);
  const seed=async(fn)=>{const s=await p.evaluate(()=>AshenGame.getState());fn(s);await p.evaluate(({s,key})=>{localStorage.setItem(key,JSON.stringify(s));AshenGame.command('load');},{s,key:saveKey});};
  await seed(s=>{s.day=17;s.player.gold=1234;s.relationships.mira.value=60;s.settings.reduceMotion=true;});
  await p.evaluate(()=>AshenGame.talkNPC('mira',false));assert(await p.locator('.dialogue-reader').isVisible());
  await p.locator('[data-dialogue-menu=topics]').click();assert(await p.locator('[data-dialogue-start]').count()>0);
  await p.keyboard.press('Escape');await p.keyboard.press('Escape');
  await p.evaluate(()=>{AshenGame.challenge('boss-town',true);});
  assert(await p.locator('.battle-primary').isVisible());
  const battleFits=await p.evaluate(()=>{const s=GameViewport.size();return [...document.querySelectorAll('.battle-primary button')].every(b=>{const r=GameViewport.localRect(b);return r.x>=0&&r.y>=0&&r.x+r.width<=s.width+1&&r.y+r.height<=s.height+1;});});assert(battleFits);
  await seed(s=>{s.battle=null;});
  await p.evaluate(()=>AshenGame.showScreen('settings'));
  const downloading=p.waitForEvent('download');await p.locator('[data-action=export]').click();
  const download=await downloading,exported=JSON.parse(fs.readFileSync(await download.path(),'utf8'));
  assert.equal(exported.schema,6);assert.equal(exported.day,17);assert.equal(exported.player.gold,1234);
  exported.day=23;exported.player.gold=4321;
  await p.locator('#importFile').setInputFiles({name:'save.json',mimeType:'application/json',buffer:Buffer.from(JSON.stringify(exported))});
  assert.equal(await p.evaluate(()=>AshenGame.getState().day),23);
  assert.equal(await p.evaluate(()=>AshenGame.getState().player.gold),4321);
  await p.reload();await ready(p);assert.equal(await p.evaluate(()=>AshenGame.getState().day),23);
  const inherited=await p.evaluate(()=>AshenGame.getState());
  await p.evaluate(({key,raw})=>{localStorage.removeItem(key);localStorage.setItem('ashen-frontier-save-v3',JSON.stringify({...raw,day:31,schema:4}));},{key:saveKey,raw:inherited});
  await p.reload();await ready(p);assert.equal(await p.evaluate(()=>AshenGame.getState().day),31);
  assert.equal(await p.evaluate(key=>JSON.parse(localStorage.getItem(key)).schema,saveKey),6);
  assert.equal(await p.evaluate(()=>JSON.parse(localStorage.getItem('ashen-frontier-save-v3')).schema),4);
  await p.evaluate(()=>{const old=JSON.parse(localStorage.getItem('ashen-frontier-save-v3'));old.day=99;localStorage.setItem('ashen-frontier-save-v3',JSON.stringify(old));});
  await p.reload();await ready(p);assert.equal(await p.evaluate(()=>AshenGame.getState().day),31);
  assert(await p.evaluate(key=>!!localStorage.getItem(key+'-backup-v4'),saveKey));
  await p.evaluate(()=>{document.documentElement.requestFullscreen=()=>Promise.reject(Error('unsupported'));});
  const before=await p.evaluate(()=>GameViewport.size());await p.evaluate(()=>GameViewport.fullscreen());assert.deepEqual(await p.evaluate(()=>GameViewport.size()),before);
  checks.push('Dialogue, battle, export/import, reload, legacy v4 inheritance, isolated backup and fullscreen fallback');
  await p.close();assert.deepEqual(errors,[]);
  fs.writeFileSync('artifacts/client-acceptance.json',JSON.stringify({id,url,checks,errors},null,2));
  await browser.close();console.log('PASS '+checks.join('\nPASS '));
})().catch(async error=>{console.error(error);await browser?.close();process.exitCode=1;});
