// ── Label maps ──────────────────────────────────────────────────────────
const GRADE_LABELS = {
  1: '1st Grade', 2: '2nd Grade', 3: '3rd Grade', 4: '4th Grade',
  5: '5th Grade', 6: '6th Grade', 7: '7th Grade', 8: '8th Grade',
  9: '9th Grade', 10: '10th Grade', 11: '11th Grade', 12: '12th Grade',
  13: 'College Freshman', 14: 'College Sophomore', 15: 'College Junior', 16: 'College Senior'
};

const GRAMMAR_LABELS = {
  1: 'Poor', 2: 'Below Average', 3: 'Average', 4: 'Good', 5: 'Perfect'
};

const COMPLEXITY_LABELS = {
  1: 'Very Simple', 2: 'Simple', 3: 'Moderate', 4: 'Advanced', 5: 'Sophisticated'
};

const SPEED_LABELS = {
  1: 'Very Slow', 2: 'Slow', 3: 'Normal', 4: 'Fast', 5: 'Very Fast'
};

// ── DOM references ──────────────────────────────────────────────────────
const $ = (id) => document.getElementById(id);

const els = {
  apiKey:           $('apiKey'),
  toggleKey:        $('toggleKey'),
  saveKey:          $('saveKey'),
  keyStatus:        $('keyStatus'),
  gradeLevel:       $('gradeLevel'),
  gradeLevelValue:  $('gradeLevelValue'),
  grammarQuality:   $('grammarQuality'),
  grammarQualityValue: $('grammarQualityValue'),
  complexity:       $('complexity'),
  complexityValue:  $('complexityValue'),
  typingSpeed:      $('typingSpeed'),
  typingSpeedValue: $('typingSpeedValue'),
  responseLength:   $('responseLength'),
  customPrompt:     $('customPrompt'),
  detectBtn:        $('detectBtn'),
  generateBtn:      $('generateBtn'),
  statusBar:        $('statusBar'),
  progressFill:     $('progressFill'),
  statusText:       $('statusText'),
  assignmentPreview: $('assignmentPreview'),
  assignmentText:   $('assignmentText'),
  responsePreview:  $('responsePreview'),
  responseText:     $('responseText'),
  typeItBtn:        $('typeItBtn'),
  regenerateBtn:    $('regenerateBtn'),
  copyBtn:          $('copyBtn'),
};

let currentResponse = '';

// ── Initialise ──────────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
  loadSettings();
  wireEvents();
});

function loadSettings() {
  chrome.storage.local.get(
    ['apiKey', 'gradeLevel', 'grammarQuality', 'complexity', 'typingSpeed', 'responseLength', 'customPrompt'],
    (data) => {
      if (data.apiKey) {
        els.apiKey.value = data.apiKey;
        els.keyStatus.textContent = 'Key saved';
      }
      if (data.gradeLevel)     els.gradeLevel.value     = data.gradeLevel;
      if (data.grammarQuality) els.grammarQuality.value  = data.grammarQuality;
      if (data.complexity)     els.complexity.value      = data.complexity;
      if (data.typingSpeed)    els.typingSpeed.value     = data.typingSpeed;
      if (data.responseLength) els.responseLength.value  = data.responseLength;
      if (data.customPrompt)   els.customPrompt.value    = data.customPrompt;
      refreshLabels();
    }
  );
}

function refreshLabels() {
  els.gradeLevelValue.textContent     = GRADE_LABELS[els.gradeLevel.value]     || els.gradeLevel.value;
  els.grammarQualityValue.textContent = GRAMMAR_LABELS[els.grammarQuality.value] || els.grammarQuality.value;
  els.complexityValue.textContent     = COMPLEXITY_LABELS[els.complexity.value] || els.complexity.value;
  els.typingSpeedValue.textContent    = SPEED_LABELS[els.typingSpeed.value]    || els.typingSpeed.value;
}

