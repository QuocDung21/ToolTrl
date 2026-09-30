import SwiftUI
import ServiceManagement




public enum TranslationDomain: String, CaseIterable, Identifiable, Sendable {
    case general = "Tổng hợp"
    case technology = "Công nghệ & IT"
    case business = "Kinh tế & Tài chính"
    case academic = "Học thuật & IELTS"
    case medical = "Y khoa & Sinh học"
    case daily = "Đời sống & Giao tiếp"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .general: return "globe"
        case .technology: return "chevron.left.forwardslash.chevron.right"
        case .business: return "chart.line.uptrend.xyaxis"
        case .academic: return "graduationcap"
        case .medical: return "cross.case"
        case .daily: return "cup.and.saucer"
        }
    }
}

public enum TranslationEngine: String, CaseIterable, Identifiable, Sendable {
    case auto = "Tự động (Fast-Racing)"
    case directAI = "Trí tuệ nhân tạo (Direct AI)"
    case deepL = "DeepL Translator"
    case googleWeb = "Google Translate"
    case appleOffline = "Apple Translation (On-Device)"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .auto: return "bolt.horizontal.fill"
        case .directAI: return "sparkles"
        case .deepL: return "d.circle.fill"
        case .googleWeb: return "g.circle.fill"
        case .appleOffline: return "apple.logo"
        }
    }
}

public enum DirectAIProvider: String, CaseIterable, Identifiable, Sendable {
    case openAI = "OpenAI (GPT-4o / mini)"
    case anthropic = "Anthropic Claude"
    case googleGemini = "Google Gemini"
    case groq = "Groq (Llama 3.3 Siêu tốc)"
    case deepSeek = "DeepSeek (V3 / R1)"
    case ollama = "Ollama Local LLM (Offline)"
    
    public var id: String { rawValue }
    
    public var defaultModel: String {
        switch self {
        case .openAI: return "gpt-4o-mini"
        case .anthropic: return "claude-3-5-haiku-20241022"
        case .googleGemini: return "gemini-1.5-flash"
        case .groq: return "llama-3.3-70b-versatile"
        case .deepSeek: return "deepseek-chat"
        case .ollama: return "llama3"
        }
    }
}

public enum TranslationTone: String, CaseIterable, Identifiable, Sendable {
    case standard = "Tiêu chuẩn"
    case academic = "Học thuật & IELTS"
    case business = "Công việc & Doanh nghiệp"
    case casual = "Thân mật & Đời sống"
    case technical = "Kỹ thuật & IT (Code)"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .standard: return "globe"
        case .academic: return "graduationcap.fill"
        case .business: return "briefcase.fill"
        case .casual: return "bubble.left.and.bubble.right.fill"
        case .technical: return "chevron.left.forwardslash.chevron.right"
        }
    }
}

public enum TranslationDisplayMode: String, CaseIterable, Identifiable, Sendable {
    case wordByWord = "Từng từ tương ứng (Interlinear Ruby)"
    case onlyTarget = "Chỉ hiển thị tiếng Việt"
    case standard = "Tiêu chuẩn (2 thẻ riêng biệt)"
    case syntax = "Tô màu ngữ pháp trực quan (Syntax)"
    
    public var id: String { rawValue }
    
    public var shortName: String {
        switch self {
        case .wordByWord: return "Từng từ"
        case .onlyTarget: return "Chỉ dịch"
        case .standard: return "Tiêu chuẩn"
        case .syntax: return "Cú pháp"
        }
    }
    
    public var icon: String {
        switch self {
        case .wordByWord: return "character.bubble.fill"
        case .onlyTarget: return "text.alignleft"
        case .standard: return "rectangle.split.2x1"
        case .syntax: return "paintpalette.fill"
        }
    }
}

public enum QuitActionPreference: String, CaseIterable, Identifiable, Sendable {
    case askEveryTime = "ask"
    case runInBackground = "background"
    case terminateImmediately = "terminate"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .askEveryTime: return "Luôn hỏi"
        case .runInBackground: return "Chạy dưới nền"
        case .terminateImmediately: return "Thoát hoàn toàn"
        }
    }
}

public enum AppFontSize: String, CaseIterable, Identifiable, Sendable {
    case small = "Nhỏ"
    case medium = "Vừa (Mặc định)"
    case large = "Lớn"
    case extraLarge = "Rất lớn"
    
