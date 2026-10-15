(() => {
  'use strict';
  const catalog=new Map(EnvironmentCatalog.map(e=>[e.id,window.ArtCatalog?.environment[e.id]?{...e,width:512,height:512,anchor:window.ArtCatalog.environment[e.id].anchor}:e])),layouts=new Map(),groundCache=new Map();
  for(const [id,e] of Object.entries(window.ArtV3Catalog?.environment||{}))catalog.set(id,{...e,id});
  const assets={
    town:['village-07-tavern-sign','village-08-market-stall','village-09-supplies','village-10-well','village-11-noticeboard','village-12-lantern-string','water-19-well','forest-08-lamp','forest-12-barrels','forest-09-signpost','forest-04-rocks'],
    wood:['forest-01-oak','forest-02-pine','forest-03-bush','village-16-bush','village-17-stump','village-18-fallen-log','village-20-campfire','village-21-tent','village-22-signpost','village-23-berry-bush','forest-11-flowers'],
    pass:['forest-04-rocks','village-15-cliff','village-19-rocks','village-24-fence','forest-10-fence','village-09-supplies','forest-12-barrels','village-21-tent'],
    fen:['water-20-reeds','water-24-lilies','water-21-stepping-stones','water-13-waterfall','forest-03-bush'],
    coast:['water-22-dock','water-23-drain','water-20-reeds','water-21-stepping-stones','water-13-waterfall','forest-04-rocks'],
    city:['royal-06-hedge','royal-07-tree','royal-08-cypress','royal-09-flower-urn','royal-10-lamp','royal-11-banner','royal-12-bench','royal-13-fountain','royal-14-statue','royal-15-stairs','royal-16-arch','royal-17-wall','royal-18-iron-fence','royal-19-flowerbed','royal-20-crates','royal-21-signpost','royal-23-drain','royal-24-noticeboard','water-14-royal-channel','water-15-royal-basin','water-17-royal-fountain','water-18-lion-fountain']
  };
  const patches={
    town:[['village-01-cobblestone',11,12,3,2],['village-02-brick',28,22,4,4],['village-03-soil',9,25,4,4],['forest-06-cobblestone',32,24,2,4]],
    wood:[['village-13-meadow',8,23,5,5],['village-14-trail',32,25,2,5],['forest-05-soil',15,23,4,4],['forest-07-flagstone',26,25,3,3]],
    pass:[['forest-05-soil',32,23,2,5],['village-03-soil',8,25,5,4],['forest-07-flagstone',20,24,4,4]],
    fen:[['water-02-deep-pool',8,25,5,5],['water-04-grass-bank',15,26,4,4],['water-06-flower-bank',21,25,4,4],['water-09-canal-left',39,24,4,4],['water-10-canal-right',43,24,4,4],['water-11-canal-cross',39,28,4,4]],
    coast:[['water-01-blue-pool',8,25,5,5],['water-03-clear-pool',14,25,5,5],['water-05-sand-bank',20,25,5,5],['water-07-canal-horizontal',39,24,5,3],['water-08-canal-vertical',46,23,3,5],['water-12-canal-cross-wide',39,28,4,4]],
    city:[['royal-04-grass',82,35,4,4],['royal-05-flower-grass',87,35,4,4]]
  };
  const cityReplace={lamp:'royal-10-lamp',tree:'royal-07-tree',fountain:'royal-13-fountain',bench:'royal-12-bench',board:'royal-24-noticeboard',wall:'royal-17-wall',bridge:'royal-22-bridge'};
  const npcPoints=place=>(NPCSystem.at(place)||[]).map(n=>({x:Number(n.position?.x??n.x??4),y:Number(n.position?.y??n.y??10)}));
  function reservedPoints(place){const p=window.WorldLayout?.portal(place);return [WorldRegions.spawn(place),...BuildingSystem.at(place).map(b=>WorldLayout.entrance(b)),...npcPoints(place),...(p?[p]:[])];}
  function objectWidth(id){return /oak|pine|tree|cypress/.test(id)?52:/lamp/.test(id)?32:/banner/.test(id)?22:/bridge/.test(id)?64:/cliff|waterfall|arch|stairs/.test(id)?42:/fountain|dock|tent|market-stall|lantern-string/.test(id)?34:23;}
  function available(place,x,y,radius=1.1){
    const b=WorldRegions.bounds(place);if(x<3||y<3||x>b.columns-4||y>b.rows-4)return false;
    if(place==='city'){if(['water','wall'].includes(RoyalCity.terrain(x,y))||Math.abs(x-16)<3||Math.abs(x-48)<3||Math.abs(x-80)<3||[18,42,66].some(v=>Math.abs(y-v)<3))return false;}
    else if(window.WorldLayout?.onRoad(place,x,y,radius)||window.WorldRegions.blocked(place,x,y))return false;
    if(BuildingSystem.at(place).some(b=>x>b.x-radius&&x<b.x+b.w+radius&&y>b.y-radius&&y<b.y+b.d+radius))return false;
    const reserved=reservedPoints(place);
    return !reserved.some(p=>Math.hypot(x-p.x,y-p.y)<2.4);
  }
  function objects(place){
    if(layouts.has(place))return layouts.get(place);
    const old=place==='city'?CityRenderer.decorations:WorldTerrain.decorations(place);
    const list=old.filter(o=>['wall','bridge'].includes(o.kind)||!WorldRegions.blocked(place,o.x,o.y)&&!reservedPoints(place).some(n=>Math.hypot(o.x-n.x,o.y-n.y)<2.4)).map((o,i)=>({...o,kind:'environment',fallback:o,asset:place==='city'?cityReplace[o.kind]:o.kind==='tree'?(place==='wood'&&i%2?'forest-02-pine':'forest-01-oak'):o.kind==='rock'?'forest-04-rocks':'forest-08-lamp',width:place==='city'&&o.kind==='wall'?21:undefined,mirror:o.kind==='bridge',anchor:o.kind==='bridge'?[.5,.65]:undefined}));
    // Fixed candidate lattice, filtered against entrances, residents and travel landings.
    const candidates=[];const b=WorldRegions.bounds(place);
    for(let y=5;y<b.rows-3;y+=4)for(let x=5;x<b.columns-3;x+=5)if(available(place,x,y))candidates.push({x,y});
    // Distribute distinct subjects across the whole region rather than filling its first row.
    candidates.sort((a,b)=>((a.x*37+a.y*19)%101)-((b.x*37+b.y*19)%101));
    let index=0;
    for(const asset of assets[place]){const repeats=place==='city'?2:2;
      for(let n=0;n<repeats;n++){let pos;while(index<candidates.length){const p=candidates[index++];if(available(place,p.x,p.y,Math.max(1.1,objectWidth(asset)/17))&&!list.some(o=>Math.hypot(o.x-p.x,o.y-p.y)<2.3)){pos=p;break;}}if(pos)list.push({kind:'environment',asset,...pos,width:objectWidth(asset)});}
    }
    // Facade elements use building-relative anchors, never standalone placement.
    if(place==='town'&&!window.ArtCatalog?.version)for(const [i,b]of BuildingSystem.at(place).filter(b=>['town','inn','shop'].includes(b.asset)).entries()){
      const fitting=['village-04-window','village-05-door','village-06-roof'][i%3];
      const roof=fitting.endsWith('roof'),bw=b.visualWidth||(b.w+b.d)*17*.72,e=catalog.get(fitting),width=roof?bw*.62:15;
      const roofY=(b.w+b.d)*9*.25-bw+width*(e.height/e.width||1)*e.anchor[1]+1;
      list.push({kind:'environment',asset:fitting,x:b.x+b.w/2,y:b.y+b.d/2,buildingId:b.id,fitting:true,width,offsetY:roof?roofY:fitting.endsWith('window')?-17:6});
    }
    if(place==='city'){const bridge=list.find(o=>o.fallback?.kind==='bridge'&&o.y===18);if(bridge)bridge.asset='water-16-water-bridge';}
    for(const b of window.WorldLayout?.regions[place]?.bridges||[])list.push({kind:'environment',asset:b.asset,x:b.x,y:b.y,width:b.width,anchor:[.5,.75],fallback:{kind:'bridge',x:b.x,y:b.y}});
    for(const o of list)o.place=place;
    const result=place==='town'?TownArt.objects(list):list;layouts.set(place,result);return result;
  }
  function sprite(ctx,o,project,base=false){
    const e=catalog.get(o.asset),image=e&&WorldAssets.ready('environment',o.asset);if(!image)return false;
    const p=project(o.x,o.y),w=o.width||objectWidth(o.asset),h=w*e.height/e.width,[ax,ay]=o.anchor||e.anchor;
    ctx.save();ctx.imageSmoothingEnabled=true;
    if(e.legacyId&&!o.fitting){ctx.fillStyle='rgba(36,40,30,.12)';ctx.beginPath();ctx.ellipse(p.x*2,p.y*2,Math.min(w*.36,8)*2,Math.min(w*.12,2.5)*2,0,0,Math.PI*2);ctx.fill();}
    if(o.place==='fen')ctx.filter=/oak|tree|bush/.test(o.asset)?'saturate(.48) brightness(.72) hue-rotate(24deg)':'saturate(.72) brightness(.87)';
    // Bridge deck belongs behind walkers; only its near base overlaps the actor layer.
    if(o.fallback?.kind==='bridge'&&!base){ctx.beginPath();ctx.rect((p.x-w)*2,(p.y+2)*2,w*4,h*2);ctx.clip();}
    ctx.translate(p.x*2,(p.y+(o.offsetY||0))*2);if(o.mirror)ctx.scale(-1,1);ctx.drawImage(image,-w*ax*2,-h*ay*2,w*2,h*2);ctx.restore();return true;
  }
  function tile(ctx,id,project,x,y,w,d){
    const image=WorldAssets.ready('environment',id);if(!image)return;
    const a=project(x,y),bx=project(x+w,y),by=project(x,y+d);
    ctx.save();ctx.imageSmoothingEnabled=true;ctx.transform((bx.x-a.x)*2/image.width,(bx.y-a.y)*2/image.width,(by.x-a.x)*2/image.height,(by.y-a.y)*2/image.height,a.x*2,a.y*2);ctx.drawImage(image,0,0);ctx.restore();
  }
  function drawSurface(ctx,place,project){
    if(groundCache.has(place)){ctx.drawImage(groundCache.get(place).canvas,groundCache.get(place).left*2,0);return;}
    const bounds=WorldRegions.bounds(place),left=Math.floor(project(0,bounds.rows).x-20),right=Math.ceil(project(bounds.columns,0).x+20),bottom=Math.ceil(project(bounds.columns,bounds.rows).y+20);
    const canvas=document.createElement('canvas');canvas.width=(right-left)*2;canvas.height=bottom*2;const c=canvas.getContext('2d');c.translate(-left*2,0);
    if(place==='city'){
      // Sample interior texture, avoiding repeated thick borders on the long canal.
      const ids=['royal-01-marble','royal-02-cobblestone','royal-03-brick','water-03-clear-pool'];ids.forEach(id=>WorldAssets.get('environment',id));
      const water=WorldAssets.ready('environment',ids[3]);if(water)for(const [start,end]of [[2,16],[20,40],[44,64],[68,69]])for(let y=start;y<end;y+=3){
        const a=project(61,y),bx=project(64,y),by=project(61,Math.min(end,y+3));c.save();c.transform((bx.x-a.x)*2,(bx.y-a.y)*2,(by.x-a.x)*2,(by.y-a.y)*2,a.x*2,a.y*2);c.drawImage(water,water.width*.17,water.height*.17,water.width*.66,water.height*.66,0,0,1,1);c.restore();
      }
    }
    c.save();if(place==='fen')c.filter='saturate(.65) brightness(.8)';
    if(place==='city')for(const[id,x,y,w,d]of patches[place])tile(c,id,project,x,y,w,d);c.restore();
    for(const bridge of objects(place).filter(o=>o.fallback?.kind==='bridge'))sprite(c,bridge,project,true);
    groundCache.set(place,{canvas,left});while(groundCache.size>2)groundCache.delete(groundCache.keys().next().value);ctx.drawImage(canvas,left*2,0);
  }
  function invalidate(){groundCache.clear();}
  function preload(place){const ids=new Set([...objects(place).map(o=>o.asset),...patches[place].map(p=>p[0])]);if(place==='city')for(const id of ['royal-01-marble','royal-02-cobblestone','royal-03-brick','water-03-clear-pool'])ids.add(id);for(const id of ids)WorldAssets.get('environment',id);}
  window.SceneEnvironment={objects,sprite,drawSurface,invalidate,preload,catalog,patches,available};
})();
