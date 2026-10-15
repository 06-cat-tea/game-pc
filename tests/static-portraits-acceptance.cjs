// Real asset and UI checks, using isolated saves. Accepts file:// or a preview URL.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const sharp=require('sharp');
const {chromium}=require('playwright');
const url=process.argv[2]||'file:///'+path.resolve('frontier.html').replaceAll('\\','/');
const ids=['hero','mira','toren','sylvi','ridge-scout','alchemist'],checks=[],errors=[];let browser;
async function meet(page,id,reduceMotion=id==='mira'){
  await page.evaluate(({id,reduceMotion})=>{
    const n=GrowthSystem.npcs()[id],b=BuildingSystem.all.find(b=>{const r=BuildingSystem.interior(b.id);return r&&NPCSystem.inside(r.occupantKey).some(n=>n.id===id);}),s=AshenGame.getState();
    s.place=n.place||b.place;s.battle=null;s.settings.reduceMotion=reduceMotion;s.relationships[id].value=80;
    s.location={sceneId:null,x:10,y:12,zoom:1,stack:[]};localStorage.setItem('ashen-frontier-save-v3-desktop',JSON.stringify(s));AshenGame.command('load');if(!n.place)AshenGame.enterBuilding(b.id);AshenGame.talkNPC(id,false);
  },{id,reduceMotion});
  await page.waitForFunction(()=>!GameLoading.blocked());
}
const loaded=(page,id,mood)=>page.waitForFunction(({id,mood})=>{const img=document.querySelector('img[data-standing-id="'+id+'"]');return img?.dataset.loadedExpression===mood&&img.complete&&img.naturalWidth===768;},{id,mood});
async function inject(page,id,mood){await page.evaluate(({id,mood})=>{let host=document.getElementById('portrait-fixture');if(!host){host=document.createElement('div');host.id='portrait-fixture';document.body.append(host);}host.innerHTML=CharacterPortraits.markup(id,id,'hero',mood,{animated:false});CharacterPortraits.activate(host);},{id,mood});}
async function chooseCompanion(page,id){await page.locator('[data-ui-search=party]').fill(await page.evaluate(id=>GameData.COMPANIONS[id].name,id));await page.locator('[data-ui-select="'+id+'"]').click();}
(async()=>{
  fs.mkdirSync('artifacts',{recursive:true});let total=0;
  for(const id of ids){const hashes=new Set();for(const mood of ['neutral','smile','serious']){
    const file=path.join('assets/characters',id,'static-v1',mood+'.webp'),bytes=fs.readFileSync(file),meta=await sharp(bytes).metadata();
    assert.equal(meta.width,768);assert.equal(meta.height,1152);assert(meta.hasAlpha);assert(bytes.length<=512*1024);total+=bytes.length;hashes.add(crypto.createHash('sha256').update(bytes).digest('hex'));
    const {data}=await sharp(bytes).ensureAlpha().raw().toBuffer({resolveWithObject:true});let transparent=0,maxAlpha=0;for(let i=3;i<data.length;i+=4){if(!data[i])transparent++;maxAlpha=Math.max(maxAlpha,data[i]);}assert(transparent>768*1152*.12);assert(maxAlpha>=200);assert.equal(data[3],0);
  }assert.equal(hashes.size,3,id+' expressions are distinct');}
  assert(total<11*1024*1024);checks.push('18 distinct transparent WebP portraits fit the dimensions and byte budget');
  browser=await chromium.launch({executablePath:process.env.CHROME_PATH,headless:true});
  async function create(){const p=await browser.newPage({viewport:{width:1280,height:720}});p.on('pageerror',e=>errors.push(e.message));return p;}
  async function boot(p){await p.goto(url,{waitUntil:'domcontentloaded'});await p.waitForFunction(()=>window.AshenGame&&!GameLoading.blocked());await p.locator('[data-command=continue]').click();await p.waitForFunction(()=>!GameLoading.blocked());}
  const p=await create(),requests=[];p.on('request',r=>requests.push(r.url()));await p.goto(url,{waitUntil:'domcontentloaded'});await p.waitForFunction(()=>window.AshenGame&&!GameLoading.blocked());
  assert(!requests.some(r=>r.includes('/static-v1/')||r.includes('/vendor/live2d/')));await p.locator('[data-command=continue]').click();await p.waitForFunction(()=>!GameLoading.blocked());
  for(const id of ids.filter(id=>id!=='hero')){
    await meet(p,id);await loaded(p,id,'neutral');
    await p.evaluate(id=>DialogueSystem.start(id,'past'),id);await loaded(p,id,'serious');
    await p.evaluate(()=>{DialogueSystem.next();DialogueSystem.next();});assert.equal(await p.locator('.dialogue-character').getAttribute('data-character-id'),id);
    await p.evaluate(()=>DialogueSystem.choose(0));await loaded(p,'hero','serious');
    await p.evaluate(()=>DialogueSystem.next());await loaded(p,id,'serious');
    await meet(p,id);await p.locator('[data-dialogue-menu=gift]').click();await loaded(p,id,'smile');
    assert.equal(await p.locator('.character-live2d:not([hidden])').count(),0);
  }
  assert.equal(await p.evaluate(()=>typeof window.AshenCubism),'undefined');checks.push('Five residents switch expressions and player replies; static portraits do not load the SDK');
  await p.evaluate(()=>AshenGame.showScreen('party','companions'));
  for(const id of ['mira','toren','sylvi','ridge-scout','alchemist']){await chooseCompanion(p,id);await loaded(p,id,'neutral');assert.equal(await p.locator('.companion-standing-art+canvas').count(),0);}
  await chooseCompanion(p,'eira');assert.equal(await p.locator('[data-standing-id=eira]').count(),0);assert((await p.locator('.detail-portrait').getAttribute('src')).includes('priest-256.png'));checks.push('Companion details use static neutral art; Eira keeps her existing portrait');
  for(const [width,height,touch] of require('./client-fixture.cjs').viewports){
    const mobile=await browser.newPage({viewport:{width,height},hasTouch:touch,isMobile:touch});mobile.on('pageerror',e=>errors.push(e.message));await boot(mobile);await meet(mobile,'sylvi');await loaded(mobile,'sylvi','neutral');
    const fits=await mobile.evaluate(()=>{const size=GameViewport.size();return ['.dialogue-options','.dialogue-caption'].every(selector=>{const r=GameViewport.localRect(document.querySelector(selector));return r.x>=0&&r.y>=0&&r.x+r.width<=size.width+1&&r.y+r.height<=size.height+1;});});assert(fits,width+' dialogue');await mobile.screenshot({path:'artifacts/static-dialogue-'+width+'x'+height+'.png'});
    await mobile.evaluate(()=>AshenGame.showScreen('party','companions'));await chooseCompanion(mobile,'sylvi');await loaded(mobile,'sylvi','neutral');
    assert(await mobile.evaluate(()=>{const image=document.querySelector('.companion-standing-art');return image.offsetHeight<=image.closest('.detail-body').clientHeight;}),width+' complete standing art fits detail body');
    await mobile.locator('[data-recruit=sylvi],[data-party=sylvi]').scrollIntoViewIfNeeded();assert(await mobile.locator('[data-recruit=sylvi],[data-party=sylvi]').isVisible());await mobile.screenshot({path:'artifacts/static-party-'+width+'x'+height+'.png'});await mobile.close();
  }checks.push('Dialogue and companion details remain usable at configured client sizes');
  if(url.startsWith('http')){
    const fallback=await create();await fallback.route('**/hero/static-v1/smile.webp*',r=>r.abort());await boot(fallback);await inject(fallback,'hero','smile');await loaded(fallback,'hero','neutral');assert.equal(await fallback.evaluate(()=>GameLoading.diagnostics().status),'ready');
    const missing=await create();await missing.route('**/hero/static-v1/**',r=>r.abort());await boot(missing);await inject(missing,'hero','smile');await missing.waitForFunction(()=>WorldAssets.inspect('url',CharacterPortraits.entries.hero.image)?.status==='failed');assert((await missing.locator('#portrait-fixture img').getAttribute('src')).includes('portraits/hero-256.png'));assert.equal(await missing.evaluate(()=>GameLoading.blocked()),false);checks.push('Missing expression falls back to neutral, missing character falls back to avatar without blocking');
    const slow=await create();let release;const pending=new Promise(r=>release=r);await slow.route('**/hero/static-v1/neutral.webp*',async r=>{await pending;await r.continue();});await boot(slow);
    await slow.evaluate(()=>{const original=window.setTimeout;window.setTimeout=(fn,ms,...args)=>original(fn,ms===45000?150:ms,...args);});await inject(slow,'hero','neutral');await slow.waitForFunction(()=>WorldAssets.inspect('url',CharacterPortraits.entries.hero.image)?.status==='failed');assert.equal(await slow.evaluate(()=>GameLoading.blocked()),false);release();await loaded(slow,'hero','neutral');checks.push('Delayed portrait recovers after timeout without opening the scene error screen');
    const stale=await create();let deliver;const waiting=new Promise(r=>deliver=r);await stale.route('**/hero/static-v1/serious.webp*',async r=>{await waiting;await r.continue();});await boot(stale);await inject(stale,'hero','serious');await inject(stale,'toren','smile');await loaded(stale,'toren','smile');deliver();await stale.waitForFunction(()=>WorldAssets.inspect('url',CharacterPortraits.entries.hero.images.serious)?.status==='ready');assert.equal(await stale.locator('#portrait-fixture img').getAttribute('data-standing-id'),'toren');checks.push('A late previous portrait cannot replace the current speaker');
  }
  assert.deepEqual(errors,[]);fs.writeFileSync('artifacts/static-portraits-acceptance.json',JSON.stringify({url,checks,totalBytes:total,errors,passed:true},null,2));await browser.close();console.log('PASS '+checks.join('\nPASS '));
})().catch(async e=>{console.error(e);await browser?.close();process.exitCode=1;});
