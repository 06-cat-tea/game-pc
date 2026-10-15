// Development-only preparation and verification. Image edits are performed with imagegen.
const fs=require('fs'),path=require('path');
const sharp=require(process.env.SHARP_MODULE||'sharp');
const root=path.resolve(__dirname,'../assets/environment');
const groups=[
 ['water','水域王国环境图标集',['blue-pool','deep-pool','clear-pool','grass-bank','sand-bank','flower-bank','canal-horizontal','canal-vertical','canal-left','canal-right','canal-cross','canal-cross-wide','waterfall','royal-channel','royal-basin','water-bridge','royal-fountain','lion-fountain','well','reeds','stepping-stones','dock','drain','lilies']],
 ['village','奇幻小镇与森林环境图标集',['cobblestone','brick','soil','window','door','roof','tavern-sign','market-stall','supplies','well','noticeboard','lantern-string','meadow','trail','cliff','bush','stump','fallen-log','rocks','campfire','tent','signpost','berry-bush','fence']],
 ['royal','皇家幻想城镇环境素材图集',['marble','cobblestone','brick','grass','flower-grass','hedge','tree','cypress','flower-urn','lamp','banner','bench','fountain','statue','stairs','arch','wall','iron-fence','flowerbed','crates','signpost','bridge','drain','noticeboard']],
 ['forest','手绘风格奇幻 RPG 环境素材表',['oak','pine','bush','rocks','soil','cobblestone','flagstone','lamp','signpost','fence','flowers','barrels']]
];
const forestRects=[[0,0,444,435],[444,0,292,435],[747,140,363,295],[1110,150,338,285],[174,435,340,310],[545,435,343,310],[909,435,363,310],[0,665,230,398],[230,746,260,317],[494,780,365,285],[859,780,280,285],[1140,792,308,273]];
const ground=new Set(['blue-pool','deep-pool','clear-pool','grass-bank','sand-bank','flower-bank','canal-horizontal','canal-vertical','canal-left','canal-right','canal-cross','canal-cross-wide','cobblestone','brick','soil','meadow','trail','marble','grass','flower-grass','flagstone']);
const fittings=new Set(['window','door','roof']);
async function prepare(){
 for(const d of ['sources','crops','masters','sprites'])fs.mkdirSync(path.join(root,d),{recursive:true});
 const entries=[];
 for(const [group,file,names]of groups){const source=path.join(root,'sources',group+'.png');fs.copyFileSync(path.join('C:/Users/23373/Downloads',file+'.png'),source);
  for(let i=0;i<names.length;i++){const name=names[i],id=group+'-'+String(i+1).padStart(2,'0')+'-'+name;const [left,top,width,height]=group==='forest'?forestRects[i]:[i%6*256,Math.floor(i/6)*256,256,256];
   await sharp(source).extract({left,top,width,height}).png().toFile(path.join(root,'crops',id+'.png'));
   const category=ground.has(name)?'ground':fittings.has(name)?'fitting':'object';
   entries.push({id,number:entries.length+1,name,group,source:'sources/'+group+'.png',sourceRect:{left,top,width,height},crop:'crops/'+id+'.png',master:'masters/'+id+'.png',sprite:'sprites/'+id+'.webp',category,anchor:category==='ground'?[.5,.5]:[.5,.91],regions:group==='water'?['fen','coast','city']:group==='royal'?['city','town']:group==='forest'?['wood','pass','town']:['town','wood','pass'],prompt:'Extract only '+name+' from the supplied crop. Preserve the entire icon, hand-painted fantasy RPG design, natural outline, fine foliage and water details. Remove beige background with true transparency, no labels, checkerboard or extra objects. Use consistent soft upper-left daylight, slightly muted natural greens and stone colors. One complete isolated environmental asset with a small transparent margin.'});
  }
 }
 fs.writeFileSync(path.join(root,'catalog.json'),JSON.stringify({version:1,entries},null,2));console.log('Prepared '+entries.length+' imagegen targets.');
}
async function build(){
 const catalog=JSON.parse(fs.readFileSync(path.join(root,'catalog.json'))),layers=[],report=[];
 fs.mkdirSync(path.resolve(__dirname,'../artifacts'),{recursive:true});
 for(const e of catalog.entries){const master=path.join(root,e.master),hasMaster=fs.existsSync(master),source=hasMaster?master:path.join(root,e.sprite);if(process.argv[3]==='partial'&&!fs.existsSync(source))continue;const meta=await sharp(source).metadata(),stats=await sharp(source).stats();if(!meta.hasAlpha||stats.channels[3].min!==0)throw Error('Missing alpha: '+e.id);
  if(hasMaster&&!e.runtimeOverride)await sharp(master).trim({background:'#00000000',threshold:10}).resize({width:384,height:384,fit:'inside',withoutEnlargement:true}).webp({lossless:true,effort:6}).toFile(path.join(root,e.sprite));
  const sm=await sharp(path.join(root,e.sprite)).metadata();e.width=sm.width;e.height=sm.height;if(hasMaster)e.masterSize=[meta.width,meta.height];report.push({id:e.id,alphaMin:stats.channels[3].min,width:sm.width,height:sm.height});
  const x=(e.number-1)%7*160,y=Math.floor((e.number-1)/7)*180;
  layers.push({input:await sharp(path.join(root,e.sprite)).resize(146,146,{fit:'contain',background:'#00000000'}).toBuffer(),left:x+7,top:y+2});
  layers.push({input:Buffer.from(`<svg width="160" height="30"><text x="80" y="13" text-anchor="middle" font-size="10" font-family="Arial" fill="#f0e5cb">${e.number}. ${e.id.replace(/^[^-]+-\d+-/,'')}</text></svg>`),left:x,top:y+151});
 }
 fs.writeFileSync(path.join(root,'catalog.json'),JSON.stringify(catalog,null,2));
 fs.writeFileSync(path.resolve(__dirname,'../js/environment-catalog.js'),'// Generated by tools/environment-assets.cjs build.\nwindow.EnvironmentCatalog='+JSON.stringify(catalog.entries.map(({id,name,category,anchor,width,height,regions})=>({id,name,category,anchor,width,height,regions})))+';\n');
 await sharp({create:{width:1120,height:2160,channels:4,background:'#28362f'}}).composite(layers).png().toFile(path.resolve(__dirname,'../artifacts/environment-contact.png'));
 fs.writeFileSync(path.resolve(__dirname,'../artifacts/environment-assets-report.json'),JSON.stringify({count:report.length,assets:report},null,2));console.log('Built and verified '+report.length+' transparent assets.');
}
(process.argv[2]==='prepare'?prepare():build()).catch(e=>{console.error(e);process.exit(1);});
