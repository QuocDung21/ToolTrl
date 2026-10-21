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

    public var title: String {
        switch self {
        case .quickTranslate: return "Dịch nhanh (Gọn)"
        case .dictionary: return "Tra từ điển (Chi tiết)"
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
    case korean = "ko"
    case french = "fr"
    case german = "de"
    case spanish = "es"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .vietnamese: return "Tiếng Việt (vi)"
        case .english: return "Tiếng Anh (en)"
        case .japanese: return "Tiếng Nhật (ja)"
        case .chinese: return "Tiếng Trung (zh)"
        case .korean: return "Tiếng Hàn (ko)"
        case .french: return "Tiếng Pháp (fr)"
        case .german: return "Tiếng Đức (de)"
        case .spanish: return "Tiếng Tây Ban Nha (es)"
        }
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
    case vietnamese = "vi"
    case english    = "en"

    public var id: String { rawValue }

    public var nativeName: String {
        switch self {
        case .vietnamese: "Tiếng Việt"
        case .english:    "English"
        }
    }

    public var flag: String {
        switch self {
        case .vietnamese: "🇻🇳"
        case .english:    "🇺🇸"
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

        return allCases.first { language in
            let raw = language.rawValue.lowercased()
            return normalized == raw || normalized.hasPrefix("\(raw)-")
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
