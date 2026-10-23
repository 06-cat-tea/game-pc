const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..'),artifacts=path.join(root,'artifacts/godot');
const read=name=>JSON.parse(fs.readFileSync(path.join(artifacts,name),'utf8'));
const native=read('native-acceptance.json'),isolated=read('standalone-acceptance.json'),build=read('standalone-build.json'),balance=read('strategy-balance.json'),assets=read('strategy-assets.json'),parity=read('content-parity.json'),windows=read('strategy-windows-smoke.json');
for(const report of [native,isolated,build,balance,assets,parity,windows])assert.equal(report.passed,true);
function files(p){return fs.readdirSync(p,{withFileTypes:true}).flatMap(e=>e.isDirectory()?files(path.join(p,e.name)):[path.join(p,e.name)]);}
const sourceFiles=['scripts','data','scenes'].flatMap(name=>files(path.join(root,'godot',name))).filter(f=>/\.(gd|json|tscn)$/.test(f));
for(const source of sourceFiles){const target=path.join(build.project,path.relative(path.join(root,'godot'),source));assert(fs.readFileSync(source).equals(fs.readFileSync(target)),'Isolated source mismatch: '+source);}
const binaryFiles=['灰烬边境.exe','灰烬边境.pck','LICENSE-Icons-CC-BY-3.0.txt'].map(name=>{const f=path.join(artifacts,'windows',name),buffer=fs.readFileSync(f);return {name,bytes:buffer.length,sha256:crypto.createHash('sha256').update(buffer).digest('hex')};});
const audits=['battle-1920x1080','inventory-1920x1080','loading-camp-1920x1080','loading-coast-960x540'].map(name=>read('strategy-review/'+name+'.png.json'));
assert(audits.every(a=>a.passed));
const report={passed:true,date:'2026-10-17',native_checks:native.checks,isolated_checks:isolated.checks,isolated_source_files_matching:sourceFiles.length,original_content_checks:parity.checks,assets,balance_samples:balance.reports.reduce((n,r)=>n+r.samples,0),balance_tiers:balance.tiers,balance_conditions:{initial_tp:0,affinity:100,awakened:'Training permits awakened actions for both policies; tactical policy may spend earned TP, default auto ultimate remains disabled.',skills:'Only skills within recommended level; same loadouts for both policies.',equipment:balance.equipment,scope:'Two parties and the individually listed encounter fixtures; tier aggregates are not guarantees for every team or encounter.'},windows:windows.strategy,release:binaryFiles,audits,backup:'artifacts/backups/windows-before-strategy-v2-20261017'};
fs.writeFileSync(path.join(artifacts,'strategy-delivery.json'),JSON.stringify(report,null,2)+'\n');
const pct=n=>(n*100).toFixed(1)+'%',link=(label,relative)=>'['+label+']('+path.join(root,relative).replaceAll('\\','/')+')';
const markdown='# 战术与手绘加载升级验收\n\n2026-10-17 · 已完成 Windows 导出与发行程序冒烟验证。\n\n'+
'- 十张 1920×1080 手绘日式西幻加载插画，含六区域与四通用场景；采用简洁构图、单一焦点和留白。\n- 原有 38 张彩色装备图保留，补齐 30 个物品与战斗符号，逐项署名及许可随包提供。\n- 分来源护盾、五属性互克、弱点削韧、击破窗口、三种阵型、战中变阵、六人羁绊和三种协奏已接入。\n- 旧档读取与导入前保留 before-combat-v2 备份，训练退出完整恢复快照。\n\n'+
'## 验证\n\n原生与独立工程各通过 **'+native.checks+'** 项检查；独立工程 '+sourceFiles.length+' 个运行脚本、数据和场景文件与交付源码一致。原剧情及新增内容基准 **'+parity.checks+'** 项检查通过。\n\n'+
'700 场固定种子对照，推荐等级内技能、相同装备与物资、初始 TP 为零；演练好感 100，双方均允许觉醒。主动策略可花费行动积累的大招，默认自动大招保持关闭。\n\n'+
'| 分层 | 默认自动 | 主动策略 |\n| --- | ---: | ---: |\n| 普通 | '+pct(balance.tiers['normal:auto'].win_rate)+' | — |\n| 精英 | '+pct(balance.tiers['elite:auto'].win_rate)+' | '+pct(balance.tiers['elite:tactical'].win_rate)+' |\n| 首领（含高级挑战） | '+pct(balance.tiers['boss:auto'].win_rate)+' | '+pct(balance.tiers['boss:tactical'].win_rate)+' |\n\n'+
'以上为两队及所列战例的分层聚合结果，不代表每个队伍或遭遇都具有相同胜率。高级峡道的游侠队，默认自动为 100%，本测试主动策略为 90%；该反例保留在逐项报告，说明主动干预仍需选对时机。\n\n'+
'实际 NVIDIA GPU 截图覆盖战斗、背包和加载界面，并检查 1920×1080 与 960×540 缩放。背包长说明和强化费用已分开，战斗预览增加浅色底以保证清晰。发行程序已确认规则 v2、十张加载图、图标及署名存在，开发插件和测试源码不随包提供。\n\n'+
'## 文件\n\n'+[
 link('Windows 游戏','artifacts/godot/windows/灰烬边境.exe'),link('十张插画总览','artifacts/godot/strategy-review/loading-overview.png'),link('战斗界面','artifacts/godot/strategy-review/battle-1920x1080.png'),link('背包界面','artifacts/godot/strategy-review/inventory-1920x1080.png'),link('最终原稿与完整提示词','art-source/loading/v2/prompts.md'),link('逐项战斗对照','artifacts/godot/strategy-balance.json'),link('规则和兼容说明','docs/Godot-护盾削韧与加载升级.md')].map(s=>'- '+s).join('\n')+'\n\n插画使用内置 image_gen 生成；最终原稿在 art-source/loading/v2/，运行贴图在 godot/assets/loading/。旧发行包保存在 artifacts/backups/windows-before-strategy-v2-20261017/。\n';
fs.writeFileSync(path.join(artifacts,'strategy-review/验收报告.md'),markdown);
console.log(JSON.stringify({passed:true,native_checks:native.checks,isolated_checks:isolated.checks,source_files_matching:sourceFiles.length,balance_samples:report.balance_samples,release_bytes:binaryFiles[1].bytes}));
