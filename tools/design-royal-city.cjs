// Authoritative city geometry. Original names, IDs, services and interiors stay intact.
const fs=require('node:fs'),path=require('node:path'),sharp=require('sharp');
const root=path.resolve(__dirname,'..'),file=path.join(root,'godot/data/world-regions.json');
const regions=JSON.parse(fs.readFileSync(file)),c=regions.city;
const roads=[];
function road(a,b,width,kind='lane'){roads.push({points:[a,b],width,kind});}
function distance(p,a,b){const dx=b[0]-a[0],dy=b[1]-a[1],t=Math.max(0,Math.min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/(dx*dx+dy*dy||1)));return Math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dy);}
const inRect=(p,r,pad=0)=>p[0]>=r.x-pad&&p[0]<=r.x+r.w+pad&&p[1]>=r.y-pad&&p[1]<=r.y+r.d+pad;
const onRoad=(p,extra=0)=>roads.some(r=>distance(p,...r.points)<=r.width/2+extra);
// Six-cell crown boulevard and cross-city avenue; four-cell district streets.
road([48,4],[48,69],6,'main');road([3,42],[92,42],6,'main');
for(const x of [16,80])road([x,3],[x,69],4,'street');
for(const y of [18,66])road([3,y],[92,y],4,'street');
road([59,3],[59,69],2,'riverside');road([67,3],[67,69],2,'riverside');
for(const y of [18,42,66])road([58,y],[68,y],y===42?6:4,'bridge');
// Each district has front gardens, short connecting alleys and an open street edge.
const slots={
 gate:[[5,50],[23,50],[5,56],[23,56],[5,60.5],[25,60.5]],
 market:[[35,50],[53,50],[35,56],[53,56],[35,60.5],[53,60.5],[40.5,50]],
 craft:[[5,26],[23,26],[5,31],[23,31],[5,35.5],[25,35.5]],
 academy:[[70,3],[86,3],[70,8.7],[86,8.7],[70,12.5],[86,12.5]],
 palace:[[35,3],[51.6,3],[35,10],[53,10],[39,23]],
 harbor:[[70,50],[86,50],[70,56],[86,56],[70,60.5],[86,60.5]],
 faith:[[5,3],[23,3],[5,8.7],[23,8.7],[5,12.5]],
 oldtown:[[35,27],[53,27],[35,31.5],[53,31.5],[35,35.5],[53,35.5]],
 garden:[[70,27],[86,26],[70,31],[86,32],[70,35.5]]
};
for(const b of c.buildings){
 const [,district,index]=b.id.split('-'),p=slots[district][Number(index)];b.x=p[0];b.y=p[1];
 // Closely spaced middle rows open toward the side alley, never into the next house.
 const down=[b.x+b.w/2,b.y+b.d+1.4],side=[b.x+(b.x%32<16?b.w+1.4:-1.4),b.y+b.d-.3];
 b.entry=down;b.display_width=(b.w+b.d)*52;
 b._side=side;
}
// Final positions must be resolved before finding a safe, front-facing entry.
for(const b of c.buildings){
 const candidates=[b.entry,b._side,[b.x+b.w+1.4,b.y+b.d-.1],[b.x-1.4,b.y+b.d-.1]];
 b.entry=candidates.find(p=>p[0]>2&&p[0]<93&&p[1]<69&&!c.buildings.some(o=>inRect(p,o,1.3)));
 if(!b.entry)throw Error('No safe entry: '+b.id);delete b._side;
 // Join via a clear elbow to the nearest street; route around real footprints.
 const goals=roads.filter(r=>r.kind!=='alley').flatMap(r=>{
  const [a,z]=r.points;return [a[0]===z[0]?[a[0],b.entry[1]]:[b.entry[0],a[1]]];
 }).sort((a,z)=>Math.hypot(...a.map((v,i)=>v-b.entry[i]))-Math.hypot(...z.map((v,i)=>v-b.entry[i])));
 let route;
 const clear=(a,z)=>{for(let i=0;i<=Math.ceil(distance(a,z,z)*8)+1;i++){const t=i/(Math.ceil(distance(a,z,z)*8)+1),p=a.map((v,k)=>v+(z[k]-v)*t);if(c.buildings.some(o=>inRect(p,o,1.3)))return false;}return true;};
 for(const g of goals){for(const elbow of [[b.entry[0],g[1]],[g[0],b.entry[1]]])if(clear(b.entry,elbow)&&clear(elbow,g)){route=[b.entry,elbow,g];break;}if(route)break;}
 if(!route)throw Error('No road connection: '+b.id);
 for(let i=1;i<route.length;i++)if(distance(route[i-1],route[i],route[i])>.01)road(route[i-1],route[i],2,'alley');
}
// Keep the central square spacious; fountains sit in gardens off the through road.
c.plazas=[{x:48,y:42,w:14,d:6},{x:48,y:18,w:10,d:7},{x:16,y:66,w:9,d:6},{x:80,y:42,w:10,d:8}];
c.bridges.find(b=>b.y===42).d=6;
c.terrain=Array.from({length:c.rows},(_,y)=>Array.from({length:c.columns},(_,x)=>{
 if(x<2||y<2||x>92||y>69)return 'wall';
 const bridge=c.bridges.some(b=>inRect([x+.5,y+.5],{x:b.x-b.w/2,y:b.y-b.d/2,w:b.w,d:b.d}));
 if(x>=61&&x<=63&&!bridge)return 'water';
 return onRoad([x+.5,y+.5])||c.plazas.some(p=>Math.abs(x+.5-p.x)<p.w/2&&Math.abs(y+.5-p.y)<p.d/2)?'road':'ground';
}));
c.roads=roads;c.decor=[];c.lights=[];c.spawn=[16,68];
const decor=c.decor,occupied=[];
function put(asset,p,width,style='',collision=null){
 if(p[0]<2.5||p[0]>92||p[1]<2.5||p[1]>68.5||p[0]>60&&p[0]<65)return;
 if(c.buildings.some(b=>inRect(p,b,.7)||Math.hypot(p[0]-b.entry[0],p[1]-b.entry[1])<1.2)||onRoad(p,collision?Math.max(...collision)+.25:.55))return;
 if(occupied.some(o=>Math.hypot(o[0]-p[0],o[1]-p[1])<1.05))return;
 const assetPath=asset.startsWith('res:')?asset:c.environment[asset];if(!assetPath)throw Error(asset);
 decor.push({point:p,asset:assetPath,width,tall:['tree','lamp','banner'].includes(style),style,anchor:[.5,.96],...(collision?{collision}: {})});occupied.push(p);
 if(style==='lamp')c.lights.push({point:p,color:'ffd28a',energy:1.0,radius:250,height:100});
}
for(const d of c.districts){
 const district=c.buildings.filter(b=>b.id.startsWith('city-'+d.id+'-'));
 for(const [i,b]of district.entries()){
  put('royal-09-flower-urn',[b.x-.9,b.y+b.d+.3],30,'flowers');
  put('royal-10-lamp',[b.x+b.w+1,b.y+b.d+.3],29,'lamp',[.3,.3]);
  if(['market','harbor','craft'].includes(d.id))put('res://assets/starlit-town/stall.webp',[b.x+b.w+1.5,b.y+1],100,'stall',[.65,.55]);
  put('royal-11-banner',[b.x+b.w+.9,b.y+.7],36,'banner');
  put('royal-19-flowerbed',[b.x+b.w/2,b.y-.7],76,'flowers',[1.1,.35]);
  if(['faith','garden','palace','academy'].includes(d.id))put('royal-08-cypress',[b.x-1,b.y+.7],82,'tree',[.4,.4]);
  if(['market','craft','harbor'].includes(d.id))put('res://assets/regions/environment/forest-12-barrels.webp',[b.x-1.2,b.y+1.5],62,'supplies',[.45,.35]);
  if(['palace','faith','garden','academy'].includes(d.id))put('royal-17-wall',[b.x+b.w/2,b.y-1.1],105,'wall',[1.1,.28]);
  if(d.id==='oldtown')put('royal-06-hedge',[b.x+b.w/2,b.y-.8],88,'hedge',[1,.35]);
 }
 for(const p of [[d.x-4,d.y-4],[d.x+4,d.y-5],[d.x-5,d.y+3]])put('royal-07-tree',p,135,'tree',[.5,.5]);
}
for(const x of [12.3,19.7,44.3,51.7,76.3,83.7])for(const y of [23,47,68])put('royal-10-lamp',[x,y],29,'lamp',[.28,.28]);
for(const y of [7,23,31,47,55,63])put('royal-10-lamp',[65.3,y],29,'lamp',[.25,.25]);
for(const x of [55.4,69.6])for(const y of [7,24,32,48,56]){
 put('royal-12-bench',[x,y],68,'bench',[.7,.35]);put('royal-19-flowerbed',[x,y+2],83,'flowers',[1,.35]);
}
for(const [p,key]of [[[42,22],'royal-13-fountain'],[[74,46],'royal-13-fountain'],[[22,22],'royal-14-statue']])put(key,p,120,'monument',[.75,.75]);
for(const p of [[42,48],[74,48],[88,46],[42,22]]){
 if(decor.filter(d=>d.asset===c.environment['royal-13-fountain']).length>=2)break;
 put('royal-13-fountain',p,128,'monument',[.75,.75]);
}
for(const x of [43.5,52.5])for(const y of [10,22,34,46,58]){
 put('royal-19-flowerbed',[x,y],88,'flowers',[.8,.35]);
 put('royal-12-bench',[x,y+1.8],70,'bench',[.7,.35]);
}
// Streets contain no objects; lamps and trees are placed on their outside verge.
const collisions=decor.filter(d=>d.collision).map(d=>({x:d.point[0]-d.collision[0],y:d.point[1]-d.collision[1],w:d.collision[0]*2,d:d.collision[1]*2}));
const walk=p=>p[0]>=2&&p[0]<=93&&p[1]>=2&&p[1]<=69&&!c.buildings.some(b=>inRect(p,b,.3))&&!collisions.some(r=>inRect(p,r))&&c.terrain[Math.floor(p[1])]?.[Math.floor(p[0])]!=='water'&&c.terrain[Math.floor(p[1])]?.[Math.floor(p[0])]!=='wall';
for(const b of c.buildings)for(const other of c.buildings)if(b.id<other.id&&b.x<other.x+other.w&&b.x+b.w>other.x&&b.y<other.y+other.d&&b.y+b.d>other.y)throw Error('Overlapping buildings '+b.id+' '+other.id);
for(const b of c.buildings)if(!walk(b.entry))throw Error('Blocked entry '+b.id);
for(const r of roads.filter(r=>['main','street','bridge','riverside'].includes(r.kind))){const [a,z]=r.points,n=Math.ceil(distance(a,z,z)*5),v=[z[0]-a[0],z[1]-a[1]],len=Math.hypot(...v);for(let i=0;i<=n;i++)for(const side of [-1,0,1]){const p=[a[0]+v[0]*i/n-v[1]/len*side*(r.width/2-.15),a[1]+v[1]*i/n+v[0]/len*side*(r.width/2-.15)];if(c.buildings.some(b=>inRect(p,b,.3)))throw Error('Street obstructed: '+JSON.stringify(p));}}
const seen=new Set(),queue=[c.spawn.map(Math.round)];for(let i=0;i<queue.length;i++){const p=queue[i],key=p.join(',');if(seen.has(key)||!walk(p))continue;seen.add(key);for(const v of [[1,0],[-1,0],[0,1],[0,-1]])queue.push([p[0]+v[0],p[1]+v[1]]);}
for(const b of c.buildings)if(!seen.has(b.entry.map(Math.round).join(',')))throw Error('Unreachable: '+b.id);
// Resident routes use the actual clear street; interactive NPC content remains unchanged.
c.residents=c.districts.map((d,i)=>({art:c.residents[i].art,width:70,points:[[d.x,d.y],[d.x+1,d.y],[d.x+1,d.y+.5],[d.x,d.y+.5]]}));
c.npcPositions={};const npcUsed=c.buildings.map(b=>b.entry);
for(const [id,npc] of Object.entries(JSON.parse(fs.readFileSync(path.join(root,'godot/data/narrative.json'))).npcs)){
 if(npc.place!=='city')continue;const b=c.buildings.find(b=>b.id===npc.home);if(!b)continue;
 let candidate;for(const radius of [1.4,2.0,2.6,3.2]){for(let i=0;i<24;i++){const p=[b.entry[0]+Math.cos(i*Math.PI/12)*radius,b.entry[1]+Math.sin(i*Math.PI/12)*radius];if(walk(p)&&onRoad(p)&&!npcUsed.some(o=>Math.hypot(o[0]-p[0],o[1]-p[1])<1.2)){candidate=p;break;}}if(candidate)break;}
 if(!candidate)throw Error('NPC placement '+id);c.npcPositions[id]=candidate;npcUsed.push(candidate);
}
c.designVersion=2;
fs.writeFileSync(file,JSON.stringify(regions,null,2)+'\n');
const source=path.join(root,'art-source/royal-city/v2');fs.mkdirSync(source,{recursive:true});
fs.writeFileSync(path.join(source,'layout.json'),JSON.stringify({buildings:c.buildings,roads,plazas:c.plazas,decor},null,2)+'\n');
const iso=([x,y])=>[800+(x-y)*8,(x+y)*4-5];
const polygon=(b)=>[[b.x,b.y],[b.x+b.w,b.y],[b.x+b.w,b.y+b.d],[b.x,b.y+b.d]].map(iso).map(p=>p.join(',')).join(' ');
fs.writeFileSync(path.join(source,'layout.svg'),'<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="740" style="background:#bdc5a4">'+roads.map(r=>`<path d="M${iso(r.points[0])} L${iso(r.points[1])}" fill="none" stroke="#eee6d1" stroke-width="${r.width*6}"/>`).join('')+c.buildings.map(b=>`<polygon points="${polygon(b)}" fill="#576e85" stroke="#e6d19b"/><circle cx="${iso(b.entry)[0]}" cy="${iso(b.entry)[1]}" r="2" fill="#bc5d40"/>`).join('')+'</svg>');
const pixels=Buffer.alloc(c.columns*c.rows*3);c.terrain.forEach((row,y)=>row.forEach((v,x)=>{const i=(y*c.columns+x)*3;pixels[i]=v==='road'?255:0;pixels[i+1]=v==='water'?255:0;pixels[i+2]=v==='wall'?255:0;}));
sharp(pixels,{raw:{width:c.columns,height:c.rows,channels:3}}).resize(c.columns*8,c.rows*8,{kernel:'nearest'}).png().toFile(path.join(root,'godot/assets/regions/city-mask.png')).then(()=>console.log(JSON.stringify({buildings:c.buildings.length,decor:decor.length,roads:roads.length,reachable:seen.size,passed:true})));
