import SwiftUI
import AppKit
import Defaults

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

    public var emojiIcon: String {
        switch self {
        case .general: return "🌐"
        case .technology: return "💻"
        case .business: return "📈"
        case .academic: return "🎓"
        case .medical: return "🏥"
        case .daily: return "☕"
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

    public var displayName: String {
        switch self {
        case .auto: return "Tự động (Nhanh nhất)"
        case .directAI: return "Trí tuệ nhân tạo (AI)"
        case .deepL: return "DeepL"
        case .googleWeb: return "Google Dịch"
        case .appleOffline: return "Apple Dịch (Offline)"
        }
    }

    public var shortName: String {
        switch self {
        case .auto: return "Tự động"
        case .directAI: return "AI"
        case .deepL: return "DeepL"
        case .googleWeb: return "Google"
        case .appleOffline: return "Apple Dịch"
        }
    }

    public var icon: String {
        switch self {
        case .auto: return "bolt.horizontal.fill"
        case .directAI: return "sparkles"
        case .deepL: return "d.circle.fill"
        case .googleWeb: return "g.circle.fill"
        case .appleOffline: return "apple.logo"
        }
    }

    public var emojiIcon: String {
        switch self {
        case .auto: return "⚡"
        case .directAI: return "✨"
        case .deepL: return "🅓"
        case .googleWeb: return "🅖"
        case .appleOffline: return ""
        }
    }
}

public enum DirectAIProvider: String, CaseIterable, Identifiable, Sendable {
    case openAI = "OpenAI (GPT-4o / mini)"
    case anthropic = "Anthropic Claude"
    case googleGemini = "Google Gemini"
    case groq = "Groq (Llama 3.3 Siêu tốc)"
    case deepSeek = "DeepSeek (V3 / R1)"
    case inProcessGGUF = "Mô hình GGUF Trực tiếp (Metal In-Process)"

    public var id: String { rawValue }

    public var defaultModel: String {
        switch self {
        case .openAI: return "gpt-4o-mini"
        case .anthropic: return "claude-3-5-haiku-20241022"
        case .googleGemini: return "gemini-1.5-flash"
        case .groq: return "llama-3.3-70b-versatile"
        case .deepSeek: return "deepseek-chat"
        case .inProcessGGUF: return "gguf-metal"
        }
    }
}

public enum TranslationDisplayMode: String, CaseIterable, Identifiable, Sendable {
    case standard = "Song ngữ (Bản gốc & Bản dịch)"
    case onlyTarget = "Chỉ hiển thị bản dịch"

    public var id: String { rawValue }

    public var shortName: String {
        switch self {
        case .standard: return "Song ngữ"
        case .onlyTarget: return "Chỉ dịch"
        }
    }

    public var icon: String {
        switch self {
        case .standard: return "rectangle.split.2x1"
        case .onlyTarget: return "text.alignleft"
        }
    }
}

public enum WordLookupMode: String, CaseIterable, Identifiable, Sendable {
    case quickTranslate = "quick"
    case dictionary = "dictionary"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .quickTranslate: return "bolt.fill"
        case .dictionary: return "book.closed.fill"
        }
    }

    public var emojiIcon: String {
        switch self {
        case .quickTranslate: return "⚡"
        case .dictionary: return "📖"
        }
    }

    public var title: String {
        switch self {
        case .quickTranslate: return "Dịch nhanh gọn"
        case .dictionary: return "Từ điển chi tiết"
        }
    }

    public var shortTitle: String {
        switch self {
        case .quickTranslate: return "Dịch gọn"
        case .dictionary: return "Từ điển"
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
    case translate = "translate"
    case notebookAll = "notebookAll"
    case notebookVocab = "notebookVocab"
    case notebookGrammar = "notebookGrammar"
    case notebookFavorites = "notebookFavorites"
    case notebookMastered = "notebookMastered"
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

/// The update channel determines which Sparkle appcast feed the app checks.
public enum UpdateChannel: String, CaseIterable, Identifiable, Codable, Sendable {
    case stable
    case beta
    case nightly
    case dev

    public var id: String { rawValue }

    public var feedURL: URL {
        switch self {
        case .stable:
            return URL(string: "https://raw.githubusercontent.com/QuocDung21/ToolTrl/main/Updates/appcast.xml")!
        case .beta:
            return URL(string: "https://raw.githubusercontent.com/QuocDung21/ToolTrl/main/Updates/appcast-beta.xml")!
        case .nightly, .dev:
            return URL(string: "https://raw.githubusercontent.com/QuocDung21/ToolTrl/main/Updates/appcast-nightly.xml")!
        }
    }

    public var badgeColor: NSColor {
        switch self {
        case .stable:  return .systemGreen
        case .beta:    return .systemBlue
        case .nightly: return .systemPurple
        case .dev:     return .systemYellow
        }
    }

    public var badgeIcon: String {
        switch self {
        case .stable:  return "checkmark.seal.fill"
        case .beta:    return "testtube.2"
        case .nightly: return "moon.stars.fill"
        case .dev:     return "hammer.fill"
        }
    }

    public static var buildChannel: UpdateChannel {
        #if DEBUG
        return .dev
        #else
        return .stable
        #endif
    }

    public static var availableChannels: [UpdateChannel] {
        UpdateChannel.allCases.filter { $0 != .dev }
    }
}

public enum TargetLanguage: String, CaseIterable, Identifiable, Sendable {
    case vietnamese = "vi"
    case english = "en"
    case japanese = "ja"
    case chinese = "zh"
    case chineseTraditional = "zh-Hant"
    case korean = "ko"
    case french = "fr"
    case german = "de"
    case spanish = "es"

    public var id: String { rawValue }

    public var voiceLocaleCode: String {
        switch self {
        case .vietnamese: return "vi-VN"
        case .english: return "en-US"
        case .japanese: return "ja-JP"
        case .chinese: return "zh-CN"
        case .chineseTraditional: return "zh-TW"
        case .korean: return "ko-KR"
        case .french: return "fr-FR"
        case .german: return "de-DE"
        case .spanish: return "es-ES"
        }
    }

    public var displayName: String {
        let currentAppLang = Defaults[.appLanguage] ?? AppLanguage.resolved(preferredLanguages: Locale.preferredLanguages)
        switch currentAppLang {
        case .vietnamese:
            switch self {
            case .vietnamese: return "Tiếng Việt"
            case .english: return "Tiếng Anh"
            case .japanese: return "Tiếng Nhật"
            case .chinese: return "Tiếng Trung (Giản thể)"
            case .chineseTraditional: return "Tiếng Trung (Phồn thể)"
            case .korean: return "Tiếng Hàn"
            case .french: return "Tiếng Pháp"
            case .german: return "Tiếng Đức"
            case .spanish: return "Tiếng Tây Ban Nha"
            }
        case .chineseSimplified:
            switch self {
            case .vietnamese: return "越南语"
            case .english: return "英语"
            case .japanese: return "日语"
            case .chinese: return "简体中文"
            case .chineseTraditional: return "繁体中文"
            case .korean: return "韩语"
            case .french: return "法语"
            case .german: return "德语"
            case .spanish: return "西班牙语"
            }
        case .chineseTraditional:
            switch self {
            case .vietnamese: return "越南語"
            case .english: return "英語"
            case .japanese: return "日語"
            case .chinese: return "簡體中文"
            case .chineseTraditional: return "繁體中文"
            case .korean: return "韓語"
            case .french: return "法語"
            case .german: return "德語"
            case .spanish: return "西班牙語"
            }
        case .english:
            switch self {
            case .vietnamese: return "Vietnamese"
            case .english: return "English"
            case .japanese: return "Japanese"
            case .chinese: return "Chinese (Simplified)"
            case .chineseTraditional: return "Chinese (Traditional)"
            case .korean: return "Korean"
            case .french: return "French"
            case .german: return "German"
            case .spanish: return "Spanish"
            }
        }
    }

    public var flag: String {
        switch self {
        case .vietnamese: return "🇻🇳"
        case .english: return "🇬🇧"
        case .japanese: return "🇯🇵"
        case .chinese: return "🇨🇳"
        case .chineseTraditional: return "🇹🇼"
        case .korean: return "🇰🇷"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .spanish: return "🇪🇸"
        }
    }

    public var displayNameWithFlag: String {
        "\(flag)  \(displayName)"
    }
}

public enum AppIconType: String, CaseIterable, Identifiable, Codable, Sendable {
    case defaultCat = "Mèo Cam (Mặc định)"
    case aiSparkle = "✨ AI Sparkle"
    case bolt = "⚡ Tia Chớp"
    case book = "📖 Sách Tri Thức"
    case globe = "🌐 Quả Cầu Dịch"
    case rocket = "🚀 Tên Lửa"
    case diamond = "💎 Kim Cương"
    case custom = "📁 Ảnh Tự Chọn"

    public var id: String { rawValue }

    public var sfSymbol: String? {
        switch self {
        case .defaultCat: return nil
        case .aiSparkle: return "sparkles"
        case .bolt: return "bolt.fill"
        case .book: return "character.book.closed.fill"
        case .globe: return "globe.americas.fill"
        case .rocket: return "rocket.fill"
        case .diamond: return "diamond.fill"
        case .custom: return nil
        }
    }

    public var accentColor: Color {
        switch self {
        case .defaultCat: return .orange
        case .aiSparkle: return .purple
        case .bolt: return .yellow
        case .book: return .blue
        case .globe: return .cyan
        case .rocket: return .red
        case .diamond: return .indigo
        case .custom: return .green
        }
    }
}

public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case vietnamese         = "vi"
    case english            = "en"
    case chineseSimplified  = "zh-Hans"
    case chineseTraditional = "zh-Hant"

    public var id: String { rawValue }

    public var nativeName: String {
        switch self {
        case .vietnamese:         "Tiếng Việt"
        case .english:            "English"
        case .chineseSimplified:  "简体中文"
        case .chineseTraditional: "繁體中文"
        }
    }

    public var flag: String {
        switch self {
        case .vietnamese:         "🇻🇳"
        case .english:            "🇺🇸"
        case .chineseSimplified:  "🇨🇳"
        case .chineseTraditional: "🇹🇼"
        }
    }

    public var locale: Locale {
        Locale(identifier: rawValue)
    }

    public var layoutDirection: LayoutDirection {
        .leftToRight
    }

    public var nsLayoutDirection: NSUserInterfaceLayoutDirection {
        .leftToRight
    }

    public static func resolved(preferredLanguages: [String]) -> AppLanguage {
        for identifier in preferredLanguages {
            if let match = match(identifier) {
                return match
            }
        }
        return .english
    }

    public static func match(_ identifier: String) -> AppLanguage? {
        let normalized = identifier
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()

        if normalized == "zh-hant" || normalized.hasPrefix("zh-hant-")
            || normalized == "zh-tw" || normalized.hasPrefix("zh-tw-")
            || normalized == "zh-hk" || normalized.hasPrefix("zh-hk-")
            || normalized == "zh-mo" || normalized.hasPrefix("zh-mo-") {
            return .chineseTraditional
        }

        if normalized == "zh-hans" || normalized.hasPrefix("zh-hans-")
            || normalized == "zh-cn" || normalized.hasPrefix("zh-cn-")
            || normalized == "zh-sg" || normalized.hasPrefix("zh-sg-")
            || normalized == "zh" {
            return .chineseSimplified
        }

        return allCases.first { language in
            let raw = language.rawValue.lowercased()
            return normalized == raw || normalized.hasPrefix("\(raw)-")
        }
    }
}

public enum AppAppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"

    public var id: String { rawValue }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    public var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light:  return NSAppearance(named: .aqua)
        case .dark:   return NSAppearance(named: .darkAqua)
        }
    }

    public var sfSymbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.stars.fill"
        }
    }
}

