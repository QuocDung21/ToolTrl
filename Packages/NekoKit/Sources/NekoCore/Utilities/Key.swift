//
//  Key.swift
//  NekoTrans
//
//  Created by Dũng Nguyễn Quốc on 25/9/26.
//

import Foundation
import Defaults

// MARK: - Single Source of Truth for Defaults.Keys
public extension Defaults.Keys {
    // ── UI & App ──────────────────────────────────────────────────────
    static let appFontSize = Key<AppFontSize>("appFontSize", default: .medium)
    static let mainWorkspaceTab = Key<MainWorkspaceTab>("mainWorkspaceTab", default: .translate)
    static let quitActionPreference = Key<QuitActionPreference>("quitActionPreference", default: .askEveryTime)
    static let showInDock = Key<Bool>("showInDock", default: true)
    static let showMainWindowOnLaunch = Key<Bool>("showMainWindowOnLaunch", default: true)
    static let clickOutsideDismiss = Key<Bool>("clickOutsideDismiss", default: true)
    static let appIconType = Key<AppIconType>("app_icon_type", default: .defaultCat)
    static let appLanguage = Key<AppLanguage?>("appLanguage", default: nil)

    // ── Speech & Audio ────────────────────────────────────────────────
    static let speechRate = Key<Double>("speechRate", default: 0.50)
    static let speechPitch = Key<Double>("speechPitch", default: 1.0)
    static let speechVolume = Key<Double>("speechVolume", default: 1.0)
    static let speechSpeedPreset = Key<Double>("speechSpeedPreset", default: 1.0)
    static let autoSpeakWord = Key<Bool>("autoSpeakWord", default: false)

    // ── Translation & AI ──────────────────────────────────────────────
    static let targetLanguage = Key<String>("targetLanguage", default: TargetLanguage.vietnamese.rawValue)
    static let autoTranslateOnSelectionWhenPinned = Key<Bool>("autoTranslateOnSelectionWhenPinned", default: true)
    static let translationDisplayMode = Key<TranslationDisplayMode>("translationDisplayMode", default: .wordByWord)
    static let wordLookupMode = Key<WordLookupMode>("wordLookupMode", default: .dictionary)
    static let translationDomain = Key<TranslationDomain>("translationDomain", default: .general)
    static let translationEngine = Key<TranslationEngine>("translationEngine", default: .auto)
    static let aiProvider = Key<DirectAIProvider>("aiProvider", default: .openAI)
    static let customAIModel = Key<String>("customAiModel", default: "")
    static let customGGUFModelPath = Key<String>("customGGUFModelPath", default: "")

    // ── Dictionary ────────────────────────────────────────────────────
    static let showPhonetics = Key<Bool>("showPhonetics", default: true)
    static let showExamples = Key<Bool>("showExamples", default: true)
    static let showSynonyms = Key<Bool>("showSynonyms", default: true)
    static let showOfflineDictionary = Key<Bool>("showOfflineDict", default: true)

    // ── Menu ──────────────────────────────────────────────────────────
    static let showAIAssistantInMenu = Key<Bool>("menuShowAiAssistant", default: true)
    static let showAIVocabGrammarInMenu = Key<Bool>("menuShowAiVocabGrammar", default: false)
    static let showOCRInMenu = Key<Bool>("menuShowOcr", default: true)
    static let showDomainSelectorInMenu = Key<Bool>("menuShowDomainSelector", default: false)
    static let showNotebookInMenu = Key<Bool>("menuShowNotebook", default: true)

    // ── Triggers & Feature Flags ──────────────────────────────────────
    static let enableSelectionBubble = Key<Bool>("enableSelectionBubble", default: false)
    static let enableDoubleCmdCTrigger = Key<Bool>("enableDoubleCmdC", default: false)

