const fs=require('node:fs'),path=require('node:path'),sharp=require('sharp');
const root=path.resolve(__dirname,'..'),out=path.join(root,'artifacts/godot'),review=path.join(out,'upgrade-review');
const caption=(text,width=640)=>Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="36"><text x="16" y="26" font-family="Microsoft YaHei, sans-serif" font-size="22" fill="#293742">${text}</text></svg>`);
async function run(){
 const tiles=[];fs.mkdirSync(review,{recursive:true});
 for(const [i,id] of ['kid-luo','kid-aya','kid-ling'].entries()){
  tiles.push({input:caption(['小洛','阿芽','小铃'][i]),left:i*640,top:0});
  tiles.push({input:await sharp(path.join(root,'godot/assets/town-life',id,'portrait.webp')).resize(460,660,{fit:'contain',background:'#00000000'}).png().toBuffer(),left:i*640+90,top:36});
 }
 for(const [col,id] of ['tuantuan','amo','snowball','diandian','gugu','doudou'].entries()){
  tiles.push({input:caption(['团团','阿墨','雪球','点点','咕咕','豆豆'][col],320),left:col*320,top:710});
  for(let row=0;row<3;row++)tiles.push({input:await sharp(path.join(root,'godot/assets/town-life',id,row+'.webp')).resize(150,150).png().toBuffer(),left:col*320+85,top:750+row*150});
 }
 await sharp({create:{width:1920,height:1200,channels:4,background:'#f5f2eb'}}).composite(tiles).png().toFile(path.join(review,'town-life-overview.png'));
 const ui=[];for(const [i,view] of ['quest-board','quest-journal','quest-archive','quest-entrance','town-life','town-life-night','child-luo','child-aya','child-ling'].entries()){
  const x=i%3*640,y=Math.floor(i/3)*396;
  ui.push({input:caption(view),left:x,top:y});ui.push({input:await sharp(path.join(out,view+'-1280x720.png')).resize(640,360).png().toBuffer(),left:x,top:y+36});
 }
 await sharp({create:{width:1920,height:1188,channels:4,background:'#f5f2eb'}}).composite(ui).png().toFile(path.join(review,'quest-ui-overview.png'));
 console.log('Rendered town life assets and quest UI overview.');
}
run().catch(e=>{console.error(e);process.exit(1)});
