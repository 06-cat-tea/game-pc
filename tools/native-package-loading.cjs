const fs=require('node:fs'),path=require('node:path'),sharp=require('sharp');
const root=path.resolve(__dirname,'..'),source=path.join(root,'art-source/loading/v2'),out=path.join(root,'godot/assets/loading');
async function main(){
 const records=JSON.parse(fs.readFileSync(path.join(source,'sources.json'),'utf8'));fs.mkdirSync(out,{recursive:true});
 const rows=[];
 for(const record of records.images){
  const local=path.join(source,record.id+'.png');
  if(!fs.existsSync(local)){if(!record.path||!fs.existsSync(record.path))throw Error('Missing generated image '+record.id);fs.copyFileSync(record.path,local);}
  await sharp(local).resize(1920,1080,{fit:'cover',position:'centre'}).webp({quality:90}).toFile(path.join(out,record.id+'.webp'));
  const thumb=await sharp(local).resize(480,270,{fit:'cover'}).png().toBuffer();rows.push(thumb);
 }
 const review=path.join(root,'artifacts/godot/strategy-review');fs.mkdirSync(review,{recursive:true});const titles=JSON.parse(fs.readFileSync(path.join(root,'godot/data/loading.json'),'utf8')).images;
 await sharp({create:{width:2400,height:628,channels:3,background:'#eee9df'}}).composite(rows.flatMap((input,i)=>[{input,left:(i%5)*480,top:Math.floor(i/5)*314},{input:Buffer.from('<svg width="480" height="44"><text x="24" y="29" font-family="Microsoft YaHei" font-size="23" fill="#645838">'+titles[records.images[i].id].title+'</text></svg>'),left:(i%5)*480,top:Math.floor(i/5)*314+270}])).png().toFile(path.join(review,'loading-overview.png'));
 fs.writeFileSync(path.join(source,'prompts.md'),'# Loading illustrations\n\nStyle: hand-painted Japanese Western fantasy; clear focal point, restrained props, quiet bottom 20% for UI. No lettering or logos.\n\n'+records.images.map(r=>'## '+r.id+'\n\n'+r.prompt+'\n').join('\n'));
 console.log('Packaged '+rows.length+' loading illustrations at 1920x1080.');
}
main().catch(e=>{console.error(e);process.exitCode=1;});
