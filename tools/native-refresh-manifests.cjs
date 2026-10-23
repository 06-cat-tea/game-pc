const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),native=path.join(root,'godot');
const hash=data=>crypto.createHash('sha256').update(data).digest('hex');
function files(dir){return fs.readdirSync(dir,{withFileTypes:true}).flatMap(e=>e.isDirectory()?files(path.join(dir,e.name)):[path.join(dir,e.name)]);}
const manifestFile=path.join(native,'data/resource-manifest.json'),manifest=JSON.parse(fs.readFileSync(manifestFile,'utf8'));
manifest.source='Native Godot desktop / locally maintained content';
manifest.files=Object.fromEntries(files(path.join(native,'assets')).filter(f=>/\.(png|webp|svg|ttf)$/.test(f)).map(f=>[path.relative(native,f).replaceAll('\\','/'),fs.statSync(f).size]));
fs.writeFileSync(manifestFile,JSON.stringify(manifest,null,2)+'\n');
const narrativeFile=path.join(native,'data/narrative-manifest.json'),n=JSON.parse(fs.readFileSync(narrativeFile,'utf8'));
if(n.sourceFiles){n.historicalSourceChecksums=n.sourceFiles;delete n.sourceFiles;}
n.maintenance='Native data/narrative.json is authoritative; historical source checksums are provenance, not runtime dependencies.';
n.resources=Object.fromEntries(Object.entries(n.resources).filter(([f])=>fs.existsSync(path.join(native,f))).map(([f])=>{const data=fs.readFileSync(path.join(native,f));return[f,{sha256:hash(data),bytes:data.length}];}));
fs.writeFileSync(narrativeFile,JSON.stringify(n,null,2)+'\n');
const progression=JSON.parse(fs.readFileSync(path.join(native,'data/progression.json'),'utf8'));
const progressionEntries=[];
function baseline(value,key){if(Array.isArray(value)){value.forEach((entry,i)=>baseline(entry,key+'.'+i));}else if(value&&typeof value==='object'){for(const [name,entry]of Object.entries(value))baseline(entry,key?key+'.'+name:name);}else progressionEntries.push({key,sha256:hash(JSON.stringify(value))});}
baseline(progression,'');
fs.writeFileSync(path.join(native,'data/progression-manifest.json'),JSON.stringify({revision:progression.revision,maintenance:'Additive native progression baseline; original narrative baseline remains unchanged.',entries:progressionEntries},null,2)+'\n');
const questFiles=['data/quest-catalog.json','data/world-interactions.json'];
const questResources=files(path.join(native,'assets/town-life')).filter(f=>f.endsWith('.webp'));
fs.writeFileSync(path.join(native,'data/quest-manifest.json'),JSON.stringify({revision:1,maintenance:'Native quest and world interaction catalogs; original narrative wording is referenced, not duplicated.',files:Object.fromEntries([...questFiles.map(f=>path.join(native,f)),...questResources].map(f=>[path.relative(native,f).replaceAll('\\','/'),{sha256:hash(fs.readFileSync(f)),bytes:fs.statSync(f).size}]))},null,2)+'\n');
console.log(JSON.stringify({nativeResources:Object.keys(manifest.files).length,narrativeResources:Object.keys(n.resources).length}));
