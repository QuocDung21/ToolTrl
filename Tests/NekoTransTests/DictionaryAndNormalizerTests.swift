import XCTest
import KeyboardShortcuts
import Defaults
@testable import NekoTrans

final class DictionaryAndNormalizerTests: XCTestCase {
    // MARK: - 15. Easydict-Inspired Logic Tests

    func testBrowserBundleIDDetection() {
        XCTAssertTrue(BrowserScriptHelper.isSupportedBrowser("com.apple.Safari"))
        XCTAssertTrue(BrowserScriptHelper.isSupportedBrowser("com.google.Chrome"))
        XCTAssertTrue(BrowserScriptHelper.isSupportedBrowser("company.thebrowser.Browser"))
        XCTAssertTrue(BrowserScriptHelper.isSupportedBrowser("com.microsoft.edgemac"))
        XCTAssertTrue(BrowserScriptHelper.isSupportedBrowser("com.brave.Browser"))
        XCTAssertFalse(BrowserScriptHelper.isSupportedBrowser("com.apple.dt.Xcode"))
        XCTAssertFalse(BrowserScriptHelper.isSupportedBrowser("com.tinyspeck.slackmacgap"))
    }

    func testOCRDashHandlingDehyphenation() {
        // Line-break hyphenation removal
        let lines1 = ["This is an impor-", "tant discovery."]
        let result1 = ScreenOCRService.assembleSmartText(from: lines1)
        XCTAssertEqual(result1, "This is an important discovery.")

        // Compound word preservation
        let lines2 = ["A state-of-", "the-art model."]
        let result2 = ScreenOCRService.assembleSmartText(from: lines2)
        XCTAssertEqual(result2, "A state-of-the-art model.")

        // Numbers/Date preservation
        let lines3 = ["During 1990-", "2020."]
        let result3 = ScreenOCRService.assembleSmartText(from: lines3)
        XCTAssertEqual(result3, "During 1990-2020.")
    }

    @MainActor
    func testVocabularyExportAnkiAndMarkdownAndJSONL() {
        let service = VocabularyService.shared
        let originalWords = service.savedWords

        service.clearAll()
        service.addWord(
            word: "Serendipity",
            phonetic: "/ˌser.ənˈdɪp.ə.t̬i/",
            translation: "Sự may mắn tình cờ",
            exampleEn: "Pure serendipity.",
            exampleVi: "Hoàn toàn là may mắn tình cờ."
        )
        service.addWord(
            word: "📐 Quá khứ hoàn thành",
            phonetic: "S + had + V3/ed",
            translation: "Diễn tả hành động xảy ra trước",
            exampleEn: "He had left."
        )

        // 1. Anki TSV
        let anki = service.exportToAnkiTSV()
        XCTAssertTrue(anki.contains("serendipity\tSự may mắn tình cờ\t/ˌser.ənˈdɪp.ə.t̬i/\tPure serendipity.\tHoàn toàn là may mắn tình cờ.\tNekoTrans::Vocabulary"))
        XCTAssertTrue(anki.contains("Quá khứ hoàn thành\tDiễn tả hành động xảy ra trước\tS + had + V3/ed\tHe had left.\t\tNekoTrans::Grammar"))

        // 2. Markdown
        let md = service.exportToMarkdown()
        XCTAssertTrue(md.contains("# 📖 Sổ tay từ vựng NekoTrans"))
        XCTAssertTrue(md.contains("**serendipity**"))
        XCTAssertTrue(md.contains("S + had + V3/ed"))

        // 3. JSONL
        let jsonl = service.exportToJSONL()
        let rows = jsonl.split(separator: "\n")
        XCTAssertEqual(rows.count, 2)
        XCTAssertTrue(jsonl.contains("serendipity"))

        // Restore original words
        service.savedWords = originalWords
        service.saveWords()
    }

    // MARK: - InputTextNormalizer Tests (Easydict Logic Inheritance)
    func testSplitCodeIdentifiers() {
        XCTAssertEqual(InputTextNormalizer.splitCodeIdentifiers("getUserProfile"), "get User Profile")
        XCTAssertEqual(InputTextNormalizer.splitCodeIdentifiers("XMLHttpRequest"), "XML Http Request")
        XCTAssertEqual(InputTextNormalizer.splitCodeIdentifiers("is_authenticated_user"), "is authenticated user")
        XCTAssertEqual(InputTextNormalizer.splitCodeIdentifiers("API_KEY_SECRET"), "API KEY SECRET")
    }

