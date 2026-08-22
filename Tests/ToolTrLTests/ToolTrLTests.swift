import XCTest
@testable import ToolTrLKit

final class ToolTrLTests: XCTestCase {
    
    // MARK: - 1. AIPromptBuilder Tests
    func testAIPromptBuilderGeneratesCorrectGrammarPrompt() {
        let title = "Hiện tại đơn"
        let context = "I study English every day."
        let prompt = AIPromptBuilder.strictEnforcedGrammarPrompt(title: title, context: context, customNote: "Chi tiết cho TOEIC")
        
        XCTAssertTrue(prompt.contains("CÔNG THỨC CHUẨN (FORMULA)"))
        XCTAssertTrue(prompt.contains("Ý NGHĨA & CÁCH DÙNG"))
        XCTAssertTrue(prompt.contains("CÁC CÂU VÍ DỤ MINH HỌA (EXAMPLES)"))
        XCTAssertTrue(prompt.contains("LỖI SAI HAY GẶP & BẪY ĐỀ THI"))
        XCTAssertTrue(prompt.contains("MẸO GHI NHỚ THẦN TỐC"))
        XCTAssertTrue(prompt.contains(title))
        XCTAssertTrue(prompt.contains(context))
        XCTAssertTrue(prompt.contains("Chi tiết cho TOEIC"))
    }
    
    func testAIPromptBuilderGeneratesStructuredWordPrompt() {
        let word = "Resilience"
        let prompt = AIPromptBuilder.structuredWordPrompt(for: word)
        
        XCTAssertTrue(prompt.contains(word))
        XCTAssertTrue(prompt.contains("TỪ LOẠI & TẦNG NGHĨA CHÍNH"))
        XCTAssertTrue(prompt.contains("HỌ TỪ (WORD FAMILY)"))
        XCTAssertTrue(prompt.contains("COLLOCATIONS & THÀNH NGỮ"))
        XCTAssertTrue(prompt.contains("SẮC THÁI & PHÂN BIỆT (NUANCES)"))
    }
    
    // MARK: - 2. AIAnalysisParser Multiline Tests
    func testAIAnalysisParserMultilineFormula() {
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
        
        XCTAssertFalse(parsed.isEmpty)
        XCTAssertNotNil(parsed.formula)
        XCTAssertTrue(parsed.formula!.contains("S + V(s/es) + O"))
        XCTAssertTrue(parsed.formula!.contains("S + do/does not + V_inf + O"))
        XCTAssertTrue(parsed.formula!.contains("S + am/is/are + N/Adj"))
        
        XCTAssertEqual(parsed.meanings.count, 2)
        XCTAssertEqual(parsed.examples.count, 2)
        XCTAssertEqual(parsed.commonMistakes.count, 1)
        XCTAssertNotNil(parsed.mnemonic)
        XCTAssertTrue(parsed.mnemonic!.contains("always"))
    }
    
    func testAIAnalysisParserVocabularyStructure() {
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
        
        XCTAssertEqual(parsed.meanings.count, 1)
        XCTAssertTrue(parsed.wordFamily.count >= 2)
        XCTAssertTrue(parsed.collocations.count >= 2)
        XCTAssertFalse(parsed.nuances.isEmpty)
        XCTAssertTrue(parsed.nuances.first?.contains("Endurance") == true)
    }
    
    // MARK: - 3. TranslationCache & LRU Eviction Tests
    func testTranslationCacheSetAndGet() {
        let cache = TranslationCache.shared
        let key = "test_word_\(UUID().uuidString)"
        let translation = "từ thử nghiệm"
        
        cache.setTranslation(key: key, value: translation)
        let retrieved = cache.getTranslation(key: key)
        
        XCTAssertEqual(retrieved, translation)
    }
    
    // MARK: - 4. SavedWordItem Domain Logic Tests
    func testSavedWordItemGrammarIdentification() {
        let grammarWord = SavedWordItem(
            word: "📐 Quá khứ hoàn thành",
            phonetic: "S + had + V3/ed",
            translation: "Diễn tả hành động xảy ra trước một hành động khác",
            exampleEn: "He had left before I arrived."
        )
        
        XCTAssertTrue(grammarWord.isGrammarFormula)
        XCTAssertEqual(grammarWord.cleanTitle, "Quá khứ hoàn thành")
        
        let normalWord = SavedWordItem(
            word: "Serendipity",
            phonetic: "/ˌser.ənˈdɪp.ə.t̬i/",
            translation: "Sự may mắn tình cờ",
            exampleEn: "Finding this book was pure serendipity."
        )
        
        XCTAssertFalse(normalWord.isGrammarFormula)
        XCTAssertEqual(normalWord.cleanTitle, "Serendipity")
    }
}
