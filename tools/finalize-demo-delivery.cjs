const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..'),out=path.join(root,'artifacts/installers');
const read=name=>JSON.parse(fs.readFileSync(path.join(out,name),'utf8'));
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const build=read('build-manifest.json'),tests=read('installer-acceptance.json'),binary=path.join(out,build.installer.name);
assert(tests.passed&&build.native.passed&&build.source_preserved&&build.regular_release_preserved);
assert.equal(hash(binary),tests.installer_sha256);assert.equal(tests.installer_sha256,build.installer.sha256);
const previous=JSON.parse(fs.readFileSync(path.join(root,'artifacts/godot/strategy-delivery.json')));
for(const entry of previous.release)assert.equal(hash(path.join(root,'artifacts/godot/windows',entry.name)),entry.sha256,'Previous Windows release must remain unchanged');
const names=['安装欢迎页.png','安装组件页.png','title.png','loading-camp.png','inventory.png','battle-strategy.png'];
for(const name of names)assert(fs.statSync(path.join(out,'验收截图',name)).size>10000,'Missing screenshot '+name);
const manual=fs.existsSync(path.join(out,'work/manual-ui-attempt.json'))?read('work/manual-ui-attempt.json'):null;
const report={passed:true,created:new Date().toISOString(),version:build.version,installer:build.installer,native_checks:build.native.checks,installer_checks:tests.checks,regular_release_unchanged:true,independent_saves:'%APPDATA%\\AshenFrontierDesktopGodotDemo\\saves',uninstall_preserves_saves:true,save_test_method:tests.save_test_method,platform_tested:tests.os,manual_ui_attempt:manual,screenshots:names.map(name=>'验收截图/'+name),limitations:tests.limitations};
fs.writeFileSync(path.join(out,'delivery.json'),JSON.stringify(report,null,2)+'\n');
const link=(label,relative)=>'['+label+']('+path.join(out,relative).replaceAll('\\','/')+')';
fs.writeFileSync(path.join(out,'验收报告.md'),'# Windows 试玩版安装交付\n\n'+build.title+' · '+build.version+'\n\n'+
 '- 单文件中文安装器，'+(build.installer.bytes/1e6).toFixed(1)+' MB，包含当前全部剧情、六区域、训练和战斗升级。\n'+
 '- Windows 10/11 x64，当前用户安装，默认目录 `%LOCALAPPDATA%\\Programs\\AshenFrontierDemo`。桌面快捷方式可选；安装完成后启动默认不选。\n'+
 '- 独立试玩存档 `%APPDATA%\\AshenFrontierDesktopGodotDemo\\saves`；重装、卸载均保留进度。原电脑版配置和之前发行文件哈希未变。\n'+
 '- 安装包默认未签名；游戏、Godot、字体、物品图标及 NSIS 许可随安装目录提供。\n\n'+
 '## 验证结果\n\n原生回归 **'+build.native.checks+'** 项通过；最终安装包 **'+tests.checks+'** 项安装与运行检查通过。\n\n'+tests.results.map(s=>'- '+s).join('\n')+'\n\n'+
 '发行 EXE 在仅有 System32 的 PATH 下启动并完成标题、加载、背包和战斗截图检查，不依赖 Node、Godot 编辑器或联网下载。发行模板禁用外部脚本，存读档自动断言由本地 Godot 测试运行器加载**实际安装后的 PCK**完成，包含训练隔离、重装与卸载后的恢复。所有测试存档位于工程内隔离目录。\n\n'+
 '测试主机 Windows '+tests.os+' x64；未额外在 Windows 10 主机或干净虚拟机验证。'+(manual?'额外交互存读档截图尝试未完成：'+manual.reason+'。该尝试未计入通过项；实际发行程序的图形截图及安装后 PCK 的存读档断言均通过。':'')+'\n\n'+
 '## 交付文件\n\n'+[link('试玩安装包',build.installer.name),link('安装与存档说明','安装与存档说明.txt'),link('SHA-256 校验','SHA256SUMS.txt'),...names.map(name=>link(name,'验收截图/'+name))].map(s=>'- '+s).join('\n')+'\n\nSHA-256：`'+build.installer.sha256+'`\n\n'+
 '构建：电脑版工程内运行 `pnpm build:demo`；自动验收：`pnpm test:installer`。构建工具与脚本均在电脑版工程内，玩家只需安装包。\n');
console.log(JSON.stringify({passed:true,installer:binary,bytes:build.installer.bytes,native_checks:build.native.checks,installer_checks:tests.checks}));