    static let devModeUnlocked = Key<Bool>("dev_mode_unlocked", default: true)
    static let betaLabsEnabled = Key<Bool>("beta_labs_enabled", default: true)
    static let flagSelectionBubble = Key<Bool>("flag_selection_bubble", default: false)
    static let flagDoubleCmdCTrigger = Key<Bool>("flag_double_cmd_c_trigger", default: false)
    static let flagLocalLLM = Key<Bool>("flag_local_llm", default: false)

    // ── Quick Prompts & Notebook & Analytics ──────────────────────────
    static let customQuickPromptsData = Key<Data?>("custom_quick_prompts", default: nil)
    static let savedVocabularyItemsData = Key<Data?>("saved_vocabulary_items_v2", default: nil)
    static let legacySavedVocabularyItemsData = Key<Data?>("saved_vocabulary_items", default: nil)
    static let dailyLookupGoal = Key<Int>("tooltrl_daily_lookup_goal", default: 20)
    static let lookupRecordsData = Key<Data?>("tooltrl_lookup_records_v2", default: nil)
    static let legacyLookupRecordsData = Key<Data?>("tooltrl_lookup_records_v1", default: nil)

    // ── GitHub Cloud Sync Metadata ────────────────────────────────────
    static let githubGistId = Key<String>("tooltrl_github_gist_id", default: "")
    static let githubLastSyncDate = Key<Date?>("tooltrl_github_last_sync_date", default: nil)
    static let githubAutoSyncEnabled = Key<Bool>("tooltrl_github_auto_sync_enabled", default: true)
    static let githubUserCacheData = Key<Data?>("tooltrl_github_user_cache", default: nil)

    // ── In-Place Replace & ActionManager ──────────────────────────────
    static let enableInPlaceReplace = Key<Bool>("enable_in_place_replace", default: true)
    static let inPlaceReplaceSound = Key<Bool>("in_place_replace_sound", default: true)

    // ── AnkiConnect ───────────────────────────────────────────────────
    static let enableAnkiConnect = Key<Bool>("enable_anki_connect", default: false)
    static let ankiConnectEndpoint = Key<String>("anki_connect_endpoint", default: "http://127.0.0.1:8765")
    static let ankiConnectDeck = Key<String>("anki_connect_deck", default: "Default")
    static let ankiConnectModel = Key<String>("anki_connect_model", default: "Basic")
    static let ankiAutoSyncOnBookmark = Key<Bool>("anki_auto_sync_on_bookmark", default: true)

    // ── Continuous Auto-Journaling (words.jsonl) ──────────────────────
    static let enableContinuousJournal = Key<Bool>("enable_continuous_journal", default: true)
    static let journalDirectoryPath = Key<String>("journal_directory_path", default: "")

    // ── App Exclusion & Silent Mode ───────────────────────────────────
    static let excludedAppBundleIdentifiers = Key<[String]>("excluded_app_bundle_identifiers", default: [
        "com.figma.Desktop",
        "com.adobe.Photoshop",
        "com.sublimetext.4",
        "com.valvesoftware.steam"
    ])

    // ── HUD Multi-Engine Comparison ───────────────────────────────────
    static let enableHUDMultiEngine = Key<Bool>("enable_hud_multi_engine", default: false)

    // ── Sparkle Auto-Updater Channel ──────────────────────────────────
    static let updateChannel = Key<UpdateChannel>("update_channel", default: .stable)
}

public enum KeyStore {
    // MARK: - Secrets (stored in the Keychain, never in UserDefaults)

    /// Account names of every secret handled by `KeychainStore`.
    ///
    /// The raw values intentionally match the historical `UserDefaults` keys so a
    /// pre-Keychain install migrates without any extra mapping.
    public enum Secret {
        public static let openAI = "openai_api_key"
        public static let anthropic = "anthropic_api_key"
        public static let gemini = "gemini_api_key"
        public static let groq = "groq_api_key"
        public static let deepSeek = "deepseek_api_key"
        public static let deepL = "deepl_api_key"
        public static let githubPAT = "tooltrl_github_pat_token"

        public static let allAccounts: [String] = [
            openAI, anthropic, gemini, groq, deepSeek, deepL, githubPAT
        ]
    }
}
