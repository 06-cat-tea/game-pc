// Resize the generated transparent masters. No runtime dependency is added to the game.
const fs=require('fs'),path=require('path');
const sharp=require(process.env.SHARP_MODULE||'sharp');
const ids=['main-quest','side-quest','character','backpack','skills','equipment','enhancement','crafting','map','exploration','combat','rest','dialogue','affinity','achievement','save','load','settings','travel','title'];
(async()=>{
  fs.mkdirSync('assets/icons',{recursive:true});fs.mkdirSync('artifacts/legacy-icons',{recursive:true});
  const sources=fs.existsSync('.icon-source.json')?JSON.parse(fs.readFileSync('.icon-source.json','utf8').replace(/^\uFEFF/,'')):ids.map(id=>({id,path:`assets/icons/${id}-512.png`}));
  const reports=[];
  for(const s of sources){const master=`assets/icons/${s.id}-512.png`;
    if(path.resolve(s.path)!==path.resolve(master))await sharp(s.path).resize(512,512,{fit:'contain',background:{r:0,g:0,b:0,alpha:0}}).png({compressionLevel:9}).toFile(master);
    await sharp(master).resize(128,128).png({compressionLevel:9}).toFile(`artifacts/legacy-icons/${s.id}-128.png`);
    const meta=await sharp(master).metadata(),stats=await sharp(master).stats();if(!meta.hasAlpha||stats.channels[3].min!==0)throw Error(s.id+' has no transparent background');
    reports.push({id:s.id,width:meta.width,height:meta.height,transparent:true,bytes:fs.statSync(master).size});
  }
  if(reports.length!==20)throw Error('Expected 20 complete icons');
  const overlays=[];
  for(let i=0;i<ids.length;i++){overlays.push({input:await sharp(`assets/icons/${ids[i]}-512.png`).resize(180,180).toBuffer(),left:20+(i%5)*220,top:15+Math.floor(i/5)*225});const svg=Buffer.from(`<svg width="220" height="25"><text x="110" y="18" text-anchor="middle" font-size="13" fill="#d3b67a" font-family="sans-serif">${ids[i]}</text></svg>`);overlays.push({input:svg,left:(i%5)*220,top:195+Math.floor(i/5)*225});}
  await sharp({create:{width:1100,height:900,channels:4,background:'#141b17'}}).composite(overlays).png().toFile('artifacts/icon-contact-sheet.png');
  fs.writeFileSync('artifacts/icons.json',JSON.stringify(reports,null,2));console.log('20 original masters verified; legacy UI previews exported to artifacts');
})().catch(e=>{console.error(e);process.exitCode=1;});

