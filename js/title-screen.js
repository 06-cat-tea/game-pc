(() => {
  'use strict';
  const artwork='assets/art-v2/title.webp';
  const esc=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  function render(s){
    const room=SceneSystem.get(s.location?.sceneId),place=room?.title||GameData.PLACES[s.place].name;
    const phase=['清晨','正午','黄昏','深夜'][s.phase]||'清晨';
    return `<div class="launch-screen" aria-label="灰烬边境启动画面">
      <div class="launch-art" aria-hidden="true"></div><div class="launch-shade" aria-hidden="true"></div>
      <div class="launch-atmosphere" aria-hidden="true">${Array.from({length:18},(_,i)=>`<i style="--x:${7+(i*37)%89}%;--y:${12+(i*29)%77}%;--delay:${-i*1.7}s;--duration:${13+i%6*3}s;--size:${i%3===0?3:2}px"></i>`).join('')}</div>
      <div class="launch-frame" aria-hidden="true"><i></i><i></i><i></i><i></i></div>
      <header class="launch-header"><div class="launch-brand"><img src="assets/expansion/icons/brand.png" alt="" width="44" height="44"><span>星陨纪事<small>CHRONICLES OF THE FALLEN STAR</small></span></div><div class="launch-client-actions">${window.GameClient.switchLink()}<button class="launch-fullscreen" data-fullscreen="1" aria-label="全屏显示" title="全屏显示"><span aria-hidden="true">⛶</span></button></div></header>
      <section class="launch-content" aria-labelledby="launchTitle">
        <p class="launch-eyebrow">ASHEN FRONTIER</p>
        <h1 id="launchTitle">灰烬边境</h1>
        <div class="launch-subtitle"><span aria-hidden="true"></span><p>星陨纪事</p><span aria-hidden="true"></span></div>
        <p class="launch-quote">每一盏归灯，<br>都在等待一个被记住的名字。</p>
        <nav class="launch-menu" aria-label="启动菜单">
          <button class="launch-continue" data-command="continue"><span class="launch-button-star" aria-hidden="true">✦</span><span class="launch-button-copy"><b>继续旅程</b><small>${esc(place)} · Lv.${s.player.level} · 第 ${s.day} 日</small></span><span class="launch-arrow" aria-hidden="true">›</span></button>
          <button class="launch-new" data-command="new-game"><span aria-hidden="true">＋</span><b>新的旅途</b><span class="launch-arrow" aria-hidden="true">›</span></button>
          <button class="launch-settings" data-screen="settings">${UIIcons.icon('settings')}<span>设置与存档</span></button>
        </nav>
        <p class="launch-save"><span aria-hidden="true"></span>旅途停驻于 ${esc(place)} · ${phase}</p>
      </section>
      <div class="launch-scene-caption" aria-hidden="true"><span>归灯尚明</span><small>星陨之夜 · 王城远景</small></div>
      <footer class="launch-footer"><span>六方远境 · 一盏归灯</span><span>星陨纪事 <i aria-hidden="true">✧</i> 6.10</span></footer>
    </div>`;
  }
  const reduced=matchMedia('(prefers-reduced-motion: reduce)');let scheduled=0;
  function activate(id){if(id==='title'&&!window.GameLoading?.blocked())document.querySelector('.launch-continue')?.focus({preventScroll:true});}
  document.querySelector('#gameViewport').addEventListener('game-ready',()=>activate(window.GameUI?.getCurrent()));
  document.addEventListener('pointermove',event=>{
    if(event.pointerType==='touch'||reduced.matches||document.body.classList.contains('reduce-motion')||window.GameLoading?.blocked())return;
    const screen=event.target.closest?.('.launch-screen');if(!screen||scheduled)return;
    const point=GameViewport.clientToLocal(event.clientX,event.clientY),size=GameViewport.size();
    scheduled=requestAnimationFrame(()=>{scheduled=0;if(!screen.isConnected)return;screen.style.setProperty('--shift-x',((point.x/size.width-.5)*-8).toFixed(2)+'px');screen.style.setProperty('--shift-y',((point.y/size.height-.5)*-5).toFixed(2)+'px');});
  });
  window.TitleScreen={render,artwork,activate};
})();
