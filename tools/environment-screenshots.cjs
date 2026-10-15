const fs=require('fs'),path=require('path');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
(async()=>{fs.mkdirSync('artifacts',{recursive:true});const browser=await chromium.launch({executablePath:process.env.CHROME_PATH,headless:true});const page=await browser.newPage({viewport:{width:1920,height:1080}});await page.goto(process.argv[3]||'file:///'+path.resolve('frontier.html').replaceAll('\\','/'));await page.waitForFunction(()=>window.AshenGame);await page.evaluate(()=>AshenGame.command('continue'));
 for(const place of ['town','wood','pass','fen','coast','city']){await page.evaluate(place=>{AshenGame.travel(place);AshenGame.showScreen('adventure');},place);await page.waitForTimeout(1800);await page.screenshot({path:'artifacts/environment-'+(process.argv[2]||'after')+'-'+place+'.png'});}
 if(process.argv[2]==='after'){
  await page.evaluate(()=>{AshenGame.travel('city');AshenGame.showScreen('adventure');});
  for(const [name,x,y]of [['bridge',62.5,42],['palace',48,18],['garden',80,42]]){await page.evaluate(({x,y})=>PixelWorld.restoreLocation({x,y,zoom:1.2}),{x,y});await page.waitForTimeout(800);await page.screenshot({path:'artifacts/environment-detail-'+name+'.png'});}
  await page.evaluate(()=>{AshenGame.travel('town');AshenGame.showScreen('adventure');const b=BuildingSystem.get('inn');PixelWorld.restoreLocation({x:b.x+b.w/2,y:b.y+b.d+1.4,zoom:1.3});});await page.waitForTimeout(700);await page.screenshot({path:'artifacts/environment-detail-facade.png'});
 }
 await browser.close();})().catch(e=>{console.error(e);process.exit(1);});
