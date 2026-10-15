(() => {
  'use strict';
  // Asset identity is separate from gameplay identity; other regions retain v2 art.
  const key=b=>b.artId||b.asset;
  function rect(b,project){
    const art=ArtCatalog.buildings[key(b)];if(!art?.footprint)return null;
    const p=project(b.x+b.w/2,b.y+b.d/2),w=b.visualWidth||(b.w+b.d)*8.5/(art.groundWidth||.91),h=w*art.height/art.width;
    const a=art.anchor||[.5,.88];return{x:p.x-w*a[0],y:p.y-h*a[1],w,h};
  }
  function shadow(ctx,b,project){
    const e=ArtCatalog.buildings[key(b)],shift=e.shadow?.offset||[.35,.45];
    const corners=[[b.x,b.y],[b.x+b.w,b.y],[b.x+b.w,b.y+b.d],[b.x,b.y+b.d]];
    const polygon=(offset,alpha)=>{ctx.beginPath();corners.map(([x,y])=>project(x+offset[0],y+offset[1])).forEach((p,i)=>i?ctx.lineTo(p.x*2,p.y*2):ctx.moveTo(p.x*2,p.y*2));ctx.closePath();ctx.fillStyle='rgba(35,40,32,'+alpha+')';ctx.fill();};
    ctx.save();ctx.filter='blur(2px)';polygon(shift,e.shadow?.opacity||.13);ctx.filter='none';polygon([0,0],.16);ctx.restore();
  }
  const widths={'forest-01-oak':42,'forest-04-rocks':17,'forest-08-lamp':11,'forest-09-signpost':12,'forest-12-barrels':17,'village-07-tavern-sign':13,'village-08-market-stall':25,'village-09-supplies':17,'village-10-well':20,'village-11-noticeboard':20,'village-12-lantern-string':30,'water-19-well':17};
  function objects(list){let signs=0;return list.filter((o,i)=>{
    if(!o.fallback)return true;
    if(o.fallback.kind==='tree')return i%3===0;
    if(o.fallback.kind==='lamp')return i%2===0;
    return true;
  }).map(o=>{
    const id='town-'+o.asset,e=ArtCatalog.environment[id];if(!e)return o;
    const result={...o,asset:id,width:widths[o.asset]||o.width,anchor:e.anchor};
    if(o.asset==='village-07-tavern-sign'){
      const b=BuildingSystem.get(signs++?'guildhall':'inn'),r=rect(b,PixelWorld.project);
      if(r)Object.assign(result,{x:b.x+b.w*.8,y:b.y+b.d*.75,offsetY:-r.h*.3,buildingId:b.id,fitting:true,width:9});
    }
    return result;
  });}
  window.TownArt={key,rect,shadow,objects};
})();
