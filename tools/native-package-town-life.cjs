const fs=require('node:fs'),path=require('node:path'),sharp=require('sharp');
const root=path.resolve(__dirname,'..'),source=path.join(root,'art-source/town-life/v1'),runtime=path.join(root,'godot/assets/town-life');
const generated=process.argv[2]||source;
const inputs={'kid-luo':'exec-eaee3587-b7f7-4c31-a4b3-3fd01f887045.png','kid-aya':'exec-a2555183-32d8-4ae1-87e9-d336105242f9.png','kid-ling':'exec-c06bf645-0293-4e84-8603-8baa261f6887.png',animals:'exec-983f308c-932c-4ae3-bd07-cd8a67a8ef84.png'};
async function run(){
 fs.mkdirSync(source,{recursive:true});fs.mkdirSync(runtime,{recursive:true});
 for(const [id,file] of Object.entries(inputs))if(!fs.existsSync(path.join(source,id+'.png')))fs.copyFileSync(path.join(generated,file),path.join(source,id+'.png'));
 for(const id of ['kid-luo','kid-aya','kid-ling']){
  const dir=path.join(runtime,id);fs.mkdirSync(dir,{recursive:true});
  const trimmed=await sharp(path.join(source,id+'.png')).trim({threshold:10}).toBuffer();
  await sharp(trimmed).resize(768,1152,{fit:'contain',background:'#00000000'}).webp({quality:93}).toFile(path.join(dir,'portrait.webp'));
  await sharp(trimmed).resize(256,384,{fit:'contain',background:'#00000000'}).webp({quality:93}).toFile(path.join(dir,'actor.webp'));
 }
 const atlas=path.join(source,'animals.png'),m=await sharp(atlas).metadata();
 const slices=JSON.parse(fs.readFileSync(path.join(source,'atlas-slices.json'),'utf8'));
 if(m.width!==slices.width||m.height!==slices.height)throw Error('Atlas dimensions changed; inspect the gutters before packaging.');
 for(const [col,id] of ['tuantuan','amo','snowball','diandian','gugu','doudou'].entries()){
  const dir=path.join(runtime,id);fs.mkdirSync(dir,{recursive:true});
  const frames=[];
  for(let row=0;row<3;row++){
   const left=slices.columns[col],top=slices.rows[row],right=slices.columns[col+1],bottom=slices.rows[row+1];
   const cell=await sharp(atlas).extract({left,top,width:right-left,height:bottom-top}).png().toBuffer();
   const buffer=await sharp(cell).trim({threshold:10}).png().toBuffer();
   frames.push({buffer,...await sharp(buffer).metadata()});
  }
  const scale=Math.min(232/Math.max(...frames.map(f=>f.width)),232/Math.max(...frames.map(f=>f.height)));
  for(const [row,f] of frames.entries()){
   const width=Math.round(f.width*scale),height=Math.round(f.height*scale);
   const input=await sharp(f.buffer).resize(width,height).png().toBuffer();
   await sharp({create:{width:256,height:256,channels:4,background:'#00000000'}}).composite([{input,left:Math.round((256-width)/2),top:244-height}]).webp({quality:94}).toFile(path.join(dir,row+'.webp'));
  }
 }
 fs.writeFileSync(path.join(source,'README.md'),'# 晨星镇居民与动物\n\n来源：OpenAI imagegen 原创透明素材，2026-10-17。参考本工程旅人常态立绘的细腻手绘动漫风格、纸色与香槟金配色。\n\n三名儿童：小洛（栗发、青绿马甲）、阿芽（双辫、鼠尾草绿裙）、小铃（黑蓝短发、蓝裙与信袋），全身、常态、保留脚底。动物图集为六列三行：团团、阿墨、雪球、点点、咕咕、豆豆；每列含站立与两张行走帧。横向移动允许镜像，不参与碰撞或战斗。\n\n生成提示：Single full body transparent original fantasy RPG NPC child portrait, delicate painterly anime rendering, muted ivory/navy/champagne palette, fully clothed, complete feet, generous transparent margins; animal atlas exactly 6 columns by 3 rows, idle / first walking pose / second walking pose, same individual in each column, isolated alpha sprites, no text.原始逐项提示见 prompts.json。运行图由 native-package-town-life.cjs 无损裁切、缩放并编码 WebP，不重绘原稿。\n');
 const prompts=[...Object.keys(inputs)].map(id=>({id,source:inputs[id],reference:'godot/assets/characters/hero/static-v2/neutral.webp',transparent:true,brief:id==='animals'?'Six columns: orange tabby cat, black-white dog, white rabbit, gray cat, brown hen, brown sparrow. Three rows idle, walk1, walk2; isometric painterly anime style.':'Full body wholesome village child, fully clothed, delicate painterly anime; '+{'kid-luo':'chestnut hair, teal waistcoat, canvas satchel','kid-aya':'braids, green dress, herb pouch','kid-ling':'dark bob, blue dress, ivory scarf, mail satchel'}[id]}));
 fs.writeFileSync(path.join(source,'prompts.json'),JSON.stringify(prompts,null,2));
 console.log('Town life: 3 full portraits, 3 scene actors, 18 animal frames.');
}
run().catch(e=>{console.error(e);process.exit(1)});
