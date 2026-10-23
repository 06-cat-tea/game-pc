const fs=require('node:fs'),path=require('node:path'),sharp=require('sharp'),assert=require('node:assert/strict');
const out=path.resolve(__dirname,'../artifacts/godot/upgrade-review');
async function main(){
 const report=JSON.parse(fs.readFileSync(path.join(out,'motion-recording.json'),'utf8'));assert(report.passed);
 const frames=await Promise.all(report.frames.map(f=>sharp(f.file).resize(640,360).ensureAlpha().raw().toBuffer()));
 await sharp(Buffer.concat(frames),{raw:{width:640,height:360*frames.length,channels:4,pageHeight:360}}).webp({quality:65,loop:0,delay:100,effort:3}).toFile(path.join(out,'eight-direction-recording.webp'));
 const tiles=[];for(let i=0;i<report.frames.length;i+=6)tiles.push({input:await sharp(report.frames[i+2].file).resize(320,180).png().toBuffer(),left:(i/6%4)*320,top:Math.floor(i/24)*180});
 await sharp({create:{width:1280,height:1080,channels:4,background:'#f5f2eb'}}).composite(tiles).png().toFile(path.join(out,'movement-scenes-overview.png'));
 console.log('Encoded '+frames.length+' recorded frames into eight-direction-recording.webp');
}
main().catch(e=>{console.error(e);process.exitCode=1});
