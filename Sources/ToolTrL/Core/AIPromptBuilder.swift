import Foundation

// MARK: - Centralized AI Prompt Builder & Schema Generator
public enum AIPromptBuilder {
    
    // MARK: 1. Deep Structured Vocabulary Analysis
    public static func structuredWordPrompt(for word: String) -> String {
        return """
        Hãy phân tích từ vựng/cấu trúc '\(word)' thành một mục từ điển chuyên sâu theo đúng cấu trúc chuẩn sau để lưu vào Sổ Tay:

        ### 1. 🏷️ TỪ LOẠI & TẦNG NGHĨA CHÍNH
        - Liệt kê các nghĩa quan trọng nhất kèm giải thích tiếng Việt ngắn gọn.

        ### 2. 🌿 HỌ TỪ (WORD FAMILY)
        - Danh từ (Noun): ...
        - Động từ (Verb): ...
        - Tính từ (Adjective): ...
        - Trạng từ (Adverb): ...

        ### 3. 💡 COLLOCATIONS & THÀNH NGỮ
        - Liệt kê 3-4 cụm từ cố định hay đi kèm (Collocations) kèm ví dụ ngắn.

        ### 4. ⚖️ SẮC THÁI & PHÂN BIỆT (NUANCES)
        - Phân biệt với các từ dễ nhầm lẫn hoặc lưu ý quan trọng khi dùng.

        ### 5. 📖 VÍ DỤ MINH HỌA
        - 2 câu ví dụ tự nhiên (kèm dịch nghĩa).

        ### 6. 🧠 MẸO GHI NHỚ (MNEMONIC & ETYMOLOGY)
        - Gốc từ hoặc mẹo liên tưởng dễ nhớ.
        """
    }
    
    // MARK: 2. Dedicated Grammar Formula & Rules Prompt
    public static func grammarFormulaPrompt(for title: String, context: String? = nil) -> String {
        let contextHint = (context != nil && !context!.isEmpty) ? "\n(Ngữ cảnh câu: \"\(context!)\")" : ""
        return """
        Hãy phân tích và thiết lập CÔNG THỨC & QUY TẮC NGỮ PHÁP cho cấu trúc '\(title)'\(contextHint) theo đúng khuôn mẫu chuẩn sau để lưu vào Sổ Tay:

        ### 1. 📐 CÔNG THỨC CHUẨN (FORMULA)
        [Ghi rõ công thức tổng quát dạng toán học, ví dụ: S + had + V3/ed + by the time + S + V2/ed, hoặc S + wish + (that) + S + V-past / would + V]

        ### 2. 💡 Ý NGHĨA & CÁCH DÙNG
        - Giải thích bản chất, hoàn cảnh sử dụng và các dấu hiệu nhận biết (Signal words / Trạng từ đi kèm).

        ### 3. 📖 CÁC CÂU VÍ DỤ MINH HỌA (EXAMPLES)
        - Thể khẳng định (+): ... ➔ Dịch nghĩa tiếng Việt
        - Thể phủ định (-): ... ➔ Dịch nghĩa tiếng Việt
        - Thể nghi vấn (?): ... ➔ Dịch nghĩa tiếng Việt

        ### 4. ⚠️ LỖI SAI HAY GẶP & BẪY ĐỀ THI (COMMON MISTAKES)
        - Điểm bẫy ngữ pháp thường xuất hiện trong đề thi TOEIC/IELTS hoặc giao tiếp.

        ### 5. 🧠 MẸO GHI NHỚ THẦN TỐC
        - Mẹo vần điệu hoặc quy tắc liên tưởng ngắn gọn giúp nhớ công thức vĩnh viễn.
        """
    }
    
    // MARK: 3. Word-level Grammar Patterns Prompt
    public static func wordGrammarPatternsPrompt(for word: String, context: String? = nil) -> String {
        let contextHint = (context != nil && !context!.isEmpty) ? "\n(Ví dụ ngữ cảnh: \"\(context!)\")" : ""
        return """
        Hãy phân tích và trích xuất các CẤU TRÚC & CÔNG THỨC NGỮ PHÁP quan trọng nhất đi với từ '\(word)'\(contextHint) theo đúng cấu trúc sau để lưu vào Sổ Tay:

        ### 1. 📐 CÔNG THỨC CHUẨN (FORMULA)
        [Liệt kê các cấu trúc ngữ pháp dạng công thức, ví dụ: S + \(word) + to V / V-ing / that + S + V / prep + O]

        ### 2. 💡 CÁCH DÙNG & GIỚI TỪ ĐI KÈM
        - Các giới từ cố định, cấu trúc đi kèm và ý nghĩa từng trường hợp.

        ### 3. 📖 CÁC CÂU VÍ DỤ MINH HỌA (EXAMPLES)
        - Câu ví dụ thực tế cho từng cấu trúc (kèm dịch nghĩa tiếng Việt).

        ### 4. ⚠️ LỖI SAI HAY GẶP & BẪY ĐỀ THI (COMMON MISTAKES)
        - Bẫy ngữ pháp thường gặp trong đề thi TOEIC/IELTS khi dùng từ này.

        ### 5. 🧠 MẸO GHI NHỚ
        - Mẹo ngắn gọn để nhớ nhanh các cấu trúc này.
        """
    }
    
    // MARK: 4. Strict Schema Enforcement Grammar Prompt
    public static func strictEnforcedGrammarPrompt(title: String, context: String? = nil, customNote: String? = nil) -> String {
        var extra = ""
        if let ctx = context, !ctx.isEmpty {
            extra += "\n- Câu ví dụ ngữ cảnh người dùng cung cấp: \"\(ctx)\""
        }
        if let note = customNote, !note.isEmpty {
            extra += "\n- Yêu cầu/ghi chú bổ sung: \(note)"
        }
        
        return """
        Hãy phân tích và thiết lập CÔNG THỨC & QUY TẮC NGỮ PHÁP cho cấu trúc '\(title)'\(extra) theo đúng 5 phần chuẩn sau để lưu trực tiếp vào Sổ Tay:

        ### 1. 📐 CÔNG THỨC CHUẨN (FORMULA)
        [Ghi công thức tổng quát dạng toán học, ví dụ: S + had + V3/ed + by the time + S + V2/ed, hoặc It + is + adj + that + S + (should) + V-inf]

        ### 2. 💡 Ý NGHĨA & CÁCH DÙNG
        - Giải thích bản chất, hoàn cảnh sử dụng và các trạng từ / từ nhận biết đi kèm.

        ### 3. 📖 CÁC CÂU VÍ DỤ MINH HỌA (EXAMPLES)
        - Thể khẳng định (+): ... ➔ Dịch nghĩa tiếng Việt
        - Thể phủ định (-): ... ➔ Dịch nghĩa tiếng Việt
        - Thể nghi vấn (?): ... ➔ Dịch nghĩa tiếng Việt

        ### 4. ⚠️ LỖI SAI HAY GẶP & BẪY ĐỀ THI (COMMON MISTAKES)
        - Bẫy ngữ pháp thường xuất hiện trong đề thi TOEIC/IELTS hoặc giao tiếp khi dùng cấu trúc này.

        ### 5. 🧠 MẸO GHI NHỚ THẦN TỐC
        - Mẹo ngắn gọn hoặc câu thần chú giúp thuộc công thức tức thì.
        """
    }
}
