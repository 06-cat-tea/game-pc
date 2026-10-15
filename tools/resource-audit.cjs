// Follow actual runtime resolvers; catalogs also retain authoring provenance.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const {execFileSync}=require('node:child_process');
const root=path.resolve(__dirname,'..'),git=args=>{if(!fs.existsSync(path.join(root,'.git')))return '';try{return execFileSync('git',args,{cwd:root,encoding:'utf8',stdio:['ignore','pipe','ignore']}).trim();}catch{return '';}};
function audit(){
  const context={addEventListener(){},dispatchEvent(){},performance:{now:()=>0},document:{body:{classList:{contains:()=>false}}}};context.window=context;context.PixelWorld={project:()=>({x:0,y:0})};vm.createContext(context);
  const scripts=JSON.parse(fs.readFileSync(path.join(root,'tools/game-scripts.json'),'utf8'));
  const end=scripts.indexOf('js/scene-characters.js');
  for(const file of scripts.slice(0,end+1).filter(file=>!/^js\/(client-platform|game-viewport)\.js$/.test(file)))vm.runInContext(fs.readFileSync(path.join(root,file),'utf8'),context,{filename:file});
  vm.runInContext(fs.readFileSync(path.join(root,'js/character-portraits.js'),'utf8'),context);
  const w=context,used=new Set(),reasons=new Map(),add=(file,reason)=>{file=file.replaceAll('\\','/');used.add(file);if(!reasons.has(file))reasons.set(file,[]);reasons.get(file).push(reason);};
  const resource=(kind,id,size)=>add(w.WorldAssets.path(kind,id,size),kind+':'+id);
  // Public enumerations are kept, including generic fallback portraits.
  for(const id of w.WorldAssets.buildings)resource('buildings',id);
  for(const id of w.WorldAssets.portraits)for(const size of [256,512])resource('portraits',id,size);
  for(const id of w.WorldAssets.scenes)resource('scenes',id);
  for(const e of w.EnvironmentCatalog)resource('environment',e.id);
  for(const [kind,entries] of Object.entries(w.ArtCatalog))if(['actors','enemies','environment','scenes','terrain','buildings'].includes(kind))for(const id of Object.keys(entries))resource(kind==='scenes'?'expansion':kind,id);
  const places=Object.keys(w.GameData.PLACES),scenes=Object.values(w.SceneSystem.scenes);
  for(const s of scenes)if(s.background)add(s.background,'scene:'+s.id);
  for(const place of places){
    for(const id of w.WorldTerrain.resourceIds(place))resource('environment',id);
    for(const o of w.SceneEnvironment.objects(place))resource('environment',o.asset);
    for(const p of w.SceneEnvironment.patches[place]||[])resource('environment',p[0]);
    for(const b of w.BuildingSystem.at(place))resource('buildings',b.asset);
    for(const n of w.NPCSystem.at(place))resource('portraits',n.type);
    for(const id of w.SceneCharacters.resources(place))resource('actors',id);
  }
  for(const scene of scenes){
    for(const id of w.SceneCharacters.resources(scene.place,scene.id))resource('actors',id);
    for(const n of w.NPCSystem.inside(scene.occupantKey||scene.buildingId))resource('portraits',n.type);
  }
  for(const [id,e]of Object.entries(w.CharacterPortraits.entries)){for(const url of Object.values(e.images||{}))add(url,'standing:'+id);if(e.avatar)add(e.avatar,'avatar:'+id);}
  const expansion=JSON.parse(fs.readFileSync(path.join(root,'assets/expansion/catalog.json'),'utf8'));
  for(const e of expansion.assets.filter(e=>e.kind==='icon'))add(path.posix.normalize('assets/expansion/'+e.file),'emblem:'+e.id);
  add('assets/maps/world-v1.webp','world map, on demand');add('assets/art-v2/title.webp','title/loading');
  for(const file of fs.readdirSync(path.join(root,'assets/icons/rail')))if(file.endsWith('.svg'))add('assets/icons/rail/'+file,'UI icon');
  // Collect literal image URLs from stylesheet and entrypoint source.
  for(const name of fs.readdirSync(path.join(root,'assets')).filter(n=>n.endsWith('.css'))){
    const css=fs.readFileSync(path.join(root,'assets',name),'utf8');for(const match of css.matchAll(/url\(['"]?([^'")]+)['"]?\)/g))if(!match[1].includes('var(')&&!match[1].startsWith('data:'))add(path.posix.normalize('assets/'+match[1].split('?')[0]),'CSS:'+name);
  }
  for(const file of ['frontier.html',...scripts.filter(f=>f!=='js/art-catalog.js')]){
    for(const match of fs.readFileSync(path.join(root,file),'utf8').matchAll(/['"\x60](assets\/[^'"\x60$]+\.(?:png|webp|svg|jpg))['"\x60]/g))add(match[1],'literal:'+file);
  }
  const tracked=new Set(git(['ls-files','-z']).split('\0')),changed=new Set(git(['diff','--name-only','HEAD','--','assets']).split(/\r?\n/));
  const images=[],protectedFiles=[],candidates=[];
  function walk(dir){for(const e of fs.readdirSync(dir,{withFileTypes:true})){const file=path.join(dir,e.name);if(e.isDirectory())walk(file);else if(/\.(png|webp|jpg|jpeg|svg)$/i.test(e.name))images.push(path.relative(root,file).replaceAll('\\','/'));}}
  walk(path.join(root,'assets'));
  for(const file of images){
    if(used.has(file))continue;
    const protect=!tracked.has(file)?'existing/new untracked artwork':changed.has(file)?'local changes':/\/(sources|masters|crops)\//.test(file)?'authoring source':file.startsWith('assets/characters/')?'character project/source':/-512\.png$/.test(file)&&file.startsWith('assets/icons/')?'icon original':/-1024\.png$/.test(file)?'building original':file.startsWith('assets/vendor/')?'vendor/project':null;
    if(protect){protectedFiles.push({path:file,reason:protect});continue;}
    const eligible=file.startsWith('assets/environment/sprites/')||file.startsWith('assets/expansion/scenes/')||/^assets\/world\/buildings\/.+-512\.png$/.test(file)||/^assets\/icons\/.+-128\.png$/.test(file)||/^assets\/(title|loading)\/.+\.webp$/.test(file);
    if(!eligible){protectedFiles.push({path:file,reason:'not in conservative runtime cleanup scope'});continue;}
    const bytes=fs.readFileSync(path.join(root,file));
    candidates.push({path:file,bytes:bytes.length,sha256:crypto.createHash('sha256').update(bytes).digest('hex'),gitBlob:git(['rev-parse','HEAD:'+file]),reason:'unreachable or superseded by current runtime resolver'});
  }
  const missing=[...used].filter(file=>!fs.existsSync(path.join(root,file)));
  return {sourceRevision:git(['rev-parse','HEAD']),regions:places,sceneCount:scenes.length,used:[...used].sort(),missing,candidates,protected:protectedFiles,bytes:candidates.reduce((n,e)=>n+e.bytes,0)};
}
if(require.main===module){const report=audit();fs.mkdirSync(path.join(root,'artifacts'),{recursive:true});fs.writeFileSync(path.join(root,'artifacts/resource-audit.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({regions:report.regions.length,scenes:report.sceneCount,used:report.used.length,missing:report.missing,candidates:report.candidates.length,MiB: +(report.bytes/1048576).toFixed(2),protected:report.protected.length}));if(report.missing.length)process.exitCode=1;}
module.exports={audit,root};
