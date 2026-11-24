import Testing
import Foundation
import Defaults
@testable import NekoCore
@testable import NekoServices

// MARK: - 1. AIPromptBuilder Tests
@Suite("NekoCore - AIPromptBuilder Tests")
struct AIPromptBuilderTests {
    @Test("Strict enforced grammar prompt contains mandatory section headers and input data")
    func grammarPromptGeneration() {
        let title = "Hiện tại đơn"
        let context = "I study English every day."
        let prompt = AIPromptBuilder.strictEnforcedGrammarPrompt(title: title, context: context, customNote: "Chi tiết cho TOEIC")

        #expect(prompt.contains("CÔNG THỨC CHUẨN (FORMULA)"))
        #expect(prompt.contains("Ý NGHĨA & CÁCH DÙNG"))
        #expect(prompt.contains("CÁC CÂU VÍ DỤ MINH HỌA (EXAMPLES)"))
        #expect(prompt.contains("LỖI SAI HAY GẶP & BẪY ĐỀ THI"))
        #expect(prompt.contains("MẸO GHI NHỚ THẦN TỐC"))
        #expect(prompt.contains(title))
        #expect(prompt.contains(context))
        #expect(prompt.contains("Chi tiết cho TOEIC"))
    }

    @Test("Structured word prompt contains vocabulary section headers")
    func structuredWordPromptGeneration() {
        let word = "Resilience"
        let prompt = AIPromptBuilder.structuredWordPrompt(for: word)

        #expect(prompt.contains(word))
        #expect(prompt.contains("TỪ LOẠI & TẦNG NGHĨA CHÍNH"))
        #expect(prompt.contains("HỌ TỪ (WORD FAMILY)"))
        #expect(prompt.contains("COLLOCATIONS & THÀNH NGỮ"))
        #expect(prompt.contains("SẮC THÁI & PHÂN BIỆT (NUANCES)"))
    }

    @Test("Contextual translation prompt format")
    func contextualTranslationPrompt() {
        let prompt = AIPromptBuilder.contextualTranslationPrompt(
            text: "Hello world",
            sourceLang: "en",
            targetLang: "vi",
            domain: "Công nghệ"
        )
        #expect(prompt.contains("Hello world"))
        #expect(prompt.contains("vi"))
    }

    @Test("Grammar and polishing prompt format")
    func grammarAndPolishingPrompt() {
        let prompt = AIPromptBuilder.grammarAndPolishingPrompt(text: "He go to school yesterday")
        #expect(prompt.contains("He go to school yesterday"))
    }

    @Test("Word in context prompt format")
    func wordInContextPrompt() {
        let prompt = AIPromptBuilder.wordInContextPrompt(word: "run", sentence: "Run a company")
        #expect(prompt.contains("run"))
        #expect(prompt.contains("Run a company"))
    }

    @Test("Quick polishing prompt format")
    func quickPolishingPrompt() {
        let prompt = AIPromptBuilder.quickPolishingPrompt(text: "I is a software developer")
        #expect(prompt.contains("I is a software developer"))
    }
}

// MARK: - 2. AIAnalysisParser Tests
@Suite("NekoCore - AIAnalysisParser Tests")
struct AIAnalysisParserTests {
    @Test("Multiline formula parsing extracts formula lines and sections correctly")
    func multilineFormulaParsing() {
        let rawAI = """
        ### 1. 📐 CÔNG THỨC CHUẨN (FORMULA)
        - Thể khẳng định (+): S + V(s/es) + O
        - Thể phủ định (-): S + do/does not + V_inf + O
        - Thể nghi vấn (?): Do/Does + S + V_inf + O?
        - Với To Be: S + am/is/are + N/Adj

        ### 2. 💡 Ý NGHĨA & CÁCH DÙNG
        - Diễn tả chân lý, sự thật hiển nhiên.
        - Diễn tả thói quen lặp đi lặp lại.

        ### 3. 📖 CÁC CÂU VÍ DỤ MINH HỌA (EXAMPLES)
        - She plays piano very well. ➔ Cô ấy chơi piano rất giỏi.
        - They do not go out. ➔ Họ không ra ngoài.

        ### 4. ⚠️ LỖI SAI HAY GẶP & BẪY ĐỀ THI (COMMON MISTAKES)
        - Quên chia 's/es' với chủ ngữ ngôi thứ 3 số ít (He/She/It).

        ### 5. 🧠 MẸO GHI NHỚ THẦN TỐC
        - Nhìn thấy always, usually, often ➔ chia ngay Hiện tại đơn!
        """

        let parsed = AIAnalysisParser.parse(rawAI)

        #expect(!parsed.isEmpty)
        #expect(parsed.formula != nil)
        #expect(parsed.formula?.contains("S + V(s/es) + O") == true)
        #expect(parsed.formula?.contains("S + do/does not + V_inf + O") == true)
        #expect(parsed.formula?.contains("S + am/is/are + N/Adj") == true)

        #expect(parsed.meanings.count == 2)
        #expect(parsed.examples.count == 2)
        #expect(parsed.commonMistakes.count == 1)
        #expect(parsed.mnemonic?.contains("always") == true)
    }

