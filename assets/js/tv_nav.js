/**
 * Binge TV Navigation Engine v2.0
 * Engineered for Fire OS 8 / Android 11 (API 30) TV with remote control
 * 
 * Features:
 * - Spatial 4-way navigation with cone-distance scoring & container scrolling
 * - Floating, detached focus ring overlay (does not mutate site DOM classes)
 * - Hardware-accelerated virtual cursor mode with authentic pointer events
 * - Video media control (play/pause, seek with acceleration, volume overlay, 10% jumps)
 * - Modal & overlay detection with automatic remote Back dismiss
 * - Desktop viewport manipulation & desktop browser signal spoofing
 * - Bidirectional communication API via window.__bingeTv
 */

(function (window, document) {
  'use strict';

  // Prevent multiple executions in the same execution context
  if (window.__bingeTv && window.__bingeTv.initialized) {
    return;
  }

  /* =========================================================================
   * CONSTANTS & DESIGN TOKENS
   * ========================================================================= */
  const COLOR_YELLOW = '#FFD600';
  const COLOR_PURPLE = '#7C3AED';
  const COLOR_DEEP_PURPLE = '#4C1D95';
  const COLOR_BG_DARK = 'rgba(13, 10, 18, 0.95)';

  const CANDIDATE_CACHE_TTL_MS = 250;
  const KEY_THROTTLE_MS = 65;
  const CURSOR_MIN_SPEED = 8;
  const CURSOR_MAX_SPEED = 55;
  const CURSOR_ACCEL_TIME_MS = 500;
  const CURSOR_IDLE_TIMEOUT_MS = 5000;
  const VIEWPORT_MARGIN_PX = 150;
  const SAFE_MARGIN_RATIO = 0.08; // 8% safe screen border for TV

  /* =========================================================================
   * STATE
   * ========================================================================= */
  let currentFocusedElement = null;
  let lastDirectionHistory = {}; // e.g. { 'Right': el, 'Left': el }
  let cachedCandidates = null;
  let lastCandidatesTime = 0;
  let lastKeyProcessedTime = 0;

  // Cursor Mode State
  let cursorMode = false;
  let cursorX = window.innerWidth / 2;
  let cursorY = window.innerHeight / 2;
  let cursorHolding = false;
  let cursorHoldStartTime = 0;
  let cursorHideTimer = null;

  // Media seek acceleration state
  let lastSeekDirection = null;
  let lastSeekTime = 0;
  let seekStepIndex = 0;
  const SEEK_STEPS = [10, 30, 60];

  // DOM Elements for overlays
  let overlayContainer = null;
  let focusRingElement = null;
  let cursorPointerElement = null;
  let activeToastElement = null;
  let seekIndicatorElement = null;
  let volumeIndicatorElement = null;

  /* =========================================================================
   * DESKTOP VIEWPORT & BROWSER NORMALISATION
   * ========================================================================= */
  let currentViewportContent = 'width=1920, initial-scale=1, maximum-scale=5, user-scalable=yes';

  function ensureDesktopViewport(targetWidth) {
    const width = targetWidth || window.__bingePageWidth || 1280;
    window.__bingePageWidth = width;

    let meta = document.querySelector('meta[name="viewport"]');
    // The default desktop mode must start at 100% instead of scaling a
    // 1280px virtual canvas up to a 4K television. Custom page widths remain
    // available through the Quick Menu.
    currentViewportContent = 'width=' + width + ', initial-scale=1, maximum-scale=5, user-scalable=yes';

    if (!meta) {
      meta = document.createElement('meta');
      meta.name = 'viewport';
      meta.content = currentViewportContent;
      if (document.head) {
        document.head.appendChild(meta);
      } else {
        document.documentElement.appendChild(meta);
      }
    } else {
      meta.content = currentViewportContent;
    }

    // Monitor for changes by single-page apps resetting the meta tag
    if (!window.__bingeViewportObserver && window.MutationObserver) {
      window.__bingeViewportObserver = new MutationObserver(function () {
        const m = document.querySelector('meta[name="viewport"]');
        if (m && m.content !== currentViewportContent) {
          m.content = currentViewportContent;
        }
      });
      window.__bingeViewportObserver.observe(document.documentElement, {
        attributes: true,
        subtree: true,
        attributeFilter: ['content', 'name']
      });
    }

    console.log('[BingeTV] Viewport adjusted to ' + width + 'px. innerWidth: ' + window.innerWidth + ', dpr: ' + window.devicePixelRatio);
  }

  function normalizeDesktopSignals() {
    try {
      // Keep real touch capability available while presenting desktop layout.
      Object.defineProperty(navigator, 'platform', { get: () => 'Win32', configurable: true });
      if (navigator.userAgentData) {
        try {
          Object.defineProperty(navigator.userAgentData, 'mobile', { get: () => false, configurable: true });
        } catch (e) {}
      }
    } catch (e) {
      // Ignore security restrictions in restricted contexts
    }
  }

  /* =========================================================================
   * OVERLAY UI LAYER (Focus Ring, Cursor, Toasts, Volume/Seek Indicators)
   * ========================================================================= */
  function ensureOverlayContainer() {
    if (overlayContainer && overlayContainer.parentNode) return;

    overlayContainer = document.createElement('div');
    overlayContainer.id = '__binge_tv_overlay_root';
    overlayContainer.style.cssText = [
      'position: fixed',
      'top: 0',
      'left: 0',
      'width: 100vw',
      'height: 100vh',
      'pointer-events: none',
      'z-index: 2147483640',
      'overflow: hidden',
      'margin: 0',
      'padding: 0'
    ].join(' !important;') + ' !important;';

    // The website supplies its own focus/selection treatment. Binge keeps
    // spatial navigation and cursor mode, but does not draw a second ring.
    focusRingElement = document.createElement('div');
    focusRingElement.id = '__binge_tv_focus_ring';
    focusRingElement.style.cssText = [
      'position: fixed',
      'display: none !important',
      'box-sizing: border-box',
      'border: 4px solid ' + COLOR_YELLOW,
      'border-radius: 8px',
      'box-shadow: 0 0 16px ' + COLOR_PURPLE + ', 0 0 32px ' + COLOR_DEEP_PURPLE,
      'transition: top 80ms ease-out, left 80ms ease-out, width 80ms ease-out, height 80ms ease-out, opacity 100ms ease',
      'pointer-events: none',
      'z-index: 2147483641'
    ].join(' !important;') + ' !important;';

    // 2. Virtual Cursor Element (28px yellow arrow with purple border)
    cursorPointerElement = document.createElement('div');
    cursorPointerElement.id = '__binge_tv_cursor';
    cursorPointerElement.innerHTML = '<svg viewBox="0 0 28 28" width="28" height="28" style="filter: drop-shadow(0 2px 6px rgba(0,0,0,0.8));">' +
      '<polygon points="0,0 24,11 13,14 18,25 13,27 8,16 0,22" fill="' + COLOR_YELLOW + '" stroke="' + COLOR_PURPLE + '" stroke-width="2.5" stroke-linejoin="round"/>' +
      '</svg>';
    cursorPointerElement.style.cssText = [
      'position: fixed',
      'display: none',
      'top: 0',
      'left: 0',
      'pointer-events: none',
      'z-index: 2147483646',
      'transform: translate3d(0, 0, 0)',
      'transition: opacity 200ms ease'
    ].join(' !important;') + ' !important;';

    overlayContainer.appendChild(focusRingElement);
    overlayContainer.appendChild(cursorPointerElement);

    const mount = document.body || document.documentElement;
    if (mount) mount.appendChild(overlayContainer);
  }

  function updateFocusRing() {
    ensureOverlayContainer();
    if (focusRingElement) focusRingElement.style.display = 'none';
    return;
    /*
    if (cursorMode || !currentFocusedElement || !document.contains(currentFocusedElement)) {
      if (focusRingElement) focusRingElement.style.display = 'none';
      return;
    }

    const rect = currentFocusedElement.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0 || rect.bottom < 0 || rect.top > window.innerHeight) {
      if (focusRingElement) focusRingElement.style.display = 'none';
      return;
    }

    // Match border-radius of the focused element
    let radius = '8px';
    try {
      const computed = window.getComputedStyle(currentFocusedElement);
      radius = computed.borderRadius || '8px';
    } catch (e) {}

    const offset = 4;
    focusRingElement.style.display = 'block';
    focusRingElement.style.left = (rect.left - offset) + 'px';
    focusRingElement.style.top = (rect.top - offset) + 'px';
    focusRingElement.style.width = (rect.width + offset * 2) + 'px';
    focusRingElement.style.height = (rect.height + offset * 2) + 'px';
    focusRingElement.style.borderRadius = radius;
    */
  }

  function updateCursorPosition(x, y) {
    ensureOverlayContainer();
    cursorX = Math.max(4, Math.min(window.innerWidth - 4, x));
    cursorY = Math.max(4, Math.min(window.innerHeight - 4, y));

    if (cursorPointerElement) {
      cursorPointerElement.style.display = cursorMode ? 'block' : 'none';
      cursorPointerElement.style.left = cursorX + 'px';
      cursorPointerElement.style.top = cursorY + 'px';
      cursorPointerElement.style.opacity = '1';
    }

    // Reset idle timer
    if (cursorHideTimer) clearTimeout(cursorHideTimer);
    cursorHideTimer = setTimeout(function () {
      if (cursorPointerElement && cursorMode) {
        cursorPointerElement.style.opacity = '0';
      }
    }, CURSOR_IDLE_TIMEOUT_MS);

    // Dispatch hover / mousemove at cursor point
    dispatchSyntheticMouseEvent('mousemove', cursorX, cursorY);
  }

  function showToast(text, durationMs) {
    ensureOverlayContainer();
    if (!overlayContainer) return;

    if (activeToastElement) {
      activeToastElement.remove();
      activeToastElement = null;
    }

    const toast = document.createElement('div');
    toast.textContent = text;
    toast.style.cssText = [
      'position: fixed',
      'bottom: 12%',
      'left: 50%',
      'transform: translateX(-50%)',
      'background: ' + COLOR_BG_DARK,
      'color: ' + COLOR_YELLOW,
      'border: 2px solid ' + COLOR_PURPLE,
      'box-shadow: 0 4px 24px rgba(0, 0, 0, 0.9)',
      'padding: 12px 28px',
      'border-radius: 12px',
      'font-family: Inter, Roboto, sans-serif',
      'font-size: 20px',
      'font-weight: 600',
      'pointer-events: none',
      'z-index: 2147483647',
      'animation: bingeFadeIn 150ms ease-out'
    ].join(' !important;') + ' !important;';

    overlayContainer.appendChild(toast);
    activeToastElement = toast;

    setTimeout(function () {
      if (activeToastElement === toast) {
        toast.remove();
        activeToastElement = null;
      }
    }, durationMs || 2500);
  }

  function showVolumeIndicator(level) {
    ensureOverlayContainer();
    if (!overlayContainer) return;

    if (!volumeIndicatorElement) {
      volumeIndicatorElement = document.createElement('div');
      volumeIndicatorElement.style.cssText = [
        'position: fixed',
        'top: 8%',
        'right: 8%',
        'background: ' + COLOR_BG_DARK,
        'border: 2px solid ' + COLOR_PURPLE,
        'border-radius: 12px',
        'padding: 12px 20px',
        'color: ' + COLOR_YELLOW,
        'font-family: Inter, Roboto, sans-serif',
        'font-size: 18px',
        'font-weight: bold',
        'z-index: 2147483647',
        'display: flex',
        'align-items: center',
        'gap: 12px'
      ].join(' !important;') + ' !important;';
      overlayContainer.appendChild(volumeIndicatorElement);
    }

    const pct = Math.round(level * 100);
    volumeIndicatorElement.innerHTML = '<span>VOL</span><div style="width:100px;height:10px;background:#333;border-radius:5px;overflow:hidden;"><div style="width:' + pct + '%;height:100%;background:' + COLOR_YELLOW + ';"></div></div><span>' + pct + '%</span>';
    volumeIndicatorElement.style.display = 'flex';

    if (volumeIndicatorElement._timer) clearTimeout(volumeIndicatorElement._timer);
    volumeIndicatorElement._timer = setTimeout(function () {
      if (volumeIndicatorElement) volumeIndicatorElement.style.display = 'none';
    }, 2000);
  }

  function showSeekIndicator(secondsDelta, totalSec) {
    ensureOverlayContainer();
    if (!overlayContainer) return;

    if (!seekIndicatorElement) {
      seekIndicatorElement = document.createElement('div');
      seekIndicatorElement.style.cssText = [
        'position: fixed',
        'bottom: 15%',
        'left: 50%',
        'transform: translateX(-50%)',
        'background: ' + COLOR_BG_DARK,
        'border: 2px solid ' + COLOR_PURPLE,
        'border-radius: 12px',
        'padding: 14px 28px',
        'color: ' + COLOR_YELLOW,
        'font-family: Inter, Roboto, sans-serif',
        'font-size: 24px',
        'font-weight: bold',
        'z-index: 2147483647'
      ].join(' !important;') + ' !important;';
      overlayContainer.appendChild(seekIndicatorElement);
    }

    const sign = secondsDelta > 0 ? '+' : '';
    seekIndicatorElement.textContent = 'Seek: ' + sign + secondsDelta + 's';
    seekIndicatorElement.style.display = 'block';

    if (seekIndicatorElement._timer) clearTimeout(seekIndicatorElement._timer);
    seekIndicatorElement._timer = setTimeout(function () {
      if (seekIndicatorElement) seekIndicatorElement.style.display = 'none';
    }, 1500);
  }

  /* =========================================================================
   * CANDIDATE INTERACTIVITY & OCCLUSION AUDITING
   * ========================================================================= */
  function isInteractiveElement(el) {
    if (!el || el.nodeType !== Node.ELEMENT_NODE) return false;
    if (el.id && el.id.startsWith('__binge_tv_')) return false;

    const tagName = el.tagName.toUpperCase();

    // Standard clickable/interactive selectors
    const matchesSelector =
      tagName === 'A' ||
      tagName === 'BUTTON' ||
      tagName === 'INPUT' ||
      tagName === 'SELECT' ||
      tagName === 'TEXTAREA' ||
      tagName === 'SUMMARY' ||
      tagName === 'VIDEO' ||
      el.hasAttribute('onclick') ||
      el.getAttribute('role') === 'button' ||
      el.getAttribute('role') === 'link' ||
      el.getAttribute('role') === 'tab' ||
      el.getAttribute('role') === 'menuitem' ||
      el.getAttribute('role') === 'option' ||
      el.getAttribute('role') === 'slider' ||
      el.getAttribute('role') === 'checkbox';

    let hasTabIndex = false;
    if (el.hasAttribute('tabindex')) {
      const ti = parseInt(el.getAttribute('tabindex'), 10);
      if (!isNaN(ti) && ti >= 0) hasTabIndex = true;
    }

    let cursorPointer = false;
    let style = null;
    try {
      style = window.getComputedStyle(el);
      cursorPointer = (style.cursor === 'pointer');
    } catch (e) {
      return false;
    }

    if (!matchesSelector && !hasTabIndex && !cursorPointer) {
      return false;
    }

    // Style and visibility audits
    if (style.display === 'none' ||
        style.visibility === 'hidden' ||
        style.opacity === '0' ||
        style.pointerEvents === 'none') {
      return false;
    }

    if (el.getAttribute('aria-hidden') === 'true' && tagName !== 'VIDEO') {
      return false;
    }

    const rect = el.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0) {
      return false;
    }

    // Viewport bounds with reasonable margin
    if (rect.bottom < -VIEWPORT_MARGIN_PX ||
        rect.top > window.innerHeight + VIEWPORT_MARGIN_PX ||
        rect.right < -VIEWPORT_MARGIN_PX ||
        rect.left > window.innerWidth + VIEWPORT_MARGIN_PX) {
      return false;
    }

    // Occlusion check at the center point (allowing descendants)
    const centerX = rect.left + rect.width / 2;
    const centerY = rect.top + rect.height / 2;
    if (centerX >= 0 && centerX <= window.innerWidth && centerY >= 0 && centerY <= window.innerHeight) {
      try {
        const topEl = document.elementFromPoint(centerX, centerY);
        if (topEl && topEl !== el && !el.contains(topEl) && !topEl.contains(el)) {
          // Check if topEl is in overlay layer or if el is obscured
          if (!topEl.id || !topEl.id.startsWith('__binge_tv_')) {
            const topStyle = window.getComputedStyle(topEl);
            if (topStyle.pointerEvents !== 'none' && topStyle.opacity !== '0') {
              // Obscured by an overlay/floating modal
              return false;
            }
          }
        }
      } catch (e) {}
    }

    return true;
  }

  function getActiveModalOrDialog() {
    const dialogs = document.querySelectorAll('[role="dialog"], [role="alertdialog"], [aria-modal="true"], dialog[open]');
    for (let i = 0; i < dialogs.length; i++) {
      const d = dialogs[i];
      const s = window.getComputedStyle(d);
      if (s.display !== 'none' && s.visibility !== 'hidden' && s.opacity !== '0') {
        return d;
      }
    }
    return null;
  }

  function getCandidates(forceRefresh) {
    const now = Date.now();
    if (!forceRefresh && cachedCandidates && (now - lastCandidatesTime < CANDIDATE_CACHE_TTL_MS)) {
      return cachedCandidates;
    }

    const modal = getActiveModalOrDialog();
    const root = modal || document;

    const raw = root.querySelectorAll('a, button, input, select, textarea, summary, video, [role], [tabindex], [onclick]');
    const filtered = [];

    for (let i = 0; i < raw.length; i++) {
      const el = raw[i];
      if (isInteractiveElement(el)) {
        filtered.push(el);
      }
    }

    // Drop nested duplicates: if an element contains another clickable candidate, prefer the innermost
    const deduplicated = [];
    for (let i = 0; i < filtered.length; i++) {
      const a = filtered[i];
      let hasChildCandidate = false;
      for (let j = 0; j < filtered.length; j++) {
        if (i !== j && a.contains(filtered[j])) {
          hasChildCandidate = true;
          break;
        }
      }
      if (!hasChildCandidate) {
        deduplicated.push(a);
      }
    }

    cachedCandidates = deduplicated;
    lastCandidatesTime = now;
    return deduplicated;
  }

  /* =========================================================================
   * SPATIAL NAVIGATION (Direction Cone & Distance Scoring)
   * ========================================================================= */
  function setFocus(el, scrollOptions) {
    if (!el) return;
    currentFocusedElement = el;

    // Trigger hover events to reveal auto-hiding video controls or dropdowns
    dispatchHoverSequence(el);

    // Scroll into view if outside the safe area
    ensureElementInSafeArea(el, scrollOptions);

    updateFocusRing();

    // If active modal exists, trap focus within it
    const modal = getActiveModalOrDialog();
    if (modal && !modal.contains(el)) {
      const modalCandidates = modal.querySelectorAll('a, button, input, select, textarea, [tabindex]');
      if (modalCandidates.length > 0) {
        setFocus(modalCandidates[0]);
      }
    }
  }

  function dispatchHoverSequence(el) {
    try {
      const evOpts = { bubbles: true, cancelable: true, view: window };
      el.dispatchEvent(new PointerEvent('pointerover', evOpts));
      el.dispatchEvent(new MouseEvent('mouseover', evOpts));
      el.dispatchEvent(new MouseEvent('mousemove', evOpts));
    } catch (e) {}
  }

  function ensureElementInSafeArea(el, options) {
    if (!el) return;
    const rect = el.getBoundingClientRect();
    const marginY = window.innerHeight * SAFE_MARGIN_RATIO;
    const marginX = window.innerWidth * SAFE_MARGIN_RATIO;

    const isOutside =
      rect.top < marginY ||
      rect.bottom > window.innerHeight - marginY ||
      rect.left < marginX ||
      rect.right > window.innerWidth - marginX;

    if (isOutside) {
      try {
        el.scrollIntoView({
          behavior: (options && options.smooth) ? 'smooth' : 'auto',
          block: 'nearest',
          inline: 'nearest'
        });
      } catch (e) {
        el.scrollIntoView();
      }
    }
  }

  function scoreDirectionCandidate(currentRect, targetRect, direction) {
    // Current center
    const curCx = currentRect.left + currentRect.width / 2;
    const curCy = currentRect.top + currentRect.height / 2;

    // Target center
    const tarCx = targetRect.left + targetRect.width / 2;
    const tarCy = targetRect.top + targetRect.height / 2;

    const dx = tarCx - curCx;
    const dy = tarCy - curCy;

    let primaryDist = 0;
    let secondaryDist = 0;
    let edgeDist = 0;

    switch (direction) {
      case 'Left':
        if (tarCx >= curCx) return -1;
        primaryDist = curCx - tarCx;
        secondaryDist = Math.abs(dy);
        edgeDist = currentRect.left - targetRect.right;
        break;
      case 'Right':
        if (tarCx <= curCx) return -1;
        primaryDist = tarCx - curCx;
        secondaryDist = Math.abs(dy);
        edgeDist = targetRect.left - currentRect.right;
        break;
      case 'Up':
        if (tarCy >= curCy) return -1;
        primaryDist = curCy - tarCy;
        secondaryDist = Math.abs(dx);
        edgeDist = currentRect.top - targetRect.bottom;
        break;
      case 'Down':
        if (tarCy <= curCy) return -1;
        primaryDist = tarCy - curCy;
        secondaryDist = Math.abs(dx);
        edgeDist = targetRect.top - currentRect.bottom;
        break;
    }

    if (edgeDist < -10 && primaryDist < 10) return -1;

    // Cone angle threshold: primary dist must dominate or have perpendicular overlap
    let perpendicularOverlap = 0;
    if (direction === 'Left' || direction === 'Right') {
      const topOverlap = Math.max(currentRect.top, targetRect.top);
      const bottomOverlap = Math.min(currentRect.bottom, targetRect.bottom);
      perpendicularOverlap = Math.max(0, bottomOverlap - topOverlap);
    } else {
      const leftOverlap = Math.max(currentRect.left, targetRect.left);
      const rightOverlap = Math.min(currentRect.right, targetRect.right);
      perpendicularOverlap = Math.max(0, rightOverlap - leftOverlap);
    }

    // Cone rejection: if secondary distance is more than 2x primary and no overlap, discard
    if (secondaryDist > primaryDist * 2.2 && perpendicularOverlap === 0) {
      return -1;
    }

    // Weighted score: lower is better
    // Bonus for perpendicular overlap, penalty for secondary drift
    let score = primaryDist + (secondaryDist * 1.8);
    if (perpendicularOverlap > 0) {
      score -= (perpendicularOverlap * 0.5);
    }

    return score;
  }

  function moveDirection(direction) {
    const list = getCandidates();
    if (list.length === 0) {
      scrollContainer(direction);
      return;
    }

    if (!currentFocusedElement || !document.contains(currentFocusedElement)) {
      findInitialFocus();
      return;
    }

    const curRect = currentFocusedElement.getBoundingClientRect();
    let best = null;
    let bestScore = Infinity;

    // Check if we came from this direction previously (direction history recall)
    const oppositeDir = getOppositeDirection(direction);
    const rememberedEl = lastDirectionHistory[direction];
    if (rememberedEl && document.contains(rememberedEl) && list.includes(rememberedEl)) {
      const score = scoreDirectionCandidate(curRect, rememberedEl.getBoundingClientRect(), direction);
      if (score > 0 && score < 300) {
        lastDirectionHistory[oppositeDir] = currentFocusedElement;
        setFocus(rememberedEl, { smooth: true });
        return;
      }
    }

    for (let i = 0; i < list.length; i++) {
      const el = list[i];
      if (el === currentFocusedElement) continue;

      const targetRect = el.getBoundingClientRect();
      const score = scoreDirectionCandidate(curRect, targetRect, direction);
      if (score > 0 && score < bestScore) {
        bestScore = score;
        best = el;
      }
    }

    if (best) {
      lastDirectionHistory[oppositeDir] = currentFocusedElement;
      lastDirectionHistory[direction] = best;
      setFocus(best, { smooth: true });
    } else {
      // Nothing found in direction: scroll nearest container and retry
      const didScroll = scrollContainer(direction);
      if (didScroll) {
        setTimeout(function () {
          updateFocusRing();
        }, 120);
      }
    }
  }

  function getOppositeDirection(dir) {
    if (dir === 'Left') return 'Right';
    if (dir === 'Right') return 'Left';
    if (dir === 'Up') return 'Down';
    if (dir === 'Down') return 'Up';
    return '';
  }

  function findScrollableContainer(el) {
    let node = el ? el.parentElement : document.body;
    while (node && node !== document.documentElement) {
      const style = window.getComputedStyle(node);
      const overflowY = style.overflowY;
      const overflowX = style.overflowX;
      if ((overflowY === 'auto' || overflowY === 'scroll') && node.scrollHeight > node.clientHeight) {
        return node;
      }
      if ((overflowX === 'auto' || overflowX === 'scroll') && node.scrollWidth > node.clientWidth) {
        return node;
      }
      node = node.parentElement;
    }
    return window;
  }

  function scrollContainer(direction) {
    const container = findScrollableContainer(currentFocusedElement);
    const scrollAmountY = Math.round(window.innerHeight * 0.6);
    const scrollAmountX = Math.round(window.innerWidth * 0.6);

    let dx = 0;
    let dy = 0;
    if (direction === 'Down') dy = scrollAmountY;
    else if (direction === 'Up') dy = -scrollAmountY;
    else if (direction === 'Right') dx = scrollAmountX;
    else if (direction === 'Left') dx = -scrollAmountX;

    if (container === window) {
      window.scrollBy({ left: dx, top: dy, behavior: 'smooth' });
    } else {
      container.scrollBy({ left: dx, top: dy, behavior: 'smooth' });
    }
    return true;
  }

  function findInitialFocus() {
    const list = getCandidates(true);
    if (list.length === 0) return;

    // Prefer elements in main, search, or top-center
    let candidate = null;
    const searchArea = document.querySelector('input[type="search"], input[type="text"], [role="search"], main, #main, article');
    if (searchArea) {
      for (let i = 0; i < list.length; i++) {
        if (searchArea.contains(list[i])) {
          candidate = list[i];
          break;
        }
      }
    }

    if (!candidate) {
      // Find candidate nearest top-center of viewport
      const targetX = window.innerWidth / 2;
      const targetY = window.innerHeight * 0.25;
      let minDistance = Infinity;

      for (let i = 0; i < list.length; i++) {
        const rect = list[i].getBoundingClientRect();
        if (rect.top >= 0 && rect.left >= 0) {
          const cx = rect.left + rect.width / 2;
          const cy = rect.top + rect.height / 2;
          const dist = Math.hypot(cx - targetX, cy - targetY);
          if (dist < minDistance) {
            minDistance = dist;
            candidate = list[i];
          }
        }
      }
    }

    setFocus(candidate || list[0]);
  }

  /* =========================================================================
   * ACTIVATION & INPUT / MEDIA CONTROLS
   * ========================================================================= */
  function activateCurrentElement() {
    if (cursorMode) {
      executeCursorClick();
      return;
    }

    if (!currentFocusedElement || !document.contains(currentFocusedElement)) {
      findInitialFocus();
      if (!currentFocusedElement) return;
    }

    const el = currentFocusedElement;
    const tagName = el.tagName.toUpperCase();

    // 1. Text Inputs / Textarea / Select
    if (tagName === 'INPUT' || tagName === 'TEXTAREA' || tagName === 'SELECT') {
      el.focus();
      if (typeof el.select === 'function' && tagName !== 'SELECT') {
        el.select();
      }
      return;
    }

    // 2. Video element: toggle playback
    if (tagName === 'VIDEO') {
      toggleVideoPlayback(el);
      return;
    }

    // 3. Child video container
    const innerVideo = el.querySelector('video');
    if (innerVideo) {
      toggleVideoPlayback(innerVideo);
      return;
    }

    // 4. Standard click invocation
    dispatchFullClickSequence(el);
  }

  function dispatchFullClickSequence(el) {
    if (!el) return;
    try {
      const rect = el.getBoundingClientRect();
      const x = rect.left + rect.width / 2;
      const y = rect.top + rect.height / 2;
      const opts = { bubbles: true, cancelable: true, view: window, clientX: x, clientY: y };

      el.dispatchEvent(new PointerEvent('pointerdown', opts));
      el.dispatchEvent(new MouseEvent('mousedown', opts));
      el.dispatchEvent(new PointerEvent('pointerup', opts));
      el.dispatchEvent(new MouseEvent('mouseup', opts));
      el.click();
    } catch (e) {
      el.click();
    }
  }

  function dispatchSyntheticMouseEvent(type, x, y) {
    try {
      const el = document.elementFromPoint(x, y);
      if (el) {
        const ev = new MouseEvent(type, {
          bubbles: true,
          cancelable: true,
          view: window,
          clientX: x,
          clientY: y
        });
        el.dispatchEvent(ev);
      }
    } catch (e) {}
  }

  function executeCursorClick() {
    ensureOverlayContainer();
    // Temporarily hide overlay root so elementFromPoint targets real page elements
    if (overlayContainer) overlayContainer.style.display = 'none';
    let target = null;
    try {
      target = document.elementFromPoint(cursorX, cursorY);
    } finally {
      if (overlayContainer) overlayContainer.style.display = 'block';
    }

    if (!target) return;

    // If inside an iframe on same-origin, target iframe contents
    if (target.tagName === 'IFRAME') {
      try {
        const idoc = target.contentDocument || target.contentWindow.document;
        if (idoc) {
          const irect = target.getBoundingClientRect();
          const frameX = cursorX - irect.left;
          const frameY = cursorY - irect.top;
          const innerTarget = idoc.elementFromPoint(frameX, frameY);
          if (innerTarget) target = innerTarget;
        }
      } catch (e) {}
    }

    dispatchFullClickSequence(target);
  }

  /* =========================================================================
   * VIDEO CONTROLS & CAPTIONS
   * ========================================================================= */
  function findActiveVideo() {
    // 1. If currently focused is video
    if (currentFocusedElement && currentFocusedElement.tagName === 'VIDEO') {
      return currentFocusedElement;
    }
    // 2. Playing video
    const videos = document.querySelectorAll('video');
    for (let i = 0; i < videos.length; i++) {
      if (!videos[i].paused && !videos[i].ended && videos[i].currentTime > 0) {
        return videos[i];
      }
    }
    // 3. Largest video element in DOM
    let largest = null;
    let maxArea = 0;
    for (let i = 0; i < videos.length; i++) {
      const r = videos[i].getBoundingClientRect();
      const area = r.width * r.height;
      if (area > maxArea) {
        maxArea = area;
        largest = videos[i];
      }
    }
    return largest;
  }

  function toggleVideoPlayback(video) {
    const v = video || findActiveVideo();
    if (!v) return;

    if (v.paused) {
      v.play().catch(function () {});
      showToast('Play', 1000);
    } else {
      v.pause();
      showToast('Pause', 1000);
    }
  }

  function seekVideo(direction, repeatCount) {
    const v = findActiveVideo();
    if (!v) return;

    const now = Date.now();
    if (lastSeekDirection === direction && (now - lastSeekTime < 800)) {
      seekStepIndex = Math.min(SEEK_STEPS.length - 1, seekStepIndex + 1);
    } else {
      seekStepIndex = 0;
    }
    lastSeekDirection = direction;
    lastSeekTime = now;

    const step = SEEK_STEPS[seekStepIndex];
    const delta = (direction === 'Forward' || direction === 'Right') ? step : -step;
    v.currentTime = Math.max(0, Math.min(v.duration || Infinity, v.currentTime + delta));
    showSeekIndicator(delta, v.duration);
  }

  function adjustVolume(delta) {
    const v = findActiveVideo();
    if (!v) return;

    const newVol = Math.max(0, Math.min(1, Math.round((v.volume + delta) * 10) / 10));
    v.volume = newVol;
    showVolumeIndicator(newVol);
  }

  function jumpVideoPercent(digit) {
    const v = findActiveVideo();
    if (!v || !v.duration || isNaN(v.duration)) return;

    const fraction = digit / 10.0;
    v.currentTime = v.duration * fraction;
    showToast('Jump to ' + Math.round(fraction * 100) + '%', 1500);
  }

  function toggleCaptions() {
    const v = findActiveVideo();
    if (v && v.textTracks && v.textTracks.length > 0) {
      let anyShowing = false;
      for (let i = 0; i < v.textTracks.length; i++) {
        if (v.textTracks[i].mode === 'showing') {
          anyShowing = true;
          v.textTracks[i].mode = 'disabled';
        }
      }
      if (!anyShowing && v.textTracks[0]) {
        v.textTracks[0].mode = 'showing';
        showToast('Subtitles ON', 1500);
        return;
      }
      showToast('Subtitles OFF', 1500);
      return;
    }

    // Fallback: look for caption / cc button in player UI
    const btn = document.querySelector('button[aria-label*="caption" i], button[aria-label*="subtitle" i], button[aria-label*="cc" i], .ytp-subtitles-button');
    if (btn) {
      dispatchFullClickSequence(btn);
      showToast('Toggled Subtitles', 1500);
    } else {
      showToast('No subtitles available', 1500);
    }
  }

  /* =========================================================================
   * MODAL & OVERLAY DISMISSAL (BACK KEY HANDLING)
   * ========================================================================= */
  function tryDismissModal() {
    const modal = getActiveModalOrDialog();
    if (!modal) return false;

    // Look for dismiss/close button
    const closeBtn = modal.querySelector('button[aria-label*="close" i], button[aria-label*="dismiss" i], [role="button"][aria-label*="close" i], .close, .btn-close, .modal-close');
    if (closeBtn) {
      dispatchFullClickSequence(closeBtn);
      return true;
    }

    // Press Escape to dismiss native dialogs
    modal.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', code: 'Escape', bubbles: true }));
    return true;
  }

  function handleBackAction() {
    // 1. Close modal or dialog if one is present
    if (tryDismissModal()) {
      return true;
    }

    // 2. Blur input fields if keyboard is open
    const active = document.activeElement;
    if (active && (active.tagName === 'INPUT' || active.tagName === 'TEXTAREA' || active.isContentEditable)) {
      active.blur();
      return true;
    }

    // 3. Exit HTML5 fullscreen
    if (document.fullscreenElement || document.webkitFullscreenElement) {
      if (document.exitFullscreen) document.exitFullscreen().catch(function () {});
      else if (document.webkitExitFullscreen) document.webkitExitFullscreen();
      return true;
    }

    return false; // Hand over to Flutter to handle history back or selector return
  }

  /* =========================================================================
   * CURSOR ACCELERATION & MOVEMENT
   * ========================================================================= */
  function moveCursor(dx, dy, isHolding) {
    const now = Date.now();
    if (!cursorHolding || !isHolding) {
      cursorHolding = isHolding;
      cursorHoldStartTime = now;
    }

    const elapsed = now - cursorHoldStartTime;
    const factor = Math.min(1.0, elapsed / CURSOR_ACCEL_TIME_MS);
    const speed = CURSOR_MIN_SPEED + (CURSOR_MAX_SPEED - CURSOR_MIN_SPEED) * (factor * factor);

    const newX = cursorX + (dx * speed);
    const newY = cursorY + (dy * speed);

    // Scroll page if cursor reaches edge
    if (newX <= 8 && dx < 0) {
      window.scrollBy({ left: -speed * 2, top: 0, behavior: 'auto' });
    } else if (newX >= window.innerWidth - 8 && dx > 0) {
      window.scrollBy({ left: speed * 2, top: 0, behavior: 'auto' });
    }

    if (newY <= 8 && dy < 0) {
      window.scrollBy({ left: 0, top: -speed * 2, behavior: 'auto' });
    } else if (newY >= window.innerHeight - 8 && dy > 0) {
      window.scrollBy({ left: 0, top: speed * 2, behavior: 'auto' });
    }

    updateCursorPosition(newX, newY);
  }

  /* =========================================================================
   * MAIN REMOTE DISPATCH API (window.__bingeTv.key)
   * ========================================================================= */
  function handleRemoteKey(actionName, repeat, isLongPress) {
    const now = Date.now();
    if (now - lastKeyProcessedTime < KEY_THROTTLE_MS && actionName !== 'Select') {
      return;
    }
    lastKeyProcessedTime = now;

    // Check if input element is currently focused and typing
    const active = document.activeElement;
    const isTyping = active && (active.tagName === 'INPUT' || active.tagName === 'TEXTAREA' || active.isContentEditable);

    // 1. Long Press OK: Toggle Cursor Mode
    if (actionName === 'Select' && isLongPress) {
      toggleCursorMode();
      return;
    }

    // 2. Cursor Mode active
    if (cursorMode) {
      if (actionName === 'Up') moveCursor(0, -1, repeat > 0);
      else if (actionName === 'Down') moveCursor(0, 1, repeat > 0);
      else if (actionName === 'Left') moveCursor(-1, 0, repeat > 0);
      else if (actionName === 'Right') moveCursor(1, 0, repeat > 0);
      else if (actionName === 'Select') executeCursorClick();
      else if (actionName === 'Back') {
        if (!handleBackAction()) {
          toggleCursorMode(false); // Back in cursor mode turns off cursor mode first
        }
      } else if (actionName === 'Red') toggleCursorMode();
      return;
    }

    // 3. Normal Spatial Navigation
    switch (actionName) {
      case 'Up':
        if (isTyping) {
          active.blur();
        }
        moveDirection('Up');
        break;

      case 'Down':
        if (isTyping) {
          active.blur();
        }
        moveDirection('Down');
        break;

      case 'Left':
        if (isTyping) {
          // Let caret move naturally in input field
          return;
        }
        // If focused on video, seek back
        if (currentFocusedElement && currentFocusedElement.tagName === 'VIDEO') {
          seekVideo('Left', repeat);
        } else {
          moveDirection('Left');
        }
        break;

      case 'Right':
        if (isTyping) {
          // Let caret move naturally in input field
          return;
        }
        if (currentFocusedElement && currentFocusedElement.tagName === 'VIDEO') {
          seekVideo('Right', repeat);
        } else {
          moveDirection('Right');
        }
        break;

      case 'Select':
        activateCurrentElement();
        break;

      case 'Back':
        handleBackAction();
        break;

      case 'PlayPause':
        toggleVideoPlayback();
        break;

      case 'Rewind':
        seekVideo('Left', repeat);
        break;

      case 'FastForward':
        seekVideo('Right', repeat);
        break;

      case 'ChannelUp':
        scrollContainer('Up');
        break;

      case 'ChannelDown':
        scrollContainer('Down');
        break;

      case 'Info':
        // Reveal player controls and show toast with URL & mode
        dispatchSyntheticMouseEvent('mousemove', window.innerWidth / 2, window.innerHeight / 2);
        showToast(location.hostname + ' [' + (cursorMode ? 'Cursor' : 'Focus') + ']', 3000);
        break;

      case 'Subtitle':
        toggleCaptions();
        break;

      case 'Red':
        toggleCursorMode();
        break;

      case 'Green':
        // Zoom in (decrease page width)
        setPageWidth((window.__bingePageWidth || 1280) - 150);
        break;

      case 'Yellow':
        // Zoom out (increase page width)
        setPageWidth((window.__bingePageWidth || 1280) + 150);
        break;

      case 'Blue':
        window.location.reload();
        break;

      default:
        // Digit keys 0-9
        if (actionName.startsWith('Digit')) {
          const digit = parseInt(actionName.replace('Digit', ''), 10);
          if (!isNaN(digit)) jumpVideoPercent(digit);
        }
        break;
    }
  }

  function toggleCursorMode(targetState) {
    cursorMode = (typeof targetState === 'boolean') ? targetState : !cursorMode;
    ensureOverlayContainer();

    if (cursorMode) {
      cursorX = window.innerWidth / 2;
      cursorY = window.innerHeight / 2;
      updateCursorPosition(cursorX, cursorY);
      if (focusRingElement) focusRingElement.style.display = 'none';
      showToast('Cursor Mode', 1800);
    } else {
      if (cursorPointerElement) cursorPointerElement.style.display = 'none';
      updateFocusRing();
      showToast('Focus Mode', 1800);
    }
  }

  function setPageWidth(width) {
    const clamped = Math.max(960, Math.min(2560, width));
    ensureDesktopViewport(clamped);
    showToast('Page width: ' + clamped + 'px', 1500);
  }

  function pauseMedia() {
    const videos = document.querySelectorAll('video, audio');
    for (let i = 0; i < videos.length; i++) {
      try { videos[i].pause(); } catch (e) {}
    }
  }

  /* =========================================================================
   * EVENT LISTENERS & LIFECYCLE
   * ========================================================================= */
  window.addEventListener('scroll', function () {
    updateFocusRing();
  }, { passive: true });

  window.addEventListener('resize', function () {
    updateFocusRing();
  }, { passive: true });

  // Listen for DOM changes to re-evaluate focus ring & candidate list
  if (window.MutationObserver) {
    const domObserver = new MutationObserver(function () {
      if (currentFocusedElement && !document.contains(currentFocusedElement)) {
        currentFocusedElement = null;
        updateFocusRing();
      }
    });
    domObserver.observe(document.documentElement, { childList: true, subtree: true });
  }

  // SPA Route Change Detection: hook pushState and replaceState
  (function () {
    const origPush = history.pushState;
    history.pushState = function () {
      origPush.apply(this, arguments);
      setTimeout(findInitialFocus, 300);
    };
    const origReplace = history.replaceState;
    history.replaceState = function () {
      origReplace.apply(this, arguments);
      setTimeout(findInitialFocus, 300);
    };
    window.addEventListener('popstate', function () {
      setTimeout(findInitialFocus, 300);
    });
  })();

  // Document ready initialisation
  function onReady() {
    ensureDesktopViewport();
    normalizeDesktopSignals();
    ensureOverlayContainer();
    setTimeout(findInitialFocus, 400);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', onReady);
  } else {
    onReady();
  }

  /* =========================================================================
   * PUBLIC EXPOSURE
   * ========================================================================= */
  window.__bingeTv = {
    initialized: true,
    version: '2.0.0',
    key: handleRemoteKey,
    setCursorMode: toggleCursorMode,
    setPageWidth: setPageWidth,
    pauseMedia: pauseMedia,
    getCurrentFocus: function () { return currentFocusedElement; },
    getCandidatesCount: function () { return getCandidates().length; },
    isCursorMode: function () { return cursorMode; }
  };

})(window, document);
