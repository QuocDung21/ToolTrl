//
//  Key.swift
//  NekoTrans
//
//  Created by Dũng Nguyễn Quốc on 25/9/26.
//

import Foundation

public enum KeyStore {
    // start - show_main_window_on_launch
    public static let showMainWindowOnLaunch = "show_main_window_on_launch"
    public static let defaultShowMainWindowOnLaunch: Bool = true
    // end - show_main_window_on_launch

    // MARK: - AppSettings keys

    /// Every raw `UserDefaults` key owned by `AppSettings`.
    ///
    /// Declaring them here keeps the writer (`didSet`) and the reader (`init`) from
    /// drifting apart: a typo is now a compile error instead of a silently ignored
    /// setting. `show_main_window_on_launch` lives above with its codegen markers.
    public enum Defaults {
        public static let aiProvider = "ai_provider"
        public static let appFontSize = "app_font_size"
        public static let autoSpeakWord = "auto_speak_word"
        public static let autoTranslateOnSelectionWhenPinned = "auto_translate_on_selection_when_pinned"
        public static let clickOutsideDismiss = "click_outside_dismiss"
        public static let customAiModel = "custom_ai_model"
        public static let enableDoubleCmdC = "enable_double_cmd_c"
        public static let enableSelectionBubble = "enable_selection_bubble"
        public static let mainWorkspaceTab = "main_workspace_tab"
        public static let menuShowAiAssistant = "menu_show_ai_assistant"
        public static let menuShowAiVocabGrammar = "menu_show_ai_vocab_grammar"
        public static let menuShowDomainSelector = "menu_show_domain_selector"
        public static let menuShowIpadContinuity = "menu_show_ipad_continuity"
        public static let menuShowNotebook = "menu_show_notebook"
        public static let menuShowOcr = "menu_show_ocr"
        public static let ollamaEndpoint = "ollama_endpoint"
        public static let quitActionPreference = "quit_action_preference"
        public static let showExamples = "show_examples"
        public static let showInDock = "show_in_dock"
        public static let showOfflineDict = "show_offline_dict"
        public static let showPhonetics = "show_phonetics"
        public static let showSynonyms = "show_synonyms"
        public static let speechPitch = "speech_pitch"
        public static let speechRate = "speech_rate"
        public static let speechSpeedPreset = "speech_speed_preset"
        public static let speechVolume = "speech_volume"
        public static let targetLanguage = "target_language"
        public static let translationDisplayMode = "translation_display_mode"
        public static let translationDomain = "translation_domain"
        public static let translationEngine = "translation_engine"
        public static let translationTone = "translation_tone"
    }

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
