const fs=require('node:fs'),path=require('node:path'),sharp=require('sharp');
const root=path.resolve(__dirname,'..'),native=path.join(root,'godot'),source=path.join(root,'art-source/characters');
const ids=['hero','mira','toren','sylvi','ridge-scout','eira','alchemist'],moods=['neutral','smile','serious'];
async function main(){
 const content=JSON.parse(fs.readFileSync(path.join(native,'data/content.json'),'utf8'));
 for(const id of ids){
  const out=path.join(native,'assets/characters',id,'static-v2');fs.mkdirSync(out,{recursive:true});
  const entry={fallback:content.art.actors[id]||content.art.actors[id==='eira'?'priest':'mage']};
  for(const mood of moods){
   const file=path.join(source,id,'fullbody-v2',mood+'.png');if(!fs.existsSync(file))throw Error('Portrait generation is not finished: '+id+'/'+mood);
   const metadata=await sharp(file).metadata();if(!metadata.hasAlpha)throw Error('Portrait has no alpha: '+file);
   await sharp(file).resize(768,1152,{fit:'contain',background:{r:0,g:0,b:0,alpha:0}}).webp({quality:88,alphaQuality:100}).toFile(path.join(out,mood+'.webp'));
   entry[mood]='res://assets/characters/'+id+'/static-v2/'+mood+'.webp';
  }
  await sharp(path.join(out,'neutral.webp')).extract({left:256,top:32,width:256,height:256}).webp({quality:90,alphaQuality:100}).toFile(path.join(out,'avatar.webp'));
  entry.avatar='res://assets/characters/'+id+'/static-v2/avatar.webp';content.art.portraits[id]=entry;
 }
 const rawDir=path.join(source,'hero/movement-v2/diagonal-raw');fs.mkdirSync(rawDir,{recursive:true});
 const output=path.join(native,'assets/characters/hero/movement-v2');fs.mkdirSync(output,{recursive:true});
 const order=['n','ne','e','se','s','sw','w','nw'],old={ne:2,se:0,sw:1,nw:3},directions={};
 for(const dir of order){
  const frames=[];
  if(dir in old){
   for(let i=0;i<5;i++){
    const raw=path.join(rawDir,dir+'-'+i+'.webp');
    if(!fs.existsSync(raw))fs.copyFileSync(path.join(native,`assets/art-v2/actors/hero-${old[dir]}-${i}.webp`),raw);
    frames.push(fs.readFileSync(raw));
   }
  }else{
   const sheet=path.join(source,'hero/movement-v2',dir+'-sheet.png'),m=await sharp(sheet).metadata();
   if(!m.hasAlpha)throw Error('Sprite sheet has no alpha: '+dir);
   for(let i=0;i<5;i++){
    const x=Math.round(i%3*m.width/3),y=Math.round(Math.floor(i/3)*m.height/2),right=Math.round((i%3+1)*m.width/3),bottom=Math.round((Math.floor(i/3)+1)*m.height/2);
    frames.push(await sharp(sheet).extract({left:x,top:y,width:right-x,height:bottom-y}).png().toBuffer());
   }
  }
  const trimmed=await Promise.all(frames.map(async frame=>{const result=await sharp(frame).trim({threshold:8}).png().toBuffer({resolveWithObject:true});if(result.info.height<30||result.info.width<10)throw Error('Empty sprite frame: '+dir);return result;}));
  const scale=Math.min(360/Math.max(...trimmed.map(f=>f.info.height)),360/Math.max(...trimmed.map(f=>f.info.width)));
  for(let i=0;i<5;i++){
   const frame=trimmed[i],w=Math.round(frame.info.width*scale),h=Math.round(frame.info.height*scale);
   const image=await sharp(frame.data).resize(w,h).png().toBuffer();
   await sharp({create:{width:384,height:384,channels:4,background:{r:0,g:0,b:0,alpha:0}}}).composite([{input:image,left:Math.round((384-w)/2),top:365-h}]).webp({quality:90,alphaQuality:100}).toFile(path.join(output,dir+'-'+i+'.webp'));
  }
  const base='res://assets/characters/hero/movement-v2/'+dir+'-';directions[dir]={idle:base+'0.webp',walk:[1,2,3,4].map(i=>base+i+'.webp')};
 }
 for(const key of Object.keys(content.art.actors))if(/^hero-[0-3]-[0-4]$/.test(key))delete content.art.actors[key];
 fs.writeFileSync(path.join(native,'data/content.json'),JSON.stringify(content,null,2)+'\n');
 fs.writeFileSync(path.join(native,'data/movement.json'),JSON.stringify({order,fps:9,frameSize:[384,384],anchor:[0.5,0.95],directions},null,2)+'\n');
 const narrativeFile=path.join(native,'data/narrative.json'),narrative=JSON.parse(fs.readFileSync(narrativeFile,'utf8'));
 for(const id of ids)delete narrative.portraits[id];fs.writeFileSync(narrativeFile,JSON.stringify(narrative,null,2)+'\n');
 console.log('Packaged 21 full-body portraits, 7 avatars and 40 eight-direction frames.');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
