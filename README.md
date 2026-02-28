# Classroom Auto-Completer — Chrome Extension

A Chrome extension that generates assignment responses for Google Classroom with adjustable grade level, grammar quality, complexity, and human-like typing simulation.

## Features

- **Grade Level Slider** (1-16): Elementary through College Senior — controls writing maturity and knowledge level
- **Grammar Quality** (1-5): From frequent errors to perfect prose
- **Vocabulary / Complexity** (1-5): From very simple to sophisticated
- **Typing Speed** (1-5): Human-like typing with realistic pauses, speed bursts, and typo corrections
- **Response Length**: Short / Medium / Long / Essay
- **Custom Instructions**: Add any extra context or requirements
- **Assignment Detection**: Auto-scrapes the assignment prompt from Google Classroom
- **Preview & Edit**: Review generated text before typing it out

## Setup

1. **Get an OpenAI API key** from [platform.openai.com](https://platform.openai.com/api-keys)
2. **Load the extension in Chrome**:
   - Open `chrome://extensions/`
   - Enable **Developer mode** (top-right toggle)
   - Click **Load unpacked**
   - Select this project folder
3. **Pin the extension** to your toolbar for easy access

## Usage

1. Navigate to a Google Classroom assignment page
2. Click the extension icon in your toolbar
3. Paste your OpenAI API key and click **Save Key** (stored locally, only needs to be done once)
4. Adjust the sliders for grade level, grammar, complexity, and typing speed
5. Click **Detect Assignment** to auto-read the assignment prompt
6. Click **Generate & Type** to create a response
7. Review the response, then click **Type It Out** to simulate typing it into the page

## File Structure

```
├── manifest.json            # Extension manifest (Manifest V3)
├── popup/
│   ├── popup.html           # Settings UI
│   ├── popup.css            # Styles
│   └── popup.js             # Settings logic + OpenAI integration
├── content/
│   ├── content.js           # DOM interaction + human-like typing engine
│   └── content.css          # Active indicator styles
├── background/
│   └── background.js        # Service worker for lifecycle events
└── icons/
    ├── icon16.png
    ├── icon48.png
    └── icon128.png
```

## How Typing Simulation Works

The extension simulates realistic human typing with:

- **Variable per-character delay** based on speed profile
- **Longer pauses** after punctuation (periods, commas, newlines)
- **Random thinking pauses** (simulates reading/distraction)
- **Speed bursts** (muscle memory on common words)
- **Typo simulation** with immediate backspace correction using QWERTY neighbor keys

## Privacy

- Your API key is stored locally in Chrome's extension storage — never transmitted anywhere except directly to OpenAI
- No data is collected, tracked, or sent to any third-party servers
- All processing happens locally in your browser + direct OpenAI API calls