    func testStripCommentSymbols() {
        let codeWithSlash = "// This is a single line comment"
        XCTAssertEqual(InputTextNormalizer.stripCommentSymbols(codeWithSlash), "This is a single line comment")

        let codeWithTripleSlash = "/// Documentation comment"
        XCTAssertEqual(InputTextNormalizer.stripCommentSymbols(codeWithTripleSlash), "Documentation comment")

        let codeWithHash = "# Python style comment"
        XCTAssertEqual(InputTextNormalizer.stripCommentSymbols(codeWithHash), "Python style comment")

        let blockComment = "/* Multi-line comment block */"
        XCTAssertEqual(InputTextNormalizer.stripCommentSymbols(blockComment), "Multi-line comment block")
    }

    func testStripSurroundingQuotes() {
        XCTAssertEqual(InputTextNormalizer.stripSurroundingQuotes("\"hello world\""), "hello world")
        XCTAssertEqual(InputTextNormalizer.stripSurroundingQuotes("'single quoted'"), "single quoted")
        XCTAssertEqual(InputTextNormalizer.stripSurroundingQuotes("`backtick code`"), "backtick code")
        XCTAssertEqual(InputTextNormalizer.stripSurroundingQuotes("“smart quotes”"), "smart quotes")
    }

    func testInputTextNormalizerNormalize() {
        let raw1 = "\"// getUserProfile\""
        XCTAssertEqual(InputTextNormalizer.normalize(raw1), "get User Profile")

        let raw2 = "  # is_admin_active  "
        XCTAssertEqual(InputTextNormalizer.normalize(raw2), "is admin active")
    }

    func testInputTextClassifier() {
        XCTAssertEqual(InputTextNormalizer.classify("getUserProfile"), .code)
        XCTAssertEqual(InputTextNormalizer.classify("is_authenticated"), .code)
        XCTAssertEqual(InputTextNormalizer.classify("apple"), .word)
        XCTAssertEqual(InputTextNormalizer.classify("big apple"), .word)
        XCTAssertEqual(InputTextNormalizer.classify("This is a complete sentence."), .sentence)
    }

    func testResolveTargetLanguageAutoFlip() {
        // Vietnamese detected -> should auto-flip to English
        let targetForVi = InputTextNormalizer.resolveTargetLanguage(
            sourceLanguageCode: "vi",
            configuredTarget: .vietnamese
        )
        XCTAssertEqual(targetForVi, .english)

        // English detected -> should translate to configured target (Vietnamese)
        let targetForEn = InputTextNormalizer.resolveTargetLanguage(
            sourceLanguageCode: "en",
            configuredTarget: .vietnamese
        )
        XCTAssertEqual(targetForEn, .vietnamese)

        // English detected when configured target was Japanese -> should keep Japanese
        let targetForEnToJa = InputTextNormalizer.resolveTargetLanguage(
            sourceLanguageCode: "en",
            configuredTarget: .japanese
        )
        XCTAssertEqual(targetForEnToJa, .japanese)
    }

    // MARK: - HTMLEntityDecoder Tests
    func testHTMLEntityDecoder() {
        let encoded = "&quot;Hello &amp; World&quot; &lt;tag&gt; &#39;test&#39; &#65;"
        let decoded = HTMLEntityDecoder.decode(encoded)
        XCTAssertEqual(decoded, "\"Hello & World\" <tag> 'test' A")

        let hexEncoded = "&#x41;&#x42;&#x43;"
        let hexDecoded = HTMLEntityDecoder.decode(hexEncoded)
        XCTAssertEqual(hexDecoded, "ABC")
    }

    // MARK: - TranslationProviderResult Tests
    func testTranslationProviderResultInit() {
        let result = TranslationProviderResult(
            engine: .googleWeb,
            providerName: "Google Translate",
            text: "Xin chào",
            latencyMs: 142
        )
        XCTAssertEqual(result.engine, .googleWeb)
        XCTAssertEqual(result.providerName, "Google Translate")
        XCTAssertEqual(result.text, "Xin chào")
        XCTAssertEqual(result.latencyMs, 142)
        XCTAssertFalse(result.isError)
        XCTAssertNil(result.errorMessage)
    }

