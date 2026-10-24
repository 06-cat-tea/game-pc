// Small artwork is available independently, before the game PCK has downloaded.
const fs=require('node:fs'),path=require('node:path'),sharp=require('sharp');
const root=path.resolve(__dirname,'..');
async function build(destination){
 const config=JSON.parse(fs.readFileSync(path.join(root,'godot/data/loading.json'),'utf8'));
 const out=path.join(destination,'loading-art');fs.mkdirSync(out,{recursive:true});const images=[];
 for(const [id,data]of Object.entries(config.images)){
  const source=path.join(root,'godot',data.path.slice(6));let buffer;
  for(const quality of [82,74,66,58]){buffer=await sharp(source).resize(1600,900,{fit:'cover'}).webp({quality}).toBuffer();if(buffer.length<=300*1024)break;}
  if(buffer.length>300*1024)throw Error('Loading preview exceeds 300 KiB: '+id);
  fs.writeFileSync(path.join(out,id+'.webp'),buffer);images.push({id,title:data.title,url:'loading-art/'+id+'.webp'});
 }
 const catalog={version:config.version,rotation:config.rotation,categories:config.categories,tips:config.tips,images};
 const htmlPath=path.join(destination,'index.html'),html=fs.readFileSync(htmlPath,'utf8');
 if(!html.includes('__ASHEN_LOADING_CATALOG__'))throw Error('Missing loading catalog placeholder');
 fs.writeFileSync(htmlPath,html.replace('__ASHEN_LOADING_CATALOG__',JSON.stringify(catalog).replaceAll('<','\\u003c')));
 fs.copyFileSync(path.join(root,'godot/web/loading-carousel.js'),path.join(destination,'loading-carousel.js'));
 console.log('Web loading carousel: '+images.length+' pictures, '+config.tips.length+' tips.');
}
if(require.main===module)build(path.resolve(process.argv[2]||path.join(root,'artifacts/godot/web'))).catch(error=>{console.error(error);process.exitCode=1;});
module.exports={build};
