// Build from an isolated native project; never alter the regular desktop release.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),{spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'..'),art=path.join(root,'artifacts/installers'),work=path.join(art,'work'),source=path.join(root,'godot'),project=path.join(work,'project'),payload=path.join(work,'payload');
const engine=process.env.GODOT_PATH||path.join(root,'artifacts/godot/engine/godot.exe');
const nsis=path.join(root,'tools/vendor/nsis-3.12/makensis.exe');
const filename='灰烬边境-星陨纪事-试玩版-7.3.0-Setup-x64.exe',title='灰烬边境：星陨纪事 · 试玩版',version='7.3.0-demo.20261017';
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const write=(file,value)=>{fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,value);};
const json=(file,value)=>write(file,JSON.stringify(value,null,2)+'\n');
function run(binary,args,label,env=process.env){
 console.log(label);const r=spawnSync(binary,args,{cwd:project,encoding:'utf8',windowsHide:true,env,timeout:900000,maxBuffer:32*1024*1024});
 const log=(r.stdout||'')+(r.stderr||'');write(path.join(work,label+'.log'),log);
 if(r.error||r.status!==0||/SCRIPT ERROR:|^ERROR:/m.test(log))throw Error(label+' failed: '+(r.error||r.status)+'\n'+log.slice(-5000));
 console.log(label+' passed');return log;
}
assert(fs.existsSync(nsis),'Extract official nsis-3.12.zip into tools/vendor first.');
assert.equal(hash(path.join(root,'tools/vendor/nsis-3.12.zip')),'56581f90db321581c5381193d796fffcf2d24b2f8fed2160a6c6a3baa67f2c4f','NSIS archive must match official SHA-256');
const sourceConfigHash=hash(path.join(source,'project.godot')),sourcePresetHash=hash(path.join(source,'export_presets.cfg'));
const regularFiles=fs.readdirSync(path.join(root,'artifacts/godot/windows')).filter(f=>fs.statSync(path.join(root,'artifacts/godot/windows',f)).isFile());
const regularHashes=Object.fromEntries(regularFiles.map(f=>[f,hash(path.join(root,'artifacts/godot/windows',f))]));
fs.mkdirSync(project,{recursive:true});fs.mkdirSync(payload,{recursive:true});
// Incrementally copy unchanged imports too; skip editor state and all authoring tools.
function sync(dir,relative=''){
 for(const entry of fs.readdirSync(dir,{withFileTypes:true})){
  const rel=path.join(relative,entry.name),segments=rel.split(path.sep);
  if(['addons','authoring','build'].includes(segments[0])||entry.name==='override.cfg')continue;
  if(segments[0]==='.godot'&&segments.length>1&&!['imported','global_script_class_cache.cfg','uid_cache.bin','.gdignore'].includes(segments[1]))continue;
  const from=path.join(dir,entry.name),to=path.join(project,rel);
  if(entry.isDirectory()){fs.mkdirSync(to,{recursive:true});sync(from,rel);}
  else if(!fs.existsSync(to)||hash(from)!==hash(to))fs.copyFileSync(from,to);
 }
}
const packageOnly=process.argv.includes('--package-only');
if(!packageOnly)sync(source);
function replace(file,from,to){const text=fs.readFileSync(file,'utf8');assert(text.includes(from),'Missing expected build anchor: '+from);write(file,text.replace(from,to));}
if(!packageOnly){
replace(path.join(project,'project.godot'),'config/name="灰烬边境：星陨纪事 · 原生电脑版"','config/name="'+title+'"');
replace(path.join(project,'project.godot'),'config/custom_user_dir_name="AshenFrontierDesktopGodot"','config/custom_user_dir_name="AshenFrontierDesktopGodotDemo"');
replace(path.join(project,'project.godot'),'enabled=PackedStringArray("res://addons/godot-mcp/plugin.cfg")','enabled=PackedStringArray()');
replace(path.join(project,'scripts/rail_hud.gd'),'灰烬边境 · 原生电脑版','灰烬边境 · 试玩版');
write(path.join(project,'project.godot'),fs.readFileSync(path.join(project,'project.godot'),'utf8').replace('config/description="六地归途 · 完整星钟故事"','config/description="完整内容试玩 · '+version+'"'));
const preset=path.join(project,'export_presets.cfg');
write(preset,fs.readFileSync(preset,'utf8').replace('application/product_name="灰烬边境：星陨纪事"','application/product_name="'+title+'"').replace('application/file_description="灰烬边境：星陨纪事 · 原生电脑版"','application/file_description="'+title+'"').replaceAll('="1.0.0.0"','="7.3.0.0"'));
// Save isolation and profile identity are asserted against the installed executable.
replace(path.join(project,'scripts/main.gd'),'report.region_count=db.regions.size();','report.user_data_dir=OS.get_user_data_dir(); report.application_name=ProjectSettings.get_setting("application/config/name"); report.demo_version="'+version+'"\n\t\treport.region_count=db.regions.size();');
}
const testEnv={...process.env,APPDATA:path.join(work,'test-profile'),ASHEN_REPORT:path.join(work,'native-acceptance.json')};
if(!packageOnly){
run(engine,['--headless','--editor','--import','--recovery-mode','--path',project],'01-import',testEnv);
run(engine,['--headless','--path',project,'--script','res://tests/test_suite.gd'],'02-native-regression',testEnv);
run(process.execPath,[path.join(root,'tools/native-verify-strategy.cjs')],'03-resource-audit');
run(engine,['--headless','--recovery-mode','--path',project,'--export-release','Windows Desktop',path.join(payload,'灰烬边境.exe')],'04-export',testEnv);
}
assert(JSON.parse(fs.readFileSync(path.join(work,'native-acceptance.json'))).passed,'Staged native regression must have passed');
const licenseSources=[['LICENSE-Game-CC0.txt','LICENSE-Game-CC0.txt'],['LICENSE-Godot.txt','LICENSE-Godot.txt'],['LICENSE-ThirdParty-CC0.txt','LICENSE-ThirdParty-CC0.txt'],['LICENSE-Icons-CC-BY-3.0.txt','LICENSE-Icons-CC-BY-3.0.txt'],['assets/fonts/OFL.txt','LICENSE-Font-OFL.txt']];
for(const [from,to] of licenseSources)fs.copyFileSync(path.join(source,from),path.join(payload,to));
fs.copyFileSync(path.join(root,'tools/vendor/nsis-3.12/COPYING'),path.join(payload,'LICENSE-Installer-NSIS.txt'));
const readme=title+'\r\n'+version+'\r\n\r\n'+
 '系统：Windows 10/11 64 位；键盘鼠标操作。离线运行，无需 Godot、Node 或额外下载。\r\n'+
 '内容：当前全部六区域、剧情、训练、成长觉醒，以及护盾、削韧、属性克制、羁绊和协奏。\r\n\r\n'+
 '安装：双击 Setup 安装包，选择游戏文件夹。默认安装在 %LOCALAPPDATA%\\Programs\\AshenFrontierDemo。\r\n'+
 '通过开始菜单或桌面快捷方式启动。若要移动游戏，保留 EXE 与 PCK 在同一目录。\r\n\r\n'+
 '试玩进度：%APPDATA%\\AshenFrontierDesktopGodotDemo\\saves\\\r\n'+
 '自动存档 autosave.json，手动存档 slot_1.json 至 slot_3.json。训练不覆盖剧情存档。\r\n'+
 '原电脑版存档不会自动读取或修改；可在游戏存档菜单主动导入/导出兼容 JSON。\r\n'+
 '卸载与重装保留进度。彻底清除进度需自行备份后删除以上独立存档目录。\r\n\r\n'+
 '卸载：Windows 设置中的应用列表，或开始菜单中的“卸载试玩版”。\r\n'+
 '重装/卸载前请正常退出游戏。自行添加的文件会保留。\r\n'+
 '本包未作数字签名。资源署名、游戏、引擎、字体与安装器许可随安装目录提供。\r\n\r\n'+
 '完整游戏操作说明\r\n'+fs.readFileSync(path.join(source,'WINDOWS-README.txt'),'utf8');
