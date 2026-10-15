// Mechanical export only: preserve PNG alpha, resize and encode runtime WebP.
const fs=require('node:fs'),path=require('node:path'),sharp=require('sharp');
const root=path.resolve(__dirname,'..'),sourceRoot=path.join(root,'artifacts/character-portraits');
const people=[['hero','主角'],['mira','米拉'],['toren','托伦'],['sylvi','希薇'],['ridge-scout','夜岚'],['alchemist','瑟琳']];
const moods=['neutral','smile','serious'],report=[];
(async()=>{
  for(const [id,name] of people){
    const output=path.join(root,'assets/characters',id,'static-v1');fs.mkdirSync(output,{recursive:true});
    for(const mood of moods){
      const input=path.join(sourceRoot,id,mood+'.png');if(!fs.existsSync(input)){if(process.argv.includes('--partial'))continue;throw Error('Missing original: '+input);}
      const meta=await sharp(input).metadata();if(!meta.hasAlpha)throw Error('Original lacks alpha: '+input);
      const dest=path.join(output,mood+'.webp');let quality;
      for(quality of [86,82,78]){await sharp(input).resize(768,1152,{fit:'contain',position:'bottom',background:{r:0,g:0,b:0,alpha:0}}).webp({quality,alphaQuality:100,effort:6}).toFile(dest);if(fs.statSync(dest).size<=512*1024)break;}
      if(fs.statSync(dest).size>512*1024)throw Error('Runtime image exceeds budget: '+dest);
      const {data,info}=await sharp(dest).ensureAlpha().raw().toBuffer({resolveWithObject:true});let transparent=0,maxAlpha=0;
      for(let i=3;i<data.length;i+=4){if(!data[i])transparent++;maxAlpha=Math.max(maxAlpha,data[i]);}
      if(transparent<info.width*info.height*.12||maxAlpha<200)throw Error('Invalid transparency: '+dest);
      report.push({id,name,mood,width:info.width,height:info.height,bytes:fs.statSync(dest).size,quality,transparentPixels:transparent});
    }
  }
  fs.writeFileSync(path.join(sourceRoot,'export-report.json'),JSON.stringify(report,null,2));
  console.log(JSON.stringify({portraits:report.length,bytes:report.reduce((n,r)=>n+r.bytes,0)}));
})().catch(e=>{console.error(e);process.exitCode=1;});
