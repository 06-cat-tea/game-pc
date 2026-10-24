// Authoring source for the approved town redesign; original narrative stays untouched.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),sharp=require('sharp');
const root=path.resolve(__dirname,'..'),read=p=>JSON.parse(fs.readFileSync(path.join(root,p),'utf8'));
const content=read('godot/data/content.json'),narrative=read('godot/data/narrative.json'),world=read('godot/data/world-interactions.json');
const plots={
 'clocktower':[26,19,3,3], 'chapel':[25,8,4,4], 'guildhall':[17,17,4,3],
 'market':[18,26,4,3], 'inn':[37,29,4,3], 'artisan-quarter':[45,27,4,3],
 'star-academy':[37,13,4,4], 'alchemist-lab':[15,8,3,3], 'town-stables':[37,35,4,3],
 'north-gate':[28,3,4,2], 'royal-hall':[43,5,5,4]
};
const buildings=content.buildings.map(old=>{const [x,y,w,d]=plots[old.id];return {id:old.id,x,y,w,d,entry:[x+w/2,y+d+1.5],art:'res://assets/starlit-town/'+old.id+'.webp',anchor:[.5,.94]};});
function walkable(p){return p[0]>=2&&p[1]>=2&&p[0]<=61&&p[1]<=45&&!buildings.some(b=>p[0]>b.x-.3&&p[0]<b.x+b.w+.3&&p[1]>b.y-.3&&p[1]<b.y+b.d+.3);}
function safe(p){if(walkable(p))return p;for(let r=.5;r<20;r+=.5)for(let i=0;i<32;i++){const q=[p[0]+Math.cos(i*Math.PI/16)*r,p[1]+Math.sin(i*Math.PI/16)*r];if(walkable(q))return q.map(v=>+v.toFixed(2));}throw Error('No safe point');}
function relocate(p){const old=content.buildings.reduce((a,b)=>Math.hypot(p[0]-b.x-b.w/2,p[1]-b.y-b.d/2)<Math.hypot(p[0]-a.x-a.w/2,p[1]-a.y-a.d/2)?b:a);const b=buildings.find(b=>b.id===old.id);return safe([b.entry[0]+Math.max(-2,Math.min(2,p[0]-old.x-old.w/2)),b.entry[1]+.7]);}
const npcs={};
for(const [id,n]of Object.entries({...content.npcs,...narrative.npcs,...world.children}))if(n.position&&(!n.place||n.place==='town'))npcs[id]=relocate([n.position.x,n.position.y]);
Object.assign(npcs,{mira:[29.7,23.3],'gate-knight':[32,7],'alchemist':[19.4,12.5],pella:[13.4,13.4],'kid-ling':[24,13.5],'kid-luo':[42,33.5],'kid-aya':[20,31.8]});
const points={};
for(const group of ['animals','resources','objects','entrances'])for(const e of world[group])if((e.scene==='town'||e.region==='town')&&e.point)points[e.id]=relocate(e.point);
Object.assign(points,{'entrance-town-wall':[30,6.6],'entrance-town-drain':[12,20],'entrance-town-trial':[23,21],pawprints:[37.5,33.2],'feeding-bowl':[23,15.4],'chapel-mail':[29,13.5],tuantuan:[40,33.6],amo:[43.5,40.2],doudou:[31.5,25.5],'medicine-bag':[16.2,31.2],gugu:[31,16.5],'herb-1':[22.5,12],'herb-2':[14,23],'herb-3':[11,27],'ore-1':[36,40.5],'ore-2':[33,41.5]});
const roads=[[[8,24],[55,24],1.65],[[30,6],[30,43],1.6],[[12,14],[48,14],1.25],[[13,32],[49,32],1.5],[[21,13],[21,33],1.1],[[39,14],[39,41],1.2]];
for(const b of buildings){const e=b.entry;roads.push([[e[0],e[1]],[30,e[1]],.85]);roads.push([[e[0],e[1]],[e[0],e[1]-1.6],1]);}
function distance(p,a,b){const dx=b[0]-a[0],dy=b[1]-a[1],t=Math.max(0,Math.min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/(dx*dx+dy*dy||1)));return Math.hypot(p[0]-a[0]-dx*t,p[1]-a[1]-dy*t);}
function isRoad(p){return roads.some(([a,b,r])=>distance(p,a,b)<=r)||((p[0]-28)**2/49+(p[1]-24)**2/25<1);}
const terrain=Array.from({length:48},(_,y)=>Array.from({length:64},(_,x)=>isRoad([x+.5,y+.5])?'road':'grass'));
// Validate reachability before commissioning final art.
const visited=new Set(),queue=[[30,27]];
for(let i=0;i<queue.length;i++){const p=queue[i],k=p.join(',');if(visited.has(k)||!walkable(p))continue;visited.add(k);for(const d of [[1,0],[-1,0],[0,1],[0,-1]])queue.push([p[0]+d[0],p[1]+d[1]]);}
for(const p of [...buildings.map(b=>b.entry),...Object.values(npcs),...Object.values(points)])assert(walkable(p)&&visited.has(p.map(Math.round).join(',')),'Unreachable target '+p);
const interactions=Object.entries({...npcs,...points});
for(let i=0;i<interactions.length;i++)for(let j=i+1;j<interactions.length;j++){const [id,a]=interactions[i],[other,b]=interactions[j];assert(Math.hypot(a[0]-b[0],a[1]-b[1])>=1.2,'Overlapping interactions: '+id+' / '+other);}
for(let i=0;i<buildings.length;i++)for(let j=i+1;j<buildings.length;j++){const a=buildings[i],b=buildings[j];assert(a.x+a.w+.7<b.x||b.x+b.w+.7<a.x||a.y+a.d+.7<b.y||b.y+b.d+.7<a.y,'Overlapping plots');}
const decor=[];
function add(p,asset,width,large=false,group='street'){if(!walkable(p)||isRoad(p)||terrain[Math.floor(p[1])][Math.floor(p[0])]==='road')return;if([...buildings.map(b=>b.entry),...Object.values(npcs),...Object.values(points)].some(e=>Math.hypot(p[0]-e[0],p[1]-e[1])<(large?2.7:1.65)))return;decor.push({point:p,asset:'res://assets/starlit-town/'+asset+'.webp',width,large,group,anchor:[.5,.94]});}
for(const b of buildings){for(const [dx,dy,kind,w]of [[-.9,-.5,'flowers',65],[b.w+1,-.5,'tree',180],[-1,b.d*.4,'lamp',26],[b.w+1,b.d+.5,'flowers',60]])add([b.x+dx,b.y+dy],kind,w,kind==='tree',b.id);}
for(let x=3;x<62;x+=3.4)for(const y of [3,44])add([x,y],'tree',175+(x%3)*15,true,'green-belt');
for(let y=6;y<44;y+=3.4)for(const x of [3,60])add([x,y],'tree',190,true,'green-belt');
for(const p of [[23,18],[23,28],[32,20],[32,28],[16,23],[35,25],[36,31],[24,15]])add(p,'lamp',26,false,'square');
for(const p of [[16.5,26],[17,30],[23.5,29],[34,34]])add(p,'stall',160,false,'market');
for(const p of [[12,26],[24,34],[34,18],[34,10],[23,8],[16,35],[46,20],[48,37]])add(p,'tree',210,true,'courtyard');
const design={version:1,reference:'art-source/ui-concepts/genshin-v1/01-exploration.png',buildings,npcs,points,terrain,roads,decor,spawn:[30,27],cameraOffset:[0,-125],bounds:[-3072,-700,6144,3950]};
fs.writeFileSync(path.join(root,'godot/data/town-design.json'),JSON.stringify(design,null,2)+'\n');
const iso=([x,y])=>[(x-y)*12+800,(x+y)*6+50];
const svg='<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="850" style="background:#d8e1cb">'+roads.map(([a,b,r])=>{const p=iso(a),q=iso(b);return `<path d="M${p} L${q}" stroke="#f2eee0" stroke-width="${r*22}" fill="none"/>`;}).join('')+buildings.map(b=>{const corners=[[b.x,b.y],[b.x+b.w,b.y],[b.x+b.w,b.y+b.d],[b.x,b.y+b.d]].map(iso);const e=iso(b.entry);return `<polygon points="${corners.map(p=>p.join(',')).join(' ')}" fill="#6c8095" stroke="#fff"/><circle cx="${e[0]}" cy="${e[1]}" r="4" fill="#a66743"/><text x="${corners[0][0]}" y="${corners[0][1]-5}" font-size="14">${b.id}</text>`;}).join('')+'</svg>';
const review=path.join(root,'art-source/starlit-town/v1');fs.mkdirSync(review,{recursive:true});fs.writeFileSync(path.join(review,'layout.svg'),svg);
async function main(){const mask=Buffer.from(terrain.flat().map(t=>t==='road'?255:0));await sharp(mask,{raw:{width:64,height:48,channels:1}}).resize(1024,768,{kernel:'cubic'}).blur(2).png().toFile(path.join(root,'godot/assets/refined-world/road-mask.png'));console.log(JSON.stringify({passed:true,buildings:buildings.length,reachableCells:visited.size,npcs:Object.keys(npcs).length,interactions:Object.keys(points).length,decor:decor.length}));}
main().catch(e=>{console.error(e);process.exitCode=1;});
