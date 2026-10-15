(() => {
  "use strict";
  const buildings=["castle","town","church","forge","shop","inn","guild","academy","alchemy","stable","farm","mine","harbor","barracks","gate","forest","ruins","rift","sky-city","demon-fortress"];
  const portraits=["hero","knight","mage","archer","blacksmith","priest","quest-giver","innkeeper","merchant","noble","villager","girl","soldier","bandit","beastfolk","elder","bard","demon","skeleton","orc"];
  const scenes=["town","wood","pass","fen","coast"],cache=new Map();
  const path=(kind,id,size)=>{const key=kind==='expansion'?'scenes':kind==='loading'?'loadingScreens':kind,art=window.ArtCatalog?.[key]?.[id];return art?art.url||`assets/art-v2/${art.file}`:kind==="environment"?`assets/environment/sprites/${id}.webp`:kind==="emblems"?`assets/expansion/icons/${id}.png`:kind==="expansion"?`assets/expansion/scenes/${id}.webp`:kind==="scenes"?`assets/world/scenes/${id}.webp`:`assets/world/${kind}/${id}-${size||(kind==="buildings"?512:256)}.png`;};
  function entryFor(kind,id,retry=false){
    const key=kind+":"+id,old=cache.get(key);if(old&&!(retry&&old.status==="failed"))return old;
    const entry={image:null,status:"loading",promise:null,reason:null,attempts:0};cache.set(key,entry);
    entry.promise=new Promise(resolve=>{
      let settled=false,timer;
      const finish=(status,reason=null)=>{
        if(cache.get(key)!==entry||entry.status==='ready')return;
        clearTimeout(timer);entry.status=status;entry.reason=reason;entry.failed=status==='failed';
        const result={kind,id,status,url:entry.image.src,reason,attempts:entry.attempts};
        // A slow image may arrive after the timeout. Replace the failed promise too.
        if(settled)entry.promise=Promise.resolve(result);else{settled=true;resolve(result);}
        if(status==='ready'){
          if(kind==='environment'||kind==='terrain'){window.SceneEnvironment?.invalidate();window.WorldTerrain?.invalidate();}
          window.CircleMap?.invalidate();window.CircleMap?.draw();
          window.dispatchEvent(new CustomEvent('worldassetready',{detail:{kind,id}}));
        }
      };
      const attempt=()=>{
        const image=new Image();entry.image=image;entry.attempts++;
        const current=()=>cache.get(key)===entry&&entry.image===image;
        const fail=reason=>{
          if(!current()||entry.status==='ready')return;
          clearTimeout(timer);
          if(entry.attempts<2&&!settled)timer=setTimeout(attempt,750);
          else finish('failed',reason);
        };
        timer=setTimeout(()=>{if(current())finish('failed','timeout');},45000);
        image.onload=async()=>{try{await image.decode();if(current())finish('ready');}catch{fail('decode');}};
        image.onerror=()=>fail('network');
        const base=kind==='url'?id:path(kind,id);
        image.src=(retry||entry.attempts>1)&&location.protocol!=='file:'?base+(base.includes('?')?'&':'?')+'asset-retry='+Date.now()+'-'+entry.attempts:base;
      };
      attempt();
    });
    if(kind==="expansion"||kind==="loading"){const keys=[...cache.keys()].filter(k=>k.startsWith(kind+":")&&cache.get(k).status!=="loading");while(keys.length>(kind==='loading'?2:4))cache.delete(keys.shift());}
    return entry;
  }
  function get(kind,id){return entryFor(kind,id).image;}
  function load(kind,id,retry=false){return entryFor(kind,id,retry).promise;}
  function ready(kind,id){if(kind==='scenes'&&id==='city')return null;const key=kind+':'+id;if(!cache.has(key)&&window.GameLoading?.blocked())return null;const entry=entryFor(kind,id);return entry.status==='ready'&&entry.image.complete&&entry.image.naturalWidth>0?entry.image:null;}
  function inspect(kind,id){const entry=cache.get(kind+':'+id);return entry?{status:entry.status,url:entry.image.src,reason:entry.reason,attempts:entry.attempts}:null;}
  const masks=new Map();
  function opaque(id,u,v){if(!masks.has(id)){const encoded=window.ArtHitMasks?.[id]||window.WorldHitMasks?.[id];masks.set(id,encoded?Uint8Array.from(atob(encoded),c=>c.charCodeAt(0)):null);}const a=masks.get(id),x=Math.floor(u*64),y=Math.floor(v*64);if(x<0||x>=64||y<0||y>=64)return false;if(!a)return true;const index=y*64+x;return!!(a[index>>3]&(1<<(index&7)));}
  function portrait(type,alt="",className="portrait-art"){return `<img class="${className}" src="${path("portraits",type||"hero")}" alt="${String(alt).replace(/[&<>\"]/g,"")}" loading="lazy">`;}
  function building(id,alt=""){return `<img class="building-art" src="${path("buildings",id)}" alt="${String(alt).replace(/[&<>\"]/g,"")}" loading="lazy">`;}
  function preload(place){window.SceneEnvironment?.preload(place);get("emblems","brand");if(place!=="city")get("scenes",place);for(const b of window.BuildingSystem?.at(place)||[])get("buildings",b.artId||b.asset);}
  window.WorldAssets={buildings,portraits,scenes,path,get,ready,load,inspect,opaque,portrait,building,preload};
})();
