import SwiftUI
import ServiceManagement
import Defaults
import Observation

@Observable
public final class AppSettings {
    public static let shared = AppSettings()

    private static func secret(_ account: String) -> String {
        KeychainStore.string(for: account) ?? ""
    }

    // MARK: - In-Memory
    public var selectedSidebarItem: WorkspaceSidebarItem = .translate

    // MARK: - 🎨 App & UI
    public var appFontSize: AppFontSize {
        didSet { Defaults[.appFontSize] = appFontSize }
    }

    public var mainWorkspaceTab: MainWorkspaceTab {
        didSet { Defaults[.mainWorkspaceTab] = mainWorkspaceTab }
    }

    public var quitActionPreference: QuitActionPreference {
        didSet { Defaults[.quitActionPreference] = quitActionPreference }
    }

    public var showMainWindowOnLaunch: Bool {
        didSet { Defaults[.showMainWindowOnLaunch] = showMainWindowOnLaunch }
    }

    public var hasCompletedOnboarding: Bool {
        didSet { Defaults[.hasCompletedOnboarding] = hasCompletedOnboarding }
    }

    public var clickOutsideDismiss: Bool {
        didSet { Defaults[.clickOutsideDismiss] = clickOutsideDismiss }
    }

    public var showInDock: Bool {
        didSet {
            Defaults[.showInDock] = showInDock
            DispatchQueue.main.async {
                let policy: NSApplication.ActivationPolicy = self.showInDock ? .regular : .accessory
                NSApp.setActivationPolicy(policy)
                if self.showInDock {
                    AppIconService.shared.updateDockIcon()
                    NSApp.activate(ignoringOtherApps: true)
                }
                NotificationCenter.default.post(name: .showInDockDidChange, object: nil)
            }
        }
    }

    public var appLanguage: AppLanguage? {
        didSet {
            Defaults[.appLanguage] = appLanguage
            Task { @MainActor in
                Localization.shared.setPreference(self.appLanguage.map { .language($0) } ?? .system)
            }
        }
    }

    public var appAppearanceMode: AppAppearanceMode {
        didSet {
            Defaults[.appAppearanceMode] = appAppearanceMode
            applyAppAppearance()
        }
    }

    public var appAccentTheme: AppAccentTheme {
        didSet {
            Defaults[.appAccentTheme] = appAccentTheme
            NotificationCenter.default.post(name: .appThemeDidChange, object: nil)
        }
    }

    public var hudMaterialStyle: HUDMaterialStyle {
        didSet {
            Defaults[.hudMaterialStyle] = hudMaterialStyle
        }
    }

    public func applyAppAppearance() {
        let targetAppearance = appAppearanceMode.nsAppearance
        DispatchQueue.main.async {
            NSApp?.appearance = targetAppearance
            for window in NSApp?.windows ?? [] {
                window.appearance = targetAppearance
            }
            NotificationCenter.default.post(name: .appThemeDidChange, object: nil)
        }
    }

    // MARK: - 🔊 Speech & Audio
    public var speechRate: Double {
        didSet { Defaults[.speechRate] = speechRate }
    }

    public var speechPitch: Double {
        didSet { Defaults[.speechPitch] = speechPitch }
    }

    public var speechVolume: Double {
        didSet { Defaults[.speechVolume] = speechVolume }
    }

    public var speechSpeedPreset: Double {
        didSet { Defaults[.speechSpeedPreset] = speechSpeedPreset }
    }

    public var autoSpeakWord: Bool {
        didSet { Defaults[.autoSpeakWord] = autoSpeakWord }
    }

    // MARK: - 🌐 Translation & AI
    public var targetLanguage: String {
        didSet { Defaults[.targetLanguage] = targetLanguage }
    }

    public var autoTranslateOnSelectionWhenPinned: Bool {
        didSet { Defaults[.autoTranslateOnSelectionWhenPinned] = autoTranslateOnSelectionWhenPinned }
    }

    public var translationDisplayMode: TranslationDisplayMode {
        didSet { Defaults[.translationDisplayMode] = translationDisplayMode }
    }

    public var wordLookupMode: WordLookupMode {
        didSet { Defaults[.wordLookupMode] = wordLookupMode }
    }

    public var translationDomain: TranslationDomain {
        didSet { Defaults[.translationDomain] = translationDomain }
    }

