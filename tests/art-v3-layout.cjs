const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const w={};w.window=w;vm.createContext(w);
for(const n of ['art-catalog','art-v3-catalog','city-content','world-layout','world-regions','world-content','building-system','crafting-system','skill-tree','class-content','npc-system','growth-system','region-content','game-data','party-system','scene-layouts','scene-system'])vm.runInContext(fs.readFileSync('js/'+n+'.js','utf8'),w);
const reports=[],failures=[];
const spawn=w.WorldRegions.spawn('town'),open=[spawn],found=new Set([spawn.x+','+spawn.y]);for(let i=0;i<open.length;i++)for(const [dx,dy]of [[.5,0],[-.5,0],[0,.5],[0,-.5]]){const x=open[i].x+dx,y=open[i].y+dy,k=x+','+y;if(!found.has(k)&&!w.WorldRegions.blocked('town',x,y)){found.add(k);open.push({x,y});}}for(const b of w.BuildingSystem.at('town')){const e=w.WorldLayout.entrance(b);assert(open.some(p=>Math.hypot(p.x-e.x,p.y-e.y)<.6),'outdoor door '+b.id);}for(const n of w.NPCSystem.at('town'))assert(open.some(p=>Math.hypot(p.x-n.position.x,p.y-n.position.y)<.6),'outdoor NPC '+n.id);
for(const r of Object.values(w.SceneSystem.scenes).filter(r=>r.place==='town')){
 const start=w.WorldRegions.safe('town',8.3,8.3,r.id),step=.25,b=w.WorldRegions.bounds('town',r.id),origin={x:Math.round(start.x/step)*step,y:Math.round(start.y/step)*step},q=[origin],seen=new Set([origin.x+','+origin.y]);
 assert(!w.WorldRegions.blocked('town',start.x,start.y,r.id));
 for(let i=0;i<q.length;i++)for(const [dx,dy]of [[step,0],[-step,0],[0,step],[0,-step]]){const p={x:q[i].x+dx,y:q[i].y+dy},key=p.x+','+p.y;if(!seen.has(key)&&!w.WorldRegions.blocked('town',p.x,p.y,r.id)){seen.add(key);q.push(p);}}
 const closest=(x,y)=>Math.min(...q.map(p=>Math.hypot(p.x-x,p.y-y)));
 assert(closest(9,9)<1.5,r.id+' reachable exit');
 const props=r.props.map(p=>({id:p.id,screen:p.screen,world:[p.x,p.y],distance:closest(p.x,p.y)}));
 for(const p of props)if(p.distance>=2.1)failures.push(r.id+' '+p.id+' distance '+p.distance.toFixed(2));
 const fixtures=r.collisions.filter(p=>p.polygon);assert(fixtures.length,r.id+' calibrated furniture');
 for(const p of fixtures){const x=p.polygon.reduce((s,p)=>s+p[0],0)/p.polygon.length,y=p.polygon.reduce((s,p)=>s+p[1],0)/p.polygon.length;assert(w.WorldRegions.blocked('town',x,y,r.id),r.id+' '+p.id+' blocks furniture center');}
 const npcKey=r.occupantKey||r.buildingId;for(const n of w.NPCSystem.inside(npcKey)){if(w.WorldRegions.blocked('town',n.x,n.y,r.id))failures.push(r.id+' NPC '+n.id+' inside furniture');}
 reports.push({scene:r.id,reachableCells:seen.size,props,fixtures:fixtures.length});
}
fs.mkdirSync('artifacts/art-v3',{recursive:true});fs.writeFileSync('artifacts/art-v3/layout.json',JSON.stringify({reports,failures,passed:!failures.length},null,2));assert.deepEqual(failures,[]);console.log('PASS 14 scene exits, keyboard-reachable props, physical furniture and NPC standing positions');
