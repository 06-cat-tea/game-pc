/* Content comes from the native loading catalog at export. No save API. */
const loadingCarousel=(()=>{
 'use strict';
 const catalog=JSON.parse(document.getElementById('loading-catalog').textContent);
 const status=document.getElementById('status'),layers=[...document.querySelectorAll('.loading-art')];
 const picture=document.getElementById('picture-title'),tip=document.getElementById('tip'),category=document.getElementById('tip-category');
 const reduced=matchMedia('(prefers-reduced-motion: reduce)');
 let active=0,current='',bag=[],tipBag=[],lastTip='',stopped=false,failed=false,sequence=0,changing=false;
 let imageTimer,tipTimer,preloadTimer,pending=null;
 const rejected=new Set(),cache=new Map();
 const shuffle=values=>{const result=[...values];for(let i=result.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[result[i],result[j]]=[result[j],result[i]];}return result;};
 function nextTip(){
  if(!tipBag.length)tipBag=shuffle(catalog.tips);
  if(tipBag.length>1&&tipBag[0].id===lastTip)tipBag.push(tipBag.shift());
  const value=tipBag.shift();lastTip=value.id;tip.textContent=value.text;category.textContent=catalog.categories[value.category];status.dataset.tipId=value.id;
 }
 function nextImage(){
  if(!bag.length)bag=shuffle(catalog.images.filter(image=>image.id!==current&&!rejected.has(image.id)));
  return bag.shift();
 }
 async function loadNext(){
  for(let attempt=0;attempt<catalog.images.length;attempt++){
   if(stopped||failed)return null;
   const data=nextImage();if(!data)return null;
   try{
    const image=new Image();image.decoding='async';image.fetchPriority='low';image.src=data.url;cache.set(data.id,image);
    if(image.decode)await image.decode();else await new Promise((resolve,reject)=>{image.onload=resolve;image.onerror=reject;});
    return {data,image};
   }catch{rejected.add(data.id);cache.delete(data.id);}
  }
  return null;
 }
 function prepare(){if(!pending&&!stopped&&!failed)pending=loadNext();}
 async function change(first=false){
  if(stopped||failed||changing||(!first&&reduced.matches))return;
  changing=true;const token=sequence;prepare();const result=await pending;pending=null;
  if(stopped||failed||token!==sequence){changing=false;return;}
  if(!result){changing=false;clearInterval(imageTimer);return;}
  const target=layers[1-active];target.src=result.image.src;
  target.classList.add('visible');layers[active].classList.remove('visible');active=1-active;
  current=result.data.id;picture.textContent=result.data.title;status.dataset.imageKey=current;
  for(const [id]of cache)if(id!==current)cache.delete(id);
  changing=false;clearTimeout(preloadTimer);
  if(!reduced.matches)preloadTimer=setTimeout(prepare,Math.max(0,catalog.rotation.image_seconds-1)*1000);
 }
 function clearTimers(){clearInterval(imageTimer);clearInterval(tipTimer);clearTimeout(preloadTimer);imageTimer=tipTimer=preloadTimer=null;}
 function startTimers(){
  clearTimers();if(stopped||failed||document.hidden)return;
  tipTimer=setInterval(nextTip,catalog.rotation.tip_seconds*1000);
  if(!reduced.matches){imageTimer=setInterval(()=>change(),catalog.rotation.image_seconds*1000);preloadTimer=setTimeout(prepare,Math.max(0,catalog.rotation.image_seconds-1)*1000);}
 }
 function stop(){stopped=true;sequence++;clearTimers();cache.clear();pending=null;status.dataset.rotating='false';}
 function showError(error){
  failed=true;sequence++;clearTimers();status.hidden=false;status.dataset.rotating='false';document.documentElement.dataset.gameState='error';
  document.getElementById('message').textContent='旅程暂时未能启动';
  document.getElementById('detail').textContent=String(error?.message||error)+'。请检查网络，并使用支持 WebGL 2 的电脑浏览器重试。';
  document.getElementById('progress').hidden=true;document.getElementById('retry').hidden=false;
 }
 document.getElementById('retry').addEventListener('click',()=>location.reload());
 document.addEventListener('visibilitychange',startTimers);reduced.addEventListener('change',startTimers);window.addEventListener('pagehide',stop,{once:true});
 status.style.setProperty('--fade-seconds',catalog.rotation.fade_seconds+'s');status.dataset.rotating='true';nextTip();change(true);startTimers();
 return {stop,showError};
})();