// ── Events ──────────────────────────────────────────────────────────────
function wireEvents() {
  // Sliders
  els.gradeLevel.addEventListener('input', () => { refreshLabels(); saveAllSettings(); });
  els.grammarQuality.addEventListener('input', () => { refreshLabels(); saveAllSettings(); });
  els.complexity.addEventListener('input', () => { refreshLabels(); saveAllSettings(); });
  els.typingSpeed.addEventListener('input', () => { refreshLabels(); saveAllSettings(); });
  els.responseLength.addEventListener('change', saveAllSettings);
  els.customPrompt.addEventListener('input', saveAllSettings);

  // API key
  els.toggleKey.addEventListener('click', () => {
    els.apiKey.type = els.apiKey.type === 'password' ? 'text' : 'password';
  });
  els.saveKey.addEventListener('click', () => {
    chrome.storage.local.set({ apiKey: els.apiKey.value.trim() }, () => {
      els.keyStatus.textContent = 'Key saved';
      setTimeout(() => { els.keyStatus.textContent = ''; }, 2000);
    });
  });

  // Detect assignment
  els.detectBtn.addEventListener('click', detectAssignment);

  // Generate & type
  els.generateBtn.addEventListener('click', generateAndType);

  // Preview actions
  els.typeItBtn.addEventListener('click', () => typeOnPage(currentResponse));
  els.regenerateBtn.addEventListener('click', generateAndType);
  els.copyBtn.addEventListener('click', () => {
    navigator.clipboard.writeText(currentResponse);
    els.copyBtn.textContent = 'Copied!';
    setTimeout(() => { els.copyBtn.textContent = 'Copy'; }, 1500);
  });
}

function saveAllSettings() {
  chrome.storage.local.set({
    gradeLevel:     els.gradeLevel.value,
    grammarQuality: els.grammarQuality.value,
    complexity:     els.complexity.value,
    typingSpeed:    els.typingSpeed.value,
    responseLength: els.responseLength.value,
    customPrompt:   els.customPrompt.value,
  });
}

// ── Detect assignment from the active tab ───────────────────────────────
async function detectAssignment() {
  setStatus('Detecting assignment...', 20);
  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    const results = await chrome.scripting.executeScript({
      target: { tabId: tab.id },
      func: scrapeAssignment,
    });
    const text = results?.[0]?.result;
    if (text) {
      els.assignmentText.textContent = text;
      els.assignmentPreview.classList.remove('hidden');
      setStatus('Assignment detected', 100);
    } else {
      setStatus('No assignment text found on this page', 0);
    }
  } catch (err) {
    setStatus('Error: ' + err.message, 0);
  }
}

// Injected into the page to scrape the assignment prompt
function scrapeAssignment() {
  // Google Classroom assignment view selectors
  const selectors = [
    '.MhXXcc',                         // assignment description
    '.tLDEHd',                         // assignment body
    '[data-stream-id] .dDKhVc',        // stream item text
    '.GDKQ1b',                         // question text
    '.pMSaOb',                         // short-answer question
    '.lRwqcd',                         // material description
    '[role="heading"]',                 // heading fallback
    '.asQXV',                          // classwork description
  ];

  for (const sel of selectors) {
    const el = document.querySelector(sel);
    if (el && el.innerText.trim().length > 5) {
      return el.innerText.trim();
    }
  }

  // Fallback: grab the largest text block on the page
  const allText = Array.from(document.querySelectorAll('p, span, div'))
    .map(e => e.innerText.trim())
    .filter(t => t.length > 30)
    .sort((a, b) => b.length - a.length);

  return allText[0] || null;
}

// ── Generate response via OpenAI ────────────────────────────────────────
async function generateAndType() {
  const apiKey = els.apiKey.value.trim();
  if (!apiKey) {
    setStatus('Please enter your OpenAI API key first', 0);
    return;
  }

  const assignmentText = els.assignmentText.textContent.trim();
  if (!assignmentText) {
    setStatus('Detect an assignment first', 0);
    return;
  }

  setStatus('Generating response...', 30);
  els.generateBtn.disabled = true;

  const prompt = buildPrompt(assignmentText);

  try {
    const res = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: prompt.system },
          { role: 'user',   content: prompt.user },
        ],
        temperature: 0.85,
        max_tokens: getMaxTokens(),
      }),
    });

    if (!res.ok) {
      const errBody = await res.json().catch(() => ({}));
      throw new Error(errBody.error?.message || `API error ${res.status}`);
    }

    const data = await res.json();
    currentResponse = data.choices[0].message.content.trim();

    els.responseText.textContent = currentResponse;
    els.responsePreview.classList.remove('hidden');
    setStatus('Response ready — review then click "Type It Out"', 100);
  } catch (err) {
    setStatus('Error: ' + err.message, 0);
  } finally {
    els.generateBtn.disabled = false;
  }
}

function getMaxTokens() {
  const map = { short: 150, medium: 500, long: 1200, essay: 2500 };
  return map[els.responseLength.value] || 500;
}