public enum AppAccentTheme: String, CaseIterable, Identifiable, Sendable {
    case oceanBlue = "ocean_blue"
    case nekoAmber = "neko_amber"
    case sakuraPink = "sakura_pink"
    case emerald = "emerald"
    case royalIndigo = "royal_indigo"
    case graphite = "graphite"

    public var id: String { rawValue }

    public var color: Color {
        switch self {
        case .oceanBlue:
            return Color(nsColor: NSColor(name: nil, dynamicProvider: { ap in
                ap.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                    ? NSColor(red: 0.25, green: 0.62, blue: 1.0, alpha: 1.0)
                    : NSColor(red: 0.0, green: 0.46, blue: 0.96, alpha: 1.0)
            }))
        case .nekoAmber:
            return Color(nsColor: NSColor(name: nil, dynamicProvider: { ap in
                ap.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                    ? NSColor(red: 1.0, green: 0.60, blue: 0.18, alpha: 1.0)
                    : NSColor(red: 0.90, green: 0.42, blue: 0.04, alpha: 1.0)
            }))
        case .sakuraPink:
            return Color(nsColor: NSColor(name: nil, dynamicProvider: { ap in
                ap.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                    ? NSColor(red: 1.0, green: 0.44, blue: 0.66, alpha: 1.0)
                    : NSColor(red: 0.86, green: 0.20, blue: 0.48, alpha: 1.0)
            }))
        case .emerald:
            return Color(nsColor: NSColor(name: nil, dynamicProvider: { ap in
                ap.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                    ? NSColor(red: 0.20, green: 0.82, blue: 0.56, alpha: 1.0)
                    : NSColor(red: 0.06, green: 0.60, blue: 0.38, alpha: 1.0)
            }))
        case .royalIndigo:
            return Color(nsColor: NSColor(name: nil, dynamicProvider: { ap in
                ap.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                    ? NSColor(red: 0.58, green: 0.50, blue: 1.0, alpha: 1.0)
                    : NSColor(red: 0.36, green: 0.28, blue: 0.88, alpha: 1.0)
            }))
        case .graphite:
            return Color(nsColor: NSColor(name: nil, dynamicProvider: { ap in
                ap.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                    ? NSColor(red: 0.78, green: 0.80, blue: 0.84, alpha: 1.0)
                    : NSColor(red: 0.28, green: 0.31, blue: 0.36, alpha: 1.0)
            }))
        }
    }
}

