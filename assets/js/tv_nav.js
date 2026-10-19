(function () {
  'use strict';
  if (window.__bingeTvNavLoaded) return;
  window.__bingeTvNavLoaded = true;
  const STEP = 300;
  const RING = '#FFD600';
  const SHADOW = '#7C3AED';
  let current = null;
  let cursorMode = false;
  let cursor = { x: innerWidth / 2, y: innerHeight / 2 };

  const style = document.createElement('style');
  style.textContent = `.binge-tv-focus{outline:4px solid ${RING} !important;outline-offset:3px !important;box-shadow:0 0 12px ${SHADOW},0 0 22px ${SHADOW} !important;}`;
  (document.head || document.documentElement).appendChild(style);

  function interactive(el) {
    if (!el || !(el instanceof HTMLElement)) return false;
    const r = el.getBoundingClientRect(), s = getComputedStyle(el);
    return r.width > 0 && r.height > 0 && s.visibility !== 'hidden' && s.display !== 'none' &&
      (el.matches('a,button,input,select,textarea,video,[role="button"],[role="link"],[role="tab"],[role="menuitem"],[tabindex]:not([tabindex="-1"]),[onclick]') || s.cursor === 'pointer');
  }
  function candidates() { return [...document.querySelectorAll('a,button,input,select,textarea,video,[role],[tabindex],[onclick]')].filter(interactive); }
  function focus(el) { if (!el) return; if (current) current.classList.remove('binge-tv-focus'); current = el; current.classList.add('binge-tv-focus'); current.scrollIntoView({ behavior: 'smooth', block: 'center', inline: 'center' }); }
  function move(key) {
    if (!current) { focus(candidates()[0]); return; }
    const a = current.getBoundingClientRect(), ax = a.left + a.width / 2, ay = a.top + a.height / 2;
    let best = null, bestScore = Infinity;
    candidates().forEach(el => {
      if (el === current) return;
      const r = el.getBoundingClientRect(), x = r.left + r.width / 2, y = r.top + r.height / 2;
      const dx = x - ax, dy = y - ay;
      if ((key === 'ArrowLeft' && dx >= -4) || (key === 'ArrowRight' && dx <= 4) || (key === 'ArrowUp' && dy >= -4) || (key === 'ArrowDown' && dy <= 4)) return;
      const primary = key === 'ArrowLeft' || key === 'ArrowRight' ? Math.abs(dx) : Math.abs(dy);
      const cross = key === 'ArrowLeft' || key === 'ArrowRight' ? Math.abs(dy) : Math.abs(dx);
      const score = primary + cross * 2;
      if (score < bestScore) { bestScore = score; best = el; }
    });
    if (best) focus(best); else window.scrollBy({ left: key === 'ArrowLeft' ? -STEP : key === 'ArrowRight' ? STEP : 0, top: key === 'ArrowUp' ? -STEP : key === 'ArrowDown' ? STEP : 0, behavior: 'smooth' });
  }
  function activate() {
    if (cursorMode) { const el = document.elementFromPoint(cursor.x, cursor.y); if (el) el.click(); return; }
    if (!current) focus(candidates()[0]);
    if (!current) return;
    if (current.matches('input,textarea,select')) current.focus();
    else if (current.tagName === 'VIDEO') current.paused ? current.play() : current.pause();
    else current.click();
  }
  function toast(text) { const t = document.createElement('div'); t.textContent = text; t.style.cssText = `position:fixed;z-index:2147483647;left:50%;bottom:10%;transform:translateX(-50%);padding:14px 24px;background:#000;color:${RING};border:2px solid ${SHADOW};font:22px sans-serif;border-radius:10px`; document.body.appendChild(t); setTimeout(() => t.remove(), 2000); }
  function keydown(e) {
    if (['ArrowUp','ArrowDown','ArrowLeft','ArrowRight'].includes(e.key)) { e.preventDefault(); if (cursorMode) { cursor.x += e.key === 'ArrowLeft' ? -25 : e.key === 'ArrowRight' ? 25 : 0; cursor.y += e.key === 'ArrowUp' ? -25 : e.key === 'ArrowDown' ? 25 : 0; } else move(e.key); }
    else if (e.key === 'Enter' || e.key === 'Select' || e.key === ' ') { e.preventDefault(); activate(); }
    else if (e.key === 'ContextMenu' || e.key === 'm' || e.key === 'M') { cursorMode = !cursorMode; toast(cursorMode ? 'Cursor mode' : 'Focus mode'); }
    else if (e.key === 'MediaPlayPause') { const v = document.querySelector('video'); if (v) v.paused ? v.play() : v.pause(); }
    else if (current && current.tagName === 'VIDEO' && (e.key === 'ArrowLeft' || e.key === 'ArrowRight')) current.currentTime += e.key === 'ArrowLeft' ? -10 : 10;
  }
  window.addEventListener('keydown', keydown, true);
  new MutationObserver(() => { if (!current || !document.contains(current)) current = null; }).observe(document.documentElement, { childList: true, subtree: true });
  window.addEventListener('popstate', () => { current = null; });
})();