    public var translationEngine: TranslationEngine {
        didSet { Defaults[.translationEngine] = translationEngine }
    }

    public var aiProvider: DirectAIProvider {
        didSet { Defaults[.aiProvider] = aiProvider }
    }

    public var customAIModel: String {
        didSet { Defaults[.customAIModel] = customAIModel }
    }

    public var customGGUFModelPath: String {
        didSet { Defaults[.customGGUFModelPath] = customGGUFModelPath }
    }

    // MARK: - 📖 Dictionary
    public var showPhonetics: Bool {
        didSet { Defaults[.showPhonetics] = showPhonetics }
    }

    public var showExamples: Bool {
        didSet { Defaults[.showExamples] = showExamples }
    }

    public var showSynonyms: Bool {
        didSet { Defaults[.showSynonyms] = showSynonyms }
    }

    public var showOfflineDictionary: Bool {
        didSet { Defaults[.showOfflineDictionary] = showOfflineDictionary }
    }

    // MARK: - 🧩 Menu
    public var showAIAssistantInMenu: Bool {
        didSet { Defaults[.showAIAssistantInMenu] = showAIAssistantInMenu }
    }

    public var showAIVocabGrammarInMenu: Bool {
        didSet { Defaults[.showAIVocabGrammarInMenu] = showAIVocabGrammarInMenu }
    }

    public var showOCRInMenu: Bool {
        didSet { Defaults[.showOCRInMenu] = showOCRInMenu }
    }

    public var showDomainSelectorInMenu: Bool {
        didSet { Defaults[.showDomainSelectorInMenu] = showDomainSelectorInMenu }
    }

    public var showNotebookInMenu: Bool {
        didSet { Defaults[.showNotebookInMenu] = showNotebookInMenu }
    }

    // MARK: - ⚡ Triggers & Flags
    public var enableSelectionBubble: Bool {
        didSet {
            Defaults[.enableSelectionBubble] = enableSelectionBubble
            NotificationCenter.default.post(name: .featureFlagsDidChange, object: nil)
        }
    }

    public var enableDoubleCmdCTrigger: Bool {
        didSet {
            Defaults[.enableDoubleCmdCTrigger] = enableDoubleCmdCTrigger
            NotificationCenter.default.post(name: .featureFlagsDidChange, object: nil)
        }
    }

    // MARK: - ✍️ In-Place Replace & ActionManager
    public var enableInPlaceReplace: Bool {
        didSet { Defaults[.enableInPlaceReplace] = enableInPlaceReplace }
    }

    public var inPlaceReplaceSound: Bool {
        didSet { Defaults[.inPlaceReplaceSound] = inPlaceReplaceSound }
    }

    // MARK: - 🔐 Keychain Secrets
    public var openAIKey: String    { didSet { KeychainStore.set(openAIKey, for: KeyStore.Secret.openAI) } }
    public var anthropicKey: String { didSet { KeychainStore.set(anthropicKey, for: KeyStore.Secret.anthropic) } }
    public var geminiKey: String    { didSet { KeychainStore.set(geminiKey, for: KeyStore.Secret.gemini) } }
    public var groqKey: String      { didSet { KeychainStore.set(groqKey, for: KeyStore.Secret.groq) } }
    public var deepSeekKey: String  { didSet { KeychainStore.set(deepSeekKey, for: KeyStore.Secret.deepSeek) } }
    public var deepLKey: String     { didSet { KeychainStore.set(deepLKey, for: KeyStore.Secret.deepL) } }

    // MARK: - 🚦 Launch at Login
    public var launchAtLogin: Bool = false

    // MARK: - 🧪 Active State
    @MainActor public var isSelectionBubbleActive: Bool {
        enableSelectionBubble && FeatureFlagService.shared.isFeatureEnabled(.selectionBubble)
    }

    @MainActor public var isDoubleCmdCActive: Bool {
        enableDoubleCmdCTrigger && FeatureFlagService.shared.isFeatureEnabled(.doubleCmdCTrigger)
    }

