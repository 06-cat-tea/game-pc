const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),{spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'..'),project=path.join(root,'godot');
const verificationEnv={...process.env,APPDATA:path.join(root,'artifacts/godot/test-profile'),XDG_DATA_HOME:path.join(root,'artifacts/godot/test-profile')};
const webBuildEnv={...process.env,APPDATA:path.join(root,'artifacts/godot/web-build-profile'),XDG_DATA_HOME:path.join(root,'artifacts/godot/web-build-profile')};
function engine(){
  if(process.env.GODOT_PATH&&fs.existsSync(process.env.GODOT_PATH))return process.env.GODOT_PATH;
  const local=path.join(root,'artifacts/godot/engine/godot.exe');if(fs.existsSync(local))return local;
  for(const name of ['godot','godot4']){const found=spawnSync(process.platform==='win32'?'where.exe':'which',[name],{encoding:'utf8',windowsHide:true});if(found.status===0)return found.stdout.trim().split(/\r?\n/)[0];}
  if(process.platform==='win32'){
    const reg=spawnSync('reg.exe',['query','HKCU\\Software\\Valve\\Steam','/v','SteamPath'],{encoding:'utf8',windowsHide:true});
    const steam=reg.stdout?.match(/SteamPath\s+REG_SZ\s+(.+)/)?.[1]?.trim();
    if(steam){const candidate=path.join(steam,'steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe');if(fs.existsSync(candidate))return candidate;}
  }
  throw Error('Godot 4.7.2 not found. Set GODOT_PATH to the engine executable.');
}
function run(args,options={}){const {verifyOutput,...rest}=options;const r=spawnSync(engine(),args,{cwd:project,stdio:verifyOutput?'pipe':'inherit',encoding:verifyOutput?'utf8':undefined,windowsHide:true,...rest});if(verifyOutput){if(r.stdout)process.stdout.write(r.stdout);if(r.stderr)process.stderr.write(r.stderr);}if(r.error)throw r.error;if(r.status!==0||verifyOutput&&/SCRIPT ERROR:|^ERROR:/m.test((r.stdout||'')+(r.stderr||'')))throw Error('Godot check failed; exit '+r.status);return r;}
const command=process.argv[2]||'run';
if(command==='run')run(['--path',project,...process.argv.slice(3)]);
else if(command==='editor')run(['--editor','--path',project]);
else if(command==='balance')run(['--headless','--path',project,'--script','res://tests/strategy_balance.gd'],{verifyOutput:true,env:verificationEnv});
else if(command==='import')run(['--headless','--editor','--import','--recovery-mode','--path',project]);
else if(command==='test'){run(['--headless','--editor','--import','--recovery-mode','--path',project],{env:verificationEnv});run(['--headless','--path',project,'--script','res://tests/test_suite.gd'],{verifyOutput:true,env:{...verificationEnv,ASHEN_REPORT:path.join(root,'artifacts/godot/native-acceptance.json')}});}
else if(command==='build-web'){
 const version=spawnSync(engine(),['--version'],{encoding:'utf8',windowsHide:true});
 if(version.status!==0||!/^4\.7\.2\.stable\./.test(version.stdout.trim()))throw Error('Web release requires Godot 4.7.2 stable and matching export templates.');
 // Isolating user:// also changes Godot's template lookup on non-portable engines.
 // Copy the installed Web templates into that build profile, never player saves.
 const engineDirectory=path.dirname(engine());
 const portable=['._sc_','_sc_'].some(name=>fs.existsSync(path.join(engineDirectory,name)));
 if(!portable&&process.platform!=='darwin'){
  const installedRoot=process.platform==='win32'?path.join(process.env.APPDATA||path.join(os.homedir(),'AppData/Roaming'),'Godot'):path.join(process.env.XDG_DATA_HOME||path.join(os.homedir(),'.local/share'),'godot');
  const isolatedRoot=process.platform==='win32'?path.join(webBuildEnv.APPDATA,'Godot'):path.join(webBuildEnv.XDG_DATA_HOME,'godot');
  const templates=path.join(isolatedRoot,'export_templates','4.7.2.stable');fs.mkdirSync(templates,{recursive:true});
  for(const name of ['web_nothreads_debug.zip','web_nothreads_release.zip']){
   const from=path.join(installedRoot,'export_templates','4.7.2.stable',name),to=path.join(templates,name);
   if(fs.existsSync(from)&&path.resolve(from)!==path.resolve(to))fs.copyFileSync(from,to);
   if(!fs.existsSync(to))throw Error('Install the official Godot 4.7.2 Web templates first: '+from);
  }
 }
 const destination=path.join(root,'artifacts/godot/web');fs.mkdirSync(destination,{recursive:true});
 run(['--headless','--editor','--import','--recovery-mode','--path',project],{verifyOutput:true,env:webBuildEnv});
 run(['--headless','--recovery-mode','--path',project,'--export-release','Web',path.join(destination,'index.html')],{verifyOutput:true,env:webBuildEnv});
 const prepared=spawnSync(process.execPath,[path.join(root,'tools/build-loading-web.cjs'),destination],{cwd:root,env:process.env,stdio:'inherit',windowsHide:true});if(prepared.status!==0)throw Error('Cannot build Web loading carousel');
 const licenses=[['LICENSE-Game-CC0.txt','游戏 · CC0'],['LICENSE-Godot.txt','Godot 引擎 · MIT'],['LICENSE-Icons-CC-BY-3.0.txt','图标 · CC BY 3.0 及作者署名'],['LICENSE-ThirdParty-CC0.txt','第三方素材 · CC0'],['assets/fonts/OFL.txt','字体 · OFL'],['assets/fonts/NotoSerifSC-OFL.txt','HUD 宋体 · OFL']];
 const links=licenses.map(([from,title])=>{const to=path.basename(from)==='OFL.txt'?'LICENSE-Font-OFL.txt':path.basename(from);fs.copyFileSync(path.join(project,from),path.join(destination,to));return '<li><a href="'+to+'">'+title+'</a></li>';}).join('');
 fs.writeFileSync(path.join(destination,'licenses.html'),'<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>许可与署名</title><link rel="icon" href="index.icon.png"><style>body{max-width:800px;margin:60px auto;padding:24px;font:18px/1.8 system-ui;background:#101925;color:#eee9dd}a{color:#dfc99b}</style><h1>灰烬边境：星陨纪事</h1><h2>许可与署名</h2><ul>'+links+'</ul><p><a href="./">返回游戏</a></p></html>');
 fs.writeFileSync(path.join(destination,'frontier.html'),'<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta http-equiv="refresh" content="0; url=./"><title>灰烬边境</title><a href="./">进入 Godot 网页版</a></html>');
 fs.writeFileSync(path.join(destination,'.nojekyll'),'');
 const listing=directory=>fs.readdirSync(directory,{withFileTypes:true}).flatMap(entry=>entry.isDirectory()?listing(path.join(directory,entry.name)):[{name:path.relative(destination,path.join(directory,entry.name)).replaceAll('\\','/'),bytes:fs.statSync(path.join(directory,entry.name)).size}]);
 const files=listing(destination);
 if(files.reduce((sum,file)=>sum+file.bytes,0)>=1024**3)throw Error('Web release exceeds the GitHub Pages 1 GB limit.');
 for(const name of ['index.html','index.js','index.wasm','index.pck'])if(!files.some(file=>file.name===name&&file.bytes>0))throw Error('Missing Web export: '+name);
 const html=fs.readFileSync(path.join(destination,'index.html'),'utf8');if(/\$GODOT_/.test(html))throw Error('Unresolved HTML export placeholders.');
 fs.writeFileSync(path.join(root,'artifacts/godot/web-build.json'),JSON.stringify({passed:true,engine:version.stdout.trim(),files,totalBytes:files.reduce((sum,file)=>sum+file.bytes,0)},null,2));
 console.log('Web release: '+destination);
}
else if(command==='build'){
 if(process.platform==='win32'){
  const guard='$ErrorActionPreference="Stop"; if (@(Get-Process -Name "灰烬边境" -ErrorAction SilentlyContinue | Where-Object { [string]::IsNullOrEmpty($_.Path) -or $_.Path -eq $env:ASHEN_BUILD_TARGET }).Count -gt 0) { exit 3 }';
  const checked=spawnSync(path.join(process.env.SystemRoot,'System32/WindowsPowerShell/v1.0/powershell.exe'),['-NoProfile','-EncodedCommand',Buffer.from(guard,'utf16le').toString('base64')],{encoding:'utf8',windowsHide:true,env:{...process.env,ASHEN_BUILD_TARGET:path.join(root,'artifacts/godot/windows/灰烬边境.exe')}});
  if(checked.status===3)throw Error('游戏仍在运行。请先正常退出，再构建；不能覆盖正在使用的 PCK。');
  if(checked.error||checked.status!==0)throw Error('Cannot check whether the release is running: '+(checked.stderr||checked.error));
 }
 const destination=path.join(root,'artifacts/godot/windows');fs.mkdirSync(destination,{recursive:true});run(['--headless','--editor','--import','--recovery-mode','--path',project]);run(['--headless','--recovery-mode','--path',project,'--export-release','Windows Desktop',path.join(destination,'灰烬边境.exe')]);
 for(const [from,to] of [['WINDOWS-README.txt','README.txt'],['LICENSE-Game-CC0.txt','LICENSE-Game-CC0.txt'],['LICENSE-Godot.txt','LICENSE-Godot.txt'],['LICENSE-Icons-CC-BY-3.0.txt','LICENSE-Icons-CC-BY-3.0.txt'],['LICENSE-ThirdParty-CC0.txt','LICENSE-ThirdParty-CC0.txt'],['assets/fonts/OFL.txt','LICENSE-Font-OFL.txt'],['assets/fonts/NotoSerifSC-OFL.txt','LICENSE-Font-Serif-OFL.txt']])fs.copyFileSync(path.join(project,from),path.join(destination,to));
 for(const name of fs.readdirSync(destination))if(/^灰烬边境\.exe~RF[\da-f]+\.TMP$/i.test(name)){
  const temporary=path.join(destination,name);
  try{fs.rmSync(temporary);}catch(error){if(!['EPERM','EACCES','EBUSY'].includes(error.code))throw error;const holding=path.join(root,'artifacts/backups/export-residue');fs.mkdirSync(holding,{recursive:true});fs.renameSync(temporary,path.join(holding,Date.now()+'-'+name));}
 }
}else if(command==='standalone'){
 const checks=path.join(root,'artifacts/godot/isolated-checks');fs.mkdirSync(checks,{recursive:true});
 const temp=fs.mkdtempSync(path.join(checks,'ashen-godot-'));fs.cpSync(project,temp,{recursive:true,filter:p=>!p.split(path.sep).includes('.godot')&&!p.split(path.sep).includes('addons')&&path.basename(p)!=='override.cfg'});
 run(['--headless','--editor','--import','--recovery-mode','--path',temp]);run(['--headless','--path',temp,'--script','res://tests/test_suite.gd'],{verifyOutput:true,cwd:temp,env:{...verificationEnv,ASHEN_REPORT:path.join(root,'artifacts/godot/standalone-acceptance.json')}});
 const binary=path.join(temp,'build/windows/灰烬边境.exe');fs.mkdirSync(path.dirname(binary),{recursive:true});
 if(process.platform==='win32'){
  const powershell=path.join(process.env.SystemRoot,'System32/WindowsPowerShell/v1.0/powershell.exe');
  const built=spawnSync(powershell,['-NoProfile','-ExecutionPolicy','Bypass','-File',path.join(temp,'build.ps1'),'-Action','export'],{cwd:temp,stdio:'inherit',windowsHide:true,env:{...process.env,GODOT_PATH:engine(),NODE_PATH:'',PATH:path.join(process.env.SystemRoot,'System32')}});
  if(built.error||built.status!==0)throw Error('Standalone PowerShell build failed: '+(built.error||built.status));
 }else run(['--headless','--recovery-mode','--path',temp,'--export-release','Windows Desktop',binary],{cwd:temp});
 const report=path.join(temp,'standalone-runtime.json');const native=spawnSync(binary,['--headless','--','--view=battle','--smoke='+report],{cwd:path.dirname(binary),encoding:'utf8',windowsHide:true,timeout:45000,env:{...verificationEnv,PATH:path.join(process.env.SystemRoot,'System32'),GODOT_PATH:'',NODE_PATH:'',ASHEN_DEV_BRIDGE:''}});
 if(native.status!==0||/SCRIPT ERROR:|^ERROR:/m.test((native.stdout||'')+(native.stderr||''))||!fs.existsSync(report))throw Error('Copied project export failed: '+native.stderr);
 const details=JSON.parse(fs.readFileSync(report,'utf8'));if(!details.passed||details.editor_binary||details.dev_plugin_included)throw Error('Copied project package verification failed');
 fs.writeFileSync(path.join(root,'artifacts/godot/standalone-build.json'),JSON.stringify({passed:true,project:temp,binary,details},null,2));console.log('Standalone native project built and ran: '+temp);
}else throw Error('Unknown Godot command: '+command);