    // MARK: - OfflineDictionaryParser Tests
    func testOfflineDictionaryParserVietnameseDCSOutput() {
        let raw = "1. context danh từ 1 (văn học) văn cảnh; ngữ cảnh ▸ Can you guess the meaning of this phrase from the context? Anh có đoán được nghĩa của cụm từ này qua ngữ cảnh hay không? ▸ Don't quote my words out of context Đừng tách trích dẫn những từ ngữ của tôi mà tách chúng ra khỏi ngữ cảnh 2 tình huống mà trong đó cái gì đang xảy ra hoặc phải được suy xét; bối cảnh ▸ In the context of the present economic crisis Trong bối cảnh khủng hoảng kinh tế hiện nay từ đồng nghĩa background, circumstances, environment, framework, milieu, perspective, setting, situation 3 Kỹ thuật văn cảnh 4 Tin học văn cảnh"

        let groups = OfflineDictionaryParser.parse(rawText: raw, term: "context")
        XCTAssertFalse(groups.isEmpty)
        guard let group = groups.first else { return }
        XCTAssertEqual(group.partOfSpeech, "noun")
        XCTAssertEqual(group.items.count, 4)

        // Item 1
        let item1 = group.items[0]
        XCTAssertTrue(item1.definition.contains("văn cảnh; ngữ cảnh"))
        XCTAssertNotNil(item1.example)
        XCTAssertTrue(item1.example?.contains("Can you guess the meaning") == true)
        XCTAssertEqual(item1.exampleTranslation, "Anh có đoán được nghĩa của cụm từ này qua ngữ cảnh hay không?")

        // Item 2
        let item2 = group.items[1]
        XCTAssertTrue(item2.definition.contains("tình huống"))
        XCTAssertTrue(item2.example?.contains("present economic crisis") == true)
        XCTAssertEqual(item2.exampleTranslation, "Trong bối cảnh khủng hoảng kinh tế hiện nay")
        XCTAssertTrue(item2.synonyms.contains("background"))
        XCTAssertTrue(item2.synonyms.contains("situation"))

        // Item 3 & 4
        XCTAssertEqual(group.items[2].definition, "Kỹ thuật văn cảnh")
        XCTAssertEqual(group.items[3].definition, "Tin học văn cảnh")
    }

    func testOfflineDictionaryParserEnglishOxfordOutput() {
        let raw = """
        context | ˈkɑntɛkst |
        noun
        1 the circumstances that form the setting for an event.
        2 the parts of something written or spoken: word processing is affected by the context.
        PHRASES
        in context / out of context
        """
        let groups = OfflineDictionaryParser.parse(rawText: raw, term: "context")
        XCTAssertFalse(groups.isEmpty)
        guard let group = groups.first else { return }
        XCTAssertEqual(group.partOfSpeech, "noun")
        XCTAssertEqual(group.items.count, 2)
        XCTAssertTrue(group.items[0].definition.contains("the circumstances that form"))
        XCTAssertEqual(group.items[1].definition, "the parts of something written or spoken")
        XCTAssertEqual(group.items[1].example, "word processing is affected by the context.")
    }

    func testResolveTargetLanguageAutoFlipIdentical() {
        // When source is English and configured target is English -> flip to Vietnamese
        let targetEnToEn = InputTextNormalizer.resolveTargetLanguage(
            sourceLanguageCode: "en",
            configuredTarget: .english
        )
        XCTAssertEqual(targetEnToEn, .vietnamese)

        // When source is Vietnamese and configured target is Vietnamese -> flip to English
        let targetViToVi = InputTextNormalizer.resolveTargetLanguage(
            sourceLanguageCode: "vi",
            configuredTarget: .vietnamese
        )
        XCTAssertEqual(targetViToVi, .english)

        // When source is undetermined "und" and target is English -> should flip to Vietnamese
        let targetUnd = InputTextNormalizer.resolveTargetLanguage(
            sourceLanguageCode: "und",
            configuredTarget: .english
        )
        XCTAssertEqual(targetUnd, .vietnamese)
    }

    // MARK: - ActionManager & Polishing Tests
    func testQuickPolishingPromptGeneration() {
        let text = "He dont has any money and he go to school."
        let prompt = AIPromptBuilder.quickPolishingPrompt(text: text)
        XCTAssertTrue(prompt.contains(text))
        XCTAssertTrue(prompt.contains("Output ONLY the polished replacement text"))
        XCTAssertTrue(prompt.contains("writing assistant"))
    }

    @MainActor
    func testActionManagerDefaultsAndShortcuts() {
        XCTAssertNotNil(ActionManager.shared)
        XCTAssertFalse(ActionManager.shared.isProcessing)

        let replaceShortcut = KeyboardShortcuts.Name.translateAndReplace.shortcut
        XCTAssertNotNil(replaceShortcut)
        XCTAssertEqual(replaceShortcut?.modifiers, [.option, .shift])

        let polishShortcut = KeyboardShortcuts.Name.polishAndReplace.shortcut
        XCTAssertNotNil(polishShortcut)
        XCTAssertEqual(polishShortcut?.modifiers, [.option, .shift])
    }

