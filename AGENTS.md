# AI AGENT INSTRUCTIONS & ARCHITECTURAL SPECIFICATION (AGENTS.md)

This document defines the strict architectural contracts, domain models, system invariants, and coding standards for Autonomous AI Agents (Antigravity, Cursor, Copilot, Claude, GPT) operating on the **NekoTrans** codebase.

---

## 1. PROJECT SPECIFICATION

- **Application Name**: `NekoTrans`
- **Target OS**: `macOS 15.0+ (Sequoia)` — the Apple `Translation` framework used by the offline engine is unavailable before macOS 15.
- **Core Frameworks**: `SwiftUI`, `AppKit`, `WebKit`, `NaturalLanguage`, `Translation`, `Vision`, `AVFoundation`, `Compression`, `Carbon`, `Security`
- **Language & Runtime**: `Swift 6 toolchain (swift-tools-version 6.0)` compiling in **Swift 5 language mode** (`.swiftLanguageMode(.v5)` on every target). Enabling Swift 6 language mode / strict concurrency is a pending migration, not the current state.
- **Architecture Pattern**: `Clean Modular Architecture (MVVM + Service Layer + Centralized Prompt Factory)`
- **Toolchain requirement**: building requires a full **Xcode** install. SwiftUI's `@State` / `#Preview` macros are expanded by plugins that ship only with Xcode; with `/Library/Developer/CommandLineTools` selected, every SwiftUI file fails with `external macro implementation type 'SwiftUIMacros.StateMacro' could not be found`. `Scripts/toolchain.sh` auto-selects an installed Xcode (or fails with an actionable message) and is sourced by `Scripts/build_app.sh` and `make test`.

---

## 2. CODEBASE TOPOLOGY & FILE CONTRACTS

```
Sources/NekoTrans/
├── App/
│   └── AppDelegate.swift            # App lifecycle, NSStatusItem (Menu Bar), HotKeys, Window Controllers.
│                                    # The SwiftUI entry point lives in Sources/NekoTransLauncher.
│
├── Core/
│   ├── KeyStore/
│   │   ├── Key.swift                # [SINGLE SOURCE OF TRUTH] UserDefaults keys + Keychain secret accounts.
│   │   └── KeychainStore.swift      # macOS Keychain wrapper for every app secret.
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
│       ├── AppLog.swift                 # os.Logger categories; use instead of `print`.
│       ├── DataCompression.swift        # Apple LZFSE / ZLIB Compression Engine.
│       └── TextGrabber.swift            # Accessibility text selection extractor.
│
└── Features/
    ├── MainWorkspace/        # MainWorkspaceView, translation/deep-AI/flashcard studios, history sheet.
    ├── Translation/          # TranslationHUDView, Header, Dictionary, Sentence, ViewModel, FloatingPanel.
    ├── Notebook/             # VocabularyNotebookView, TableView, Flashcard, QuickLook, WordDetail, Grammar.
    ├── OCR/                  # ScreenOCRService, ScreenSnipController.
    ├── AI/                   # QuickAIAssistantView, AIWebView, TextAnalysisSheet.
    ├── ContinuityHomework/   # iPad Continuity studio, Bonjour server, floating homework bubble.
    ├── Stats/                # LearningStatsDashboardView, LookupStatsService.
    ├── Settings/             # SettingsView, GitHubSyncSettingsSection, ShortcutRecorder.
    ├── Widget/               # WidgetEntryView.
    └── Common/               # CommonUIComponents, Components/* (NekoBadge, NekoCard, ...).
```

Additional targets in `Package.swift`: `NekoTrans` (launcher, `Sources/NekoTransLauncher`), `NekoTransiPad` (`Sources/NekoTransiPad`, all UIKit code guarded by `#if canImport(UIKit)`), `NekoTransTests` (`Tests/NekoTransTests`).

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

