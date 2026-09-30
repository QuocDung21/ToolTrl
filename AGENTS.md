# AI AGENT INSTRUCTIONS & ARCHITECTURAL SPECIFICATION (AGENTS.md)

This document defines the strict architectural contracts, domain models, system invariants, and coding standards for Autonomous AI Agents (Antigravity, Cursor, Copilot, Claude, GPT) operating on the **NekoTrans** codebase.

---

## 1. PROJECT SPECIFICATION

- **Application Name**: `NekoTrans`
- **Target OS**: `macOS 14.0+ (Sonoma, Sequoia)`
- **Core Frameworks**: `SwiftUI`, `AppKit`, `WebKit`, `NaturalLanguage`, `Vision`, `AVFoundation`, `Compression`, `Carbon`
- **Language & Runtime**: `Swift 5.9+ / Swift 6 Sendable Mode`
- **Architecture Pattern**: `Clean Modular Architecture (MVVM + Service Layer + Centralized Prompt Factory)`

---

## 2. CODEBASE TOPOLOGY & FILE CONTRACTS

```
Sources/NekoTrans/
├── App/
│   ├── AppDelegate.swift            # App lifecycle, NSStatusItem (Menu Bar), HotKeys, Window Controllers.
│   └── NekoTransApp.swift           # SwiftUI Application entry point.
│
├── Core/
│   ├── Models/
│   │   └── KeyShortcut.swift        # Carbon KeyCode & ModifierFlags domain model.
│   ├── Services/
│   │   ├── VocabularyService.swift      # JSON Persistence, domain mutations, AI tagging.
│   │   ├── GitHubSyncService.swift      # GitHub Secret Gist cloud 2-way sync & LZFSE backup engine.
│   │   ├── SpeechService.swift          # Text-To-Speech (AVSpeechSynthesizer) state tracking.
│   │   ├── AudioPlayerService.swift     # Native pronunciation audio player with 0ms prefetch.
│   │   ├── SmartDictionaryService.swift # REST client for Dictionary API (definitions, IPA).
│   │   ├── TranslationService.swift     # Multi-engine translation with LRU TranslationCache.
│   │   ├── TranslationCache.swift       # In-memory LRU translation cache.
│   │   ├── HotKeyManager.swift          # Carbon global keyboard shortcut listener.
│   │   ├── QuickPromptService.swift     # Dynamic prompt template management.
│   │   └── AppSettings.swift            # App configuration defaults and persistence.
│   └── Helpers/
│       ├── AIPromptBuilder.swift        # [SINGLE SOURCE OF TRUTH] Prompt Factory.
│       ├── AIAnalysisParser.swift       # Multiline regex LLM parser -> ParsedAIAnalysis.
│       ├── DataCompression.swift        # Apple LZFSE / ZLIB Compression Engine.
│       └── TextGrabber.swift            # Accessibility text selection extractor.
│
└── Features/
    ├── Translation/          # TranslationHUDView, Header, Dictionary, Sentence, ViewModel, FloatingPanel.
    ├── Notebook/             # VocabularyNotebookView, TableView, Flashcard, QuickLook, WordDetail, Grammar.
    ├── OCR/                  # ScreenOCRService, ScreenSnipController.
    ├── AI/                   # QuickAIAssistantView, AIWebView, TextAnalysisSheet.
    ├── Stats/                # LearningStatsDashboardView, LookupStatsService.
    ├── Settings/             # SettingsView, GitHubSyncSettingsSection, ShortcutRecorder.
    └── Common/               # CommonUIComponents (LiveSpokenTextView, VisualEffectBackground).
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

### RULE 5: STRICT RESTRICTED ZONES & NO-GO DIRECTORIES
- **DO NOT TOUCH / DO NOT INDEX**:
  - `build/`, `.build/`, `DerivedData/`, `*.dmg`, `*.app` (Build artifacts)
  - `Windows/` (Future platform planning directory; do NOT modify or mix with macOS Swift codebase)
  - `Resources/AppIcon.iconset/`, `Resources/*.png` (Binary assets)
  - `.git/`, `.env*`, `*.key`, `*.p12`, `*.pem` (Credentials & VCS internals)

---

## 4. STANDARD BUILD & RUN PIPELINE

Always execute the following shell pipeline after code modifications:

```bash
./Scripts/build_app.sh && (killall NekoTrans 2>/dev/null || killall ToolTrL 2>/dev/null || true) && sleep 1 && open build/NekoTrans.app
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