write(path.join(payload,'README.txt'),'\ufeff'+readme);
const names=['灰烬边境.exe','灰烬边境.pck','README.txt',...licenseSources.map(x=>x[1]),'LICENSE-Installer-NSIS.txt'];
const files=names.map(name=>({name,bytes:fs.statSync(path.join(payload,name)).size,sha256:hash(path.join(payload,name))}));
// Explicit manifest drives installation AND removal. Never use recursive wildcard deletion.
const escape=s=>s.replaceAll('$','$$').replaceAll('"','$\\"');
write(path.join(payload,'payload.nsh'),'!macro InstallPayload\n'+names.map(n=>'  File "'+escape(path.join(payload,n))+'"').join('\n')+'\n!macroend\n!macro RemovePayload\n'+names.map(n=>'  Delete "$INSTDIR\\'+escape(n)+'"').join('\n')+'\n!macroend\n');
const smoke=path.join(work,'export-smoke.json');
run(path.join(payload,'灰烬边境.exe'),['--headless','--','--view=battle-strategy','--smoke='+smoke],'05-export-smoke',testEnv);
const details=JSON.parse(fs.readFileSync(smoke));assert(details.passed&&!details.editor_binary&&!details.test_sources_included&&!details.dev_plugin_included);assert.equal(details.application_name,title);assert(details.user_data_dir.endsWith('AshenFrontierDesktopGodotDemo'));
const output=path.join(art,filename);
run(nsis,['/INPUTCHARSET','UTF8','/V3',...(process.argv.includes('--quick')?['/DQUICK']:[]),'/DPAYLOAD='+payload,'/DOUTPUT='+output,'/DICON='+path.join(source,'assets/ui/branding/logo.ico'),'/DSIZE_KB='+Math.ceil(files.reduce((n,f)=>n+f.bytes,0)/1024),path.join(root,'tools/installer/demo.nsi')],'06-installer-compile');
assert.equal(hash(path.join(source,'project.godot')),sourceConfigHash);assert.equal(hash(path.join(source,'export_presets.cfg')),sourcePresetHash);
for(const [name,digest] of Object.entries(regularHashes))assert.equal(hash(path.join(root,'artifacts/godot/windows',name)),digest,'Regular desktop release must remain unchanged');
json(path.join(art,'build-manifest.json'),{version,title,created:new Date().toISOString(),installer:{name:filename,bytes:fs.statSync(output).size,sha256:hash(output)},files,native:JSON.parse(fs.readFileSync(path.join(work,'native-acceptance.json'))),smoke:details,source_preserved:true,regular_release_preserved:true,nsis:{version:'3.12',archive_sha256:hash(path.join(root,'tools/vendor/nsis-3.12.zip')),source:'https://sourceforge.net/projects/nsis/files/NSIS%203/3.12/nsis-3.12.zip/download'}});
write(path.join(art,'SHA256SUMS.txt'),hash(output)+'  '+filename+'\r\n');
write(path.join(art,'安装与存档说明.txt'),'\ufeff'+readme);
console.log('Installer ready: '+output+' ('+fs.statSync(output).size+' bytes)');