    // MARK: - Concise Word Dictionary (Easydict Standard) Tests
    func testPartOfSpeechStandardizationAndAbbreviations() {
        XCTAssertEqual(InputTextNormalizer.partAbbreviation("noun"), "n.")
        XCTAssertEqual(InputTextNormalizer.partAbbreviation("Danh từ"), "n.")
        XCTAssertEqual(InputTextNormalizer.partAbbreviation("verb"), "v.")
        XCTAssertEqual(InputTextNormalizer.partAbbreviation("động từ"), "v.")
        XCTAssertEqual(InputTextNormalizer.partAbbreviation("adjective"), "adj.")
        XCTAssertEqual(InputTextNormalizer.partAbbreviation("tính từ"), "adj.")
        XCTAssertEqual(InputTextNormalizer.partAbbreviation("adverb"), "adv.")
        XCTAssertEqual(InputTextNormalizer.partAbbreviation("phó từ"), "adv.")
        XCTAssertEqual(InputTextNormalizer.partAbbreviation("preposition"), "prep.")
        XCTAssertEqual(InputTextNormalizer.partAbbreviation("conjunction"), "conj.")
        XCTAssertEqual(InputTextNormalizer.partAbbreviation("pronoun"), "pron.")
        XCTAssertEqual(InputTextNormalizer.partAbbreviation("interjection"), "int.")

        XCTAssertEqual(InputTextNormalizer.partFullName("noun"), "Danh từ")
        XCTAssertEqual(InputTextNormalizer.partFullName("verb"), "Động từ")
        XCTAssertEqual(InputTextNormalizer.partFullName("adjective"), "Tính từ")
    }

    func testRichWordEntryConcisePartsExtraction() {
        let def1 = DefinitionItem(
            definitionEn: "A reference work with a list of words from one or more languages, explaining each word's meaning...",
            definitionVi: "Tài liệu tham khảo có danh sách các từ của một hoặc nhiều ngôn ngữ, giải thích nghĩa của từng từ...",
            exampleEn: "look up in dictionary",
            exampleVi: "tra từ điển"
        )
        let def2 = DefinitionItem(
            definitionEn: "To look up in a dictionary.",
            definitionVi: "Tra trong từ điển.",
            exampleEn: nil,
            exampleVi: nil
        )
        let def3 = DefinitionItem(
            definitionEn: "To compile into a dictionary.",
            definitionVi: "Biên soạn từ điển.",
            exampleEn: nil,
            exampleVi: nil
        )

        let nounGroup = MeaningGroup(
            partOfSpeech: "noun",
            definitions: [def1],
            synonyms: ["wordbook"],
            antonyms: []
        )
        let verbGroup = MeaningGroup(
            partOfSpeech: "verb",
            definitions: [def2, def3],
            synonyms: [],
            antonyms: []
        )

        let entry = RichWordEntry(
            word: "Dictionary",
            phonetic: "/'dɪkʃə,nɛɹi/",
            mainTranslation: "từ điển",
            meanings: [nounGroup, verbGroup],
            allSynonyms: ["wordbook"],
            allAntonyms: []
        )

        let conciseParts = entry.conciseParts
        XCTAssertEqual(conciseParts.count, 2)

        let nounPart = conciseParts.first(where: { $0.part == "n." })
        XCTAssertNotNil(nounPart)
        XCTAssertEqual(nounPart?.partFullName, "Danh từ")
        XCTAssertTrue(nounPart?.meanings.contains("từ điển") == true)

        let verbPart = conciseParts.first(where: { $0.part == "v." })
        XCTAssertNotNil(verbPart)
        XCTAssertEqual(verbPart?.partFullName, "Động từ")
        XCTAssertTrue(verbPart?.meanings.contains("Tra trong từ điển") == true)
        XCTAssertTrue(verbPart?.meanings.contains("Biên soạn từ điển") == true)
    }