    // MARK: - Init
    private init() {
        // ── UI ────────────────────────────────────────────────
        self.appFontSize = Defaults[.appFontSize]
        self.mainWorkspaceTab = Defaults[.mainWorkspaceTab]
        self.quitActionPreference = Defaults[.quitActionPreference]
        self.showMainWindowOnLaunch = Defaults[.showMainWindowOnLaunch]
        self.hasCompletedOnboarding = Defaults[.hasCompletedOnboarding]
        self.clickOutsideDismiss = Defaults[.clickOutsideDismiss]
        self.showInDock = Defaults[.showInDock]
        self.appLanguage = Defaults[.appLanguage]
        self.appAppearanceMode = Defaults[.appAppearanceMode]
        self.appAccentTheme = Defaults[.appAccentTheme]
        self.hudMaterialStyle = Defaults[.hudMaterialStyle]

        let savedRate = Defaults[.speechRate]
        self.speechRate = savedRate > 0.05 ? savedRate : 0.50

        let savedPitch = Defaults[.speechPitch]
        self.speechPitch = savedPitch > 0.05 ? savedPitch : 1.0

        let savedVolume = Defaults[.speechVolume]
        self.speechVolume = min(max(savedVolume, 0.0), 1.0)

        let savedSpeed = Defaults[.speechSpeedPreset]
        self.speechSpeedPreset = savedSpeed > 0.1 ? savedSpeed : 1.0

        self.autoSpeakWord = Defaults[.autoSpeakWord]

        // ── Translation ───────────────────────────────────────
        self.targetLanguage = Defaults[.targetLanguage]
        self.autoTranslateOnSelectionWhenPinned = Defaults[.autoTranslateOnSelectionWhenPinned]
        self.translationDisplayMode = Defaults[.translationDisplayMode]
        self.wordLookupMode = Defaults[.wordLookupMode]
        self.translationDomain = Defaults[.translationDomain]
        self.translationEngine = Defaults[.translationEngine]
        self.aiProvider = Defaults[.aiProvider]
        self.customAIModel = Defaults[.customAIModel]
        self.customGGUFModelPath = Defaults[.customGGUFModelPath]

        // ── Dictionary ────────────────────────────────────────
        self.showPhonetics = Defaults[.showPhonetics]
        self.showExamples = Defaults[.showExamples]
        self.showSynonyms = Defaults[.showSynonyms]
        self.showOfflineDictionary = Defaults[.showOfflineDictionary]

        // ── Menu ──────────────────────────────────────────────
        self.showAIAssistantInMenu = Defaults[.showAIAssistantInMenu]
        self.showAIVocabGrammarInMenu = Defaults[.showAIVocabGrammarInMenu]
        self.showOCRInMenu = Defaults[.showOCRInMenu]
        self.showDomainSelectorInMenu = Defaults[.showDomainSelectorInMenu]
        self.showNotebookInMenu = Defaults[.showNotebookInMenu]

        // ── Flags ─────────────────────────────────────────────
        self.enableSelectionBubble = Defaults[.enableSelectionBubble]
        self.enableDoubleCmdCTrigger = Defaults[.enableDoubleCmdCTrigger]
        self.enableInPlaceReplace = Defaults[.enableInPlaceReplace]
        self.inPlaceReplaceSound = Defaults[.inPlaceReplaceSound]

        // ── Keychain (migrate UserDefaults → Keychain once) ──
        KeychainStore.migrateAllSecretsFromUserDefaults()
        self.openAIKey    = AppSettings.secret(KeyStore.Secret.openAI)
        self.anthropicKey = AppSettings.secret(KeyStore.Secret.anthropic)
        self.geminiKey    = AppSettings.secret(KeyStore.Secret.gemini)
        self.groqKey      = AppSettings.secret(KeyStore.Secret.groq)
        self.deepSeekKey  = AppSettings.secret(KeyStore.Secret.deepSeek)
        self.deepLKey     = AppSettings.secret(KeyStore.Secret.deepL)

        // ── Launch at Login ──────────────────────────────────
        if #available(macOS 13.0, *) {
            self.launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    // MARK: - Public setters
    public func setShowMainWindowOnLaunch(_ enabled: Bool) {
        self.showMainWindowOnLaunch = enabled
        Defaults[.showMainWindowOnLaunch] = enabled
    }

    public func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                self.launchAtLogin = (SMAppService.mainApp.status == .enabled)
            } catch {
                AppLog.settings.error("Launch at login toggle failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

extension Notification.Name {
    public static let showInDockDidChange = Notification.Name("showInDockDidChange")
    public static let appThemeDidChange = Notification.Name("appThemeDidChange")
}
