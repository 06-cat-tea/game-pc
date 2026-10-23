const fs=require('node:fs'),path=require('node:path'),sharp=require('sharp'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..'),native=path.join(root,'godot'),ids=['hero','mira','toren','sylvi','ridge-scout','eira','alchemist'];
async function inspect(file,w,h){const {data,info}=await sharp(file).ensureAlpha().raw().toBuffer({resolveWithObject:true});assert.equal(info.width,w,file);assert.equal(info.height,h,file);let transparent=0,opaque=0,minX=w,minY=h,maxX=-1,maxY=-1;for(let y=0;y<h;y++)for(let x=0;x<w;x++){const a=data[(y*w+x)*4+3];if(a===0)transparent++;if(a>180){opaque++;minX=Math.min(minX,x);maxX=Math.max(maxX,x);minY=Math.min(minY,y);maxY=Math.max(maxY,y);}}assert(transparent>w*h*.05&&opaque>w*h*.05,'Invalid alpha/content: '+file);return{file:path.relative(native,file).replaceAll('\\','/'),alpha:true,bounds:[minX,minY,maxX,maxY],bytes:fs.statSync(file).size};}
async function main(){
 const portraits=[],avatars=[],frames=[];
 for(const id of ids){for(const mood of ['neutral','smile','serious'])portraits.push(await inspect(path.join(native,'assets/characters',id,'static-v2',mood+'.webp'),768,1152));avatars.push(await inspect(path.join(native,'assets/characters',id,'static-v2/avatar.webp'),256,256));}
 const movement=JSON.parse(fs.readFileSync(path.join(native,'data/movement.json')));
 for(const dir of movement.order){const entry=movement.directions[dir];for(const file of [entry.idle,...entry.walk])frames.push(await inspect(path.join(native,file.slice(6)),384,384));}
 for(const frame of frames)assert(frame.bounds[3]>=360&&frame.bounds[3]<=366,'Sprite feet are not aligned: '+frame.file);
 const report={passed:true,portraits:portraits.length,avatars:avatars.length,movementFrames:frames.length,portraitBytes:portraits.reduce((n,p)=>n+p.bytes,0),details:{portraits,avatars,frames}};
 fs.writeFileSync(path.join(root,'artifacts/godot/native-character-acceptance.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({...report,details:undefined}));
}
main().catch(error=>{console.error(error);process.exitCode=1;});
