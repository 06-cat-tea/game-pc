// Maintained four-biome scene composition. Functional IDs and the royal city are preserved.
const fs=require('node:fs'),path=require('node:path'),sharp=require('sharp'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..'),source=path.join(root,'art-source/regional-redraw/v1');
const file=path.join(root,'godot/data/world-regions.json'),regions=JSON.parse(fs.readFileSync(file));
const bases=JSON.parse(fs.readFileSync(path.join(source,'layout-base.json'))),content=JSON.parse(fs.readFileSync(path.join(root,'godot/data/content.json')));
const interactions=JSON.parse(fs.readFileSync(path.join(root,'godot/data/world-interactions.json')));
const art=name=>'res://assets/regional-redraw/'+name+'.webp';
const distance=(a,b)=>Math.hypot(a[0]-b[0],a[1]-b[1]);
function segment(p,a,b){const dx=b[0]-a[0],dy=b[1]-a[1],t=Math.max(0,Math.min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/(dx*dx+dy*dy||1)));return distance(p,[a[0]+t*dx,a[1]+t*dy]);}
const inRect=(p,b,pad=0)=>p[0]>=b.x-pad&&p[0]<=b.x+b.w+pad&&p[1]>=b.y-pad&&p[1]<=b.y+b.d+pad;
function inPoly(p,poly){let inside=false;for(let i=0,j=poly.length-1;i<poly.length;j=i++){const a=poly[i],b=poly[j];if((a[1]>p[1])!==(b[1]>p[1])&&p[0]<(b[0]-a[0])*(p[1]-a[1])/(b[1]-a[1])+a[0])inside=!inside;}return inside;}
function smooth(points){
 const line=points.filter((p,i)=>i===0||i===points.length-1||(p[0]-points[i-1][0])*(points[i+1][1]-p[1])!==(p[1]-points[i-1][1])*(points[i+1][0]-p[0]));
 const result=[line[0]];
 for(let i=1;i<line.length-1;i++){
  const a=line[i-1],b=line[i],c=line[i+1],radius=Math.min(.8,distance(a,b)*.3,distance(b,c)*.3);
  const u=b.map((v,k)=>v+(a[k]-v)*radius/distance(a,b)),v=b.map((z,k)=>z+(c[k]-z)*radius/distance(b,c));
  result.push(u);for(let j=1;j<=5;j++){const t=j/5;result.push(u.map((z,k)=>(1-t)*(1-t)*z+2*t*(1-t)*b[k]+t*t*v[k]));}
 }
 result.push(line.at(-1));return result;
}
function roadDistance(p,road){let d=Infinity;for(let i=1;i<road.points.length;i++)d=Math.min(d,segment(p,road.points[i-1],road.points[i]));return d;}
function random(seed){return()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};}
function bridgeRect(b){return {x:b.x-b.w/2,y:b.y-b.d/2,w:b.w,d:b.d};}
const report=[];
async function main(){
 for(const [index,id]of ['wood','pass','fen','coast'].entries()){
  const base=structuredClone(bases[id]),d=regions[id];
  d.designVersion=2;d.artVersion='regional-redraw-v1';d.ground=art(id+'-ground');d.road=art(id+'-road');
  const sizes={'forest-hut':[4,3],'moss-shrine':[5,3],'moon-well':[2.8,2.5],'windmill-farm':[4.5,3.5],waystation:[4.5,3.5],grayforge:[4,3],'caravan-yard':[4.5,3],'ridge-barracks':[3.6,3.5],'deep-mine':[5.5,4.5],'ember-fortress':[5,4.5],'sunken-temple':[5.5,4.5],'royal-crypt':[4.2,3.2],'moon-shrine':[2.8,2.5],'violet-rift':[4,3],'cloud-observatory':[5,4],lighthouse:[3,3],'fisher-hut':[4,3],'wreck-shrine':[3,2.5],'tide-harbor':[4,3]};
  d.buildings=base.buildings.map(original=>{const b={...original},size=sizes[b.id];b.w=size[0];b.d=size[1];b.entry=b.id==='windmill-farm'?[27.25,43]:b.entry;b.x=b.entry[0]-b.w/2;b.y=b.entry[1]-b.d-1.5;return {...b,art:art(b.id),anchor:[.5,b.id==='lighthouse'?.93:.9],display_width:(b.w+b.d)*(b.id==='lighthouse'?70:58)};});
  d.roads=base.roads.filter(r=>!r.building_id).map(r=>({...r,width:id==='wood'?2.7:r.width,points:smooth(r.points)}));d.bridges=base.bridges.map(b=>({...b,material:'wood'}));
  if(id==='fen'){
   d.roads[0].points=smooth([[12,40],[18,40],[18,32]]);
   d.roads[1].points=smooth([[18,32],[23,32],[23,28],[24,27]]);
   d.roads[3].points=smooth([[36,22],[36,20],[48,20]]);
   d.bridges[0].x=22.5;d.bridges[0].w=4.8;
  }
  const facilities=[];
  const addRoad=(points,width=2.4,kind='service')=>d.roads.push({points:smooth(points),width,kind,building_id:''});
  if(id==='coast'){
   facilities.push(
    {id:'harbor-warehouse',name:'港口货栈',x:31,y:15,w:4,d:3,entry:[33,19.4]},
    {id:'harbor-fishmarket',name:'鱼市',x:30.5,y:23,w:3.8,d:2.8,entry:[32.4,27.2]},
    {id:'harbor-boathouse',name:'修船棚',x:38,y:16,w:4,d:3.2,entry:[40,20.6]}
   );
   addRoad([[36.5,30],[36.5,21.5]],2.4,'harbor-street');
   addRoad([[33,19.4],[33,21.5],[36.5,21.5],[40,21.5],[54.5,21.5]],2.4,'quayside');
   addRoad([[32.4,27.2],[32.4,30]],2.4,'market-access');
   addRoad([[40,20.6],[40,21.5]],2.2,'shipyard-access');
   d.bridges.push({x:49,y:22,w:14,d:3.8,material:'wood',kind:'main-pier'},{x:46,y:28,w:2.8,d:14,material:'wood',kind:'quay'},{x:51,y:30,w:10,d:4.4,material:'wood',kind:'finger-pier'});
   // The quay links the shore road and both working jetties.
   addRoad([[46,22],[46,35]],2.2,'quay-access');addRoad([[46,30],[55,30]],2.2,'finger-access');
   d.harbor={bounds:[29,13,31,24],facilities,roads:['harbor-street','quayside','market-access','shipyard-access','quay-access','finger-access'],berths:[[52,25.8],[58.2,29.5],[51,18]],service_id:'tide-harbor'};
  }
  const footprints=[...d.buildings,...facilities];
  const npcs=Object.values(content.npcs).filter(n=>n.place===id&&n.position).map(n=>[n.position.x,n.position.y]);
  const entrances=interactions.entrances.filter(e=>e.region===id).map(e=>e.point);
  const protectedPoints=[d.spawn,[d.spawn[0],d.spawn[1]+1],...footprints.map(b=>b.entry),...npcs,...entrances];
  const water=p=>d.water.some(poly=>inPoly(p,poly));
  const protectedAt=(p,pad=.4)=>protectedPoints.some(q=>distance(p,q)<2.1+pad)||d.roads.some(r=>roadDistance(p,r)<r.width/2+pad)||d.bridges.some(b=>inRect(p,bridgeRect(b),pad));
  const bareWalk=p=>p[0]>=2&&p[1]>=2&&p[0]<=61&&p[1]<=45&&!footprints.some(b=>inRect(p,b,.3))&&!d.rocks.some(poly=>inPoly(p,poly))&&(!water(p)||d.bridges.some(b=>inRect(p,bridgeRect(b))));
  // Reconnect enlarged building plots rather than drawing roads through them.
  const destinations=d.roads.slice();
  for(const b of d.buildings){
   const start=b.entry.map(v=>Math.round(v*2)),key=p=>p.join(','),queue=[start],previous=new Map([[key(start),null]]);
   const centerClear=p=>bareWalk(p)&&!footprints.some(o=>inRect(p,o,1.16));let end=null;
   for(let j=0;j<queue.length&&!end;j++){
    const cell=queue[j],p=cell.map(v=>v/2);
    if(destinations.some(r=>roadDistance(p,r)<Math.min(.65,r.width/2-.3))){end=cell;break;}
    for(const [dx,dy]of [[1,0],[-1,0],[0,1],[0,-1]]){const next=[cell[0]+dx,cell[1]+dy],name=key(next);if(previous.has(name)||!centerClear(next.map(v=>v/2)))continue;previous.set(name,cell);queue.push(next);}
   }
   assert(end,'No clear branch road '+b.id);const route=[];for(let at=end;at;at=previous.get(key(at)))route.push(at.map(v=>v/2));route.reverse();
   if(distance(b.entry,route[0])>.01)route.unshift(b.entry);
   d.roads.push({points:smooth(route),width:2.0,building_id:b.id,kind:'landmark-access'});
  }
  const rng=random(20261025+index*971),decor=[],workspaces=[];
  function add(p,name,width,{tall=false,collision=null,group='habitat',allowWater=false,force=false,style=''}={}){
   if(!allowWater&&['canyon-cliff','coastal-rock','marsh-rock'].includes(name)){
    var radius=Math.min(1.0,width/280);collision=[radius,radius];
   }
   if(p[0]<2.3||p[0]>61||p[1]<2.3||p[1]>45)return false;
   if(id==='coast'&&['coastal-pine','coastal-rock'].includes(name)&&group!=='shoreline'&&p[0]>29&&p[0]<58&&p[1]>13&&p[1]<36)return false;
   if(id==='pass'&&['canyon-cliff','ore-supplies'].includes(name)&&workspaces.some(q=>distance(p,q)<2.3))return false;
   if(!force&&(protectedAt(p,tall?.8:.2)||footprints.some(b=>inRect(p,b,.7))))return false;
   if(!allowWater&&!bareWalk(p))return false;
   if(allowWater&&footprints.some(b=>inRect(p,b,.7)))return false;
   if(!force&&decor.some(v=>distance(p,v.point)<(tall&&v.tall?1.75:.65)))return false;
   if(collision&&!force){for(const x of [-collision[0],0,collision[0]])for(const y of [-collision[1],0,collision[1]])if(protectedAt([p[0]+x,p[1]+y],.15)||!bareWalk([p[0]+x,p[1]+y]))return false;}
   decor.push({point:p.map(v=>+v.toFixed(3)),asset:art(name),width,tall,style,anchor:[.5,.91],group,...(collision?{collision}:{})});return true;
  }
  // Harbor structures are independent silhouettes with their own exact collision footprints.
  for(const b of facilities)decor.push({point:[b.x+b.w/2,b.y+b.d/2],asset:art(b.id),width:(b.w+b.d)*56,tall:true,style:'structure',anchor:[.5,.88],group:'harbor',collision:[b.w/2+.3,b.d/2+.3],footprint:[b.x,b.y,b.w,b.d],facility_id:b.id});
  if(id==='pass')for(const [desired,name]of [[[37.8,23],'forge-bench'],[[47,15],'mine-cart']]){
   let placed=false;
   for(let radius=0;radius<=5&&!placed;radius+=.5)for(let i=0;i<24&&!placed;i++){
    const p=[desired[0]+Math.cos(i*Math.PI/12)*radius,desired[1]+Math.sin(i*Math.PI/12)*radius];
    if(add(p,name,145,{collision:[.6,.5],group:'working-yard'})){workspaces.push(p);placed=true;}
   }
   assert(placed,'No safe industrial workyard '+name);
  }
  const choices={wood:['wood-oak','wood-birch','wood-garden'],pass:['canyon-cliff','ore-supplies'],fen:['wetland-willow','wetland-reeds','marsh-rock'],coast:['coastal-pine','coastal-rock']}[id];
  // Keep the original ecological clusters, but replace every regional prop's art.
  for(const old of base.decor){
   if(old.style==='lamp')continue;
   let name=choices[0],tall=old.tall,width=old.width,collision=null;
   if(id==='wood'){name=tall?(rng()<.7?'wood-oak':'wood-birch'):'wood-garden';width=tall?220+rng()*55:75+rng()*38;collision=tall?[.3,.3]:null;}
   if(id==='pass'){name='canyon-cliff';tall=old.tall;width=tall?185+rng()*80:70+rng()*55;collision=tall?[.65,.65]:null;}
   if(id==='fen'){name=tall?'wetland-willow':(rng()<.65?'wetland-reeds':'marsh-rock');width=tall?215+rng()*45:70+rng()*40;collision=tall?[.3,.3]:null;}
   if(id==='coast'){name=tall?'coastal-pine':'coastal-rock';width=tall?205+rng()*45:100+rng()*55;collision=tall?[.35,.35]:null;}
   add(old.point,name,width,{tall,collision,group:'biome'});
  }
  function scatter(count,name,width,tall=false,allowWater=false){let made=0;for(let i=0;i<count*40&&made<count;i++){const p=[3+rng()*57,3+rng()*41];if(add(p,name,width*(.8+rng()*.35),{tall,collision:tall?[.3,.3]:null,allowWater,group:'understory'}))made++;}return made;}
  if(id==='wood'){
   scatter(44,'wood-oak',245,true);scatter(30,'wood-birch',210,true);scatter(105,'wood-garden',82);
   for(let x=19.5;x<=23.5;x+=1.8)for(let y=38;y<=43;y+=1.65)add([x,y],'wheat-patch',150,{group:'farm'});
   for(const p of [[16,29],[11,29],[18,38],[24.3,37],[36,12],[41.5,13],[47.5,24.5],[52,25]])add(p,'wood-garden',110,{group:'landmark-garden',collision:[.65,.25]});
  }
  if(id==='pass'){
   scatter(40,'canyon-cliff',115);scatter(16,'canyon-cliff',245,true);
   for(const b of d.buildings)for(const p of [[b.x-1.5,b.y+b.d*.5],[b.x+b.w+1.6,b.y+.3],[b.x+.8,b.y-1.5]])add(p,'ore-supplies',95,{collision:[.45,.4],group:b.id});
  }
  if(id==='fen'){
   scatter(28,'wetland-willow',235,true);scatter(100,'wetland-reeds',80);scatter(32,'marsh-rock',95);
   for(const poly of d.water)for(let i=0;i<poly.length;i++){const a=poly[i],b=poly[(i+1)%poly.length];for(let n=0;n<distance(a,b);n+=1.2){const t=n/distance(a,b),p=a.map((v,k)=>v+(b[k]-v)*t+(rng()-.5)*1.3);add(p,'wetland-reeds',75+rng()*35,{allowWater:true,group:'shoreline'});}}
   for(const b of d.buildings)for(const p of [[b.x-1.4,b.y+.4],[b.x+b.w+1.5,b.y-.4],[b.x+.5,b.y-1.3]])add(p,'ruin-wall',135,{collision:[.65,.35],group:b.id});
  }
  if(id==='coast'){
   scatter(30,'coastal-pine',225,true);scatter(35,'coastal-rock',145);
   for(const poly of d.water)for(let i=0;i<poly.length;i++){const a=poly[i],b=poly[(i+1)%poly.length];for(let n=0;n<distance(a,b);n+=2.2){const t=n/distance(a,b),p=a.map((v,k)=>v+(b[k]-v)*t+(rng()-.5)*1.2);add(p,'coastal-rock',175+rng()*80,{allowWater:true,group:'shoreline'});}}
   for(const b of [...facilities,d.buildings.find(b=>b.id==='tide-harbor'),d.buildings.find(b=>b.id==='fisher-hut')]){
    for(const p of [[b.x-1.2,b.y+.3],[b.x+b.w+1.4,b.y+.4],[b.x+.5,b.y-1]])add(p,'harbor-supplies',90,{collision:[.4,.4],group:'harbor'});
    add([b.x-1.7,b.y+b.d*.7],'fishing-rack',120,{collision:[.5,.35],group:'harbor'});
   }
   for(const p of [[53.8,23.1],[55.1,31.6]])add(p,'harbor-crane',210,{force:true,collision:[.45,.4],tall:true,group:'harbor'});
   for(const p of [[34,33],[36.3,33],[38,33]])add(p,'harbor-supplies',110,{collision:[.4,.4],group:'cargo-yard'});
   for(const p of d.harbor.berths)add(p,'fishing-boat',260,{force:true,allowWater:true,tall:true,group:'harbor-boats'});
  }
  // Lamps belong beside entrances and street edges, with a clear walking lane.
  for(const b of footprints){
   const p=[b.x+b.w+1.35,b.y+b.d+.4];
   if(protectedAt(p,.15)||!bareWalk(p))continue;
   decor.push({point:p,asset:'res://assets/starlit-town/lamp.webp',width:58,tall:true,style:'lamp',anchor:[.5,.94],group:'landmark-light'});
  }
  d.decor=decor;
  d.lights=d.buildings.map(b=>({point:[b.entry[0]+.65,b.entry[1]-.6],color:id==='fen'?'a9dce5':'ffd39a',energy:id==='fen'?.3:.35,radius:220}));
  if(id==='coast')for(const b of facilities)d.lights.push({point:b.entry,color:'ffd39a',energy:.3,radius:200});
  d.ambient_residents=id==='coast'?[{actor:'merchant',points:[[36.5,24],[36.5,21.5],[40,21.5]]},{actor:'villager',points:[[46,23],[46,26],[46,29]]},{actor:'blacksmith',points:[[40,21.5],[42,21.5],[44,21.5]]}]:[];
  const walk=p=>bareWalk(p)&&!decor.some(v=>v.collision&&Math.abs(p[0]-v.point[0])<v.collision[0]&&Math.abs(p[1]-v.point[1])<v.collision[1]);
  for(const road of d.roads)for(let i=1;i<road.points.length;i++){
   const a=road.points[i-1],b=road.points[i],length=distance(a,b),normal=[-(b[1]-a[1])/(length||1),(b[0]-a[0])/(length||1)];
   for(let step=0;step<=Math.ceil(length*4);step++)for(const side of [-1,0,1]){const t=Math.min(1,step*.25/(length||1)),p=a.map((v,k)=>v+(b[k]-v)*t+normal[k]*side*(road.width*.5-.35));assert(walk(p),'Road clearance '+id+' '+(road.kind||road.building_id||'main')+' '+JSON.stringify(p));}
  }
  // Authoring checks use the same eight-neighbour/no-corner-cut grid as Godot.
  const key=p=>p[0]+','+p[1],spawn=d.spawn.map(Math.round),queue=[spawn],visited=new Set([key(spawn)]);
  for(let i=0;i<queue.length;i++)for(const [dx,dy]of [[1,0],[-1,0],[0,1],[0,-1],[1,1],[1,-1],[-1,1],[-1,-1]]){
   const a=queue[i],p=[a[0]+dx,a[1]+dy];if(visited.has(key(p))||!walk(p)||dx&&dy&&(!walk([a[0]+dx,a[1]])||!walk([a[0],a[1]+dy])))continue;visited.add(key(p));queue.push(p);
  }
  for(const b of footprints){assert(walk(b.entry),'Blocked entry '+b.id);assert(visited.has(key(b.entry.map(Math.round))),'Unreachable '+b.id);}
  for(const p of npcs){assert(walk(p),'Blocked NPC '+id);assert(visited.has(key(p.map(Math.round))),'Unreachable NPC '+id);}
  for(const p of entrances){assert(walk(p),'Blocked story entrance '+id);assert(visited.has(key(p.map(Math.round))),'Unreachable story entrance '+id);}
  for(const bridge of d.bridges)assert(walk([bridge.x,bridge.y]),'Blocked bridge '+id+' '+bridge.kind);
  const terrain=[],resolution=4,width=d.columns*resolution,height=d.rows*resolution,pixels=Buffer.alloc(width*height*3);
  for(let y=0;y<d.rows;y++){const row=[];for(let x=0;x<d.columns;x++){const p=[x+.5,y+.5];row.push(water(p)?'water':d.roads.some(r=>roadDistance(p,r)<r.width/2)?'road':'ground');}terrain.push(row);}d.terrain=terrain;
  for(let y=0;y<height;y++)for(let x=0;x<width;x++){const p=[(x+.5)/resolution,(y+.5)/resolution],offset=(y*width+x)*3;let road=0;for(const r of d.roads)road=Math.max(road,Math.max(0,Math.min(1,(r.width/2+.25-roadDistance(p,r))/.5)));pixels[offset]=road*255;pixels[offset+1]=water(p)?255:0;pixels[offset+2]=d.rocks.some(poly=>inPoly(p,poly))?255:0;}
  const mask='assets/regional-redraw/'+id+'-mask.png';await sharp(pixels,{raw:{width,height,channels:3}}).resize(1024,768,{kernel:'cubic'}).blur(.8).png().toFile(path.join(root,'godot',mask));d.mask='res://'+mask;
  report.push({id,buildings:d.buildings.length,facilities:facilities.length,decor:decor.length,roads:d.roads.length,bridges:d.bridges.length,reachableCells:visited.size});
 }
 fs.writeFileSync(file,JSON.stringify(regions,null,2)+'\n');
 const manifestFile=path.join(root,'godot/data/resource-manifest.json'),manifest=JSON.parse(fs.readFileSync(manifestFile));
 for(const id of Object.keys(bases)){const p='assets/regional-redraw/'+id+'-mask.png';manifest.files[p]=fs.statSync(path.join(root,'godot',p)).size;}
 fs.writeFileSync(manifestFile,JSON.stringify(manifest,null,2)+'\n');
 fs.writeFileSync(path.join(source,'layout.json'),JSON.stringify(Object.fromEntries(Object.keys(bases).map(id=>[id,{buildings:regions[id].buildings,harbor:regions[id].harbor,roads:regions[id].roads,bridges:regions[id].bridges}])),null,2)+'\n');
 console.log(JSON.stringify(report,null,2));
}
main().catch(e=>{console.error(e);process.exitCode=1;});
