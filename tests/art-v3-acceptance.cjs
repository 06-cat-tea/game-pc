const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const sharp=require('sharp'),{chromium}=require('playwright');
let activeBrowser;
const url=process.argv[2]||'file:///'+path.resolve('frontier.html').replaceAll('\\','/'),out='artifacts/art-v3';
(async()=>{
 fs.mkdirSync(out,{recursive:true});const c=JSON.parse(fs.readFileSync('assets/art-v3/catalog.json')),prompts=JSON.parse(fs.readFileSync('assets/art-v3/prompts.json')),checks=[],errors=[];
 for(const [kind,count]of Object.entries({buildings:11,environment:12,terrain:5,scenes:14,equipment:38,loading:6}))assert.equal(Object.keys(c[kind]).length,count,kind+' generated coverage');
 assert.equal(prompts.jobs.length,86);assert.equal(new Set(prompts.jobs.map(j=>j.key)).size,86);
 for(const j of prompts.jobs){const e=c[j.kind][j.id];assert(fs.existsSync(e.url),j.key+' runtime');assert(fs.existsSync('assets/art-v3/'+c.sources[j.key].file),j.key+' original');const m=await sharp(e.url).metadata();assert.equal(m.width,e.width);assert.equal(m.height,e.height);assert.equal(m.format,'webp');if(j.transparent){assert(m.hasAlpha,j.key+' alpha');const {data,info}=await sharp(e.url).ensureAlpha().raw().toBuffer({resolveWithObject:true});let transparent=0,opaque=0;for(let i=3;i<data.length;i+=info.channels){if(data[i]<10)transparent++;if(data[i]>240)opaque++;}assert(transparent>info.width*info.height*.02&&opaque>info.width*info.height*.05,j.key+' real cutout');}else if(j.kind!=='terrain')assert.equal(m.width/m.height,16/9);}
 checks.push('86 individually generated originals, exact coverage, real alpha and runtime dimensions');
 const browser=activeBrowser=await chromium.launch({executablePath:process.env.CHROME_PATH,headless:true});
 const ready=p=>p.waitForFunction(()=>window.GameLoading&&!GameLoading.blocked()&&GameLoading.diagnostics().status==='ready',null,{timeout:90000});
 async function boot(options={}){const p=await browser.newPage({viewport:{width:1280,height:720},...options});p.on('pageerror',e=>errors.push(e.message));await p.goto(url);await ready(p);await p.evaluate(()=>AshenGame.command('continue'));await ready(p);return p;}
 const p=await boot();
 assert(await p.evaluate(()=>BuildingSystem.at('town').every(b=>b.artId==='town-'+b.id)&&BuildingSystem.at('city').every(b=>!b.artId)&&['wood','pass','fen','coast'].every(place=>BuildingSystem.at(place).every(b=>!b.artId))));
 assert(await p.evaluate(()=>BuildingSystem.at('town').every(b=>{const r=PixelWorld.buildingRect(b),e=ArtCatalog.buildings[b.artId];return Math.abs(r.h/r.w-e.height/e.width)<1e-8&&e.footprint[0]===b.w&&e.footprint[1]===b.d;})));
 checks.push('Town-specific identity, aspect ratio and footprint; other five regions retain v2 art');
 await p.evaluate(()=>{const s=AshenGame.getState();s.sceneProgress['town-wall:survey']=true;s.sceneProgress['town-drain:survey']=true;localStorage.setItem('ashen-frontier-save-v3-desktop',JSON.stringify(s));AshenGame.command('load');});await ready(p);
 for(const b of await p.evaluate(()=>BuildingSystem.at('town').map(b=>({id:b.id,scene:'room-'+b.id})))){
  const before=await p.evaluate(()=>({state:AshenGame.getState(),position:PixelWorld.getPosition()}));
  await p.evaluate(id=>AshenGame.enterBuilding(id),b.id);await ready(p);assert.equal(await p.evaluate(()=>AshenGame.getState().location.sceneId),b.scene);
  const props=await p.evaluate(()=>{const r=PixelWorld.getInterior();return r.props.map(v=>({id:v.id,blocked:WorldRegions.blocked('town',v.x,v.y,r.sceneId),action:v.action}));});
  assert(props.filter(x=>!['portal','encounter','event'].includes(x.action)).every(x=>x.blocked));
  await p.screenshot({path:out+'/scene-'+b.scene+'.png'});
  assert(await p.evaluate(()=>{const r=PixelWorld.getInterior();return !WorldRegions.blocked('town',r.exit.x,r.exit.y,r.sceneId)&&r.background.startsWith('assets/art-v3/')&&WorldAssets.inspect('expansion',r.sceneId).status==='ready';}));
  await p.evaluate(()=>AshenGame.leaveBuilding());await ready(p);assert.equal(await p.evaluate(()=>AshenGame.getState().location.sceneId),null);
  const after=await p.evaluate(()=>AshenGame.getState());assert.equal(after.player.gold,before.state.player.gold);assert.equal(after.storyStage,before.state.storyStage);
 }
 for(const id of ['town-wall','town-drain','town-trial']){await p.evaluate(id=>AshenGame.enterScene(id),id);await ready(p);assert.equal(await p.evaluate(()=>AshenGame.getState().location.sceneId),id);await p.screenshot({path:out+'/scene-'+id+'.png'});await p.evaluate(()=>AshenGame.leaveBuilding());await ready(p);}
 checks.push('All 11 interiors and 3 route maps: background, collisions, exit and retained progression');
 for(const place of ['wood','pass','fen','coast','city','town']){await p.evaluate(place=>AshenGame.travel(place),place);await ready(p);assert.equal(await p.locator('#gameLoading').getAttribute('data-loading-place'),place);assert(await p.evaluate(place=>document.querySelector('#gameLoading').style.getPropertyValue('--loading-art').includes('/loading/'+place+'.webp'),place));assert(await p.locator('#gameLoading').evaluate((el,place)=>getComputedStyle(el).backgroundImage.includes('/loading/'+place+'.webp'),place),'actual rendered loading backdrop '+place);assert.equal(await p.evaluate(place=>WorldAssets.inspect('loading',place).status,place),'ready');assert.equal(await p.evaluate(()=>GameLoading.diagnostics().failed.length),0);}
 await p.evaluate(()=>{AshenGame.travel('wood');AshenGame.travel('coast');});await ready(p);assert.equal(await p.evaluate(()=>GameLoading.diagnostics().key),'coast:outdoor');assert((await p.locator('#gameLoading').getAttribute('style')).includes('coast.webp'));
 checks.push('Six matching regional loading backgrounds and newest destination wins');
 await p.evaluate(()=>{AshenGame.travel('town');});await ready(p);
 const initial=await p.evaluate(()=>AshenGame.getState());
 await p.evaluate(()=>AshenGame.showScreen('codex','lore'));assert(!await p.locator('#screen-codex').innerText().then(x=>x.includes('补全星图之后')));assert(await p.locator('[data-ui-select="border-history"]').count());
 await p.evaluate(()=>{const s=AshenGame.getState();s.storyStage=8;s.inventory.owned=Object.keys(GameData.ITEMS);localStorage.setItem('ashen-frontier-save-v3-desktop',JSON.stringify(s));AshenGame.command('load');});await ready(p);
 assert(await p.evaluate(()=>WorldLore.visible(AshenGame.getState()).some(e=>e.id==='returning')));
 await p.evaluate(()=>AshenGame.showScreen('inventory'));assert(await p.locator('[data-item-art]').count());
 const ids=await p.evaluate(()=>Object.keys(GameData.ITEMS));for(const id of ids){await p.evaluate(id=>{GameUI.views.inventory.selected=id;GameUI.render();},id);const detail=p.locator('.detail-heading [data-item-art="'+id+'"]');await detail.waitFor();await detail.evaluate(i=>i.decode());assert.equal(await detail.getAttribute('data-item-fallback'),null,id+' unique image');}
 await p.evaluate(()=>AshenGame.showScreen('crafting','craft'));assert(await p.locator('.entry-select [data-item-art]').count());await p.evaluate(()=>AshenGame.showScreen('crafting','enhance'));assert(await p.locator('.detail-heading [data-item-art]').count());
 checks.push('38 unique equipment icons in inventory, slots, crafting and enhancement; lore gated by story stage');
 await p.evaluate(()=>{AshenGame.showScreen('adventure');PixelWorld.restoreLocation({x:25,y:29,zoom:1.25});});await p.waitForTimeout(350);await p.screenshot({path:out+'/town-after.png'});
 for(const [width,height,touch]of require('./client-fixture.cjs').viewports){const q=await boot({viewport:{width,height},hasTouch:touch,isMobile:touch});await q.evaluate(()=>AshenGame.showScreen('codex','lore'));await q.screenshot({path:out+'/lore-'+width+'x'+height+'.png'});await q.evaluate(()=>AshenGame.showScreen('inventory'));await q.screenshot({path:out+'/inventory-'+width+'x'+height+'.png'});assert(await q.evaluate(()=>{const r=document.querySelector('#gameViewport').getBoundingClientRect();return r.width<=innerWidth+1&&r.height<=innerHeight+1;}));await q.close();}
 checks.push('Configured client viewports, rotated portrait screens, accessible lore and item actions');
 if(url.startsWith('http')){
  const q=await browser.newPage({viewport:{width:1280,height:720}});q.on('pageerror',e=>errors.push(e.message));await q.route('**/art-v3/loading/wood.webp*',r=>r.abort());await q.route('**/art-v3/equipment/sword.webp*',r=>r.abort());await q.goto(url);await ready(q);await q.evaluate(()=>AshenGame.command('continue'));await ready(q);await q.evaluate(()=>AshenGame.travel('wood'));await ready(q);assert.equal(await q.evaluate(()=>GameLoading.diagnostics().failed.length),0);assert.equal(await q.locator('#gameLoading').evaluate(el=>el.style.getPropertyValue('--loading-art')),'');await q.evaluate(()=>AshenGame.showScreen('inventory'));await q.waitForFunction(()=>document.querySelector('[data-item-art="sword"]')?.dataset.itemFallback==='true');assert(await q.locator('.entry-select[data-ui-select="sword"]').isEnabled());await q.close();
  checks.push('Missing loading artwork uses common backdrop; missing item artwork retains interactive fallback');
 }
 await p.close();await browser.close();assert.deepEqual(errors,[]);const report={passed:true,url,checks,errors,counts:Object.fromEntries(['buildings','environment','terrain','scenes','equipment','loading'].map(k=>[k,Object.keys(c[k]).length]))};fs.writeFileSync(out+'/acceptance-'+(url.startsWith('http')?'http':'file')+'.json',JSON.stringify(report,null,2));checks.forEach(c=>console.log('PASS '+c));
})().catch(async e=>{console.error(e);if(activeBrowser)await activeBrowser.close();process.exitCode=1;});
