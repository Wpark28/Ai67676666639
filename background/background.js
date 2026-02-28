// ── Background service worker ───────────────────────────────────────────
// Handles extension lifecycle events and cross-context communication.

chrome.runtime.onInstalled.addListener((details) => {
  if (details.reason === 'install') {
    // Set default settings on first install
    chrome.storage.local.set({
      gradeLevel: '10',
      grammarQuality: '3',
      complexity: '3',
      typingSpeed: '3',
      responseLength: 'medium',
      customPrompt: '',
    });
  }
});

// Relay messages between popup and content scripts when needed
chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg.action === 'getActiveTab') {
    chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
      sendResponse({ tab: tabs[0] || null });
    });
    return true;
  }
});
