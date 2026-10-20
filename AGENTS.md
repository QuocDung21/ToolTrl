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
Packages/NekoKit/
├── Package.swift                    # Apple-style Multi-Target Local Swift Package
└── Sources/
    ├── NekoCore/                    # Layer 1: Models, Key, KeychainStore, SafeURL, AppLog, Parsers
    │   ├── Models/
    │   │   ├── AppConfigurationModels.swift # TranslationEngine, TranslationDomain, WordLookupMode, AppLanguage...
    │   │   └── VocabularyModels.swift       # SavedWordItem, VocabularyItemType, ItemThematicGenre, ItemAIPriority.
    │   └── Utilities/
    │       ├── AIPromptBuilder.swift        # [SINGLE SOURCE OF TRUTH] Prompt Factory.
    │       ├── AIAnalysisParser.swift       # Multiline regex LLM parser -> ParsedAIAnalysis.
    │       ├── AppLog.swift                 # os.Logger categories; use instead of `print`.
    │       ├── BrowserScriptHelper.swift    # AppleScript browser text grabber/injector.
    │       ├── DataCompression.swift        # Apple LZFSE / ZLIB Compression Engine.
    │       ├── HTMLEntityDecoder.swift      # HTML entity decoding utility.
    │       ├── IPANormalizer.swift          # Broad Oxford/Cambridge IPA normalizer.
    │       ├── InputTextNormalizer.swift    # camelCase/snake_case splitter & POS normalizer.
    │       ├── Key.swift                    # [SINGLE SOURCE OF TRUTH] Defaults.Keys + KeyStore.Secret accounts.
    │       ├── KeychainStore.swift          # macOS Keychain wrapper for every app secret.
    │       ├── SafeURL.swift                # URL builder; NEVER interpolate into URL(string:).
    │       ├── TextGrabber.swift            # Accessibility text selection extractor.
    │       └── WordClassifierService.swift  # NaturalLanguage POS & thematic classification.
    │
    ├── NekoServices/                # Layer 2: Domain, Networking, AI, Dictionary, Persistence Services
    │   ├── AnkiConnectService.swift
    │   ├── AppExclusionService.swift
    │   ├── AudioPlayerService.swift
    │   ├── ContinuousJournalService.swift
    │   ├── DictionaryService.swift
    │   ├── DirectAIService.swift
    │   ├── FeatureFlagService.swift
    │   ├── GitHubSyncService.swift
    │   ├── LookupStatsService.swift
    │   ├── QuickPromptService.swift
    │   ├── ScreenOCRService.swift
    │   ├── SmartDictionaryService.swift
    │   ├── SoundService.swift
    │   ├── SpeechService.swift
    │   ├── SpotlightService.swift
    │   ├── TextAnalysisService.swift
    │   ├── TranslationCache.swift
    │   ├── TranslationHistoryService.swift
    │   ├── TranslationProvider.swift
    │   ├── TranslationService.swift
    │   └── VocabularyService.swift
    │
    └── NekoUI/                      # Layer 3: Design System & Reusable SwiftUI Components
        ├── AppDesignSystem.swift    # Design tokens, colors, typography, and card modifiers.
        ├── CommonUIComponents.swift # Shared visual effects and reusable UI elements.
        └── Neko*.swift              # NekoBadge, NekoCard, NekoAudioButton, NekoCopyButton, NekoSearchBar...

Sources/NekoTrans/                   # Layer 4: macOS App Shell, Windows, Views, String Catalog
├── App/
│   ├── NekoTransApp.swift           # @main SwiftUI application entry point.
│   ├── AppDelegate.swift            # App lifecycle, HotKeys, Background monitors, System Menu.
│   ├── AppSettings.swift            # App configuration defaults and persistence.
│   ├── MenuBarController.swift      # NSStatusItem (Menu Bar) controller.
│   └── ModuleExports.swift          # Re-exports NekoCore, NekoServices, NekoUI across the app target.
│
├── Services/
│   ├── ActionManager.swift          # Global shortcut action dispatcher.
│   ├── AppIconService.swift         # App & Dock icon management.
│   ├── HotKeyManager.swift          # Global keyboard shortcut listener (KeyboardShortcuts).
│   └── UpdaterService.swift         # Sparkle auto-update manager.
│
├── Views/
│   ├── Workspace/        # MainWorkspaceView, translation/deep-AI/flashcard studios, history sheet.
│   ├── Translation/      # TranslationHUDView, Header, Dictionary, Sentence, TranslationViewModel.
│   ├── Notebook/         # VocabularyNotebookView, TableView, Flashcard, QuickLook, WordDetail, Grammar.
│   ├── AI/               # QuickAIAssistantView, AIWebView, SmartTextAnalysisSheet.
│   ├── Stats/            # LearningStatsDashboardView, ApexChartView.
│   └── Settings/         # SettingsView, GitHubSyncSettingsSection, ShortcutRecorderView, Sections/*.
│
├── Windows/
│   ├── FloatingPanel.swift              # Non-activating HUD translation panel.
│   ├── MainWindowController.swift       # Main workspace window controller.
│   ├── QuickAIWindowController.swift    # Quick AI web assistant window controller.
│   ├── ScreenSnipController.swift       # Interactive screen region selection overlay for OCR.
│   ├── SelectionBubbleController.swift  # Floating mouse-up text selection bubble.
│   ├── SettingsWindowController.swift   # Preferences window controller.
│   ├── TextAnalysisWindowController.swift # Smart text analysis window controller.
│   └── VocabularyWindowController.swift # Standalone notebook window controller.
│
└── Localization/
    ├── AppConfigurationModels+Localization.swift # LocalizedStringResource extensions on NekoCore models.
    ├── Localizable.xcstrings        # Xcode 16 String Catalog with auto-generated Swift symbols.
    ├── Localization.swift           # Runtime language preference & LocalizedStringResource manager.
    └── LocalizedRootView.swift      # Root SwiftUI localization environment wrapper.
