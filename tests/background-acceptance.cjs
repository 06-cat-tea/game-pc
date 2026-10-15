const fs=require('fs'),path=require('path'),assert=require('assert/strict');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const sharp=require(process.env.SHARP_MODULE||'sharp');
(async()=>{
 const url=process.argv[2]||'file:///'+path.resolve('frontier.html').replaceAll('\\','/'),browser=await chromium.launch({executablePath:process.env.CHROME_PATH,headless:true}),page=await browser.newPage({viewport:{width:1920,height:1080}}),errors=[],results=[];
 page.on('pageerror',e=>errors.push(e.message));await page.goto(url);await page.waitForFunction(()=>window.AshenGame);await page.evaluate(()=>AshenGame.command('continue'));
 for(const place of ['town','wood','pass','fen','coast','city']){
  await page.evaluate(place=>{AshenGame.travel(place);AshenGame.showScreen('adventure');SceneEnvironment.preload(place);},place);await page.waitForTimeout(1200);
  const check=await page.evaluate(async place=>{
   const map=document.querySelector('#hudMap'),c=map.getContext('2d'),clip=c.clip;let clipped=false;c.clip=function(...args){clipped=true;return clip.apply(this,args);};CircleMap.draw();c.clip=clip;
   const a=CircleMap.backdrop(place,100,1),b=CircleMap.backdrop(place,100,1),thumb=WorldTerrain.thumbnail(place),thumbAgain=WorldTerrain.thumbnail(place);
   const art=place!=='city'&&WorldAssets.ready('scenes',place),ctx=document.querySelector('#pixelWorld').getContext('2d'),original=ctx.drawImage;let paintedOriginal=false;ctx.drawImage=function(image,...args){if(image===art)paintedOriginal=true;return original.call(this,image,...args);};await new Promise(r=>setTimeout(r,120));ctx.drawImage=original;
   return {clipped,round:getComputedStyle(map).borderRadius==='50%',cached:a===b&&thumb===thumbAgain,paintedOriginal,scene:PixelWorld.assetDiagnostics().scene};
  },place);
  const mapImage=await page.locator('#hudMap').screenshot(),sample=await sharp(mapImage).resize(60,60).extract({left:15,top:15,width:30,height:30}).removeAlpha().raw().toBuffer(),colours=new Set();for(let i=0;i<sample.length;i+=3)colours.add(sample[i]+','+sample[i+1]+','+sample[i+2]);check.colours=colours.size;assert(check.colours>100,place+' scenic minimap');assert(check.clipped&&check.round);assert(check.cached);assert(!check.paintedOriginal);assert(check.scene);results.push({place,...check});
  await page.screenshot({path:'artifacts/environment-background-after-'+place+'.png'});await page.locator('#hudMap').screenshot({path:'artifacts/background-minimap-'+place+'.png'});
  const bounds=await page.evaluate(place=>WorldRegions.bounds(place),place);
  for(const [name,x,y,zoom]of [['edge',1,bounds.rows-2,1],['far-edge',bounds.columns-2,2,1.75]]){
   await page.evaluate(p=>PixelWorld.restoreLocation(p),{x,y,zoom});await page.waitForTimeout(130);
   // Screenshot pixels are also readable for file://, where local images taint Canvas readback.
   const pixels=await sharp(await page.locator('#pixelWorld').screenshot()).ensureAlpha().raw().toBuffer();let blank=0,holes=0;for(let i=0;i<pixels.length;i+=40){if(pixels[i+3]!==255)holes++;if(pixels[i]===38&&pixels[i+1]===62&&pixels[i+2]===50)blank++;}assert.equal(holes,0);assert(blank<30,place+' '+name+' solid background patch');await page.screenshot({path:'artifacts/background-'+place+'-'+name+'.png'});
  }
 }
 // Rebuilding a resource cache must refresh both generated and painted backdrops.
 assert(await page.evaluate(()=>{const a=CircleMap.backdrop('city',100,1),revision=WorldTerrain.revision;SceneEnvironment.invalidate();WorldTerrain.invalidate();CircleMap.invalidate();const b=CircleMap.backdrop('city',100,1);return a!==b&&WorldTerrain.revision>revision;}));
 await page.route('**/assets/art-v2/environment/**',r=>r.abort());await page.route('**/assets/world/scenes/**',r=>r.abort());await page.reload();await page.waitForFunction(()=>window.AshenGame);await page.evaluate(()=>{AshenGame.command('continue');AshenGame.travel('fen');AshenGame.showScreen('adventure');});
 await page.waitForFunction(()=>GameLoading.diagnostics().status==='failed');await page.locator('[data-loading-fallback]').click();await page.waitForFunction(()=>!GameLoading.blocked());
 assert(await page.evaluate(()=>{CircleMap.draw();return PixelWorld.assetDiagnostics().scene&&CircleMap.backdrop('fen',100,1).width===100;}));assert.deepEqual(errors,[]);
 await browser.close();
 const layers=[],places=['town','wood','pass','fen','coast','city'];for(let i=0;i<places.length;i++)for(let j=0;j<2;j++){const phase=j?'after':'before';layers.push({input:await sharp('artifacts/environment-background-'+phase+'-'+places[i]+'.png').resize(720,405).toBuffer(),left:j*720,top:i*435+30});layers.push({input:Buffer.from(`<svg width="720" height="30"><text x="15" y="21" font-family="Arial" font-size="18" fill="#eee4c8">${places[i]} / ${phase}</text></svg>`),left:j*720,top:i*435});}await sharp({create:{width:1440,height:2610,channels:4,background:'#182b23'}}).composite(layers).png().toFile('artifacts/background-comparison.png');
 fs.writeFileSync('artifacts/background-acceptance.json',JSON.stringify({url,regions:results,edges:12,cacheInvalidation:true,imageFailureFallback:true,errors,passed:true},null,2));console.log('PASS six continuous backgrounds, 12 camera edges/zoom views, scenic round maps, cache invalidation and failed-image fallback');
})().catch(e=>{console.error(e);process.exit(1);});
