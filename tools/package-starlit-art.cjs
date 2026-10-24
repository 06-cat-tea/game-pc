// Mechanical atlas extraction and resource packaging; no painted content is synthesized here.
const fs=require('node:fs'),path=require('node:path'),sharp=require('sharp');
const root=path.resolve(__dirname,'..'),source=path.join(root,'art-source/starlit-town/v1'),out=path.join(root,'godot/assets/starlit-town');
fs.mkdirSync(out,{recursive:true});
const mapping={'buildings-a':['clocktower','chapel','guildhall','inn'],'buildings-b':['market','royal-hall','artisan-quarter','star-academy'],'buildings-c':['alchemist-lab','town-stables','north-gate','house'],'props':['tree','lamp','flowers','stall'],'items':['potion','tonic','revive','supply']};
async function sprites(id,names){
 const file=path.join(source,id+'.png'),{data,info}=await sharp(file).ensureAlpha().raw().toBuffer({resolveWithObject:true}),w=info.width,h=info.height;
 const visited=new Uint32Array(w*h),components=[];let label=0;
 for(let j=0;j<w*h;j++){if(visited[j]||data[j*4+3]<100)continue;const queue=[j];visited[j]=++label;let area=0,minx=w,miny=h,maxx=0,maxy=0;
  for(let k=0;k<queue.length;k++){const p=queue[k],x=p%w,y=Math.floor(p/w);area++;minx=Math.min(minx,x);miny=Math.min(miny,y);maxx=Math.max(maxx,x);maxy=Math.max(maxy,y);for(const q of [x>0?p-1:-1,x<w-1?p+1:-1,y>0?p-w:-1,y<h-1?p+w:-1])if(q>=0&&!visited[q]&&data[q*4+3]>=100){visited[q]=label;queue.push(q);}}
  if(area>1000)components.push({label,area,left:minx,top:miny,width:maxx-minx+1,height:maxy-miny+1});
 }
 components.sort((a,b)=>b.area-a.area);
 const major=components.slice(0,4).sort((a,b)=>Math.floor((a.top+a.height/2)/ (h/2))-Math.floor((b.top+b.height/2)/(h/2))||a.left-b.left);
 // A connected silhouette gives exact cut bounds even when the atlas gutters are not at 50%.
 if(major.length!==4)throw Error('Atlas must have four separated silhouettes: '+id);
 for(let i=0;i<4;i++){const c=major[i],left=Math.max(0,c.left-3),top=Math.max(0,c.top-3),width=Math.min(w-left,c.width+6),height=Math.min(h-top,c.height+6),pixels=Buffer.alloc(width*height*4);
  for(let y=0;y<height;y++)for(let x=0;x<width;x++){const p=(y+top)*w+x+left;let belongs=visited[p]===c.label;if(!belongs&&data[p*4+3]>0&&data[p*4+3]<100)for(let dy=-2;dy<=2&&!belongs;dy++)for(let dx=-2;dx<=2;dx++){const q=p+dy*w+dx;if(q>=0&&q<w*h&&visited[q]===c.label){belongs=true;break;}}if(belongs)data.copy(pixels,(y*width+x)*4,p*4,p*4+4);}
  await sharp(pixels,{raw:{width,height,channels:4}}).extend({top:8,bottom:8,left:8,right:8,background:'#00000000'}).webp({lossless:true}).toFile(path.join(out,names[i]+'.webp'));console.log(id,names[i],JSON.stringify(c));}
}
async function main(){
 require('./create-hud-reference-assets.cjs');
 for(const [id,names]of Object.entries(mapping))await sprites(id,names);
 const ground=path.join(source,'ground.png'),m=await sharp(ground).metadata(),half=Math.floor(m.width/2);
 for(const [i,name]of ['grass','dirt','sand','pavement'].entries()){
  await sharp(ground).extract({left:(i%2)*half+3,top:Math.floor(i/2)*half+3,width:half-6,height:half-6}).png().toFile(path.join(out,name+'.png'));
  // Keep the existing world shader's paths; only the town renderer consumes these textures.
  fs.copyFileSync(path.join(out,name+'.png'),path.join(root,'godot/assets/refined-world',name+'.png'));
 }
 for(const id of ['menu-background','world-map'])await sharp(path.join(source,id+'.png')).webp({quality:94}).toFile(path.join(out,id+'.webp'));
 const manifestFile=path.join(root,'godot/data/resource-manifest.json'),manifest=JSON.parse(fs.readFileSync(manifestFile));
 for(const key of Object.keys(manifest.files))if(key.startsWith('assets/starlit-town/')&&key.endsWith('.import'))delete manifest.files[key];
 for(const name of fs.readdirSync(out).filter(name=>/\.(png|webp)$/.test(name))){const relative='assets/starlit-town/'+name;manifest.files[relative]=fs.statSync(path.join(out,name)).size;}
 for(const name of fs.readdirSync(path.join(root,'godot/assets/ui/hud-filled')).filter(name=>name.endsWith('.svg'))){const relative='assets/ui/hud-filled/'+name;manifest.files[relative]=fs.statSync(path.join(root,'godot',relative)).size;}
 manifest.files['assets/fonts/NotoSerifSC.ttf']=fs.statSync(path.join(root,'godot/assets/fonts/NotoSerifSC.ttf')).size;
 for(const name of ['grass.png','dirt.png','sand.png','pavement.png','road-mask.png','maps/town.png'])manifest.files['assets/refined-world/'+name]=fs.statSync(path.join(root,'godot/assets/refined-world',name)).size;
 fs.writeFileSync(manifestFile,JSON.stringify(manifest,null,2)+'\n');
}
main().catch(e=>{console.error(e);process.exitCode=1;});