    public var id: String { rawValue }
    
    public var baseSize: CGFloat {
        switch self {
        case .small: return 12.5
        case .medium: return 14.0
        case .large: return 16.0
        case .extraLarge: return 18.0
        }
    }
    
    public var scaleDelta: CGFloat {
        switch self {
        case .small: return -1.5
        case .medium: return 0.0
        case .large: return 2.0
        case .extraLarge: return 4.0
        }
    }
}

public enum MainWorkspaceTab: String, CaseIterable, Identifiable, Sendable {
    case translate = "Dịch & Tra từ"
    case notebook = "Sổ tay từ vựng"
    case flashcards = "Ôn tập Flashcards"
    case deepAI = "AI Phân tích sâu"
    case stats = "Tiến độ & Thống kê"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .translate: return "globe.americas.fill"
        case .notebook: return "book.closed.fill"
        case .flashcards: return "rectangle.portrait.on.rectangle.portrait.angled.fill"
        case .deepAI: return "brain.head.profile"
        case .stats: return "chart.bar.xaxis"
        }
    }
}

public enum WorkspaceSidebarItem: String, CaseIterable, Identifiable, Sendable {
    // 1. Dịch thuật
    case translate = "translate"
    
    // 2. Sổ tay & Ngữ pháp
    case notebookAll = "notebookAll"
    case notebookVocab = "notebookVocab"
    case notebookGrammar = "notebookGrammar"
    case notebookFavorites = "notebookFavorites"
    case notebookMastered = "notebookMastered"
    
    // 3. Học tập & Công cụ
    case flashcards = "flashcards"
    case deepAI = "deepAI"
    case stats = "stats"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .translate: return "Dịch & Tra cứu"
        case .notebookAll: return "Tất cả ghi chú"
        case .notebookVocab: return "Từ vựng"
        case .notebookGrammar: return "Cấu trúc ngữ pháp"
        case .notebookFavorites: return "Mục yêu thích"
        case .notebookMastered: return "Đã ghi nhớ"
        case .flashcards: return "Ôn tập Flashcards"
        case .deepAI: return "AI Bóc tách văn bản"
        case .stats: return "Tiến độ & Thống kê"
        }
    }
    
    public var icon: String {
        switch self {
        case .translate: return "globe.americas.fill"
        case .notebookAll: return "tray.full.fill"
        case .notebookVocab: return "character.book.closed.fill"
        case .notebookGrammar: return "function"
        case .notebookFavorites: return "star.fill"
        case .notebookMastered: return "checkmark.seal.fill"
        case .flashcards: return "rectangle.portrait.on.rectangle.portrait.angled.fill"
        case .deepAI: return "brain.head.profile"
        case .stats: return "chart.bar.xaxis"
        }
    }
    
    public var isNotebookFolder: Bool {
        switch self {
        case .notebookAll, .notebookVocab, .notebookGrammar, .notebookFavorites, .notebookMastered:
            return true
        default:
            return false
        }
    }
}

