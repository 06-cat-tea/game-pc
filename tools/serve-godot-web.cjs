const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

const defaultRoot = path.resolve(__dirname, '../artifacts/godot/web');
const mime = {'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png','.svg':'image/svg+xml','.ico':'image/x-icon','.txt':'text/plain; charset=utf-8','.json':'application/json; charset=utf-8'};

async function startServer({root=defaultRoot,port=0,host='127.0.0.1'}={}) {
  root = path.resolve(root);
  const server = http.createServer((request,response) => {
    let relative;
    try { relative = decodeURIComponent(new URL(request.url, 'http://localhost').pathname); }
    catch { response.writeHead(400).end(); return; }
    if (relative.includes('\0')) { response.writeHead(400).end(); return; }
    if (relative === '/game-pc') { response.writeHead(302,{Location:'/game-pc/'}).end(); return; }
    relative = relative.replace(/^\/game-pc\//,'/');
    const filename = path.resolve(root, '.' + (relative.endsWith('/') ? relative+'index.html' : relative));
    if (!filename.startsWith(root+path.sep)) { response.writeHead(403).end(); return; }
    fs.stat(filename,(error,stat) => {
      if (error || !stat.isFile()) { response.writeHead(404).end('Not found'); return; }
      const headers = {'Content-Type':mime[path.extname(filename)]||'application/octet-stream','Content-Length':stat.size,'Cache-Control':'no-cache','X-Content-Type-Options':'nosniff'};
      response.writeHead(200,headers);
      if (request.method === 'HEAD') response.end();
      else fs.createReadStream(filename).pipe(response);
    });
  });
  await new Promise((resolve,reject) => { server.once('error',reject); server.listen(port,host,resolve); });
  return server;
}
module.exports={startServer};
if(require.main===module) startServer({port:Number(process.env.PORT||8060)}).then(server=>console.log('Godot Web preview: http://127.0.0.1:'+server.address().port+'/game-pc/'));