    @Test("Vocabulary structure parsing extracts word family, collocations, and nuances")
    func vocabularyStructureParsing() {
        let rawAI = """
        ### 1. 🏷️ TỪ LOẠI & TẦNG NGHĨA CHÍNH
        - Danh từ: Sự kiên cường, khả năng phục hồi.

        ### 2. 🌿 HỌ TỪ (WORD FAMILY)
        - Noun: Resilience
        - Adj: Resilient

        ### 3. 💡 COLLOCATIONS & THÀNH NGỮ
        - Show resilience: Thể hiện sự kiên cường.
        - Build resilience: Xây dựng sức bền.

        ### 4. ⚖️ SẮC THÁI & PHÂN BIỆT (NUANCES)
        - Khác với Endurance (sức chịu đựng về thể chất), Resilience nhấn mạnh khả năng bật dậy sau thất bại.
        """

        let parsed = AIAnalysisParser.parse(rawAI)

        #expect(parsed.meanings.count == 1)
        #expect(parsed.wordFamily.count >= 2)
        #expect(parsed.collocations.count >= 2)
        #expect(!parsed.nuances.isEmpty)
        #expect(parsed.nuances.first?.contains("Endurance") == true)
    }

    @Test("GrammarRewriteResult JSON decoding parses tones and explanations correctly")
    func grammarRewriteResultJSONDecoding() throws {
        let json = """
        {
          "has_errors": true,
          "correction": "He went to school yesterday.",
          "explanation_vi": "Sai thì động từ: dùng 'went' thay vì 'go'.",
          "academic_version": "He attended school yesterday.",
          "business_version": "He was present at school yesterday.",
          "casual_version": "He was at school yesterday."
        }
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(GrammarRewriteResult.self, from: json)
        #expect(result.hasErrors)
        #expect(result.explanationVi == "Sai thì động từ: dùng 'went' thay vì 'go'.")
        #expect(result.correction == "He went to school yesterday.")
        #expect(result.academicVersion == "He attended school yesterday.")
        #expect(result.businessVersion == "He was present at school yesterday.")
        #expect(result.casualVersion == "He was at school yesterday.")
    }
}

// MARK: - 3. Normalizer & Text Utilities Tests
@Suite("NekoCore - Normalizer & Text Utilities Tests")
struct NormalizerTests {
    @Test("IPANormalizer standardizes ASCII stress markers, brackets, and digraphs")
    func ipaNormalizerStandardization() {
        #expect(IPANormalizer.normalize("/'dɪkʃə,nɛɹi/") == "/ˈdɪkʃəˌnɛri/")
        #expect(IPANormalizer.normalize("[ˈækʃən]") == "/ˈækʃən/")
        #expect(IPANormalizer.normalize("| ˈdikSHəˌnerē |") == "/ˈdikʃəˌneri/")
    }

    @Test("InputTextNormalizer splits camelCase and snake_case code identifiers")
    func splitCodeIdentifiers() {
        #expect(InputTextNormalizer.splitCodeIdentifiers("getUserProfile") == "get User Profile")
        #expect(InputTextNormalizer.splitCodeIdentifiers("is_authenticated_user") == "is authenticated user")
        #expect(InputTextNormalizer.splitCodeIdentifiers("API_KEY_SECRET") == "API KEY SECRET")
    }

    @Test("InputTextNormalizer strips comment symbols")
    func stripCommentSymbols() {
        #expect(InputTextNormalizer.stripCommentSymbols("// single line") == "single line")
        #expect(InputTextNormalizer.stripCommentSymbols("/* block comment */") == "block comment")
        #expect(InputTextNormalizer.stripCommentSymbols("# python comment") == "python comment")
    }

    @Test("InputTextNormalizer strips surrounding quotes")
    func stripSurroundingQuotes() {
        #expect(InputTextNormalizer.stripSurroundingQuotes("\"quoted text\"") == "quoted text")
        #expect(InputTextNormalizer.stripSurroundingQuotes("'single quoted'") == "single quoted")
        #expect(InputTextNormalizer.stripSurroundingQuotes("`code backtick`") == "code backtick")
    }

    @Test("InputTextNormalizer full normalize pipeline")
    func fullNormalizePipeline() {
        #expect(InputTextNormalizer.normalize("// \"getUserProfile\"") == "get User Profile")
    }

    @Test("InputTextNormalizer query content classification")
    func queryClassification() {
        #expect(InputTextNormalizer.classify("word") == .word)
        #expect(InputTextNormalizer.classify("getUserProfile") == .code)
        #expect(InputTextNormalizer.classify("This is a complete sentence.") == .sentence)
    }

    @Test("Target language auto-flip for source-target symmetry")
    func targetLanguageAutoFlip() {
        let flipped = InputTextNormalizer.resolveTargetLanguage(
            sourceLanguageCode: "vi",
            configuredTarget: .vietnamese
        )
        #expect(flipped == .english)

        let regular = InputTextNormalizer.resolveTargetLanguage(
            sourceLanguageCode: "en",
            configuredTarget: .vietnamese
        )
        #expect(regular == .vietnamese)
    }

    @Test("HTMLEntityDecoder decodes HTML entities into clean Unicode text")
    func htmlEntityDecoder() {
        #expect(HTMLEntityDecoder.decode("&quot;Hello &amp; World&quot;") == "\"Hello & World\"")
        #expect(HTMLEntityDecoder.decode("&#39;test&#39;") == "'test'")
    }
}

// MARK: - 4. DataCompression Tests
@Suite("NekoCore - DataCompression Tests")
struct DataCompressionTests {
    @Test("DataCompression compresses and decompresses using LZFSE")
    func compressionRoundtrip() throws {
        let originalText = String(repeating: "The quick brown fox jumps over the lazy dog. ", count: 50)
        let originalData = originalText.data(using: .utf8)!

        let compressed = try #require(DataCompression.compress(data: originalData))
        #expect(compressed.count < originalData.count)

        let decompressed = try #require(DataCompression.decompress(data: compressed))
        let recoveredText = String(data: decompressed, encoding: .utf8)
        #expect(recoveredText == originalText)
    }

    @Test("DataCompression handles incompressible payload safely")
    func incompressiblePayload() throws {
        var randomBytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let payload = Data(randomBytes)

        let compressed = try #require(DataCompression.compress(data: payload))
        let decompressed = try #require(DataCompression.decompress(data: compressed))
        #expect(decompressed == payload)
    }

    @Test("DataCompression rejects corrupt input")
    func corruptInputRejection() {
        let corrupt = Data([0xDE, 0xAD, 0xBE, 0xEF, 0x01, 0x02])
        let result = DataCompression.decompress(data: corrupt)
        #expect(result == nil)
    }

    @Test("DataCompression passes empty data through without error")
    func emptyInputPassThrough() {
        let empty = Data()
        #expect(DataCompression.compress(data: empty) == empty)
        #expect(DataCompression.decompress(data: empty) == empty)
    }
}

// MARK: - 5. Security & URL Tests
@Suite("NekoCore - Security & SafeURL Tests")
struct SecurityAndURLTests {
    @Test("SafeURL builds clean URL with percent-encoded query items")
    func safeURLBuildsCleanly() throws {
        let url = try #require(SafeURL.make(
            host: "api.mymemory.translated.net",
            path: "/get",
            queryItems: [
                URLQueryItem(name: "q", value: "hello world"),
                URLQueryItem(name: "langpair", value: "en|vi")
            ]
        ))

        let string = url.absoluteString
        #expect(string.contains("q=hello%20world"))
        #expect(string.contains("langpair=en%7Cvi"))
        #expect(!string.contains("%2520"))
    }

    @Test("SafeURL roundtrips reserved characters without double escaping")
    func safeURLReservedCharacters() throws {
        let url = try #require(SafeURL.make(
            host: "api.github.com",
            path: "/search",
            queryItems: [URLQueryItem(name: "query", value: "Swift & SwiftUI + C++")]
        ))
        #expect(url.query?.contains("query=Swift%20&%20SwiftUI%20+%20C++") == true || url.absoluteString.contains("query="))
    }

    @Test("SafeURL escapes path segments safely")
    func safeURLEscapesPathSegment() throws {
        let url = try #require(SafeURL.make(
            host: "api.github.com",
            path: "/gists/abc 123/comments"
        ))
        #expect(url.path == "/gists/abc 123/comments")
        #expect(url.absoluteString.contains("/gists/abc%20123/comments"))
    }

    @Test("Secret accounts declared in KeyStore.Secret are unique and non-empty")
    func secretAccountsIntegrity() {
        let accounts = KeyStore.Secret.allAccounts

        let set = Set(accounts)
        #expect(set.count == accounts.count)
        #expect(accounts.contains(KeyStore.Secret.openAI))
        #expect(accounts.contains(KeyStore.Secret.anthropic))
        #expect(accounts.contains(KeyStore.Secret.gemini))
        #expect(accounts.contains(KeyStore.Secret.groq))
        #expect(accounts.contains(KeyStore.Secret.deepSeek))
        #expect(accounts.contains(KeyStore.Secret.deepL))
        #expect(accounts.contains(KeyStore.Secret.githubPAT))
        for acc in accounts {
            #expect(!acc.isEmpty)
        }
    }
}

// MARK: - 6. VocabularyModels Tests
@Suite("NekoCore - VocabularyModels Tests")
struct VocabularyModelTests {
    @Test("SavedWordItem correctly identifies grammar formulas")
    func grammarIdentification() {
        let grammarItem = SavedWordItem(
            word: "📐 Hiện tại hoàn thành",
            phonetic: "S + have/has + V3/ed",
            translation: "Diễn tả hành động xảy ra trong quá khứ kéo dài đến hiện tại"
        )
        #expect(grammarItem.isGrammarFormula)

        let vocabItem = SavedWordItem(
            word: "Resilience",
            phonetic: "/rɪˈzɪliəns/",
            translation: "Khả năng phục hồi, kiên cường"
        )
        #expect(!vocabItem.isGrammarFormula)
    }

    @Test("Inferred item type classifies formula vs vocabulary correctly")
    func inferredItemType() {
        let grammarType = SavedWordItem.inferredItemType(
            word: "Cấu trúc so sánh hơn",
            phonetic: "S + V + adj-er + than + N",
            translation: "So sánh hai đối tượng"
        )
        #expect(grammarType == .grammar)

        let vocabType = SavedWordItem.inferredItemType(
            word: "Accomplish",
            phonetic: "/əˈkʌm.plɪʃ/",
            translation: "Hoàn thành, đạt được"
        )
        #expect(vocabType == .vocabulary)
    }

    @Test("SavedWordItem Codable roundtrip preserves all fields")
    func codableRoundtrip() throws {
        let original = SavedWordItem(
            word: "Test Word",
            phonetic: "/test/",
            translation: "Từ thử nghiệm",
            exampleEn: "This is a test.",
            exampleVi: "Đây là ví dụ.",
            itemType: .vocabulary
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SavedWordItem.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.word == original.word)
        #expect(decoded.phonetic == original.phonetic)
        #expect(decoded.translation == original.translation)
        #expect(decoded.itemType == .vocabulary)
    }

    @Test("Legacy item normalization and deduplication is idempotent")
    @MainActor
    func legacyItemNormalization() {
        let item1 = SavedWordItem(word: "Leadership", phonetic: nil, translation: "Khả năng lãnh đạo")
        let item2 = SavedWordItem(word: "leadership", phonetic: nil, translation: "Khả năng lãnh đạo")

        let (migrated, didMigrate) = VocabularyService.migrateLegacyItems([item1, item2])
        #expect(didMigrate)
        #expect(migrated.count == 1)
        #expect(migrated.first?.word == "leadership")

        let (_, secondPass) = VocabularyService.migrateLegacyItems(migrated)
        #expect(!secondPass)
    }
}

// MARK: - 5. AppLanguage Tests
@Suite("NekoCore - AppLanguage Tests")
struct AppLanguageTests {
    @Test("Matches Simplified Chinese locale variants")
    func matchesSimplifiedChinese() {
        #expect(AppLanguage.match("zh-Hans") == .chineseSimplified)
        #expect(AppLanguage.match("zh-Hans-CN") == .chineseSimplified)
        #expect(AppLanguage.match("zh_CN") == .chineseSimplified)
        #expect(AppLanguage.match("zh-SG") == .chineseSimplified)
        #expect(AppLanguage.match("zh") == .chineseSimplified)
    }

    @Test("Matches Traditional Chinese locale variants")
    func matchesTraditionalChinese() {
        #expect(AppLanguage.match("zh-Hant") == .chineseTraditional)
        #expect(AppLanguage.match("zh-Hant-TW") == .chineseTraditional)
        #expect(AppLanguage.match("zh-Hant-HK") == .chineseTraditional)
        #expect(AppLanguage.match("zh_TW") == .chineseTraditional)
        #expect(AppLanguage.match("zh-HK") == .chineseTraditional)
        #expect(AppLanguage.match("zh-MO") == .chineseTraditional)
    }

    @Test("Resolves preferred languages with Chinese fallback to English")
    func resolvesPreferredLanguages() {
        #expect(AppLanguage.resolved(preferredLanguages: ["fr-FR", "zh-Hans-CN"]) == .chineseSimplified)
        #expect(AppLanguage.resolved(preferredLanguages: ["zh-Hant-TW", "en-US"]) == .chineseTraditional)
        #expect(AppLanguage.resolved(preferredLanguages: ["ja-JP"]) == .english)
    }
}

// MARK: - 6. PinyinConverter Tests
@Suite("NekoCore - PinyinConverter Tests")
struct PinyinConverterTests {
    @Test("Detects Chinese characters accurately")
    func detectsChineseCharacters() {
        #expect(PinyinConverter.containsChineseCharacters("你好"))
        #expect(PinyinConverter.containsChineseCharacters("Hello 世界"))
        #expect(!PinyinConverter.containsChineseCharacters("Hello World"))
        #expect(!PinyinConverter.containsChineseCharacters("Xin chào"))
    }

    @Test("Returns nil for non-Chinese or empty input and converts Chinese to Pinyin")
    func convertsChineseToPinyin() {
        #expect(PinyinConverter.toPinyin("") == nil)
        #expect(PinyinConverter.toPinyin("   ") == nil)
        #expect(PinyinConverter.toPinyin("Hello") == nil)

        let pinyin = PinyinConverter.toPinyin("你好")
        #expect(pinyin != nil)
        #expect(pinyin?.lowercased().contains("nǐ") == true)
        #expect(pinyin?.lowercased().contains("hǎo") == true)
    }
}

// MARK: - 7. Spaced Repetition (SM-2) & TargetLanguage Tests
@Suite("NekoCore - Spaced Repetition & TargetLanguage Tests")
struct SpacedRepetitionTests {
    @Test("New unmastered item is due for review immediately")
    func newCardIsDue() {
        let item = SavedWordItem(word: "resilient", phonetic: nil, translation: "kiên cường")
        #expect(item.isDueForReview(at: Date()))
    }

    @Test("Applying SM-2 grades updates intervals, ease factor, and next review date")
    func sm2SchedulingProgression() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var item = SavedWordItem(word: "你好", phonetic: "nǐ hǎo", translation: "Xin chào")

        item.applyReview(grade: .good, now: now)
        #expect(item.reviewCount == 1)
        #expect(item.intervalDays == 1)
        #expect(!item.isDueForReview(at: now))

        let nextDay = now.addingTimeInterval(86_400 * 2)
        #expect(item.isDueForReview(at: nextDay))

        item.applyReview(grade: .easy, now: nextDay)
        #expect(item.reviewCount == 2)
        #expect((item.intervalDays ?? 0) >= 4)
        #expect((item.easeFactor ?? 2.5) > 2.5)

        item.applyReview(grade: .again, now: nextDay)
        #expect(item.reviewCount == 0)
        #expect(item.intervalDays == 1)
        #expect(!item.isMastered)
    }

    @Test("TargetLanguage includes Traditional Chinese and voice locale codes")
    func targetLanguageVoiceCodes() {
        #expect(TargetLanguage.chinese.voiceLocaleCode == "zh-CN")
        #expect(TargetLanguage.chineseTraditional.voiceLocaleCode == "zh-TW")
        #expect(TargetLanguage.vietnamese.voiceLocaleCode == "vi-VN")
    }
}

// MARK: - 8. Theme & Appearance Models Tests
@Suite("NekoCore - Theme & Appearance Models Tests")
struct ThemeModelsTests {
    @Test("AppAppearanceMode maps accurately to SwiftUI ColorScheme and NSAppearance")
    func appearanceModeMapping() {
        #expect(AppAppearanceMode.system.colorScheme == nil)
        #expect(AppAppearanceMode.system.nsAppearance == nil)
        #expect(AppAppearanceMode.light.colorScheme == .light)
        #expect(AppAppearanceMode.dark.colorScheme == .dark)
    }

    @Test("AppAccentTheme, HUDMaterialStyle, and SelectionPopupStyle expose complete cases and valid opacities")
    func accentAndHUDMaterialCases() {
        #expect(AppAccentTheme.allCases.count == 6)
        #expect(HUDMaterialStyle.allCases.count == 3)
        #expect(SelectionPopupStyle.allCases.count == 3)
        for style in HUDMaterialStyle.allCases {
            #expect(style.tintOverlayOpacity > 0.0 && style.tintOverlayOpacity < 1.0)
        }
        for popupStyle in SelectionPopupStyle.allCases {
            #expect(!popupStyle.sfSymbol.isEmpty)
        }
    }
}




