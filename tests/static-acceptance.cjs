// Serve only this project, as if deployed at the root of an independent site.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const {id,mobile}=require('../client.json'),root=path.resolve(__dirname,'..');
let browser,server;
(async()=>{
  const types={'.html':'text/html; charset=utf-8','.css':'text/css; charset=utf-8','.js':'text/javascript; charset=utf-8','.png':'image/png','.webp':'image/webp','.svg':'image/svg+xml','.json':'application/json'};
  server=http.createServer((req,res)=>{
    let file;try{const name=decodeURIComponent(new URL(req.url,'http://localhost').pathname);file=path.resolve(root,'.'+(name==='/'?'/index.html':name));}catch{res.writeHead(400).end();return;}
    if(!file.startsWith(root+path.sep)){res.writeHead(403).end();return;}
    fs.readFile(file,(error,data)=>{if(error){res.writeHead(404).end();return;}res.writeHead(200,{'Content-Type':types[path.extname(file)]||'application/octet-stream'}).end(data);});
  });
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const base='http://127.0.0.1:'+server.address().port;
  browser=await chromium.launch({headless:true,executablePath:process.env.CHROME_PATH});
  const p=await browser.newPage({viewport:{width:1280,height:720},hasTouch:mobile,isMobile:mobile}),errors=[],requests=[];
  p.on('pageerror',e=>errors.push(e.message));p.on('request',r=>requests.push(r.url()));
  p.on('response',r=>{if(r.status()>=400)errors.push(r.status()+' '+r.url());});
  const ready=()=>p.waitForFunction(()=>window.GameLoading&&!GameLoading.blocked(),null,{timeout:60000});
  await p.goto(base+'/');await ready();assert.equal(await p.evaluate(()=>GameClient.id),id);
  await p.locator('[data-command=continue]').click();await ready();
  await p.evaluate(()=>AshenGame.travel('city'));await ready();
  await p.evaluate(()=>AshenGame.showScreen('codex','map'));assert(await p.locator('#circleMap').isVisible());
  assert(requests.every(url=>url.startsWith(base+'/')||url.startsWith('data:')||url.startsWith('blob:')));
  assert.deepEqual(errors,[]);fs.mkdirSync('artifacts',{recursive:true});
  fs.writeFileSync('artifacts/static-acceptance.json',JSON.stringify({id,passed:true,requests:requests.length},null,2));
  await browser.close();await new Promise(resolve=>server.close(resolve));console.log('PASS independent static-site entry, resources, exploration and map');
})().catch(async error=>{console.error(error);await browser?.close();server?.close();process.exitCode=1;});
