(() => {
  'use strict';
  const stage=document.querySelector('#gameViewport');
  const touch=()=>false;
  let layout={width:0,height:0,rotated:false,touch:false};
  const probe=document.createElement('div');probe.className='safe-insets';document.body.append(probe);
  function rawPoint(x,y){const r=stage.getBoundingClientRect();return layout.rotated?{x:y-r.top,y:r.right-x}:{x:x-r.left,y:y-r.top};}
  function localRect(element=stage){
    if(element===stage)return {x:0,y:0,width:layout.width,height:layout.height};
    const r=element.getBoundingClientRect(),a=rawPoint(r.left,r.top),b=rawPoint(r.right,r.bottom);
    return {x:Math.min(a.x,b.x),y:Math.min(a.y,b.y),width:Math.abs(b.x-a.x),height:Math.abs(b.y-a.y)};
  }
  function clientToLocal(x,y,element=stage){const p=rawPoint(x,y),r=localRect(element);return {x:p.x-r.x,y:p.y-r.y};}
  function localToClient(x,y,element=stage){const p=localRect(element),r=stage.getBoundingClientRect();x+=p.x;y+=p.y;return layout.rotated?{x:r.right-y,y:r.top+x}:{x:r.left+x,y:r.top+y};}
  function update(){
    const vp=window.visualViewport,w=vp?.width||innerWidth,h=vp?.height||innerHeight,style=getComputedStyle(probe);
    const left=parseFloat(style.paddingLeft)||0,right=parseFloat(style.paddingRight)||0,top=parseFloat(style.paddingTop)||0,bottom=parseFloat(style.paddingBottom)||0;
    const aw=Math.max(1,w-left-right),ah=Math.max(1,h-top-bottom),mobile=touch(),rotated=mobile&&ah>aw;
    const availableW=rotated?ah:aw,availableH=rotated?aw:ah,width=Math.min(availableW,availableH*16/9,1920),height=width*9/16;
    const next={width,height,rotated,touch:mobile};
    const changed=Object.keys(next).some(k=>next[k]!==layout[k]);layout=next;
    Object.assign(stage.style,{width:width+'px',height:height+'px',left:((vp?.offsetLeft||0)+left+aw/2)+'px',top:((vp?.offsetTop||0)+top+ah/2)+'px',transform:`translate(-50%,-50%) rotate(${rotated?90:0}deg)`});
    stage.dataset.touch=String(mobile);stage.dataset.compact=String(height<520);stage.dataset.rotated=String(rotated);
    if(changed){window.PixelWorld?.clearInput();window.dispatchEvent(new CustomEvent('gameviewportchange',{detail:{...layout}}));}
  }
  async function fullscreen(){
    try{if(!document.fullscreenElement)await document.documentElement.requestFullscreen();else {await document.exitFullscreen();update();return;}}catch{update();return;}
    if(touch())try{await screen.orientation?.lock('landscape');}catch{}
    update();
  }
  window.GameViewport={update,size:()=>({...layout}),localRect,clientToLocal,localToClient,fullscreen,isTouch:touch};
  window.addEventListener('resize',update);window.visualViewport?.addEventListener('resize',update);window.visualViewport?.addEventListener('scroll',update);document.addEventListener('fullscreenchange',update);
  update();
})();
