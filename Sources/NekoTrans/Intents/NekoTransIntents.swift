import AppIntents
import Foundation

/// Errors surfaced to Shortcuts / Siri. Conforming to
/// `CustomLocalizedStringResourceConvertible` is what makes the system show a real message.
enum NekoIntentError: Error, CustomLocalizedStringResourceConvertible {
    case emptyText
    case translationFailed
    case notebookEmpty

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .emptyText: return "Văn bản trống, không có gì để dịch."
        case .translationFailed: return "Không dịch được văn bản. Kiểm tra kết nối mạng hoặc engine dịch trong Cài đặt."
        case .notebookEmpty: return "Sổ tay chưa có từ nào."
        }
    }
}

// MARK: - Translate (background)

/// Translates text headlessly and returns the result, so it can be chained in Shortcuts
/// (e.g. "Get clipboard → Translate with NekoTrans → Copy to clipboard").
struct TranslateTextIntent: AppIntent {
    static let title: LocalizedStringResource = "Dịch văn bản"
    static let description = IntentDescription(
        "Dịch văn bản bằng engine đang chọn trong NekoTrans và trả về kết quả.",
        categoryName: "Dịch thuật"
    )

    @Parameter(title: "Văn bản", inputOptions: String.IntentInputOptions(multiline: true))
    var text: String

    @Parameter(title: "Dịch sang")
    var targetLanguage: IntentTargetLanguage?

    static var parameterSummary: some ParameterSummary {
        Summary("Dịch \(\.$text) sang \(\.$targetLanguage)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw NekoIntentError.emptyText }

        let target = targetLanguage ?? .preferred
        guard let result = await TranslationService.shared.translate(text: trimmed, to: target.rawValue),
              !result.isEmpty else {
            throw NekoIntentError.translationFailed
        }
        return .result(value: result, dialog: "\(result)")
    }
}

// MARK: - Translate in HUD (foreground)

/// Opens the NekoTrans translation HUD for the given text.
struct ShowTranslationHUDIntent: AppIntent {
    static let title: LocalizedStringResource = "Dịch trong cửa sổ NekoTrans"
    static let description = IntentDescription(
        "Mở bảng dịch nổi (HUD) của NekoTrans với văn bản đã cho, kèm từ điển và phát âm.",
        categoryName: "Dịch thuật"
    )
    static let openAppWhenRun = true

    @Parameter(title: "Văn bản", inputOptions: String.IntentInputOptions(multiline: true))
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw NekoIntentError.emptyText }
        AppDelegate.shared?.triggerTranslationWithText(trimmed)
        return .result()
    }
}

// MARK: - Save word

/// Saves a word (or phrase) into the NekoTrans notebook. If no meaning is given the word
/// is translated first. The write happens last so a parameter re-prompt can't duplicate it.
struct SaveWordIntent: AppIntent {
    static let title: LocalizedStringResource = "Lưu từ vào sổ tay"
    static let description = IntentDescription(
        "Lưu một từ hoặc cụm từ vào sổ tay NekoTrans. Tự động dịch nếu bỏ trống nghĩa.",
        categoryName: "Sổ tay"
    )

    @Parameter(title: "Từ / Cụm từ")
    var word: String

    @Parameter(title: "Nghĩa")
    var meaning: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Lưu \(\.$word) vào sổ tay") {
            \.$meaning
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<VocabularyEntity> & ProvidesDialog {
        let cleanWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanWord.isEmpty else { throw NekoIntentError.emptyText }

        var resolvedMeaning = meaning?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if resolvedMeaning.isEmpty {
            resolvedMeaning = await TranslationService.shared.translate(
                text: cleanWord,
                to: IntentTargetLanguage.preferred.rawValue
            ) ?? ""
        }
        let finalMeaning = resolvedMeaning

        // Idempotent: `addWord` merges into an existing entry with the same title.
        let inferredPhonetic = PinyinConverter.toPinyin(cleanWord)
        let entity: VocabularyEntity? = await MainActor.run {
            let service = VocabularyService.shared
            guard let id = service.addWord(
                word: cleanWord,
                phonetic: inferredPhonetic,
                translation: finalMeaning
            ),
                  let item = service.savedWords.first(where: { $0.id == id }) else { return nil }
            return VocabularyEntity(item: item)
        }
        guard let entity else { throw NekoIntentError.emptyText }
        return .result(value: entity, dialog: "Đã lưu \"\(entity.word)\": \(entity.translation)")
    }
}

// MARK: - Random review word

/// Returns a random due-for-review notebook entry, handy for a daily-review shortcut.
struct ReviewRandomWordIntent: AppIntent {
    static let title: LocalizedStringResource = "Ôn một từ ngẫu nhiên"
    static let description = IntentDescription(
        "Lấy ngẫu nhiên một từ cần ôn tập trong sổ tay NekoTrans để ôn tập.",
        categoryName: "Sổ tay"
    )

    func perform() async throws -> some IntentResult & ReturnsValue<VocabularyEntity> & ProvidesDialog {
        let entity: VocabularyEntity? = await MainActor.run {
            let service = VocabularyService.shared
            let words = service.savedWords
            let duePool = service.dueForReviewWords
            let pool = duePool.isEmpty ? words.filter { !$0.isMastered } : duePool
            return (pool.isEmpty ? words : pool).randomElement().map(VocabularyEntity.init(item:))
        }
        guard let entity else { throw NekoIntentError.notebookEmpty }

        var line = entity.word
        if let phonetic = entity.phonetic, !phonetic.isEmpty, !entity.isGrammar {
            line += " \(phonetic)"
        }
        return .result(value: entity, dialog: "\(line) — \(entity.translation)")
    }
}

// MARK: - Open notebook

/// Opens the notebook in the main NekoTrans window.
struct OpenNotebookIntent: AppIntent {
    static let title: LocalizedStringResource = "Mở sổ tay NekoTrans"
    static let description = IntentDescription(
        "Mở cửa sổ sổ tay từ vựng và ngữ pháp của NekoTrans.",
        categoryName: "Sổ tay"
    )
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        MainWindowController.shared.showMainWindow(initialTab: .notebook)
        return .result()
    }
}

// MARK: - Ask AI

/// Opens the Quick AI assistant, optionally pre-filled with a prompt.
struct AskQuickAIIntent: AppIntent {
    static let title: LocalizedStringResource = "Hỏi AI với NekoTrans"
    static let description = IntentDescription(
        "Mở trợ lý AI nhanh của NekoTrans, có thể điền sẵn câu hỏi.",
        categoryName: "AI"
    )
    static let openAppWhenRun = true

    @Parameter(title: "Câu hỏi", inputOptions: String.IntentInputOptions(multiline: true))
    var prompt: String?

    @MainActor
    func perform() async throws -> some IntentResult {
        let trimmed = prompt?.trimmingCharacters(in: .whitespacesAndNewlines)
        QuickAIWindowController.shared.showAI(prompt: (trimmed?.isEmpty ?? true) ? nil : trimmed)
        return .result()
    }
}