### RULE 2: CENTRALIZED PROMPT FACTORY (`Core/Helpers/AIPromptBuilder.swift`)
- **NEVER** write inline raw prompt strings inside SwiftUI Views or Controller classes.
- All prompts must be static methods in `AIPromptBuilder`:
  - `AIPromptBuilder.structuredWordPrompt(for:)`
  - `AIPromptBuilder.grammarFormulaPrompt(for:context:)`
  - `AIPromptBuilder.wordGrammarPatternsPrompt(for:context:)`
  - `AIPromptBuilder.strictEnforcedGrammarPrompt(title:context:customNote:)`

### RULE 3: MULTILINE STREAM PARSING (`Core/Helpers/AIAnalysisParser.swift`)
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
- Grammar vs. vocabulary rendering lives in `Features/Notebook/GrammarDetailView.swift` and `Features/Notebook/VocabularyNotebookView.swift`.

### RULE 5: SECRETS NEVER TOUCH `UserDefaults`
- Every credential (LLM/translation API keys, GitHub PAT) **MUST** be persisted through `KeychainStore` and its account name **MUST** be declared in `KeyStore.Secret`.
- **NEVER** call `UserDefaults.standard.set(...)` with a secret, and never add a new raw secret key string outside `KeyStore.Secret`.
- Legacy installs are migrated once by `KeychainStore.migrateFromUserDefaults`; the `UserDefaults` copy is only removed after a successful Keychain write.

### RULE 6: STRICT RESTRICTED ZONES & NO-GO DIRECTORIES
- **DO NOT TOUCH / DO NOT INDEX**:
  - `build/`, `.build/`, `DerivedData/`, `*.dmg`, `*.app` (Build artifacts)
  - `Windows/` (Future platform planning directory; do NOT modify or mix with macOS Swift codebase)
  - `Resources/AppIcon.iconset/`, `Resources/*.png` (Binary assets)
  - `.git/`, `.env*`, `*.key`, `*.p12`, `*.pem` (Credentials & VCS internals)

### RULE 7: NO `print` IN SHIPPING CODE
- Diagnostic output **MUST** go through `AppLog` (`os.Logger`), never `print()`. stdout is discarded when the app is launched from Finder, so `print` messages are invisible exactly when they matter.
- Pick the existing category (`app`, `settings`, `vocabulary`, `spotlight`, `history`, `dictionary`, `translation`, `continuity`, `sync`) or add one to `AppLog`.
- User-supplied content (word titles, translated text) **MUST** stay `.private`; mark only error descriptions and identifiers `.public`.
- Inspect logs with: `log stream --predicate 'subsystem == "com.nekotrans.mac"' --level debug`

---

## 4. STANDARD BUILD & RUN PIPELINE

Always execute the following shell pipeline after code modifications:

```bash
./Scripts/build_app.sh && (killall NekoTrans 2>/dev/null || true) && sleep 1 && open build/NekoTrans.app
```

`Scripts/build_app.sh` sources `Scripts/toolchain.sh` first, so it works even when `xcode-select` points at Command Line Tools. `make build`, `make run` and `make test` go through the same guard. The script writes `LSMinimumSystemVersion` = `15.0` to match the package platform.

---

## 5. EXTENSION RECIPES FOR AI AGENTS

### Recipe A: Adding a New AI Analysis Section
1. **Update Model**: Add field `public var myField: [String] = []` to `ParsedAIAnalysis` in `Core/Helpers/AIAnalysisParser.swift`.
2. **Update Parser**: Add header keyword detection in `AIAnalysisParser.parse()` and append to `result.myField`.
3. **Update Prompt**: Add corresponding markdown section header in `Core/Helpers/AIPromptBuilder.swift`.
4. **Update UI**: Render a new `GroupBox` inside `Features/Notebook/GrammarDetailView.swift` or `Features/Notebook/VocabularyNotebookView.swift`.

### Recipe B: Adding a New AI Provider to WebView
1. **Enum Addition**: Add case in `enum AIProvider: String, CaseIterable, Identifiable` in `Features/AI/QuickAIAssistantView.swift`.
2. **Input Selector**: Add DOM selector & input handler in `Features/AI/AIWebView.swift` inside the JavaScript injection loop.
