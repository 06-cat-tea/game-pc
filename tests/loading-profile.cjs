// Cold-cache startup measurements using an isolated browser and fixed network.
const fs=require('node:fs'),path=require('node:path');
const {chromium}=require('playwright');
const url=process.argv[2]||'file:///'+path.resolve('frontier.html').replaceAll('\\','/'),label=process.argv[3]||'current';
(async()=>{
  const browser=await chromium.launch({executablePath:process.env.CHROME_PATH,headless:true});
  const page=await browser.newPage({viewport:{width:1280,height:720}}),cdp=await page.context().newCDPSession(page),requested=[];
  await cdp.send('Network.enable');await cdp.send('Network.setCacheDisabled',{cacheDisabled:true});
  await cdp.send('Network.emulateNetworkConditions',{offline:false,latency:80,downloadThroughput:2*1024*1024,uploadThroughput:1024*1024});
  page.on('request',r=>requested.push(r.url()));
  const start=performance.now();await page.goto(url,{waitUntil:'domcontentloaded'});await page.waitForFunction(()=>window.GameLoading&&!GameLoading.blocked());
  const capture=async()=>page.evaluate(()=>({resources:performance.getEntriesByType('resource').map(r=>({url:r.name,bytes:r.decodedBodySize})),loading:GameLoading.diagnostics()}));
  const title={ms:Math.round(performance.now()-start),...await capture(),requests:requested.length};
  await page.locator('[data-command=continue]').click();await page.waitForFunction(()=>!GameLoading.blocked());
  const world={ms:Math.round(performance.now()-start),...await capture(),requests:requested.length};
  const result={label,url,network:'2 MiB/s, 80 ms latency, cold browser cache',title,world};
  for(const value of [title,world])value.bytes=value.resources.reduce((n,r)=>n+r.bytes,0);
  fs.mkdirSync('artifacts',{recursive:true});fs.writeFileSync('artifacts/loading-profile-'+label+'.json',JSON.stringify(result,null,2));
  console.log(JSON.stringify({label,title:{ms:title.ms,requests:title.requests,bytes:title.bytes},world:{ms:world.ms,requests:world.requests,bytes:world.bytes}}));await browser.close();
})().catch(e=>{console.error(e);process.exit(1);});
