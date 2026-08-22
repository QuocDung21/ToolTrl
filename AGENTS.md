# AI AGENT INSTRUCTIONS & ARCHITECTURAL SPECIFICATION (AGENTS.md)

This document defines the strict architectural contracts, domain models, system invariants, and coding standards for Autonomous AI Agents (Antigravity, Cursor, Copilot, Claude, GPT) operating on the **ToolTrL** codebase.

---

## 1. PROJECT SPECIFICATION

- **Application Name**: `ToolTrL`
- **Target OS**: `macOS 13.0+ (Ventura, Sonoma, Sequoia)`
- **Core Frameworks**: `SwiftUI`, `AppKit`, `WebKit`, `NaturalLanguage`, `Vision`, `AVFoundation`, `Carbon`
- **Language & Runtime**: `Swift 5.9+ / Swift 6 Sendable Mode`
- **Architecture Pattern**: `Clean Modular Architecture (MVVM + Service Layer + Centralized Prompt Factory)`

---

## 2. CODEBASE TOPOLOGY & FILE CONTRACTS

```
Sources/ToolTrL/
├── App/
│   ├── AppDelegate.swift            # App lifecycle, NSStatusItem (Menu Bar), Global Event Monitor / HotKeys, Window Controllers.
│   └── ToolTrLApp.swift             # SwiftUI Application entry point.
│
├── Core/
│   ├── AIPromptBuilder.swift        # [SINGLE SOURCE OF TRUTH] All LLM Prompt Templates & Schema Enforcement strings.
│   ├── AIAnalysisParser.swift       # Multiline regex-based LLM Text Parser -> ParsedAIAnalysis struct.
│   ├── VocabularyService.swift      # Persistence Engine (JSON), domain mutations, AI classification (Priority, Genre, POS).
│   ├── SmartDictionaryService.swift # Async REST client for Free Dictionary API (definitions, phonetics, audio URLs).
│   ├── SpeechService.swift          # Text-To-Speech (AVSpeechSynthesizer) with dynamic speakerID state tracking.
│   ├── TranslationService.swift     # Google Translate / MyMemory API client with LRU TranslationCache.
│   ├── HotKeyManager.swift          # Carbon RegisterEventHotKey global keyboard shortcut listener.
│   ├── ScreenOCRService.swift       # Vision framework VNRecognizeTextRequest screen capture OCR.
│   ├── TextAnalysisService.swift    # NaturalLanguage NLTokenizer sentence and token breakdown.
│   └── QuickPromptService.swift     # User customizable dynamic quick prompt template management.
│
└── UI/
    ├── VocabularyNotebookView.swift # 3-Pane NavigationSplitView & Table mode notebook, search, filter, QuickLook spacebar.
    ├── GrammarDetailView.swift      # [MODULAR COMPONENT] Standalone 5-section Grammar Document view.
    ├── AddGrammarSheet.swift        # [MODULAR COMPONENT] Modal sheet to input grammar rule and auto-trigger AI Prompt Enforcement.
    ├── QuickAIAssistantView.swift   # Multi-provider Floating AI Assistant (ChatGPT, Gemini, Claude, Perplexity).
    ├── AIWebView.swift              # WKWebView with SPA polling retry loop and synthetic DOM event prompt injection.
    ├── TranslationHUDView.swift     # Global floating HUD panel showing instant translation.
    ├── SmartTextAnalysisSheet.swift # Paragraph extraction & vocabulary breakdown modal.
    └── FlashcardStudyView...        # 3D interactive flip-card study mode.
```

---

## 3. DOMAIN INVARIANTS & STRICT RULES

### RULE 1: STRICT DOMAIN SEPARATION (Grammar vs. Vocabulary)
```swift
// SavedWordItem.isGrammarFormula determines rendering pipeline:
if item.isGrammarFormula {
    // 1. MUST render GrammarDetailView(item: item)
    // 2. MUST NEVER render dictionary tabs or offline API meanings
    // 3. Formula MUST be stored in `item.phonetic` and rendered in monospaced font
} else {
    // 1. MUST render 2-tab layout: [ 📖 Từ điển & Ghi chú ] and [ ✨ Phân tích AI ]
    // 2. MUST NOT display grammar generator callouts inside the dictionary tab
}
```

### RULE 2: CENTRALIZED PROMPT FACTORY (`AIPromptBuilder.swift`)
- **NEVER** write inline raw prompt strings inside SwiftUI Views or Controller classes.
- All prompts must be static methods in `AIPromptBuilder`:
  - `AIPromptBuilder.structuredWordPrompt(for:)`
  - `AIPromptBuilder.grammarFormulaPrompt(for:context:)`
  - `AIPromptBuilder.wordGrammarPatternsPrompt(for:context:)`
  - `AIPromptBuilder.strictEnforcedGrammarPrompt(title:context:customNote:)`

### RULE 3: MULTILINE STREAM PARSING (`AIAnalysisParser.swift`)
- LLM outputs must be parsed through `AIAnalysisParser.parse(rawText)`.
- When extending new sections (e.g. `quizzes`, `idioms`), add the property to `ParsedAIAnalysis` and handle its header detection in `AIAnalysisParser.swift`.
- Formula parsing (`case 7`) must accumulate **all lines** into a multiline formula string until the next header is reached.

### RULE 4: NATIVE macOS HUMAN INTERFACE GUIDELINES (HIG)
- Window styling: Translucent backgrounds via `VisualEffectBackground(material: .sidebar / .hudWindow)`.
- Layout: Use native `GroupBox`, `NavigationSplitView`, `Picker(style: .segmented)`.
- Typography:
  - Formulas: `.font(.system(size: 13.5, weight: .bold, design: .monospaced))` with blue tint.
  - Examples: `.font(.system(size: 13, design: .serif)).italic()`.
  - Badges & Tags: 10pt bold uppercase in subtle colored rounded pills.

---

## 4. STANDARD BUILD & RUN PIPELINE

Always execute the following shell pipeline after code modifications:

```bash
./Scripts/build_app.sh && killall ToolTrL 2>/dev/null || true && sleep 1 && open build/ToolTrL.app
```

---

## 5. EXTENSION RECIPES FOR AI AGENTS

### Recipe A: Adding a New AI Analysis Section
1. **Update Model**: Add field `public var myField: [String] = []` to `ParsedAIAnalysis` in `Core/AIAnalysisParser.swift`.
2. **Update Parser**: Add header keyword detection in `AIAnalysisParser.parse()` and append to `result.myField`.
3. **Update Prompt**: Add corresponding markdown section header in `Core/AIPromptBuilder.swift`.
4. **Update UI**: Render a new `GroupBox` inside `UI/GrammarDetailView.swift` or `UI/VocabularyNotebookView.swift`.

### Recipe B: Adding a New AI Provider to WebView
1. **Enum Addition**: Add case in `enum AIProvider: String, CaseIterable, Identifiable` in `UI/QuickAIAssistantView.swift`.
2. **Input Selector**: Add DOM selector & input handler in `AIWebView.swift` inside the JavaScript injection loop.
