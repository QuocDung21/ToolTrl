import AppIntents
import Defaults

/// Shortcuts-facing mirror of `TargetLanguage`.
///
/// Raw values are persisted by string inside saved shortcuts, so they intentionally reuse
/// the ISO codes of `TargetLanguage` and must never be renamed — only appended.
enum IntentTargetLanguage: String, AppEnum {
    case vietnamese = "vi"
    case english = "en"
    case japanese = "ja"
    case chinese = "zh"
    case chineseTraditional = "zh-Hant"
    case korean = "ko"
    case french = "fr"
    case german = "de"
    case spanish = "es"

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Ngôn ngữ đích"

    static let caseDisplayRepresentations: [IntentTargetLanguage: DisplayRepresentation] = [
        .vietnamese: "Tiếng Việt",
        .english: "Tiếng Anh",
        .japanese: "Tiếng Nhật",
        .chinese: "Tiếng Trung",
        .chineseTraditional: "Tiếng Trung (Phồn thể)",
        .korean: "Tiếng Hàn",
        .french: "Tiếng Pháp",
        .german: "Tiếng Đức",
        .spanish: "Tiếng Tây Ban Nha"
    ]

    /// Language currently selected in Settings, used when the shortcut leaves it empty.
    static var preferred: IntentTargetLanguage {
        IntentTargetLanguage(rawValue: Defaults[.targetLanguage]) ?? .vietnamese
    }
}
