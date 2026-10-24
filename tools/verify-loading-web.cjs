// Exercise the real exported bootstrap while delaying the actual PCK request.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),{once}=require('node:events');
const {chromium}=require('playwright'),sharp=require('sharp'),{startServer}=require('./serve-godot-web.cjs');
const root=path.resolve(__dirname,'..'),out=path.join(root,'artifacts/godot/loading-web-review');fs.mkdirSync(out,{recursive:true});
const checks=[],errors=[];let browser,server;
const check=(value,name)=>{assert(value,name);checks.push(name);console.log('PASS '+name);};
async function snapshot(page,name){await page.screenshot({path:path.join(out,name+'.png')});}
async function hold(context,options={}){
 const page=await context.newPage();let unlock;const gate=new Promise(resolve=>{unlock=resolve;});
 page.on('pageerror',error=>errors.push(error.message));
 await page.route('**/*.pck',async route=>{await gate;if(!page.isClosed())await route.continue().catch(()=>{});});
 if(options.missingImages)await page.route('**/loading-art/*.webp',route=>route.fulfill({status:404,body:''}));
 if(options.failPackage){await page.unroute('**/*.pck');await page.route('**/*.pck',route=>route.abort('failed'));}
 const url=process.argv.find(v=>v.startsWith('--url='))?.slice(6)||'http://127.0.0.1:'+server.address().port+'/game-pc/';
 await page.goto(url,{waitUntil:'domcontentloaded',timeout:60000});
 return {page,unlock,url};
}
async function main(){
 server=await startServer();browser=await chromium.launch({channel:'chrome',headless:true,args:['--enable-unsafe-swiftshader','--disable-dev-shm-usage']});
 const context=await browser.newContext({viewport:{width:1280,height:720}});
 const held=await hold(context),page=held.page;
 await page.waitForFunction(()=>document.querySelector('#status').dataset.imageKey&&document.querySelector('.loading-art.visible').naturalWidth>0,null,{timeout:30000});
 const catalog=await page.locator('#loading-catalog').textContent();const config=JSON.parse(catalog);
 check(config.images.length===10&&config.tips.length===30,'首次下载前即可读取10张画面与30条提示');
 const first=await page.locator('#status').getAttribute('data-image-key'),firstTip=await page.locator('#status').getAttribute('data-tip-id');
 for(const [width,height]of [[1280,720],[1920,1080],[3840,2160]]){
  await page.setViewportSize({width,height});await page.waitForTimeout(150);
  const valid=await page.evaluate(()=>['.brand','.loading-content','#tip','#message','#progress','#picture-title'].every(selector=>{const r=document.querySelector(selector).getBoundingClientRect();return r.x>=0&&r.y>=0&&r.right<=innerWidth+1&&r.bottom<=innerHeight+1;}));
  check(valid,'网页加载页布局 '+width+'×'+height);await snapshot(page,'bootstrap-'+width+'x'+height);
 }
 await page.waitForFunction(old=>document.querySelector('#status').dataset.tipId!==old,firstTip,{timeout:10000});
 check(true,'6秒轮换提示');
 await page.waitForFunction(old=>document.querySelector('#status').dataset.imageKey!==old,first,{timeout:12000});await page.waitForTimeout(700);
 check(true,'8秒轮换已解码画面，不连续重复');await snapshot(page,'bootstrap-rotated');
 check(await page.locator('#status').isVisible(),'画面轮播不伪装为游戏资源已加载完成');
 await page.close();held.unlock();await context.close();
 const reducedContext=await browser.newContext({viewport:{width:1280,height:720},reducedMotion:'reduce'});
 const reduced=await hold(reducedContext);await reduced.page.waitForFunction(()=>document.querySelector('#status').dataset.imageKey);
 const reducedImage=await reduced.page.locator('#status').getAttribute('data-image-key'),reducedTip=await reduced.page.locator('#status').getAttribute('data-tip-id');
 await reduced.page.waitForTimeout(8500);
 check(await reduced.page.locator('#status').getAttribute('data-image-key')===reducedImage,'减少动效固定背景');
 check(await reduced.page.locator('#status').getAttribute('data-tip-id')!==reducedTip,'减少动效仍更新文字提示');
 await snapshot(reduced.page,'reduced-motion');await reduced.page.close();reduced.unlock();await reducedContext.close();
 const missingContext=await browser.newContext({viewport:{width:1280,height:720}});const missing=await hold(missingContext,{missingImages:true});
 await missing.page.waitForTimeout(2000);
 check(await missing.page.locator('#tip').textContent()!==''&&await missing.page.locator('#status').isVisible(),'插画全部失败时纯色背景与提示可用');
 check(await missing.page.locator('#retry').isHidden(),'可选插画失败不阻断游戏下载');await snapshot(missing.page,'missing-art');await missing.page.close();missing.unlock();await missingContext.close();
 const errorContext=await browser.newContext({viewport:{width:1280,height:720}});const broken=await hold(errorContext,{failPackage:true});
 await broken.page.waitForFunction(()=>document.documentElement.dataset.gameState==='error',null,{timeout:30000});
 check(await broken.page.locator('#retry').isVisible()&&await broken.page.locator('#status').getAttribute('data-rotating')==='false','下载失败保留错误与重试并停止轮播');await snapshot(broken.page,'download-error');
 await broken.page.unroute('**/*.pck');await broken.page.locator('#retry').click();
 await broken.page.waitForFunction(()=>document.documentElement.dataset.gameState==='ready',null,{timeout:180000});
 check(await broken.page.locator('#status').isHidden()&&await broken.page.locator('#status').getAttribute('data-rotating')==='false','重试成功后进入游戏并停止网页轮播');
 const stoppedTip=await broken.page.locator('#status').getAttribute('data-tip-id');await broken.page.waitForTimeout(6200);
 check(await broken.page.locator('#status').getAttribute('data-tip-id')===stoppedTip,'游戏启动后没有遗留的提示计时器');await snapshot(broken.page,'ready-after-retry');
 await errorContext.close();check(errors.length===0,'无未处理的页面脚本错误');
 const directory=path.join(root,'artifacts/godot/web/loading-art');
 for(const image of config.images){const file=path.join(directory,image.id+'.webp'),meta=await sharp(file).metadata();assert(meta.width===1600&&meta.height===900&&fs.statSync(file).size<=300*1024);}
 check(true,'10张独立预览图均为1600×900且每张不超过300KiB');
}
main().catch(error=>{errors.push(error.stack||error.message);console.error(error);process.exitCode=1;}).finally(async()=>{
 await browser?.close();if(server){server.close();server.closeAllConnections?.();await once(server,'close').catch(()=>{});}
 fs.writeFileSync(path.join(out,'report.json'),JSON.stringify({passed:!process.exitCode&&errors.length===0,checks,errors},null,2)+'\n');
});
