// Development-only: derive UI sizes, verify alpha and render contact sheets.
const fs=require('fs'),path=require('path');
const sharp=require(process.env.SHARP_MODULE||'sharp');
const root='assets/world',catalog=JSON.parse(fs.readFileSync(root+'/catalog.json','utf8').replace(/^\uFEFF/,''));
(async()=>{fs.mkdirSync('artifacts',{recursive:true});const report=[],masks={};
 for(const [kind,entries]of [['buildings',catalog.buildings],['portraits',catalog.portraits]]){
   const layers=[];for(let i=0;i<entries.length;i++){
     const e=entries[i],master=root+'/'+e.master,size=kind==='buildings'?512:256,target=root+'/'+(e.scene||e.ui),meta=await sharp(master).metadata(),stats=await sharp(master).stats();
     if(!meta.hasAlpha||stats.channels[3].min!==0)throw Error('Missing transparent background: '+master);
     if(!e.runtimeOverride)await sharp(master).resize(size,size,{fit:'contain',background:{r:0,g:0,b:0,alpha:0}}).png({palette:true,colours:256,effort:6}).toFile(target);
     report.push({kind,id:e.id,width:meta.width,height:meta.height,alphaMin:stats.channels[3].min,alphaMax:stats.channels[3].max});
     if(kind==='buildings'){const {data,info}=await sharp(target).resize(64,64).ensureAlpha().raw().toBuffer({resolveWithObject:true}),bits=Buffer.alloc(512);for(let p=0;p<4096;p++)if(data[p*info.channels+3]>30)bits[p>>3]|=1<<(p&7);masks[e.id]=bits.toString('base64');}
     const left=(i%5)*180,top=Math.floor(i/5)*195;layers.push({input:await sharp(master).resize(166,166,{fit:'contain',background:{r:0,g:0,b:0,alpha:0}}).toBuffer(),left:left+7,top:top+5});
     layers.push({input:Buffer.from(`<svg width="180" height="20"><text x="90" y="14" font-family="sans-serif" font-size="12" fill="#eee0b9" text-anchor="middle">${e.id}</text></svg>`),left,top:top+172});
   }
   await sharp({create:{width:900,height:780,channels:4,background:'#121d18'}}).composite(layers).png().toFile('artifacts/world-'+kind+'-contact.png');
 }
 for(const s of catalog.scenes){const m=await sharp(root+'/'+s.file).metadata();if(m.width!==480||m.height!==270)throw Error('Wrong minimap dimensions: '+s.id);}
 fs.writeFileSync('js/world-hit-masks.js','// Generated local alpha masks; file:// can query hit shapes without reading Canvas pixels.\nwindow.WorldHitMasks='+JSON.stringify(masks)+';\n');
 fs.writeFileSync('artifacts/world-assets-report.json',JSON.stringify({transparentAssets:report.length,scenes:catalog.scenes.length,assets:report},null,2));console.log('Verified 40 transparent subjects and 5 minimap backdrops.');
})().catch(e=>{console.error(e);process.exit(1);});
