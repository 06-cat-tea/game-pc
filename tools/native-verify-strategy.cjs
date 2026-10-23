const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),sharp=require('sharp');
const root=path.resolve(__dirname,'..'),project=path.join(root,'godot');
const read=f=>JSON.parse(fs.readFileSync(path.join(project,f),'utf8'));
async function main(){
 const loading=read('data/loading.json'),icons=read('data/item-icons.json'),content=read('data/content.json');
 assert.equal(Object.keys(loading.images).length,10);assert.equal(Object.keys(content.art.equipment).length,38);
 for(const [id,record] of Object.entries(loading.images)){
  const f=path.join(project,record.path.slice(6)),meta=await sharp(f).metadata();assert.equal(meta.width,1920,id);assert.equal(meta.height,1080,id);
  assert(fs.existsSync(path.join(root,'art-source/loading/v2',id+'.png')),id+' original');
  for(const resource of record.resources||[])assert(fs.existsSync(path.join(project,resource.slice(6))),resource);
 }
 for(const [id,entry] of Object.entries(icons.icons)){
  assert(fs.readFileSync(path.join(project,entry.path.slice(6)),'utf8').includes('<svg'),id);
  assert(entry.author&&entry.source&&entry.page&&entry.license==='CC BY 3.0',id+' attribution');
 }
 assert(fs.existsSync(path.join(project,'LICENSE-Icons-CC-BY-3.0.txt')));
 const report={passed:true,loading_images:10,dimensions:'1920x1080',style:loading.style,item_and_combat_icons:Object.keys(icons.icons).length,preserved_equipment_images:38,local_originals:true,attribution:true};
 fs.writeFileSync(path.join(root,'artifacts/godot/strategy-assets.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report));
 const keys=Object.keys(icons.icons);const thumbs=[];
 for(let i=0;i<keys.length;i++){
  const key=keys[i],buffer=await sharp(path.join(project,icons.icons[key].path.slice(6))).resize(72,72).png().toBuffer();
  thumbs.push({input:buffer,left:(i%6)*180+54,top:Math.floor(i/6)*124+10});
  thumbs.push({input:Buffer.from('<svg width="180" height="32"><text x="90" y="23" text-anchor="middle" font-family="sans-serif" font-size="16" fill="#705e43">'+key+'</text></svg>'),left:(i%6)*180,top:Math.floor(i/6)*124+86});
 }
 await sharp({create:{width:1080,height:620,channels:3,background:'#eee9df'}}).composite(thumbs).png().toFile(path.join(root,'artifacts/godot/strategy-review/item-icons.png'));
}
main().catch(e=>{console.error(e);process.exitCode=1;});
