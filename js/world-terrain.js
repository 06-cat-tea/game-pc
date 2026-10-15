(() => {
  'use strict';
  const cache=new Map(),textures=new Map(),thumbnails=new Map();
  let revision=0;
  const themes={
    town:{color:'#788067',ground:'royal-04-grass',road:'village-01-cobblestone',tint:'#737958'},
    wood:{color:'#48604b',ground:'village-13-meadow',road:'village-14-trail',tint:'#314f45'},
    pass:{color:'#897a65',ground:'forest-05-soil',road:'village-03-soil',tint:'#817363'},
    fen:{color:'#506663',ground:'royal-04-grass',road:'forest-07-flagstone',tint:'#365c64'},
    coast:{color:'#a69876',ground:'water-05-sand-bank',road:'forest-05-soil',tint:'#a59d80'},
    city:{color:'#738565',ground:'royal-04-grass',road:'royal-02-cobblestone',tint:'#778268'}
  };
  const noise=(x,y)=>{const n=Math.sin(x*127.1+y*311.7)*43758.5453;return n-Math.floor(n);};
  // Feathered, wrapped interior samples omit ornamented source borders.
  function texture(place,kind='ground'){
    const key=place+':'+kind;if(textures.has(key))return textures.get(key);
    if(place==='town'){
      const id='town-'+({ground:'grass',road:'road',soil:'soil',brick:'brick',gravel:'gravel'}[kind]||'grass');
      const image=window.ArtV3Catalog?.terrain[id]&&WorldAssets.ready('terrain',id);
      if(image){const canvas=document.createElement('canvas');canvas.width=canvas.height=256;canvas.getContext('2d').drawImage(image,0,0,256,256);textures.set(key,canvas);return canvas;}
    }
    const theme=themes[place]||themes.town;
    const id=kind==='water'?'water-03-clear-pool':kind==='marble'?'royal-01-marble':kind==='brick'?'royal-03-brick':theme[kind];
    const image=WorldAssets.ready('environment',id),canvas=document.createElement('canvas');canvas.width=768;canvas.height=384;
    const c=canvas.getContext('2d'),base=kind==='ground'?theme.color:kind==='water'?'#4d777e':kind==='marble'?'#b7b5a3':kind==='brick'?'#a0846c':'#a0957a';
    c.fillStyle=base;c.fillRect(0,0,768,384);
    const cleanId=kind==='ground'?place:kind==='road'?'road':null,clean=cleanId&&window.ArtCatalog?.terrain?.[cleanId]&&WorldAssets.ready('terrain',cleanId);if(clean){if(kind==='road'){canvas.width=192;canvas.height=96;c.drawImage(clean,0,0,192,96);}else c.drawImage(clean,0,0,768,384);textures.set(key,canvas);return canvas;}
    if(image){
      const stamp=document.createElement('canvas');stamp.width=128;stamp.height=128;const sc=stamp.getContext('2d');
      const sand=id==='water-05-sand-bank',sx=.12,sy=.12,sw=.76;
      sc.drawImage(image,image.width*sx,image.height*sy,image.width*sw,image.height*sw,0,0,128,128);
      sc.globalCompositeOperation='destination-in';const mask=sc.createRadialGradient(64,64,20,64,64,64);mask.addColorStop(0,'#fff');mask.addColorStop(1,'#fff0');sc.fillStyle=mask;sc.fillRect(0,0,128,128);
      for(let i=0;i<140;i++){const x=noise(i,3)*768,y=noise(i,9)*384,w=85+noise(i,5)*65;
        for(const dx of [-768,0,768])for(const dy of [-384,0,384]){c.save();c.translate(x+dx,y+dy);c.rotate(Math.floor(noise(i,6)*4)*Math.PI/2);if(i%2)c.scale(-1,1);c.globalAlpha=.75;c.drawImage(stamp,-w/2,-w/2,w,w);c.restore();}
      }
      c.fillStyle=kind==='ground'?theme.tint:base;c.globalAlpha=kind==='ground'?(place==='fen'?.32:place==='wood'?.16:.08):.06;c.fillRect(0,0,768,384);c.globalAlpha=1;
    }
    for(let i=0;i<4000;i++){const x=noise(i,17)*768,y=noise(i,29)*384;c.fillStyle=i%2?'#e4d7a51c':'#172b2920';c.beginPath();c.ellipse(x,y,noise(i,21)*2+.4,.4,0,0,Math.PI*2);c.fill();}
    textures.set(key,canvas);return canvas;
  }
  function pattern(ctx,place,kind){const p=ctx.createPattern(texture(place,kind),'repeat');if(place==='town'&&window.ArtV3Catalog?.terrain['town-grass'])p.setTransform(new DOMMatrix([.5,9/34,-.5,9/34,450,92]));return p;}
  function fill(ctx,place,kind,x,y,w,h){ctx.fillStyle=pattern(ctx,place,kind);ctx.fillRect(x,y,w,h);}
  function get(place,project){
    const ratio=window.GameViewport?.size().width>=1280?4:2;if(cache.get(place)?.ratio===ratio)return cache.get(place);cache.delete(place);
    const b=WorldRegions.bounds(place),corners=[project(0,0),project(b.columns,0),project(0,b.rows),project(b.columns,b.rows)],left=Math.floor(Math.min(...corners.map(p=>p.x))-24),top=0,width=Math.ceil(Math.max(...corners.map(p=>p.x))-left+24),height=Math.ceil(Math.max(...corners.map(p=>p.y))+24),canvas=document.createElement('canvas');canvas.width=width*ratio;canvas.height=height*ratio;
    const ctx=canvas.getContext('2d');ctx.scale(ratio/2,ratio/2);ctx.translate(-left*2,0);fill(ctx,place,'ground',left*2,0,width*2,height*2);
    const surfaces=new Map();
    for(let y=0;y<b.rows;y++)for(let x=0;x<b.columns;x++){
      const kind=place==='city'?RoyalCity.terrain(x+.5,y+.5):WorldLayout.terrain(place,x+.5,y+.5);if(kind==='ground'||kind==='wall')continue;
      const material=['water','bridge'].includes(kind)?'water':kind==='rock'?'brick':place==='city'&&y<24&&x>32&&x<60?'marble':place==='city'&&y>48?'brick':'road';if(!surfaces.has(material))surfaces.set(material,[]);surfaces.get(material).push(project(x,y));
    }
    // Clip each continuous material once, avoiding antialias cracks between tiles.
    for(const [material,points]of surfaces){ctx.save();ctx.beginPath();for(const p of points){ctx.moveTo(p.x*2,p.y*2);ctx.lineTo((p.x+8.5)*2,(p.y+4.5)*2);ctx.lineTo(p.x*2,(p.y+9)*2);ctx.lineTo((p.x-8.5)*2,(p.y+4.5)*2);ctx.closePath();}if(place==='town'&&material==='road'){ctx.strokeStyle=pattern(ctx,place,'soil');ctx.lineWidth=4;ctx.lineJoin='round';ctx.filter='blur(.75px)';ctx.stroke();ctx.filter='none';}ctx.clip();fill(ctx,place,material,left*2,0,width*2,height*2);ctx.restore();}
    if(place==='town'&&window.ArtV3Catalog?.terrain['town-soil']){
      // A material apron joins every building footing to the street; logical paths stay unchanged.
      for(const b of BuildingSystem.at('town')){
        const material=b.id==='artisan-quarter'?'brick':b.id==='town-stables'?'gravel':['market','guildhall','royal-hall','north-gate'].includes(b.id)?'road':'soil';
        for(const [pad,alpha]of [[.65,.16],[.4,.3],[.18,.9]]){
          const corners=[[b.x-pad,b.y-pad],[b.x+b.w+pad,b.y-pad],[b.x+b.w+pad,b.y+b.d+pad+.35],[b.x-pad,b.y+b.d+pad+.35]].map(([x,y])=>project(x,y));
          ctx.save();ctx.globalAlpha=alpha;ctx.beginPath();corners.forEach((p,i)=>i?ctx.lineTo(p.x*2,p.y*2):ctx.moveTo(p.x*2,p.y*2));ctx.closePath();ctx.clip();fill(ctx,place,material,left*2,0,width*2,height*2);ctx.restore();
        }
      }
    }
    if(place==='town')for(const b of BuildingSystem.at('town'))if(b.artId)TownArt.shadow(ctx,b,project);
    if(place==='city')for(const b of RoyalCity.buildings){const corners=[[b.x-.6,b.y-.6],[b.x+b.w+.6,b.y-.6],[b.x+b.w+.6,b.y+b.d+.9],[b.x-.6,b.y+b.d+.9]].map(([x,y])=>project(x,y));ctx.save();ctx.beginPath();corners.forEach((p,i)=>i?ctx.lineTo(p.x*2,p.y*2):ctx.moveTo(p.x*2,p.y*2));ctx.closePath();ctx.clip();fill(ctx,place,b.district==='palace'?'marble':'road',left*2,0,width*2,height*2);ctx.restore();}
    const result={canvas,left,top,width,height,ratio};cache.set(place,result);while(cache.size>2)cache.delete(cache.keys().next().value);return result;
  }
  function draw(ctx,place,project,cam,zoom){
    const x=-cam.x/zoom*2,y=-cam.y/zoom*2,w=960/zoom,h=540/zoom;
    fill(ctx,place,'ground',Math.floor(x)-1,Math.floor(y)-1,Math.ceil(w)+3,Math.ceil(h)+3);const t=get(place,project),sx=Math.max(0,-cam.x/zoom-t.left),sy=Math.max(0,-cam.y/zoom),sw=Math.min(t.width-sx,480/zoom),sh=Math.min(t.height-sy,270/zoom);
    if(sw>0&&sh>0)ctx.drawImage(t.canvas,sx*t.ratio,sy*t.ratio,sw*t.ratio,sh*t.ratio,(t.left+sx)*2,sy*2,sw*2,sh*2);
    const fog=ctx.createRadialGradient(x+w/2,y+h/2,w*.2,x+w/2,y+h/2,w*.7);fog.addColorStop(0,'#0000');fog.addColorStop(1,place==='fen'?'#27444d55':'#d4cba329');ctx.fillStyle=fog;ctx.fillRect(x,y,w,h);
  }
  function thumbnail(place,size=256){
    const key=place+':'+size;if(thumbnails.has(key))return thumbnails.get(key);
    const project=PixelWorld.project,t=get(place,project),canvas=document.createElement('canvas');canvas.width=size;canvas.height=size;const c=canvas.getContext('2d');fill(c,place,'ground',0,0,size,size);
    const scale=Math.min(size/(t.width*2),size/(t.height*2)),dx=(size-t.width*2*scale)/2,dy=(size-t.height*2*scale)/2;c.save();c.translate(dx-t.left*2*scale,dy);c.scale(scale,scale);c.drawImage(t.canvas,t.left*2,0,t.width*2,t.height*2);SceneEnvironment.drawSurface(c,place,project);
    for(const o of SceneEnvironment.objects(place).slice().sort((a,b)=>a.x+a.y-b.x-b.y))SceneEnvironment.sprite(c,o,project);c.restore();thumbnails.set(key,canvas);while(thumbnails.size>6)thumbnails.delete(thumbnails.keys().next().value);return canvas;
  }
  function invalidate(){cache.clear();textures.clear();thumbnails.clear();revision++;}
  const scenery={};
  function decorations(place){if(place==='city')return[];if(scenery[place])return scenery[place];const list=[];for(let i=0;i<105;i++){const x=3+(i*17)%58,y=3+(i*13)%42;if(WorldLayout.onRoad(place,x,y,3.1)||WorldRegions.blocked(place,x,y))continue;list.push({kind:place==='pass'?'rock':place==='town'&&i%3===0?'lamp':place==='coast'&&i%3!==0?'rock':'tree',x,y,variant:i});}scenery[place]=list;return list;}
  function resourceIds(place){const t=themes[place]||themes.town;return [t.ground,t.road,...(place==='city'?['royal-01-marble','royal-03-brick','water-03-clear-pool']:[])];}
  window.WorldTerrain={draw,cache,decorations,invalidate,thumbnail,texture,resourceIds,get revision(){return revision;}};
})();
