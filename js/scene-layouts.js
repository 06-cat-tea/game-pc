(() => {
  'use strict';
  // Logical image coordinates (480 × 270) match the 1920 × 1080 paintings.
  // The original object IDs are retained; the marker sits on the depicted object.
  const anchors={
    'room-chapel':[[240,66],[126,88],[74,155],[359,170]],
    'room-inn':[[253,80],[125,73],[69,162],[375,170]],
    'room-guildhall':[[123,72],[338,71],[72,147],[381,158]],
    'room-clocktower':[[145,73],[358,90],[72,145],[402,157]],
    'room-market':[[281,81],[368,127],[71,155],[362,174]],
    'room-forest-hut':[[332,79],[132,73],[70,159],[359,177]],
    'room-waystation':[[126,76],[264,44],[73,141],[364,179]],
    'room-grayforge':[[292,72],[281,49],[73,147],[377,163]],
    'room-lighthouse':[[240,78],[119,74],[70,151],[362,170]],
    'room-fisher-hut':[[237,76],[374,140],[72,148],[363,173]],
    'room-royal-hall':[[119,72],[379,150],[76,160],[361,177]],
    'room-artisan-quarter':[[124,83],[405,103],[72,161],[376,182]],
    'room-star-academy':[[398,113],[152,79],[77,169],[366,189]],
    'room-alchemist-lab':[[118,79],[335,78],[72,161],[377,171]],
    'room-town-stables':[[121,81],[363,64],[63,159],[366,175]],
    'room-north-gate':[[122,85],[385,107],[72,159],[363,176]],
    'room-windmill-farm':[[127,76],[336,96],[72,160],[385,172]],
    'room-ridge-barracks':[[151,65],[367,75],[70,160],[366,181]],
    'room-deep-mine':[[118,73],[354,101],[68,150],[375,170]],
    'room-ember-fortress':[[111,71],[330,67],[68,154],[379,176]],
    'room-violet-rift':[[153,68],[368,102],[72,156],[377,179]],
    'room-cloud-observatory':[[126,64],[189,53],[68,146],[388,175]],
    'room-tide-harbor':[[117,79],[361,86],[68,156],[378,168]],
    'town-wall':[[124,76],[62,161],[383,175],[309,187],[391,97]],
    'town-drain':[[126,70],[70,148],[363,112],[380,182],[413,148]],
    'town-trial':[[116,74],[71,158],[407,102],[383,181]],
    'wood-trail':[[140,57],[72,146],[401,91],[381,167],[417,128]],
    'wood-roots':[[135,70],[71,143],[395,88],[384,184],[416,137]],
    'wood-well':[[127,48],[74,151],[396,81],[386,181]],
    'pass-path':[[131,68],[76,140],[390,88],[383,168],[418,126]],
    'pass-mine':[[117,61],[75,135],[392,81],[383,164],[419,124]],
    'pass-core':[[127,64],[71,143],[394,63],[388,168]],
    'fen-temple':[[127,69],[76,147],[387,104],[386,182],[410,141],[240,66]],
    'fen-crypt':[[135,67],[69,137],[385,81],[384,174],[409,125],[157,83]],
    'fen-seal':[[138,72],[69,148],[414,110],[392,178]],
    'coast-reef':[[127,72],[70,145],[391,89],[394,188],[414,124]],
    'coast-hold':[[132,70],[65,139],[404,86],[385,182],[411,136]],
    'coast-deck':[[118,76],[69,149],[387,87],[379,178]]
  };
  const roomNames={
    'royal-hall':['王朝家谱','接待银印'], 'artisan-quarter':['旅人歌谱','工匠长桌'],
    'star-academy':['星路天球','观星课桌'], 'alchemist-lab':['试剂记录','青瓶蒸馏器'],
    'town-stables':['饲养日志','马具架'], 'north-gate':['值勤簿','城门绞盘'],
    'windmill-farm':['农时账册','银麦磨盘'], 'ridge-barracks':['斥候路线图','训练盾架'],
    'deep-mine':['选矿记录','玄铁分拣台'], 'ember-fortress':['停战文书','余火火盆'],
    'violet-rift':['无眠档案','紫晶锁链'], 'cloud-observatory':['王朝星路仪','星图抄写台'],
    'tide-harbor':['失航船票','货物清点台']
  };
  const point=(x,y)=>({x:(y-42.5)/20.7+(x-240)/39,y:(y-42.5)/20.7-(x-240)/39});
  function apply(scene) {
    const artwork=window.ArtV3Catalog?.scenes[scene.sceneId];
    const list=artwork?.props?.map(p=>[p.screen.x,p.screen.y])||anchors[scene.sceneId];if(!list)throw Error('Missing scene layout: '+scene.sceneId);
    scene.walkArea={minX:.5,minY:.5,maxX:9.5,maxY:9.5};
    scene.collisions=[];scene.occluders=[];
    scene.props.forEach((p,i)=>{
      const [x,y]=list[i],foot=point(x,y);
      p.screen={x,y};p.x=artwork?foot.x:Math.max(.65,Math.min(9.35,foot.x));p.y=artwork?foot.y:Math.max(.65,Math.min(9.35,foot.y));
      p.w=.8;p.d=.75;
      if(scene.kind==='room'&&roomNames[scene.buildingId]&&i<2)p.name=roomNames[scene.buildingId][i];
      // Route signposts mark open paths; solid furniture blocks only its base.
      if(!['portal','encounter','event'].includes(p.action))scene.collisions.push({x:p.x,y:p.y,w:p.w,d:p.d,id:p.id});
      if(y>135&&['cache','restore','service'].includes(p.action))scene.occluders.push({depth:p.x+p.y,polygon:[[x-15,y-24],[x+16,y-24],[x+20,y+3],[x-18,y+5]]});
    });
    for(const fixture of artwork?.fixtures||[]){
      const polygon=fixture.footprint.map(([x,y])=>{const p=point(x,y);return[p.x,p.y];});
      scene.collisions.push({id:fixture.id,polygon});
      if(fixture.occluder){const y=fixture.footprint.reduce((sum,p)=>sum+p[1],0)/fixture.footprint.length;scene.occluders.push({depth:(y-42.5)/10.35,polygon:fixture.occluder});}
    }
    scene.exit={x:9,y:9};
    return scene;
  }
  window.SceneLayouts={apply,anchors};
})();
