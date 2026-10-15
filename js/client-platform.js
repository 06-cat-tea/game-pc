(() => {
  'use strict';
  const id = 'desktop';
  const saveKey = 'ashen-frontier-save-v3-' + id;
  const other = id === 'desktop' ? 'mobile' : 'desktop';
  const preferenceKey = 'ashen-frontier-client';
  let legacy = null;

  function prepareLegacySave() {
    try {
      if (localStorage.getItem(saveKey) !== null) return;
      for (const key of ['ashen-frontier-save-v3', 'ashen-frontier-save-v2']) {
        try {
          let raw = JSON.parse(localStorage.getItem(key));
          if (key === 'ashen-frontier-save-v2' && raw && raw.schema === undefined) raw = {...raw, schema:2};
          if (raw && [2, 3, 4, 5, 6].includes(raw.schema) &&
              (raw.player && typeof raw.player === 'object' || raw.schema === 2 && raw.level !== undefined)) {
            legacy = raw;
            return;
          }
        } catch { /* A damaged legacy slot must not hide another valid legacy slot. */ }
      }
    } catch { /* Storage can be disabled for local files and private sessions. */ }
  }

  function readSave() {
    const stored = localStorage.getItem(saveKey);
    return stored === null ? legacy : JSON.parse(stored);
  }

  function finishLegacySave(state) {
    if (!legacy) return;
    try {
      // Persist only the normalized state. Never replace an existing client slot.
      if (localStorage.getItem(saveKey) === null) localStorage.setItem(saveKey, JSON.stringify(state));
      legacy = null;
    } catch {
      console.warn('旧进度已载入，浏览器暂时无法保存，请使用设置中的导出备份。');
    }
  }

  function switchLink() {
    const destination = window.GameDeployment?.[other];
    if (!destination) return '';
    const url = new URL(destination, location.href);
    if (!['file:', 'http:', 'https:'].includes(url.protocol)) return '';
    const href = url.href.replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
    return `<a class="client-switch" data-switch-client="${other}" href="${href}">切换至${other === 'mobile' ? '手机' : '电脑'}版</a>`;
  }

  document.addEventListener('click', event => {
    const link = event.target.closest?.('[data-switch-client]');
    if (!link || event.defaultPrevented || event.button !== 0) return;
    if (window.AshenGame && !window.AshenGame.save()) {
      event.preventDefault();
      return;
    }
    try { localStorage.setItem(preferenceKey, other); } catch { }
  });

  window.GameClient = Object.freeze({id, mobile:id === 'mobile', saveKey,
    prepareLegacySave, readSave, finishLegacySave, switchLink});
})();
