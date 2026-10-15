// Encoding/resize only; runtime sprites and model texture preserve visible RGBA pixels.
const fs=require('node:fs'),path=require('node:path');
const sharp=require('sharp'),root=path.resolve(__dirname,'..'),report=[];
async function convert(input,output,resize){
  const src=path.join(root,input),dest=path.join(root,output);let image=sharp(src);if(resize)image=image.resize(...resize);
  await image.webp(resize?{quality:86,effort:6}:{lossless:true,effort:6}).toFile(dest);
  if(!resize){const a=await sharp(src).ensureAlpha().raw().toBuffer(),b=await sharp(dest).ensureAlpha().raw().toBuffer();
    if(a.length!==b.length)throw Error('Changed dimensions: '+input);
    for(let i=0;i<a.length;i+=4)if(a[i+3]!==b[i+3]||(a[i+3]&&(a[i]!==b[i]||a[i+1]!==b[i+1]||a[i+2]!==b[i+2])))throw Error('Changed visible pixels: '+input);}
  report.push({input,output,before:fs.statSync(src).size,after:fs.statSync(dest).size,lossless:!resize});
}
(async()=>{
  for(const name of fs.readdirSync(path.join(root,'assets/environment/sprites')).filter(n=>n.endsWith('.png')))
    await convert('assets/environment/sprites/'+name,'assets/environment/sprites/'+name.replace('.png','.webp'));
  for(const name of fs.readdirSync(path.join(root,'assets/world/scenes')).filter(n=>n.endsWith('.png')))
    await convert('assets/world/scenes/'+name,'assets/world/scenes/'+name.replace('.png','.webp'),[480,270]);
  await convert('assets/characters/mira/mira-standing.png','assets/characters/mira/mira-standing.webp');
  await convert('assets/characters/mira/mira-v1.2048/texture_00.png','assets/characters/mira/mira-v1.2048/texture_00.runtime.webp');
  fs.mkdirSync(path.join(root,'artifacts'),{recursive:true});fs.writeFileSync(path.join(root,'artifacts/resource-compression.json'),JSON.stringify(report,null,2));
  console.log(JSON.stringify({files:report.length,before:report.reduce((n,r)=>n+r.before,0),after:report.reduce((n,r)=>n+r.after,0)}));
})().catch(e=>{console.error(e);process.exitCode=1;});
