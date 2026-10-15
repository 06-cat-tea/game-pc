(() => {
  'use strict';
  const root=document.querySelector('#gameViewport'),screen=document.querySelector('#gameLoading');
  const title=screen.querySelector('h1'),destination=screen.querySelector('.loading-destination'),status=screen.querySelector('.loading-status'),progress=screen.querySelector('[role="progressbar"]'),percent=screen.querySelector('.loading-percent'),actions=screen.querySelector('.loading-actions');
  const layers=['worldStage','hudLayer','panelLayer','modal'];
  let currentKey=null,active=true,generation=0,currentState=null,returnFocus=null,task=Promise.resolve(),diagnostics={status:'starting',completed:0,total:0,percent:0,failed:[]};
  // Include off-camera decorations and the whole region's terrain, not just visible sprites.
  function loadingKey(s){return GameUI.getCurrent()==='title'?'title':s.place+':'+(s.location?.sceneId||'outdoor')+(s.battle?':battle:'+s.battle.name:'');}
  function manifest(s){
    const items=new Map(),add=(kind,id,optional=false)=>{if(id)items.set(kind+':'+id,{kind,id,optional});},place=s.place,room=SceneSystem.get(s.location?.sceneId);
    if(GameUI.getCurrent()==='title'){
      add('url',TitleScreen.artwork);add('url','assets/art-v2/title.webp');add('emblems','brand');return [...items.values()];
    }
    if(window.ArtCatalog?.loadingScreens?.[place])add('loading',place,true);
    if(place==='town')for(const id of Object.keys(window.ArtV3Catalog?.terrain||{}))add('terrain',id);
    if(room){
      if(!room.procedural||window.ArtCatalog?.scenes[room.sceneId])add('expansion',room.sceneId);
      for(const n of NPCSystem.inside(room.occupantKey||room.buildingId))add('portraits',n.type);
    }else{
      if(place!=='city')add('scenes',place);
      for(const b of BuildingSystem.at(place))add('buildings',b.artId||b.asset);
      if(window.ArtCatalog?.terrain?.[place])add('terrain',place);if(window.ArtCatalog?.terrain?.road)add('terrain','road');
      for(const id of WorldTerrain.resourceIds(place))add('environment',id);
      for(const o of SceneEnvironment.objects(place))add('environment',o.asset);
      for(const p of SceneEnvironment.patches[place]||[])add('environment',p[0]);
      // City people are procedural, but their portraits are used when speaking.
      if(place!=='city')for(const n of NPCSystem.at(place))add('portraits',n.type);
    }
    for(const id of window.SceneCharacters?.resources(place,room?.sceneId)||[])add('actors',id);
    if(s.battle){const scene=s.location.sceneId||SceneSystem.route(place)[0]?.id;if(scene)add('expansion',scene);for(const enemy of BattleSystem.init(s.battle).enemies)add('enemies',SceneCharacters.enemyId(enemy,place));for(const id of ['hero',...s.party.active])if(ArtCatalog.actors[id])add('actors',id);}
    add('portraits','hero');
    add('emblems','brand');
    for(const id of ['map','backpack','main-quest','character','skills','crafting','achievement','settings','dialogue'])add('url','assets/icons/rail/'+id+'.svg');
    return [...items.values()];
  }
  function update(value,message){
    diagnostics.percent=value;progress.setAttribute('aria-valuenow',value);progress.style.setProperty('--progress',value+'%');percent.textContent=value+'%';status.textContent=message;
  }
  function lock(){
    if(!active)returnFocus=document.activeElement;
    active=true;screen.hidden=false;screen.setAttribute('aria-busy','true');screen.classList.remove('loading-error');root.classList.add('is-loading');root.setAttribute('aria-busy','true');
    for(const id of layers)document.getElementById(id).inert=true;
    PixelWorld.clearInput();GameHUD.closeWheel();InteractionMenu.close();screen.focus({preventScroll:true});actions.hidden=true;
  }
  function unlock(){
    active=false;screen.hidden=true;screen.setAttribute('aria-busy','false');root.classList.remove('is-loading');root.setAttribute('aria-busy','false');
    for(const id of layers)document.getElementById(id).inert=false;
    PixelWorld.clearInput();const focused=returnFocus?.isConnected&&returnFocus.getClientRects().length?returnFocus:document.querySelector('#modal.open button:not(:disabled),#panelLayer .screen.active button:not(:disabled),#pixelWorld');focused?.focus({preventScroll:true});returnFocus=null;
  }
  async function prepare(token){
    if(token!==generation)return;
    if(currentKey==='title'){diagnostics.status='ready';update(100,'归灯已亮，旅途即将继续');unlock();root.dispatchEvent(new CustomEvent('game-ready',{detail:{key:currentKey}}));return;}
    diagnostics.status='preparing';update(94,'正在铺展地形与水岸…');
    SceneEnvironment.invalidate();WorldTerrain.invalidate();CircleMap.invalidate();
    // The renderer builds terrain/surface caches beneath the opaque loading screen.
    await PixelWorld.whenRendered();if(token!==generation)return;
    CircleMap.draw();update(98,'正在点亮地图与路标…');
    await PixelWorld.whenRendered();if(token!==generation)return;
    diagnostics.status='ready';update(100,'归灯已亮，旅途即将继续');unlock();
    root.dispatchEvent(new CustomEvent('game-ready',{detail:{key:currentKey}}));
  }
  function failure(message){
    diagnostics.status='failed';screen.classList.add('loading-error');status.textContent=message;actions.hidden=false;
    screen.querySelector('[data-loading-fallback]').hidden=!diagnostics.failed.length;
    screen.querySelector('[data-loading-retry]').focus({preventScroll:true});
  }
  function remainingFailures(){return diagnostics.failed.filter(r=>WorldAssets.inspect(r.kind,r.id)?.status!=='ready');}
  window.addEventListener('worldassetready',()=>{
    if(!active||diagnostics.status!=='failed'||!diagnostics.failed.length)return;
    diagnostics.failed=remainingFailures();
    if(diagnostics.failed.length){failure('有 '+diagnostics.failed.length+' 项画面未能载入，请重试。');return;}
    task=prepare(generation).catch(error=>{console.error(error);failure('场景准备未完成，请重试。');});
  });
  async function run(s,retry=false){
    const token=++generation;currentState=s;currentKey=loadingKey(s);
    const room=SceneSystem.get(s.location?.sceneId);destination.textContent=room?.title||GameData.PLACES[s.place].name;title.textContent='循光赴远境';screen.dataset.loadingPlace=currentKey==='title'?'title':s.place;screen.dataset.loadingScene=room?.sceneId||'outdoor';screen.style.removeProperty('--loading-art');screen.querySelector('.loading-tip').textContent=currentKey==='title'?'灯火照亮来路，也指引下一段旅程。':WorldLore.loadingTips[s.place];if(currentKey!=='title'&&WorldAssets.inspect('loading',s.place)?.status==='ready')screen.style.setProperty('--loading-art','url("'+new URL(WorldAssets.path('loading',s.place),document.baseURI).href+'")');lock();
    const resources=manifest(s);diagnostics={key:currentKey,status:'loading',completed:0,total:resources.length,percent:0,failed:[]};update(0,'正在唤醒这片远境…');
    // Cap parallel decodes to avoid a memory spike on phones.
    let cursor=0;
    try{
      await Promise.all(Array.from({length:Math.min(6,resources.length)},async()=>{
        while(cursor<resources.length&&token===generation){
          const resource=resources[cursor++],result=await WorldAssets.load(resource.kind,resource.id,retry);
          if(token!==generation)return;
          diagnostics.completed++;if(result.status!=='ready'&&!resource.optional)diagnostics.failed.push(resource);if(resource.kind==='loading'&&result.status==='ready')screen.style.setProperty('--loading-art','url("'+new URL(WorldAssets.path('loading',resource.id),document.baseURI).href+'")');
          update(Math.floor(diagnostics.completed/resources.length*90),'正在载入场景 · '+diagnostics.completed+' / '+resources.length);
        }
      }));
      if(token!==generation)return;
      diagnostics.failed=remainingFailures();
      if(diagnostics.failed.length){failure('有 '+diagnostics.failed.length+' 项画面未能载入，请重试。');return;}
      await prepare(token);
    }catch(error){if(token===generation){console.error('Scene preparation failed',error);failure('场景准备未完成，请重试。');}}
  }
  function ensure(s){const key=loadingKey(s);if(key===currentKey)return task;task=run(s);return task;}
  screen.addEventListener('click',e=>{
    if(e.target.closest('[data-loading-retry]'))task=run(currentState,true);
    if(e.target.closest('[data-loading-fallback]')){actions.hidden=true;task=prepare(generation).catch(error=>{console.error(error);failure('场景准备未完成，请重试。');});}
  });
  // Capture input before the HUD, dialogue and scene handlers, including during boot.
  for(const type of ['click','contextmenu','pointerdown','pointermove','pointerup','wheel','keydown','keyup'])document.addEventListener(type,e=>{
    if(!active)return;
    if(!screen.contains(e.target)){e.preventDefault();e.stopImmediatePropagation();return;}
    if(type==='keydown'&&e.key==='Tab'){
      const buttons=[...screen.querySelectorAll('button')].filter(b=>!b.hidden&&!actions.hidden),index=buttons.indexOf(document.activeElement);
      e.preventDefault();(buttons.length?buttons[(index+(e.shiftKey?-1:1)+buttons.length)%buttons.length]:screen).focus({preventScroll:true});
    }
  },{capture:true,passive:false});
  window.GameLoading={ensure,manifest,blocked:()=>active,whenReady:()=>task,diagnostics:()=>({...diagnostics,failed:diagnostics.failed.map(r=>({...r,...WorldAssets.inspect(r.kind,r.id)}))})};
})();
