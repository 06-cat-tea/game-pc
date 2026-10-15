const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const {chromium}=require('playwright');
const url=process.argv[2]||'file:///'+path.resolve('frontier.html').replaceAll('\\','/');
const out='artifacts/art-v3';
(async()=>{fs.mkdirSync(out,{recursive:true});const browser=await chromium.launch({executablePath:process.env.CHROME_PATH,headless:true});
 const page=await browser.newPage({viewport:{width:1920,height:1080}}),errors=[];page.on('pageerror',e=>errors.push(e.message));
 const ready=()=>page.waitForFunction(()=>window.GameLoading&&!GameLoading.blocked(),{timeout:90000});
 async function shot(before){if(before){const body=cp.execFileSync('git',['show','HEAD:js/game-bundle.js'],{maxBuffer:8*1024*1024});await page.route('**/js/game-bundle.js*',r=>r.fulfill({body,contentType:'text/javascript'}));}else await page.unroute('**/js/game-bundle.js*');
  await page.goto(url);await ready();await page.evaluate(()=>AshenGame.command('continue'));await ready();await page.evaluate(()=>{AshenGame.showScreen('adventure');PixelWorld.restoreLocation({x:25,y:29,zoom:1.25});});await page.waitForTimeout(600);await page.screenshot({path:out+'/town-'+(before?'before':'after')+'.png'});
  await page.evaluate(()=>PixelWorld.restoreLocation({x:21.5,y:32,zoom:1.6}));await page.waitForTimeout(350);await page.screenshot({path:out+'/inn-'+(before?'before':'after')+'.png'});
 }
 await shot(true);await page.evaluate(()=>localStorage.clear());await shot(false);console.log(JSON.stringify({errors}));await browser.close();if(errors.length)process.exitCode=1;
})().catch(e=>{console.error(e);process.exitCode=1;});
