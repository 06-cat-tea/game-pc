(() => {
  'use strict';
  const key=window.GameClient.saveKey;
  function backup(raw,version){if(!raw)return;const old=version||raw.schema;if(old&&old<6)try{const k=key+'-backup-v'+old;if(!localStorage.getItem(k))localStorage.setItem(k,JSON.stringify(raw));}catch{}}
  function extend(s){window.ClassContent.normalize(s);window.PartySystem.normalize(s);window.WorldLayout?.migrate(s);window.SceneSystem.normalize(s);if(s.battle)window.BattleSystem.init(s.battle);return s;}
  window.SaveMigrations={backup,extend};
})();