public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    
    /// Reads a secret from the Keychain, returning an empty string when unset.
    private static func secret(_ account: String) -> String {
        KeychainStore.string(for: account) ?? ""
    }
    
    @Published public var selectedSidebarItem: WorkspaceSidebarItem = .translate
    
    @Published public var appFontSize: AppFontSize {
        didSet {
            UserDefaults.standard.set(appFontSize.rawValue, forKey: KeyStore.Defaults.appFontSize)
        }
    }
    
    @Published public var speechRate: Double {
        didSet {
            UserDefaults.standard.set(speechRate, forKey: KeyStore.Defaults.speechRate)
        }
    }
    
    @Published public var speechPitch: Double {
        didSet {
            UserDefaults.standard.set(speechPitch, forKey: KeyStore.Defaults.speechPitch)
        }
    }
    
    @Published public var speechVolume: Double {
        didSet {
            UserDefaults.standard.set(speechVolume, forKey: KeyStore.Defaults.speechVolume)
        }
    }
    
    @Published public var autoSpeakWord: Bool {
        didSet {
            UserDefaults.standard.set(autoSpeakWord, forKey: KeyStore.Defaults.autoSpeakWord)
        }
    }
    
    @Published public var clickOutsideDismiss: Bool {
        didSet {
            UserDefaults.standard.set(clickOutsideDismiss, forKey: KeyStore.Defaults.clickOutsideDismiss)
        }
    }
    
    // Hành vi khi nhấn Cmd+Q hoặc đóng ứng dụng (Luôn hỏi / Chạy dưới nền / Thoát hoàn toàn)
    @Published public var quitActionPreference: QuitActionPreference {
        didSet {
            UserDefaults.standard.set(quitActionPreference.rawValue, forKey: KeyStore.Defaults.quitActionPreference)
        }
    }
    
    @Published public var targetLanguage: String {
        didSet {
            UserDefaults.standard.set(targetLanguage, forKey: KeyStore.Defaults.targetLanguage)
        }
    }
    
    // Tự động dịch trực tiếp khi bôi đen từ lúc ghim cửa sổ (không cần Option + D)
    @Published public var autoTranslateOnSelectionWhenPinned: Bool {
        didSet {
            UserDefaults.standard.set(autoTranslateOnSelectionWhenPinned, forKey: KeyStore.Defaults.autoTranslateOnSelectionWhenPinned)
        }
    }
    
    // Chế độ hiển thị bản dịch (Từng từ tương ứng / Chỉ tiếng Việt / Tiêu chuẩn / Cú pháp)
    @Published public var translationDisplayMode: TranslationDisplayMode {
        didSet {
            UserDefaults.standard.set(translationDisplayMode.rawValue, forKey: KeyStore.Defaults.translationDisplayMode)
        }
    }
    
    // Ngữ cảnh dịch chuyên ngành (IT, Kinh tế, IELTS, Y khoa, v.v.)
    @Published public var translationDomain: TranslationDomain {
        didSet {
            UserDefaults.standard.set(translationDomain.rawValue, forKey: KeyStore.Defaults.translationDomain)
        }
    }
    
    // Tùy chọn hiển thị từ điển
    @Published public var showPhonetics: Bool {
        didSet {
            UserDefaults.standard.set(showPhonetics, forKey: KeyStore.Defaults.showPhonetics)
        }
    }
    
    @Published public var showExamples: Bool {
        didSet {
            UserDefaults.standard.set(showExamples, forKey: KeyStore.Defaults.showExamples)
        }
    }
    
    @Published public var showSynonyms: Bool {
        didSet {
            UserDefaults.standard.set(showSynonyms, forKey: KeyStore.Defaults.showSynonyms)
        }
    }
    
    @Published public var showOfflineDictionary: Bool {
        didSet {
            UserDefaults.standard.set(showOfflineDictionary, forKey: KeyStore.Defaults.showOfflineDict)
        }
    }
    
    // MARK: - 🧩 Tùy chọn hiển thị Menu Tính Năng Nâng Cao
    @Published public var showAIAssistantInMenu: Bool {
        didSet {
            UserDefaults.standard.set(showAIAssistantInMenu, forKey: KeyStore.Defaults.menuShowAiAssistant)
        }
    }
    
    @Published public var showAIVocabGrammarInMenu: Bool {
        didSet {
            UserDefaults.standard.set(showAIVocabGrammarInMenu, forKey: KeyStore.Defaults.menuShowAiVocabGrammar)
        }
    }
    
    @Published public var showOCRInMenu: Bool {
        didSet {
            UserDefaults.standard.set(showOCRInMenu, forKey: KeyStore.Defaults.menuShowOcr)
        }
    }
    
    @Published public var showiPadContinuityInMenu: Bool {
        didSet {
            UserDefaults.standard.set(showiPadContinuityInMenu, forKey: KeyStore.Defaults.menuShowIpadContinuity)
        }
    }
    
    @Published public var showDomainSelectorInMenu: Bool {
        didSet {
            UserDefaults.standard.set(showDomainSelectorInMenu, forKey: KeyStore.Defaults.menuShowDomainSelector)
        }
    }
    
    @Published public var showNotebookInMenu: Bool {
        didSet {
            UserDefaults.standard.set(showNotebookInMenu, forKey: KeyStore.Defaults.menuShowNotebook)
        }
    }
    
    // MARK: - 🚀 Translation Engine, AI & Stylistic Tones
    @Published public var translationEngine: TranslationEngine {
        didSet {
            UserDefaults.standard.set(translationEngine.rawValue, forKey: KeyStore.Defaults.translationEngine)
        }
    }
    
    @Published public var aiProvider: DirectAIProvider {
        didSet {
            UserDefaults.standard.set(aiProvider.rawValue, forKey: KeyStore.Defaults.aiProvider)
        }
    }
    
    @Published public var translationTone: TranslationTone {
        didSet {
            UserDefaults.standard.set(translationTone.rawValue, forKey: KeyStore.Defaults.translationTone)
        }
    }
    
    @Published public var openAIKey: String {
        didSet {
            KeychainStore.set(openAIKey, for: KeyStore.Secret.openAI)
        }
    }
    
    @Published public var anthropicKey: String {
        didSet {
            KeychainStore.set(anthropicKey, for: KeyStore.Secret.anthropic)
        }
    }
    
    @Published public var geminiKey: String {
        didSet {
            KeychainStore.set(geminiKey, for: KeyStore.Secret.gemini)
        }
    }
    
    @Published public var groqKey: String {
        didSet {
            KeychainStore.set(groqKey, for: KeyStore.Secret.groq)
        }
    }
    
    @Published public var deepSeekKey: String {
        didSet {
            KeychainStore.set(deepSeekKey, for: KeyStore.Secret.deepSeek)
        }
    }
    
    @Published public var deepLKey: String {
        didSet {
            KeychainStore.set(deepLKey, for: KeyStore.Secret.deepL)
        }
    }
    
    @Published public var ollamaEndpoint: String {
        didSet {
            UserDefaults.standard.set(ollamaEndpoint, forKey: KeyStore.Defaults.ollamaEndpoint)
        }
    }
    
    @Published public var customAIModel: String {
        didSet {
            UserDefaults.standard.set(customAIModel, forKey: KeyStore.Defaults.customAiModel)
        }
    }
    
    @Published public var speechSpeedPreset: Double {
        didSet {
            UserDefaults.standard.set(speechSpeedPreset, forKey: KeyStore.Defaults.speechSpeedPreset)
        }
    }
    
    @Published public var enableSelectionBubble: Bool {
        didSet {
            UserDefaults.standard.set(enableSelectionBubble, forKey: KeyStore.Defaults.enableSelectionBubble)
            NotificationCenter.default.post(name: .featureFlagsDidChange, object: nil)
        }
    }
    
    @Published public var enableDoubleCmdCTrigger: Bool {
        didSet {
            UserDefaults.standard.set(enableDoubleCmdCTrigger, forKey: KeyStore.Defaults.enableDoubleCmdC)
            NotificationCenter.default.post(name: .featureFlagsDidChange, object: nil)
        }
    }
    
    // MARK: - 🧪 Active State (Kết hợp Runtime Setting & Feature Flag)
    @MainActor public var isSelectionBubbleActive: Bool {
        enableSelectionBubble && FeatureFlagService.shared.isFeatureEnabled(.selectionBubble)
    }
    
    @MainActor public var isDoubleCmdCActive: Bool {
        enableDoubleCmdCTrigger && FeatureFlagService.shared.isFeatureEnabled(.doubleCmdCTrigger)
    }
    
    @MainActor public var isContinuityStudioActive: Bool {
        showiPadContinuityInMenu && FeatureFlagService.shared.isFeatureEnabled(.continuityStudio)
    }
    
    @Published public var launchAtLogin: Bool = false
    
    @Published public var showInDock: Bool {
        didSet {
            UserDefaults.standard.set(showInDock, forKey: KeyStore.Defaults.showInDock)
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
    
    @Published public var mainWorkspaceTab: MainWorkspaceTab {
        didSet {
            UserDefaults.standard.set(mainWorkspaceTab.rawValue, forKey: KeyStore.Defaults.mainWorkspaceTab)
        }
    }
    
    @Published public var showMainWindowOnLaunch: Bool {
        didSet {
            UserDefaults.standard.set(showMainWindowOnLaunch, forKey: KeyStore.showMainWindowOnLaunch)
        }
    }
    
    private init() {
        if UserDefaults.standard.object(forKey: KeyStore.showMainWindowOnLaunch) == nil {
            self.showMainWindowOnLaunch = KeyStore.defaultShowMainWindowOnLaunch
        } else {
            self.showMainWindowOnLaunch = UserDefaults.standard.bool(forKey: KeyStore.showMainWindowOnLaunch)
        }
        
        let savedFontSize = UserDefaults.standard.string(forKey: KeyStore.Defaults.appFontSize) ?? AppFontSize.medium.rawValue
        self.appFontSize = AppFontSize(rawValue: savedFontSize) ?? .medium
        
        let savedRate = UserDefaults.standard.double(forKey: KeyStore.Defaults.speechRate)
        self.speechRate = savedRate > 0.05 ? savedRate : 0.50
        
        let savedPitch = UserDefaults.standard.double(forKey: KeyStore.Defaults.speechPitch)
        self.speechPitch = savedPitch > 0.05 ? savedPitch : 1.0
        
        let savedVolume = UserDefaults.standard.object(forKey: KeyStore.Defaults.speechVolume) != nil ? UserDefaults.standard.double(forKey: KeyStore.Defaults.speechVolume) : 1.0
        self.speechVolume = min(max(savedVolume, 0.0), 1.0)
        
        self.autoSpeakWord = UserDefaults.standard.bool(forKey: KeyStore.Defaults.autoSpeakWord)
        
        if UserDefaults.standard.object(forKey: KeyStore.Defaults.clickOutsideDismiss) == nil {
            self.clickOutsideDismiss = true
        } else {
            self.clickOutsideDismiss = UserDefaults.standard.bool(forKey: KeyStore.Defaults.clickOutsideDismiss)
        }
        
        let savedQuitAction = UserDefaults.standard.string(forKey: KeyStore.Defaults.quitActionPreference) ?? QuitActionPreference.askEveryTime.rawValue
        self.quitActionPreference = QuitActionPreference(rawValue: savedQuitAction) ?? .askEveryTime
        
        self.targetLanguage = UserDefaults.standard.string(forKey: KeyStore.Defaults.targetLanguage) ?? TargetLanguage.vietnamese.rawValue
        
        if UserDefaults.standard.object(forKey: KeyStore.Defaults.autoTranslateOnSelectionWhenPinned) == nil {
            self.autoTranslateOnSelectionWhenPinned = true
        } else {
            self.autoTranslateOnSelectionWhenPinned = UserDefaults.standard.bool(forKey: KeyStore.Defaults.autoTranslateOnSelectionWhenPinned)
        }
        
        // Display Mode initialization (Default to wordByWord)
        let savedMode = UserDefaults.standard.string(forKey: KeyStore.Defaults.translationDisplayMode) ?? TranslationDisplayMode.wordByWord.rawValue
        self.translationDisplayMode = TranslationDisplayMode(rawValue: savedMode) ?? .wordByWord
        
        let savedDomain = UserDefaults.standard.string(forKey: KeyStore.Defaults.translationDomain) ?? TranslationDomain.general.rawValue
        self.translationDomain = TranslationDomain(rawValue: savedDomain) ?? .general
        
        // Default display settings
        self.showPhonetics = UserDefaults.standard.object(forKey: KeyStore.Defaults.showPhonetics) == nil ? true : UserDefaults.standard.bool(forKey: KeyStore.Defaults.showPhonetics)
        self.showExamples = UserDefaults.standard.object(forKey: KeyStore.Defaults.showExamples) == nil ? true : UserDefaults.standard.bool(forKey: KeyStore.Defaults.showExamples)
        self.showSynonyms = UserDefaults.standard.object(forKey: KeyStore.Defaults.showSynonyms) == nil ? true : UserDefaults.standard.bool(forKey: KeyStore.Defaults.showSynonyms)
        self.showOfflineDictionary = UserDefaults.standard.object(forKey: KeyStore.Defaults.showOfflineDict) == nil ? true : UserDefaults.standard.bool(forKey: KeyStore.Defaults.showOfflineDict)
        
        // Menu customization defaults
        self.showAIAssistantInMenu = UserDefaults.standard.object(forKey: KeyStore.Defaults.menuShowAiAssistant) == nil ? true : UserDefaults.standard.bool(forKey: KeyStore.Defaults.menuShowAiAssistant)
        self.showAIVocabGrammarInMenu = UserDefaults.standard.object(forKey: KeyStore.Defaults.menuShowAiVocabGrammar) == nil ? false : UserDefaults.standard.bool(forKey: KeyStore.Defaults.menuShowAiVocabGrammar)
        self.showOCRInMenu = UserDefaults.standard.object(forKey: KeyStore.Defaults.menuShowOcr) == nil ? true : UserDefaults.standard.bool(forKey: KeyStore.Defaults.menuShowOcr)
        self.showiPadContinuityInMenu = UserDefaults.standard.object(forKey: KeyStore.Defaults.menuShowIpadContinuity) == nil ? false : UserDefaults.standard.bool(forKey: KeyStore.Defaults.menuShowIpadContinuity)
        self.showDomainSelectorInMenu = UserDefaults.standard.object(forKey: KeyStore.Defaults.menuShowDomainSelector) == nil ? false : UserDefaults.standard.bool(forKey: KeyStore.Defaults.menuShowDomainSelector)
        self.showNotebookInMenu = UserDefaults.standard.object(forKey: KeyStore.Defaults.menuShowNotebook) == nil ? true : UserDefaults.standard.bool(forKey: KeyStore.Defaults.menuShowNotebook)
        
        // Translation Engine & AI initialization
        let savedEngine = UserDefaults.standard.string(forKey: KeyStore.Defaults.translationEngine) ?? TranslationEngine.auto.rawValue
        self.translationEngine = TranslationEngine(rawValue: savedEngine) ?? .auto
        
        let savedProvider = UserDefaults.standard.string(forKey: KeyStore.Defaults.aiProvider) ?? DirectAIProvider.openAI.rawValue
        self.aiProvider = DirectAIProvider(rawValue: savedProvider) ?? .openAI
        
        let savedTone = UserDefaults.standard.string(forKey: KeyStore.Defaults.translationTone) ?? TranslationTone.standard.rawValue
        self.translationTone = TranslationTone(rawValue: savedTone) ?? .standard
        
        // Secrets are stored in the Keychain. Migrate any pre-Keychain UserDefaults
        // value exactly once, then read the authoritative copy back.
        KeychainStore.migrateAllSecretsFromUserDefaults()

        self.openAIKey = AppSettings.secret(KeyStore.Secret.openAI)
        self.anthropicKey = AppSettings.secret(KeyStore.Secret.anthropic)
        self.geminiKey = AppSettings.secret(KeyStore.Secret.gemini)
        self.groqKey = AppSettings.secret(KeyStore.Secret.groq)
        self.deepSeekKey = AppSettings.secret(KeyStore.Secret.deepSeek)
        self.deepLKey = AppSettings.secret(KeyStore.Secret.deepL)
        self.ollamaEndpoint = UserDefaults.standard.string(forKey: KeyStore.Defaults.ollamaEndpoint) ?? "http://localhost:11434"
        self.customAIModel = UserDefaults.standard.string(forKey: KeyStore.Defaults.customAiModel) ?? ""
        
        let savedSpeed = UserDefaults.standard.double(forKey: KeyStore.Defaults.speechSpeedPreset)
        self.speechSpeedPreset = savedSpeed > 0.1 ? savedSpeed : 1.0
        
        self.enableSelectionBubble = UserDefaults.standard.bool(forKey: KeyStore.Defaults.enableSelectionBubble)
        self.enableDoubleCmdCTrigger = UserDefaults.standard.bool(forKey: KeyStore.Defaults.enableDoubleCmdC)
        
        if UserDefaults.standard.object(forKey: KeyStore.Defaults.showInDock) == nil {
            self.showInDock = true
            UserDefaults.standard.set(true, forKey: KeyStore.Defaults.showInDock)
        } else {
            self.showInDock = UserDefaults.standard.bool(forKey: KeyStore.Defaults.showInDock)
        }
        let savedWorkspaceTab = UserDefaults.standard.string(forKey: KeyStore.Defaults.mainWorkspaceTab) ?? MainWorkspaceTab.translate.rawValue
        self.mainWorkspaceTab = MainWorkspaceTab(rawValue: savedWorkspaceTab) ?? .translate
        
        if #available(macOS 13.0, *) {
            self.launchAtLogin = SMAppService.mainApp.status == .enabled
        }
        
        
    }
    
    public func setShowMainWindowOnLaunch(_ enabled: Bool) {
        self.showMainWindowOnLaunch = enabled
        UserDefaults.standard.set(enabled, forKey: KeyStore.showMainWindowOnLaunch)
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
}
