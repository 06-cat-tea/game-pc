// Native JSON is the maintained source of truth; no browser scripts are loaded.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..'),native=path.join(root,'godot');
const read=file=>JSON.parse(fs.readFileSync(path.join(native,file),'utf8'));
const hash=value=>crypto.createHash('sha256').update(typeof value==='string'||Buffer.isBuffer(value)?value:JSON.stringify(value)).digest('hex');
const data=read('data/narrative.json'),manifest=read('data/narrative-manifest.json');
let checks=0;
for(const entry of manifest.entries){let value=data;for(const key of entry.key.split('.'))value=value[key];assert.equal(hash(value),entry.sha256,entry.key+' native text baseline');checks++;}
for(const [file,entry]of Object.entries(manifest.resources)){assert.equal(hash(fs.readFileSync(path.join(native,file))),entry.sha256,file);checks++;}
const counts={npcs:Object.keys(data.npcs).length,scenes:Object.keys(data.scenes).length,topics:Object.values(data.dialogues).reduce((n,entry)=>n+Object.keys(entry).length,0),props:Object.values(data.scenes).reduce((n,entry)=>n+entry.props.length,0),lore:Object.keys(data.lore).length};
assert.deepEqual(counts,{npcs:66,scenes:64,topics:204,props:242,lore:15});checks+=5;
const progression=read('data/progression.json'),added=read('data/progression-manifest.json');
for(const entry of added.entries){let value=progression;for(const key of entry.key.split('.'))value=value[key];assert.equal(hash(JSON.stringify(value)),entry.sha256,entry.key+' additive progression baseline');checks++;}
const additions={awakenings:Object.keys(progression.ultimates).length,ultimates:Object.keys(progression.ultimates).length,buildings:Object.keys(progression.buildings).length,details:Object.values(progression.buildings).reduce((n,site)=>n+site.details.length,0),clues:Object.values(progression.ultimates).reduce((n,story)=>n+story.clues.length,0),rooms:Object.keys(progression.rooms).length};
assert.deepEqual(additions,{awakenings:7,ultimates:7,buildings:12,details:24,clues:14,rooms:2});checks+=6;
const quests=read('data/quest-catalog.json'),world=read('data/world-interactions.json'),questManifest=read('data/quest-manifest.json');
for(const [file,entry] of Object.entries(questManifest.files)){assert.equal(hash(fs.readFileSync(path.join(native,file))),entry.sha256,file+' additive quest baseline');checks++;}
assert.equal(Object.keys(world.children).length,3);assert.equal(world.animals.length,6);assert.equal(world.resources.length,5);assert.equal(world.entrances.length,15);assert.equal(Object.keys(quests.tasks).filter(id=>id.startsWith('resident:')).length,6);checks+=5;
for(const entry of world.entrances){assert(data.scenes[entry.scene],entry.scene);assert.equal(data.scenes[entry.scene].place,entry.region);checks+=2;}
additions.questCatalog=Object.keys(quests.tasks).length;additions.entrances=world.entrances.length;additions.children=3;additions.animals=6;additions.residentCommissions=6;
const report={passed:true,checks,counts,additions,textRecords:manifest.entries.length,addedRecords:added.entries.length,resourceFiles:Object.keys(manifest.resources).length,coverage:'Original native text baseline plus additive progression baseline, resource hashes and complete content counts; runtime entrypoints covered by native tests.'};
fs.mkdirSync(path.join(root,'artifacts/godot'),{recursive:true});fs.writeFileSync(path.join(root,'artifacts/godot/content-parity.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report));