public enum HUDMaterialStyle: String, CaseIterable, Identifiable, Sendable {
    case frostedPopover = "popover"
    case deepHUDGlass   = "hud_window"
    case ultraClean     = "sidebar"

    public var id: String { rawValue }

    public var nsMaterial: NSVisualEffectView.Material {
        switch self {
        case .frostedPopover: return .popover
        case .deepHUDGlass:   return .hudWindow
        case .ultraClean:     return .sidebar
        }
    }

    public var tintOverlayOpacity: Double {
        switch self {
        case .frostedPopover: return 0.52
        case .deepHUDGlass:   return 0.68
        case .ultraClean:     return 0.78
        }
    }
}

public enum SelectionPopupStyle: String, CaseIterable, Identifiable, Sendable {
    case instantTranslation = "instant_translation"
    case actionBar          = "action_bar"
    case iconBubble         = "icon_bubble"

    public var id: String { rawValue }

    public var sfSymbol: String {
        switch self {
        case .instantTranslation: return "bolt.horizontal.circle.fill"
        case .actionBar:          return "menubar.rectangle"
        case .iconBubble:         return "character.bubble.fill"
        }
    }
}

extension TranslationDomain: Defaults.Serializable {}
extension TranslationEngine: Defaults.Serializable {}
extension DirectAIProvider: Defaults.Serializable {}
extension TranslationDisplayMode: Defaults.Serializable {}
extension WordLookupMode: Defaults.Serializable {}
extension QuitActionPreference: Defaults.Serializable {}
extension AppFontSize: Defaults.Serializable {}
extension MainWorkspaceTab: Defaults.Serializable {}
extension WorkspaceSidebarItem: Defaults.Serializable {}
extension UpdateChannel: Defaults.Serializable {}
extension TargetLanguage: Defaults.Serializable {}
extension AppIconType: Defaults.Serializable {}
extension AppLanguage: Defaults.Serializable {}
extension AppAppearanceMode: Defaults.Serializable {}
extension AppAccentTheme: Defaults.Serializable {}
extension HUDMaterialStyle: Defaults.Serializable {}
extension SelectionPopupStyle: Defaults.Serializable {}


