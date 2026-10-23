// Exercise the real installer/uninstaller, with native game saves redirected to a test profile.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),{spawnSync,spawn}=require('node:child_process');
const root=path.resolve(__dirname,'..'),art=path.join(root,'artifacts/installers'),work=path.join(art,'work'),review=path.join(art,'验收截图');
const manifest=JSON.parse(fs.readFileSync(path.join(art,'build-manifest.json'))),installer=path.join(art,manifest.installer.name),registry='Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\AshenFrontierDesktopGodotDemo';
const powershell=path.join(process.env.SystemRoot,'System32/WindowsPowerShell/v1.0/powershell.exe');
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const write=(name,value)=>fs.writeFileSync(path.join(work,name),JSON.stringify(value,null,2)+'\n');
const checks=[];
function check(ok,label){assert(ok,label);checks.push(label);console.log('PASS '+label);}
function ps(code){const r=spawnSync(powershell,['-NoProfile','-EncodedCommand',Buffer.from('[Console]::OutputEncoding=New-Object System.Text.UTF8Encoding($false);'+code,'utf16le').toString('base64')],{encoding:'utf8',windowsHide:true,timeout:90000});assert.equal(r.status,0,r.stderr||r.stdout);return JSON.parse(r.stdout.replace(/^\uFEFF/,''));}
function systemState(){return ps(`$ErrorActionPreference='Stop'; $s=New-Object -ComObject WScript.Shell; $r=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('${registry}'); $result=@{installed=$null -ne $r;desktop=$s.SpecialFolders('Desktop');start=$s.SpecialFolders('Programs');os=[Environment]::OSVersion.Version.ToString();is64=[Environment]::Is64BitOperatingSystem}; if($r){$result.location=$r.GetValue('InstallLocation');$result.version=$r.GetValue('DisplayVersion');$r.Close()};$result|ConvertTo-Json -Compress`);}
function run(exe,args,label,{env=process.env,expected=0,timeout=300000}={}){
 const r=spawnSync(exe,args,{cwd:path.dirname(exe),encoding:'utf8',windowsHide:true,windowsVerbatimArguments:args.some(a=>a.startsWith('/D=')||a.startsWith('_?=')),env,timeout,maxBuffer:8*1024*1024});
 const log=(r.stdout||'')+(r.stderr||'');fs.writeFileSync(path.join(work,label+'.log'),log);
 assert(!r.error,label+': '+r.error);assert((Array.isArray(expected)?expected:[expected]).includes(r.status),label+': unexpected exit '+r.status+'; '+log.slice(-3000));assert(!/SCRIPT ERROR:|^ERROR:/m.test(log),label+': '+log);return r;
}
function snapshot(dir){
 if(!fs.existsSync(dir))return null;
 return Object.fromEntries(fs.readdirSync(dir,{withFileTypes:true}).flatMap(e=>{const f=path.join(dir,e.name);if(e.isDirectory()){const sub=snapshot(f);return Object.entries(sub).map(([key,v])=>[e.name+'/'+key,v]);}return[[e.name,hash(f)]];}));
}
async function main(){
 fs.mkdirSync(review,{recursive:true});
 const installerBytes=fs.readFileSync(installer);
 check(crypto.createHash('sha256').update(installerBytes).digest('hex')===manifest.installer.sha256,'验收安装包与交付 SHA-256 一致');
 check(installerBytes.subarray(0,0x20000).toString('utf8').includes('level="asInvoker"'),'安装器清单请求当前用户权限');
 const before=systemState();check(!before.installed,'没有已有试玩安装，验收不覆盖用户安装');
 const desktop=path.join(before.desktop,'灰烬边境试玩版.lnk'),menu=path.join(before.start,'灰烬边境试玩版');
 check(!fs.existsSync(desktop)&&!fs.existsSync(menu),'验收快捷方式不存在，不覆盖其他入口');
 const originalSaves=path.join(process.env.APPDATA,'AshenFrontierDesktopGodot','saves'),saveSnapshot=snapshot(originalSaves);
 const dir=fs.mkdtempSync(path.join(work,'试玩 安装验收 ')),exe=path.join(dir,'灰烬边境.exe');
 async function uninstall(label){
  run(path.join(dir,'卸载试玩版.exe'),['/S'],label);
  for(let i=0;i<100;i++){
   if(!fs.existsSync(path.join(dir,'卸载试玩版.exe'))&&!systemState().installed)return;
   await new Promise(resolve=>setTimeout(resolve,300));
  }
  throw Error('Uninstaller did not finish: '+label);
 }
 const env={...process.env,APPDATA:path.join(work,'installed-test-profile'),PATH:path.join(process.env.SystemRoot,'System32'),GODOT_PATH:'',NODE_PATH:'',ASHEN_DEV_BRIDGE:''};
 run(installer,['/S','/D='+dir],'install');
 check(systemState().location===dir,'中文及空格路径安装登记正确');
 check(systemState().version===manifest.version,'试玩版本登记正确');
 // NSIS can sanitize an invalid /D before our callback, falling back to the
 // registered folder. Either an explicit rejection or that safe fallback is valid.
 run(installer,['/S','/D='+path.parse(dir).root],'reject-drive-root',{expected:[0,2]});
 check(systemState().location===dir&&!fs.existsSync(path.join(path.parse(dir).root,'demo-install.id')),'根目录参数被拒绝或安全回退，不向盘符根目录写入游戏');
 const occupied=fs.mkdtempSync(path.join(work,'其他版本 ')),foreign=path.join(occupied,'灰烬边境.exe');fs.writeFileSync(foreign,'other-version-fixture');
 run(installer,['/S','/D='+occupied],'reject-other-version',{expected:2});
 check(fs.readFileSync(foreign,'utf8')==='other-version-fixture'&&systemState().location===dir,'拒绝覆盖其他版本目录，文件和原安装登记不变');
 for(const f of manifest.files)check(hash(path.join(dir,f.name))===f.sha256,'安装文件一致：'+f.name);
 const gameBytes=fs.readFileSync(exe),pe=gameBytes.readUInt32LE(0x3c);
 check(gameBytes.readUInt16LE(pe+4)===0x8664,'安装后的游戏为原生 x86_64 程序');
 check(fs.existsSync(desktop)&&fs.existsSync(path.join(menu,'开始试玩.lnk'))&&fs.existsSync(path.join(menu,'卸载试玩版.lnk')),'桌面、开始菜单与卸载快捷方式齐全');
 const shortcuts=ps(`$s=New-Object -ComObject WScript.Shell; $desktop=$s.CreateShortcut($s.SpecialFolders('Desktop')+'\\灰烬边境试玩版.lnk');$start=$s.CreateShortcut($s.SpecialFolders('Programs')+'\\灰烬边境试玩版\\开始试玩.lnk');@{desktop=$desktop.TargetPath;start=$start.TargetPath;working=$start.WorkingDirectory}|ConvertTo-Json -Compress`);
 check(shortcuts.desktop===exe&&shortcuts.start===exe&&shortcuts.working===dir,'快捷方式目标和工作目录正确');
 const smoke=path.join(work,'installed-smoke.json');
 run(exe,['--headless','--','--view=battle-strategy','--smoke='+smoke],'installed-smoke',{env});
 const details=JSON.parse(fs.readFileSync(smoke));
 check(details.passed&&!details.editor_binary&&!details.dev_plugin_included&&!details.test_sources_included&&!details.authoring_included,'安装后独立运行，未携带编辑器插件或测试源码');
 check(details.strategy.loading_count===10&&details.strategy.loading_included&&details.strategy.icons_included&&details.strategy.icon_license_included,'十张加载图、物品符号与许可完整');
 check(details.user_data_dir===path.join(env.APPDATA,'AshenFrontierDesktopGodotDemo').replaceAll('\\','/'),'实际发行程序使用独立试玩存档目录');
 // Release templates deliberately disable external scripts. Load the actual installed
 // PCK in the local test runner for storage assertions; standalone EXE is tested above.
 function saveCheck(operation,label){const dest=path.join(work,label+'.json');run(path.join(root,'artifacts/godot/engine/godot.exe'),['--headless','--main-pack',path.join(dir,'灰烬边境.pck'),'--script',path.join(root,'tools/installer/save-roundtrip.gd').replaceAll('\\','/'),'--',dest,operation],label,{env,timeout:60000});const report=JSON.parse(fs.readFileSync(dest));check(report.passed,'安装后 PCK 存档读写：'+label);return report;}
 const saved=saveCheck('write','save-initial'),digest=hash(saved.save);
 // A live process must make both replacement and uninstall stop without killing it.
 const game=spawn(exe,['--headless'],{cwd:dir,env,windowsHide:true,stdio:'ignore'});
 try{
  await new Promise(resolve=>setTimeout(resolve,1800));check(game.exitCode===null,'运行中检测使用真实游戏进程');
  run(installer,['/S','/D='+dir],'install-running',{expected:3});
  run(path.join(dir,'卸载试玩版.exe'),['/S','_?='+dir],'uninstall-running',{expected:3});
  check(hash(path.join(dir,'灰烬边境.pck'))===manifest.files.find(f=>f.name.endsWith('.pck')).sha256,'运行中阻止覆盖和卸载，资源不变');
 }finally{game.kill();await new Promise(resolve=>game.exitCode!==null?resolve():game.once('exit',resolve));}
 const extra=path.join(dir,'玩家自行添加.txt');fs.writeFileSync(extra,'保留文件');
 // No /D: reinstall must pick the registered location.
 run(installer,['/S'],'reinstall');
 check(systemState().location===dir,'重复安装沿用原目录');check(hash(saved.save)===digest&&fs.existsSync(extra),'重装保留进度及用户文件');saveCheck('read','save-after-reinstall');
 for(const view of ['title','loading-camp','inventory','battle-strategy']){
  const out=path.join(review,view+'.png');
  run(exe,['--resolution','1280x720','--','--view='+view,'--capture='+out],'capture-'+view,{env,timeout:60000});
  check(fs.statSync(out).size>10000&&JSON.parse(fs.readFileSync(out+'.json')).passed,'实际安装程序界面：'+view);
 }
 await uninstall('uninstall');
 check(!systemState().installed&&!fs.existsSync(desktop)&&!fs.existsSync(menu),'卸载移除安装登记与快捷方式');
 check(manifest.files.every(f=>!fs.existsSync(path.join(dir,f.name)))&&!fs.existsSync(path.join(dir,'卸载试玩版.exe')),'卸载移除全部清单文件与卸载器');
 check(fs.readFileSync(extra,'utf8')==='保留文件'&&hash(saved.save)===digest,'卸载保留用户文件及试玩存档');
 run(installer,['/S','/D='+dir],'install-again');saveCheck('read','save-after-uninstall');
 check(hash(saved.save)===digest,'卸载后重装可继续读取原进度');
 await uninstall('cleanup-uninstall');
 assert.deepEqual(snapshot(originalSaves),saveSnapshot);check(true,'原电脑版存档内容未变');
 check(!systemState().installed&&!fs.existsSync(desktop)&&!fs.existsSync(menu),'验收完成后清理测试安装及系统入口');
 const report={passed:true,created:new Date().toISOString(),checks:checks.length,results:checks,os:before.os,windows_x64:before.is64,directory:dir,save_profile:env.APPDATA,installer_sha256:hash(installer),save_test_method:'Local Godot runner loads the actual installed PCK; external scripts are disabled by the release template. Standalone EXE smoke and graphical checks run separately without the editor.',save:saved,smoke:details,screenshots:['title','loading-camp','inventory','battle-strategy'].map(v=>path.join(review,v+'.png')),limitations:'Validated on the current Windows host; no separate Windows 10 or clean virtual-machine run.'};
 fs.writeFileSync(path.join(art,'installer-acceptance.json'),JSON.stringify(report,null,2)+'\n');
 fs.writeFileSync(path.join(art,'验收报告.md'),'# 试玩版安装验收\n\n'+manifest.version+'\n\n通过 '+checks.length+' 项安装与运行检查。原生回归 '+manifest.native.checks+' 项通过。\n\n'+checks.map(s=>'- '+s).join('\n')+'\n\n安装包 SHA-256：`'+hash(installer)+'`。\n\n使用当前 Windows '+before.os+' x64 主机验证，未在额外 Windows 10 主机或干净虚拟机验证。发行 EXE 的启动与图形检查仅保留 System32 PATH，无 Node、Godot 编辑器与网络下载依赖。发行模板禁用外部脚本，因此存档自动断言由本地 Godot 测试运行器加载实际安装后的 PCK 完成，实际界面保存与读取另行记录。存档测试重定向到工程内隔离用户目录，未写入玩家正式进度。\n');
 console.log('Installer acceptance passed: '+checks.length);
 run(process.execPath,[path.join(root,'tools/finalize-demo-delivery.cjs')],'delivery-finalize');
}
main().catch(error=>{write('installer-failure.json',{passed:false,checks,error:error.stack});console.error(error);process.exitCode=1;});
