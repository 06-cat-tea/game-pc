// Refresh a previously copied independent project and stage a tested release.
// The live Windows directory is never modified by this command.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'..'),out=path.join(root,'artifacts/godot'),project=path.join(root,'godot'),engine=path.join(out,'engine/godot.exe');
const copied=JSON.parse(fs.readFileSync(path.join(out,'standalone-build.json'))),independent=copied.project;
if(!path.resolve(independent).startsWith(path.join(out,'isolated-checks')+path.sep))throw Error('Independent project must be inside isolated-checks.');
function files(dir){return fs.readdirSync(dir,{withFileTypes:true}).flatMap(e=>e.isDirectory()?files(path.join(dir,e.name)):[path.join(dir,e.name)]);}
function run(binary,args,env=process.env){const r=spawnSync(binary,args,{encoding:'utf8',windowsHide:true,cwd:root,env,timeout:300000});if(r.stdout)process.stdout.write(r.stdout);if(r.stderr)process.stderr.write(r.stderr);if(r.error||r.status!==0||/SCRIPT ERROR:|^ERROR:/m.test((r.stdout||'')+(r.stderr||'')))throw Error('Staged verification failed: '+(r.error||r.status));}
const runtime=[...files(path.join(project,'scripts')),...files(path.join(project,'data')),...files(path.join(project,'assets')),...files(path.join(project,'scenes')),...['project.godot','export_presets.cfg','WINDOWS-README.txt','build.ps1'].map(f=>path.join(project,f))].filter(f=>!f.endsWith('.import')&&!f.endsWith('.uid'));
for(const file of [...runtime,...files(path.join(project,'tests')).filter(f=>f.endsWith('.gd'))]){const dest=path.join(independent,path.relative(project,file));fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(file,dest);}
run(process.execPath,[path.join(root,'tools/godot.cjs'),'test']);
run(engine,['--headless','--path',independent,'--script','res://tests/test_suite.gd'],{...process.env,APPDATA:path.join(out,'test-profile/standalone-final'),ASHEN_REPORT:path.join(out,'standalone-acceptance.json')});
const powershell=path.join(process.env.SystemRoot,'System32/WindowsPowerShell/v1.0/powershell.exe');
run(powershell,['-NoProfile','-ExecutionPolicy','Bypass','-File',path.join(independent,'build.ps1'),'-Action','export'],{...process.env,GODOT_PATH:engine,NODE_PATH:''});
const source=path.join(independent,'build/windows'),smoke=path.join(independent,'standalone-runtime.json');
run(path.join(source,'灰烬边境.exe'),['--headless','--','--view=battle','--smoke='+smoke],{...process.env,APPDATA:path.join(out,'test-profile/standalone-runtime'),PATH:path.join(process.env.SystemRoot,'System32'),GODOT_PATH:'',NODE_PATH:''});
copied.details=JSON.parse(fs.readFileSync(smoke));if(!copied.details.passed||copied.details.editor_binary)throw Error('Standalone smoke failed.');
fs.writeFileSync(path.join(out,'standalone-build.json'),JSON.stringify(copied,null,2));
const stage=path.join(out,'native-quest-stage');fs.mkdirSync(stage,{recursive:true});
for(const name of ['灰烬边境.exe','灰烬边境.pck','README.txt','LICENSE-Game-CC0.txt','LICENSE-Godot.txt','LICENSE-ThirdParty-CC0.txt','LICENSE-Font-OFL.txt'])fs.copyFileSync(path.join(source,name),path.join(stage,name));
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const sourceFiles=Object.fromEntries(runtime.map(f=>{const key=path.relative(project,f).replaceAll('\\','/');if(hash(f)!==hash(path.join(independent,key)))throw Error('Independent source drift: '+key);return[key,hash(f)];}));
fs.writeFileSync(path.join(out,'native-quest-build.json'),JSON.stringify({passed:true,created:new Date().toISOString(),independent,stage,sourceFiles,pckSha256:hash(path.join(stage,'灰烬边境.pck'))},null,2));
console.log('Current source and independent project matched; verified EXE/PCK staged at '+stage);