    func testIPANormalizerStandardization() {
        // 1. Raw Wiktionary phonetic with ASCII stress markers and turned-r
        let raw = "/'dɪkʃə,nɛɹi/"
        let normalized = IPANormalizer.normalize(raw)
        XCTAssertEqual(normalized, "/ˈdɪkʃəˌnɛri/")

        // 2. Square brackets stripping and character conversions
        let rawBrackets = "[ˈækʃən]"
        XCTAssertEqual(IPANormalizer.normalize(rawBrackets), "/ˈækʃən/")

        // 3. Apple DCS American Heritage legacy digraph conversion
        let dcsRaw = "| ˈdikSHəˌnerē |"
        let dcsNormalized = IPANormalizer.normalize(dcsRaw)
        XCTAssertEqual(dcsNormalized, "/ˈdikʃəˌneri/")

        // 4. Comparison check
        XCTAssertTrue(IPANormalizer.areIdentical("/ˈdɪkʃənri/", "ˈdɪkʃənri"))
        XCTAssertFalse(IPANormalizer.areIdentical("/ˈdɪkʃənri/", "/ˈdɪkʃəˌneri/"))

        // 5. Wiktionary narrow glottal stop and unreleased stop diacritics stripping (e.g. [ʔæʔp̚] -> /æp/)
        let narrowApp = "[ʔæʔp̚]"
        XCTAssertEqual(IPANormalizer.normalize(narrowApp), "/æp/")

        // 6. User-specified broad Oxford IPA notation /'sɜ:və[r]/
        let oxfordServer = "/'sɜ:və[r]/"
        XCTAssertEqual(IPANormalizer.normalize(oxfordServer), "/ˈsɜːvə(r)/")

        // 7. Oxford Dictionary of English notation with triangular colon /əː/ -> /ɜː/
        let odeServer = "ˈsəːvə"
        XCTAssertEqual(IPANormalizer.normalize(odeServer), "/ˈsɜːvə/")

        // 8. Agent noun typo correction for server / servers
        let typoDCS = "/sə:v/"
        XCTAssertEqual(IPANormalizer.normalize(typoDCS, forWord: "servers"), "/ˈsɜːvə(r)/")
        XCTAssertEqual(IPANormalizer.normalize(typoDCS, forWord: "server"), "/ˈsɜːvə(r)/")
        XCTAssertEqual(IPANormalizer.normalize("/sɜːv/", forWord: "serve"), "/sɜːv/", "Root verb serve must not be altered")
    }

    @MainActor
    func testServersPhoneticFromDictionaryService() {
        // DictionaryService must extract valid broad IPA for "server" and "servers" (UK or US standard)
        let phoneticServer = DictionaryService.shared.extractPhonetic(for: "server")
        XCTAssertTrue(phoneticServer == "/ˈsɜːvə(r)/" || phoneticServer == "/ˈsərvər/", "Phonetic must be valid broad IPA (UK or US), got: \(String(describing: phoneticServer))")

        let phoneticServers = DictionaryService.shared.extractPhonetic(for: "servers")
        XCTAssertTrue(phoneticServers == "/ˈsɜːvə(r)/" || phoneticServers == "/ˈsərvər/", "Phonetic must be valid broad IPA (UK or US), got: \(String(describing: phoneticServers))")
    }

    func testCacheDecoderSanitizesContaminatedServersPhonetic() throws {
        let poisonedEntry = RichWordEntry(
            word: "servers",
            phonetic: "/sə:v/",
            ukPhonetic: "/sə:v/",
            usPhonetic: "/sə:v/",
            mainTranslation: "máy chủ",
            meanings: [],
            allSynonyms: [],
            allAntonyms: [],
            baseLemma: "server"
        )

        let data = try JSONEncoder().encode(
            TranslationCache.PersistentCacheData(
                version: TranslationCache.currentCacheVersion,
                translations: [:],
                dictionaries: ["servers_vi": poisonedEntry]
            )
        )

        let decoded = TranslationCache.decodeCache(data)
        let sanitized = decoded?.dictionaries["servers_vi"]
        XCTAssertNotNil(sanitized)
        XCTAssertEqual(sanitized?.phonetic, "/ˈsɜːvə(r)/")
        XCTAssertEqual(sanitized?.ukPhonetic, "/ˈsɜːvə(r)/")
    }

    func testCleanConciseMeaningChunkParenthesesBalancing() {
        let unbalanced = "Ứng dụng (sử dụng"
        XCTAssertEqual(SmartDictionaryService.cleanConciseMeaningChunk(unbalanced), "Ứng dụng")

        let balanced = "Một ứng dụng (chương trình)"
        XCTAssertEqual(SmartDictionaryService.cleanConciseMeaningChunk(balanced), "Một ứng dụng (chương trình)")
    }

}
