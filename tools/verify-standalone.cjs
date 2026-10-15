// Run through `pnpm run test:standalone` so the package manager is discoverable.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'..'),manager=process.env.npm_execpath;
if(!manager){console.error('Run this check with pnpm run test:standalone');process.exit(1);}
const temp=fs.mkdtempSync(path.join(os.tmpdir(),'ashen-frontier-'));
const excluded=new Set(['node_modules','.git','artifacts','.cache','.pnpm-store']);
function run(file,args){const r=spawnSync(file,args,{cwd:temp,env:process.env,stdio:'inherit'});if(r.error)throw r.error;if(r.status!==0)throw Error('Standalone check failed: '+args.join(' '));}
try{
  fs.cpSync(root,temp,{recursive:true,filter:file=>!path.relative(root,file).split(path.sep).some(p=>excluded.has(p))});
  const store=spawnSync(process.execPath,[manager,'store','path'],{cwd:root,env:process.env,encoding:'utf8'});
  if(store.status!==0)throw Error('Cannot locate the package store for offline installation');
  const storeRoot=path.dirname(store.stdout.trim());
  run(process.execPath,[manager,'install','--offline','--frozen-lockfile','--ignore-scripts','--store-dir',storeRoot]);
  run(process.execPath,['tools/build-game.cjs']);
  run(process.execPath,['tests/client-acceptance.cjs']);
  run(process.execPath,['tests/static-acceptance.cjs']);
  fs.mkdirSync(path.join(root,'artifacts'),{recursive:true});
  fs.writeFileSync(path.join(root,'artifacts/standalone-acceptance.json'),JSON.stringify({
    project:require('../client.json').id,temp,passed:true,
    checks:['independent file copies','offline frozen dependency install','local build','file:// game and UI acceptance','independent static-site acceptance']
  },null,2));
  console.log('PASS standalone copy, offline install, build and file:// acceptance');
}finally{
  const resolved=path.resolve(temp),base=path.resolve(os.tmpdir());
  if(path.dirname(resolved)!==base||!path.basename(resolved).startsWith('ashen-frontier-'))throw Error('Unexpected temporary directory');
  fs.rmSync(resolved,{recursive:true,force:true});
}