function buildPrompt(assignment) {
  const grade       = parseInt(els.gradeLevel.value, 10);
  const grammar     = parseInt(els.grammarQuality.value, 10);
  const complexity  = parseInt(els.complexity.value, 10);
  const length      = els.responseLength.value;
  const custom      = els.customPrompt.value.trim();

  const gradeDesc   = GRADE_LABELS[grade];
  const grammarDesc = GRAMMAR_LABELS[grammar];
  const compDesc    = COMPLEXITY_LABELS[complexity];

  const grammarInstructions = buildGrammarInstructions(grammar);
  const complexityInstructions = buildComplexityInstructions(complexity);
  const lengthInstructions = buildLengthInstructions(length);

  const system = `You are a student at the ${gradeDesc} level writing an assignment response.

CRITICAL RULES — follow these exactly:
1. Write as a real ${gradeDesc} student would. Match their typical knowledge, vocabulary, and writing maturity.
2. Grammar quality: ${grammarDesc}. ${grammarInstructions}
3. Vocabulary / complexity: ${compDesc}. ${complexityInstructions}
4. Length: ${lengthInstructions}
5. Do NOT use overly formal or academic phrasing that would be unusual for this grade level.
6. Do NOT include any meta-commentary, disclaimers, or mentions that you are an AI.
7. Write naturally as if you are turning in homework — conversational tone appropriate to grade level.
8. Vary sentence length and structure to sound human.
${custom ? `9. Additional instructions: ${custom}` : ''}`;

  const user = `Here is the assignment prompt:\n\n${assignment}\n\nWrite a response as described in your instructions.`;

  return { system, user };
}

function buildGrammarInstructions(level) {
  switch (level) {
    case 1: return 'Make frequent grammar errors: run-on sentences, missing commas, their/there/they\'re mix-ups, sentence fragments, inconsistent tense. Misspell a few common words.';
    case 2: return 'Make occasional grammar mistakes: a few comma splices, minor subject-verb disagreements, one or two misspellings. Not polished but mostly readable.';
    case 3: return 'Use generally correct grammar with a few minor imperfections — maybe one run-on sentence or a slightly awkward phrase. Typical average student.';
    case 4: return 'Use good grammar with only very rare, subtle errors. Well-structured sentences. Shows effort but not flawless.';
    case 5: return 'Use perfect grammar, punctuation, and spelling throughout. Clean, well-crafted prose.';
    default: return '';
  }
}

function buildComplexityInstructions(level) {
  switch (level) {
    case 1: return 'Use only very basic, everyday words. Short sentences. Simple ideas. No jargon or SAT words.';
    case 2: return 'Use simple vocabulary with occasional slightly harder words. Straightforward sentence structures.';
    case 3: return 'Use a moderate vocabulary appropriate for the grade level. Mix of simple and slightly complex sentences.';
    case 4: return 'Use advanced vocabulary when fitting. Include compound-complex sentences. Show deeper analysis.';
    case 5: return 'Use sophisticated, precise vocabulary. Employ nuanced arguments, varied rhetorical strategies, and complex sentence structures.';
    default: return '';
  }
}

function buildLengthInstructions(length) {
  switch (length) {
    case 'short':  return 'Write 1-2 sentences. Very brief.';
    case 'medium': return 'Write 1-2 paragraphs (roughly 80-150 words).';
    case 'long':   return 'Write 3-5 paragraphs (roughly 250-500 words).';
    case 'essay':  return 'Write a full essay of 5+ paragraphs (500+ words) with an intro, body paragraphs, and conclusion.';
    default:       return 'Write 1-2 paragraphs.';
  }
}

// ── Type the response on the page with human-like speed ─────────────────
async function typeOnPage(text) {
  if (!text) return;

  setStatus('Typing response on page...', 40);
  const speed = parseInt(els.typingSpeed.value, 10);

  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    await chrome.tabs.sendMessage(tab.id, {
      action: 'typeText',
      text,
      speed,
    });
    setStatus('Done typing!', 100);
  } catch (err) {
    setStatus('Error: ' + err.message + ' — make sure you\'re on a Classroom page', 0);
  }
}

// ── Status helpers ──────────────────────────────────────────────────────
function setStatus(message, percent) {
  els.statusBar.classList.remove('hidden');
  els.statusText.textContent = message;
  els.progressFill.style.width = percent + '%';
}