```

Targets in `NekoTrans.xcodeproj` (`PBXFileSystemSynchronizedRootGroup`): `NekoTrans` (`Sources/NekoTrans`), `NekoTransTests` (`Tests/NekoTransTests`), plus local package `Packages/NekoKit` (`NekoCore`, `NekoServices`, `NekoUI`).

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

### RULE 2: CENTRALIZED PROMPT FACTORY (`Utilities/AIPromptBuilder.swift`)
- **NEVER** write inline raw prompt strings inside SwiftUI Views or Controller classes.
- All prompts must be static methods in `AIPromptBuilder`:
  - `AIPromptBuilder.structuredWordPrompt(for:)`
  - `AIPromptBuilder.grammarFormulaPrompt(for:context:)`
  - `AIPromptBuilder.wordGrammarPatternsPrompt(for:context:)`
  - `AIPromptBuilder.strictEnforcedGrammarPrompt(title:context:customNote:)`

### RULE 3: MULTILINE STREAM PARSING (`Utilities/AIAnalysisParser.swift`)
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
- Grammar vs. vocabulary rendering lives in `Views/Notebook/GrammarDetailView.swift` and `Views/Notebook/VocabularyNotebookView.swift`.

### RULE 5: SECRETS NEVER TOUCH `UserDefaults` & CENTRALIZED `Defaults` KEYS
- Every credential (LLM/translation API keys, GitHub PAT) **MUST** be persisted through `KeychainStore` and its account name **MUST** be declared in `KeyStore.Secret`.
- **NEVER** call `UserDefaults.standard.set(...)` with a secret, and never add a new raw secret key string outside `KeyStore.Secret`.
- All non-secret persistent settings **MUST** use `Defaults` (`sindresorhus/Defaults`) with keys declared in `Utilities/Key.swift` (`extension Defaults.Keys`).
- Legacy installs are migrated once by `KeychainStore.migrateFromUserDefaults`; the `UserDefaults` copy is only removed after a successful Keychain write.

### RULE 6: STRICT RESTRICTED ZONES & NO-GO DIRECTORIES
- **DO NOT TOUCH / DO NOT INDEX**:
  - `build/`, `.build/`, `DerivedData/`, `*.dmg`, `*.app` (Build artifacts)
  - `Windows/` (Top-level future platform planning directory at repo root; note `Sources/NekoTrans/Windows/` is for macOS `NSWindow`/`NSPanel` controllers)
  - `Resources/AppIcon.iconset/`, `Resources/*.png` (Binary assets)
  - `.git/`, `.env*`, `*.key`, `*.p12`, `*.pem` (Credentials & VCS internals)

### RULE 7: NO `print` IN SHIPPING CODE
- Diagnostic output **MUST** go through `AppLog` (`os.Logger`), never `print()`. stdout is discarded when the app is launched from Finder, so `print` messages are invisible exactly when they matter.
- Pick the existing category (`app`, `settings`, `vocabulary`, `spotlight`, `history`, `dictionary`, `translation`, `sync`) or add one to `AppLog`.
- User-supplied content (word titles, translated text) **MUST** stay `.private`; mark only error descriptions and identifiers `.public`.
- Inspect logs with: `log stream --predicate 'subsystem == "com.nekotrans.mac"' --level debug`

### RULE 8: NEVER INTERPOLATE INTO `URL(string:)`
- Any request URL that **embeds a value** (user text, an API key, an id, a user-typed endpoint) **MUST** be built with `SafeURL.make(...)` (`Utilities/SafeURL.swift`) or `URLComponents`. Never write `URL(string: "https://host/path?q=\(value)")`.
- `URL(string:)` stays fine for a literal constant (`URL(string: "https://api.github.com/user")`) or for a URL already produced/validated elsewhere.
- Reason: `URL(string:)` percent-encodes the **entire** string the moment it contains a character Foundation rejects. Interpolating an already-escaped value then escapes the escapes (`%20` → `%2520`) and the server receives literal `%20` text. MyMemory's `langpair=en|vi` carries a raw `|`, so every query it received was double-encoded and echoed back as the "translation".
- Pass **raw** values to `SafeURL`; pre-escaping them reintroduces the bug.
- Third-party responses **MUST** be validated before being trusted: MyMemory answers `HTTP 200` with `responseStatus: 403` and puts the error sentence in `translatedText` (see `MyMemoryResponse`). Never surface a payload field to the user without checking the payload's own status.

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
1. **Update Model**: Add field `public var myField: [String] = []` to `ParsedAIAnalysis` in `Utilities/AIAnalysisParser.swift`.
2. **Update Parser**: Add header keyword detection in `AIAnalysisParser.parse()` and append to `result.myField`.
3. **Update Prompt**: Add corresponding markdown section header in `Utilities/AIPromptBuilder.swift`.
4. **Update UI**: Render a new `GroupBox` inside `Views/Notebook/GrammarDetailView.swift` or `Views/Notebook/VocabularyNotebookView.swift`.

### Recipe B: Adding a New AI Provider to WebView
1. **Enum Addition**: Add case in `enum AIProvider: String, CaseIterable, Identifiable` in `Views/AI/QuickAIAssistantView.swift`.
2. **Input Selector**: Add DOM selector & input handler in `Views/AI/AIWebView.swift` inside the JavaScript injection loop.
