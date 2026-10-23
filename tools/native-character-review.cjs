const fs=require('node:fs'),path=require('node:path'),sharp=require('sharp');
const root=path.resolve(__dirname,'..'),out=path.join(root,'artifacts/godot/upgrade-review');
const ids=['hero','mira','toren','sylvi','ridge-scout','eira','alchemist'];
const label=(text,width,height)=>Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}"><text x="12" y="24" fill="#27313b" font-family="sans-serif" font-size="18">${text}</text></svg>`);
async function main(){
 fs.mkdirSync(out,{recursive:true});const portraits=[];
 for(let i=0;i<ids.length;i++){
  const image=await sharp(path.join(root,'godot/assets/characters',ids[i],'static-v2/neutral.webp')).resize(192,288).png().toBuffer();
  portraits.push({input:image,left:i*200+4,top:40},{input:label(ids[i],200,36),left:i*200,top:0});
 }
 await sharp({create:{width:1400,height:340,channels:4,background:'#f5f2eb'}}).composite(portraits).png().toFile(path.join(out,'fullbody-overview.png'));
 const expressions=[];
 for(let y=0;y<ids.length;y++)for(let x=0;x<3;x++){
  const mood=['neutral','smile','serious'][x],image=await sharp(path.join(root,'godot/assets/characters',ids[y],'static-v2',mood+'.webp')).extract({left:204,top:15,width:360,height:360}).resize(180,180).png().toBuffer();
  expressions.push({input:image,left:140+x*190,top:y*190},{input:label(ids[y],140,36),left:0,top:y*190+60});
 }
 await sharp({create:{width:710,height:1330,channels:4,background:'#f5f2eb'}}).composite(expressions).png().toFile(path.join(out,'expressions-overview.png'));
 const movement=JSON.parse(fs.readFileSync(path.join(root,'godot/data/movement.json'))),frames=[];
 for(let y=0;y<8;y++){
  const direction=movement.order[y],entry=movement.directions[direction];
  frames.push({input:label(direction.toUpperCase(),70,36),left:0,top:y*136+42});
  for(let x=0;x<5;x++)frames.push({input:await sharp(path.join(root,'godot',(x?entry.walk[x-1]:entry.idle).slice(6))).resize(128,128).png().toBuffer(),left:70+x*128,top:y*136});
 }
 await sharp({create:{width:710,height:1088,channels:4,background:'#f5f2eb'}}).composite(frames).png().toFile(path.join(out,'eight-direction-overview.png'));
 console.log('Character and movement contact sheets: '+out);
}
main().catch(error=>{console.error(error);process.exitCode=1;});
