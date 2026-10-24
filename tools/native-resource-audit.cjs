const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),native=path.join(root,'godot'),out=path.join(root,'artifacts/godot');
const slash=value=>value.replaceAll('\\','/');
function files(dir){return fs.readdirSync(dir,{withFileTypes:true}).flatMap(e=>e.isDirectory()?files(path.join(dir,e.name)):[path.join(dir,e.name)]);}
function size(dir){return files(dir).reduce((sum,f)=>{try{return sum+fs.statSync(f).size;}catch(e){if(e.code==='ENOENT')return sum;throw e;}},0);}
const roots=new Set(),prefixes=new Set();
function add(value){if(typeof value!=='string')return;if(!value.startsWith('res://assets/'))return;const p=value.slice(6);if(p.endsWith('/'))prefixes.add(p);else roots.add(p);}
function strings(value){if(typeof value==='string')add(value);else if(Array.isArray(value))value.forEach(strings);else if(value&&typeof value==='object')for(const [key,item]of Object.entries(value))if(!['source','originalSource','sourceFiles'].includes(key))strings(item);}
const content=JSON.parse(fs.readFileSync(path.join(native,'data/content.json'),'utf8'));
// Retired browser rendering tables; native ground/region data are independent.
delete content.art.terrain;delete content.art.environment;delete content.art.scenes;
if(process.argv.includes('--apply-metadata'))fs.writeFileSync(path.join(native,'data/content.json'),JSON.stringify(content,null,2)+'\n');
strings(content);
for(const f of files(path.join(native,'data')).filter(f=>f.endsWith('.json')&&!/manifest/.test(path.basename(f))&&path.basename(f)!=='content.json'))strings(JSON.parse(fs.readFileSync(f,'utf8')));
for(const f of [...files(path.join(native,'scripts')),...files(path.join(native,'scenes'))]){
 const text=fs.readFileSync(f,'utf8');for(const m of text.matchAll(/res:\/\/assets\/[^"'\s)]+/g))add(m[0]);
}
prefixes.add('assets/ui/hud-filled/');prefixes.add('assets/ui/icons/');prefixes.add('assets/ui/branding/');
const all=files(path.join(native,'assets')).filter(f=>!f.endsWith('.import'));
const unused=all.filter(file=>{const p=slash(path.relative(native,file));return !roots.has(p)&&![...prefixes].some(prefix=>p.startsWith(prefix))&&!p.endsWith('/OFL.txt');});
const deletions=[];
function remove(candidate,reason){const full=path.join(root,candidate);if(fs.existsSync(full))deletions.push({path:full,relative:slash(candidate),bytes:fs.statSync(full).isDirectory()?size(full):fs.statSync(full).size,reason});}
for(const p of ['js','assets','tests','index.html','frontier.html','client.json','tools/live2d-build'])remove(p,'retired desktop browser project');
const keepTools=new Set(['godot.cjs','prepare-godot-world.cjs','bake-godot-world.cjs','bake-godot-regions.cjs','create-godot-brand.cjs','verify-godot-brand.cjs','verify-godot-package.cjs','verify-godot-visuals.cjs','verify-godot-windows-brand.ps1','verify-godot-content.cjs','setup-godot-mcp.ps1']);
for(const name of ['build-loading-web.cjs','verify-loading-web.cjs','design-royal-city.cjs','design-starlit-town.cjs','package-starlit-art.cjs','create-hud-reference-assets.cjs','verify-starlit-delivery.cjs'])keepTools.add(name);
for(const name of fs.readdirSync(path.join(root,'tools'))){if(!keepTools.has(name)&&!name.startsWith('native-')&&fs.statSync(path.join(root,'tools',name)).isFile())remove('tools/'+name,'retired web, migration or historical review tool');}
for(const name of fs.readdirSync(root))if(name.endsWith('.md')&&!['AGENTS.md','README.md'].includes(name))remove(name,'retired browser delivery document');
for(const name of fs.readdirSync(path.join(root,'docs')))if(!['Godot-原生角色与工程整理.md','Godot-角色觉醒与星轨交互.md','Godot-任务委托与探索入口.md','Godot-晨星镇与界面升级.md','Godot-王城布局与昼夜光照.md','Godot-加载画面轮播.md'].includes(name))remove('docs/'+name,'superseded delivery document; preserved in backup');
for(const name of fs.readdirSync(path.join(root,'artifacts')))if(!['backups','godot'].includes(name))remove('artifacts/'+name,'retired web preview and generation intermediates');
const keepArtifactDirs=new Set(['engine','windows','test-profile','upgrade-review']);
const keepArtifactFiles=new Set(['native-acceptance.json','native-upgrade-progress.log','brand-preview.png','native-cleanup-plan.json','native-cleanup-result.json','content-parity.json','content-flow.json','standalone-acceptance.json','standalone-build.json','windows-acceptance.json','brand-acceptance.json','windows-brand-acceptance.json','windows-runtime-icon.png','windows-smoke.log','windows-graphics.log']);
for(const name of fs.readdirSync(out)){
 const f=path.join(out,name);if(fs.statSync(f).isDirectory()?keepArtifactDirs.has(name):keepArtifactFiles.has(name)||name.startsWith('native-')||name.startsWith('windows-release')||/^(?:quest-[a-z-]+|child-[a-z-]+|town-life(?:-night)?|entrance-world-[a-z-]+|title|portrait-[a-z-]+|dialogue|battle|wheel-selected|inventory|skills|map|town|character|journal|effect-[a-z-]+|awakening-[a-z-]+|building-site-[a-z0-9-]+|building-log|room-observatory|room-archive)-\d+x\d+\.(?:png(?:\.json|\.log)?|log)$/.test(name))continue;
 remove('artifacts/godot/'+name,'old native build, test copy, cache or superseded evidence');
}
for(const file of unused){const p=slash(path.relative(root,file));remove(p,'unreachable native runtime resource');if(fs.existsSync(file+'.import'))remove(p+'.import','import metadata of removed asset');}
const missing=[...roots].filter(p=>path.extname(p)&&!fs.existsSync(path.join(native,p)));
const runtimeResources=Object.fromEntries(all.filter(f=>!unused.includes(f)).map(f=>{const data=fs.readFileSync(f);return[slash(path.relative(native,f)),{bytes:data.length,sha256:crypto.createHash('sha256').update(data).digest('hex')}];}));
const report={root,created:new Date().toISOString(),beforeBytes:size(root),missing,reachableFiles:all.length-unused.length,unusedNativeFiles:unused.length,deletedBytes:deletions.reduce((n,d)=>n+d.bytes,0),deletions,retention:'one pre-change source backup, current native engine/templates, current package, required authoring sources and latest acceptance evidence'};
fs.mkdirSync(out,{recursive:true});fs.writeFileSync(path.join(out,'native-cleanup-plan.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({missing,unusedNativeFiles:unused.length,entries:deletions.length,bytes:report.deletedBytes}));
fs.writeFileSync(path.join(out,'native-resource-audit.json'),JSON.stringify({passed:missing.length===0,created:report.created,missing,reachableFiles:report.reachableFiles,unusedNativeFiles:unused.length,dynamicPrefixes:[...prefixes],runtimeResources},null,2));
if(missing.length)process.exitCode=1;
