(() => {
  'use strict';
  const art=()=>window.ArtCatalog?.actors||{};
  let direction=0,movingUntil=0,started=0,lastFrame=0,running=false;
  function actorId(n){return art()[n?.id]?n.id:art()[n?.type]?n.type:'villager';}
  function movement(dx,dy,moved){if(!moved)return;const sx=dx-dy,sy=dx+dy;direction=sy>=0?(sx>=0?0:1):(sx>=0?2:3);if(performance.now()>movingUntil)started=performance.now();movingUntil=performance.now()+110;}
  function heroId(){const moving=performance.now()<movingUntil&&!document.body.classList.contains('reduce-motion');lastFrame=moving?1+Math.floor((performance.now()-started)/(125/(running?1.8:1)))%4:0;return 'hero-'+direction+'-'+lastFrame;}
  function draw(ctx,n,p,player=false,selected=false,scale=1){const id=player?heroId():actorId(n),e=art()[id],image=e&&WorldAssets.ready('actors',id);if(!image)return false;const height=(player?30:28)*scale,width=height,anchor=e.anchor||[.5,.97];ctx.save();ctx.imageSmoothingEnabled=true;ctx.fillStyle='#182b3c36';ctx.beginPath();ctx.ellipse(p.x*2,(p.y+1)*2,7*scale*2,2.5*scale*2,0,0,Math.PI*2);ctx.fill();if(player||selected){ctx.strokeStyle=player?'#f0dca1':'#fff8db';ctx.lineWidth=1.3;ctx.beginPath();ctx.ellipse(p.x*2,(p.y+1)*2,8.5*scale*2,3*scale*2,0,0,Math.PI*2);ctx.stroke();}ctx.drawImage(image,(p.x-width*anchor[0])*2,(p.y-height*anchor[1])*2,width*2,height*2);ctx.restore();return true;}
  const enemyRules=[[/狼/,'wolf'],[/树|古根/,'treant'],[/鹿/,'deer'],[/蟹/,'crab'],[/幼兽|熔核/,'lava-beast'],[/流亡骑士/,'knight'],[/守门|石像|沉星/,'golem'],[/王嗣|王冠/,'prince'],[/亡语|巫医|祭司/,'eclipse-priest'],[/走私|弩/,'smuggler'],[/海蛇|潮王/,'serpent'],[/船|海盗|雾帆/,'pirate'],[/晶|封印|月蚀/,'sorceress'],[/熔|炉|峡/,'commander'],[/试炼|钟|公会|守誓|护卫|骑士/,'sentinel'],[/掠夺|盗|匪|斥候/,'raider']];
  function enemyId(e,place){return enemyRules.find(([re])=>re.test(e.name))?.[1]||{town:'sentinel',wood:'treant',pass:'raider',fen:'prince',coast:'pirate'}[place]||'sentinel';}
  function markup(id,alt='',kind='actors',cls='standing-sprite'){const e=window.ArtCatalog?.[kind]?.[id];return e?`<img class="${cls}" src="${WorldAssets.path(kind,id)}" alt="${String(alt).replace(/[&<>"']/g,'')}" draggable="false">`:WorldAssets.portrait(kind==='actors'?id:'soldier',alt,cls);}
  function resources(place,sceneId){const ns=sceneId?NPCSystem.inside(SceneSystem.get(sceneId)?.occupantKey||SceneSystem.get(sceneId)?.buildingId):NPCSystem.at(place);return [...new Set([...Array.from({length:20},(_,i)=>'hero-'+Math.floor(i/5)+'-'+i%5),...ns.map(actorId)])].filter(id=>art()[id]);}
  window.SceneCharacters={draw,movement,actorId,heroId,markup,enemyId,resources,setRunning:value=>{running=!!value;},diagnostics:()=>({direction,frame:lastFrame,moving:performance.now()<movingUntil,running,npcsAnimated:false})};
})();
