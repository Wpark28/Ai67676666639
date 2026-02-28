// ── Content script: injected into Google Classroom & Docs pages ─────────

(() => {
  'use strict';

  // ── Typing speed profiles (delay in ms per character) ─────────────────
  // Each profile defines a base range plus variation parameters
  const SPEED_PROFILES = {
    1: { base: [180, 350], pauseChance: 0.12, pauseRange: [500, 2000], typoChance: 0.04 }, // hunt & peck
    2: { base: [120, 250], pauseChance: 0.08, pauseRange: [400, 1200], typoChance: 0.025 },
    3: { base: [60, 150],  pauseChance: 0.05, pauseRange: [300, 900],  typoChance: 0.015 },  // normal
    4: { base: [35, 90],   pauseChance: 0.03, pauseRange: [200, 600],  typoChance: 0.008 },
    5: { base: [20, 60],   pauseChance: 0.02, pauseRange: [150, 400],  typoChance: 0.005 },  // fast
  };

  // ── Listen for messages from the popup ────────────────────────────────
  chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
    if (msg.action === 'typeText') {
      handleTypeText(msg.text, msg.speed)
        .then(() => sendResponse({ success: true }))
        .catch(err => sendResponse({ success: false, error: err.message }));
      return true; // keep the message channel open for async
    }

    if (msg.action === 'scrapeAssignment') {
      sendResponse({ text: scrapeAssignment() });
    }
  });

  // ── Find the active text input on the page ────────────────────────────
  function findTargetElement() {
    // 1. Google Classroom text-box (contenteditable div in assignment turn-in)
    const classroomEditable = document.querySelector(
      '.nnSXVc [contenteditable="true"], ' +   // assignment text box
      '.uyYuVb [contenteditable="true"], ' +    // short-answer
      '.MhXXcc [contenteditable="true"], ' +    // another variant
      '.lRwqcd [contenteditable="true"], ' +    // material comment
      '.dDKhVc [contenteditable="true"]'        // stream comment
    );
    if (classroomEditable) return { el: classroomEditable, type: 'contenteditable' };

    // 2. Google Docs canvas (uses a special input approach)
    const docsEditable = document.querySelector('.kix-appview-editor [contenteditable="true"]');
    if (docsEditable) return { el: docsEditable, type: 'contenteditable' };

    // 3. Generic contenteditable
    const genericEditable = document.querySelector('[contenteditable="true"]');
    if (genericEditable) return { el: genericEditable, type: 'contenteditable' };

    // 4. Textarea or input
    const textarea = document.querySelector('textarea:not([readonly]), input[type="text"]:not([readonly])');
    if (textarea) return { el: textarea, type: 'input' };

    // 5. Currently focused element
    const active = document.activeElement;
    if (active && (active.isContentEditable || active.tagName === 'TEXTAREA' || active.tagName === 'INPUT')) {
      return { el: active, type: active.isContentEditable ? 'contenteditable' : 'input' };
    }

    return null;
  }

  // ── Human-like typing engine ──────────────────────────────────────────
  async function handleTypeText(text, speedLevel) {
    const target = findTargetElement();
    if (!target) throw new Error('No text input found on this page. Click into a text field first.');

    const profile = SPEED_PROFILES[speedLevel] || SPEED_PROFILES[3];
    target.el.focus();

    // Small initial pause — like a human placing their hands
    await sleep(rand(300, 800));

    for (let i = 0; i < text.length; i++) {
      const char = text[i];

      // Simulate occasional typo then correction
      if (profile.typoChance && Math.random() < profile.typoChance && char.match(/[a-zA-Z]/)) {
        const typo = nearbyKey(char);
        await typeChar(target, typo);
        await sleep(rand(100, 300));
        await deleteChar(target);
        await sleep(rand(80, 200));
      }

      await typeChar(target, char);

      // Base delay with variance
      let delay = rand(profile.base[0], profile.base[1]);

      // Extra delay after punctuation (thinking pause)
      if ('.!?'.includes(char))          delay += rand(200, 600);
      else if (',;:'.includes(char))     delay += rand(80, 250);
      else if (char === '\n')            delay += rand(300, 800);

      // Occasional longer pause (thinking, reading, distraction)
      if (Math.random() < profile.pauseChance) {
        delay += rand(profile.pauseRange[0], profile.pauseRange[1]);
      }

      // Speed burst: sometimes type several chars faster (muscle memory on common words)
      if (Math.random() < 0.1) {
        delay = Math.max(delay * 0.4, 15);
      }

      await sleep(delay);
    }
  }

  // ── Type a single character ───────────────────────────────────────────
  async function typeChar(target, char) {
    if (target.type === 'contenteditable') {
      // Dispatch realistic key events
      dispatchKeyEvents(target.el, char);
      // Insert the character via execCommand for undo support and Classroom compatibility
      document.execCommand('insertText', false, char);
    } else {
      // Standard input/textarea
      const el = target.el;
      const start = el.selectionStart;
      const end = el.selectionEnd;
      const before = el.value.substring(0, start);
      const after = el.value.substring(end);
      el.value = before + char + after;
      el.selectionStart = el.selectionEnd = start + 1;
      dispatchKeyEvents(el, char);
      el.dispatchEvent(new Event('input', { bubbles: true }));
    }
  }

  // ── Delete a character (for typo correction) ──────────────────────────
  async function deleteChar(target) {
    if (target.type === 'contenteditable') {
      dispatchKeyEvents(target.el, 'Backspace', 8);
      document.execCommand('delete', false, null);
    } else {
      const el = target.el;
      const pos = el.selectionStart;
      if (pos > 0) {
        el.value = el.value.substring(0, pos - 1) + el.value.substring(pos);
        el.selectionStart = el.selectionEnd = pos - 1;
        el.dispatchEvent(new Event('input', { bubbles: true }));
      }
    }
  }

  // ── Dispatch keydown/keypress/keyup for realism ───────────────────────
  function dispatchKeyEvents(el, char, keyCode) {
    const code = keyCode || char.charCodeAt(0);
    const opts = { key: char, code: `Key${char.toUpperCase()}`, keyCode: code, which: code, bubbles: true };
    el.dispatchEvent(new KeyboardEvent('keydown',  opts));
    el.dispatchEvent(new KeyboardEvent('keypress', opts));
    el.dispatchEvent(new KeyboardEvent('keyup',    opts));
  }

  // ── Nearby-key typo simulation (QWERTY layout) ───────────────────────
  const QWERTY_NEIGHBORS = {
    a: 'sqwz', b: 'vghn', c: 'xdfv', d: 'sfcer', e: 'wrsdf', f: 'dgcvrt',
    g: 'fhtbvy', h: 'gjynbu', i: 'uojkl', j: 'hkunmi', k: 'jlomi', l: 'kop',
    m: 'njk', n: 'bhjm', o: 'iklp', p: 'ol', q: 'wa', r: 'edft',
    s: 'adwxze', t: 'rfgy', u: 'yihj', v: 'cfgb', w: 'qase', x: 'zsdc',
    y: 'tghu', z: 'asx',
  };

  function nearbyKey(char) {
    const lower = char.toLowerCase();
    const neighbors = QWERTY_NEIGHBORS[lower];
    if (!neighbors) return char;
    const typo = neighbors[Math.floor(Math.random() * neighbors.length)];
    return char === char.toUpperCase() ? typo.toUpperCase() : typo;
  }

  // ── Assignment scraping (also usable from content script context) ─────
  function scrapeAssignment() {
    const selectors = [
      '.MhXXcc', '.tLDEHd', '[data-stream-id] .dDKhVc',
      '.GDKQ1b', '.pMSaOb', '.lRwqcd', '[role="heading"]', '.asQXV',
    ];
    for (const sel of selectors) {
      const el = document.querySelector(sel);
      if (el && el.innerText.trim().length > 5) return el.innerText.trim();
    }
    const allText = Array.from(document.querySelectorAll('p, span, div'))
      .map(e => e.innerText.trim())
      .filter(t => t.length > 30)
      .sort((a, b) => b.length - a.length);
    return allText[0] || null;
  }

  // ── Utilities ─────────────────────────────────────────────────────────
  function rand(min, max) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
  }

  function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  // ── Floating indicator ────────────────────────────────────────────────
  // Shows a small indicator on the page when the extension is active
  function injectIndicator() {
    if (document.getElementById('cc-indicator')) return;
    const dot = document.createElement('div');
    dot.id = 'cc-indicator';
    dot.title = 'Classroom Completer is active';
    document.body.appendChild(dot);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', injectIndicator);
  } else {
    injectIndicator();
  }
})();
