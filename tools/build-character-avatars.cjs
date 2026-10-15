// Mechanical crops only: keep each avatar identical to its neutral standing art.
const fs=require('node:fs'),path=require('node:path');
const sharp=require('sharp');
const root=path.resolve(__dirname,'..');
const crops={hero:[210,0,390,390],mira:[210,250,390,390],toren:[210,0,390,390],sylvi:[190,0,420,420],'ridge-scout':[210,0,390,390],alchemist:[200,0,420,420]};
(async()=>{
  const report=[];
  for(const [id,[left,top,width,height]] of Object.entries(crops)){
    const relative=`assets/characters/${id}/static-v1/`,source=relative+'neutral.webp',file=relative+'avatar.webp';
    await sharp(path.join(root,source)).extract({left,top,width,height}).resize(256,256).webp({quality:90,alphaQuality:100}).toFile(path.join(root,file));
    report.push({id,source,file,crop:{left,top,width,height},width:256,height:256,bytes:fs.statSync(path.join(root,file)).size});
  }
  fs.writeFileSync(path.join(root,'assets/characters/avatar-crops.json'),JSON.stringify({version:1,entries:report},null,2)+'\n');
  console.log(JSON.stringify({avatars:report.length,bytes:report.reduce((n,e)=>n+e.bytes,0)}));
})().catch(e=>{console.error(e);process.exitCode=1;});
