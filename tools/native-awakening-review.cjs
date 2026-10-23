const fs=require('node:fs'),path=require('node:path'),sharp=require('sharp'),assert=require('node:assert/strict');
const out=path.resolve(__dirname,'../artifacts/godot'),review=path.join(out,'upgrade-review');
function caption(text,width){return Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="30"><text x="12" y="22" font-family="Microsoft YaHei, sans-serif" font-size="16" fill="#293742">${text}</text></svg>`);}
async function sheet(entries,name,width,columns){
 const height=Math.round(width*9/16),tiles=[];
 for(let i=0;i<entries.length;i++){
  const left=i%columns*width,top=Math.floor(i/columns)*(height+30);
  tiles.push({input:caption(entries[i].label,width),left,top});
  tiles.push({input:await sharp(entries[i].file).resize(width,height).png().toBuffer(),left,top:top+30});
 }
 await sharp({create:{width:width*columns,height:Math.ceil(entries.length/columns)*(height+30),channels:4,background:'#f5f2eb'}}).composite(tiles).png().toFile(path.join(review,name));
}
async function main(){
 const effects=JSON.parse(fs.readFileSync(path.join(review,'combat-effects.json'),'utf8'));assert(effects.passed);
 await sheet(effects.results.filter(r=>r.kind==='ultimate').map(r=>({label:r.id+(r.reduced?' / reduced motion':''),file:r.file})),'ultimate-effects-overview.png',480,4);
 await sheet(effects.results.filter(r=>r.kind==='skill').map(r=>({label:r.id,file:r.file})),'active-skills-effects-overview.png',320,8);
 await sheet(['journal','town','character','awakening-eira'].map(view=>({label:view,file:path.join(out,view+'-1280x720.png')})),'startrack-ui-overview.png',640,2);
 await sheet(['room-observatory','room-archive','building-site-grayforge','building-log'].map(view=>({label:view,file:path.join(out,view+'-1280x720.png')})),'buildings-overview.png',640,2);
 console.log('Rendered UI, buildings, seven ultimates and all active-skill overview sheets.');
}
main().catch(error=>{console.error(error);process.exitCode=1});
