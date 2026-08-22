# Hướng Dẫn Kiến Trúc & Quy Chuẩn Phát Triển Cho AI (AGENTS.md)

Tài liệu này mô tả chi tiết kiến trúc, cấu trúc thư mục, quy chuẩn lập trình và hướng dẫn mở rộng dự án **ToolTrL** dành cho các AI Agent (Antigravity, Cursor, Copilot, ChatGPT, Claude...) khi tham gia phát triển và bảo trì mã nguồn.

---

## 📌 1. Tổng Quan Dự Án (Project Overview)

**ToolTrL** là ứng dụng macOS Native chuyên biệt hỗ trợ học ngôn ngữ toàn diện:
- **Dịch tức thì (Quick Translate & Overlay HUD)**: Phím tắt toàn cục dịch đoạn văn bản được bôi đen hoặc chụp ảnh màn hình (OCR).
- **Trợ lý AI Tích hợp (Quick AI Assistant WebView)**: Tích hợp ChatGPT, Google Gemini, Claude, Perplexity vào giao diện nổi, tự động paste prompt và bóc tách kết quả bằng JavaScript injection.
- **Sổ Tay Từ Vựng & Ngữ Pháp (Vocabulary & Grammar Notebook)**: Giao diện 3 cột chuẩn macOS HIG hoặc dạng Bảng (Table), phân loại theo AI (Mức độ quan trọng, Chủ đề, Từ loại), hỗ trợ Flashcard và Quick Look (phím Space).
- **Trình Sinh & Bóc Tách Ngữ Pháp Chuyên Sâu**: Tự động ép prompt AI trả về 5 khối dữ liệu chuẩn (Công thức toán học, Ý nghĩa, Ví dụ 3 thể +, -, ?, Bẫy đề thi TOEIC/IELTS, Mẹo nhớ).

---

## 🏛️ 2. Cấu Trúc Thư Mục & Trách Nhiệm (Directory Structure)

```
Sources/ToolTrL/
├── App/
│   ├── AppDelegate.swift          # Vòng đời ứng dụng, khởi tạo MenuBar, HotKey toàn cục, quản lý Window.
│   └── ToolTrLApp.swift           # Entry point chính của ứng dụng SwiftUI / AppKit.
│
├── Core/
│   ├── AIPromptBuilder.swift      # [QUAN TRỌNG] Nơi tập trung TẤT CẢ các Prompt Template và Schema ép cấu trúc AI.
│   ├── AIAnalysisParser.swift     # [QUAN TRỌNG] Bộ bóc tách văn bản thô từ AI thành Model có cấu trúc (ParsedAIAnalysis).
│   ├── VocabularyService.swift    # Quản lý dữ liệu lưu trữ Sổ Tay (SavedWordItem), phân loại AI, lưu file JSON.
│   ├── SmartDictionaryService.swift # Tích hợp API Từ điển miễn phí (DictionaryAPI) tra cứu nghĩa Anh - Anh và ví dụ.
│   ├── SpeechService.swift        # Quản lý phát âm âm thanh (AVSpeechSynthesizer) đa ngôn ngữ.
│   ├── TranslationService.swift   # Dịch thuật qua Google Translate / MyMemory API với bộ nhớ đệm (Cache).
│   ├── HotKeyManager.swift        # Lắng nghe và đăng ký phím tắt toàn hệ thống (Carbon / EventTap).
│   ├── ScreenOCRService.swift     # Nhận diện chữ trên màn hình bằng Vision Framework của macOS.
│   ├── TextAnalysisService.swift  # Bóc tách từ vựng & cấu trúc ngữ pháp từ văn bản dài bằng NaturalLanguage.
│   └── QuickPromptService.swift   # Quản lý danh sách các mẫu prompt hỏi nhanh của người dùng.
│
└── UI/
    ├── VocabularyNotebookView.swift # Giao diện Sổ Tay trung tâm (Sidebar, Content List, Search, Table Mode, Quick Look).
    ├── GrammarDetailView.swift    # [MODULAR] Giao diện chi tiết nguyên khối cho Cấu Trúc Ngữ Pháp & Công Thức.
    ├── AddGrammarSheet.swift      # [MODULAR] Modal cho phép người dùng nhập ngữ pháp và kích hoạt AI ép prompt.
    ├── QuickAIAssistantView.swift # Cửa sổ Web Trợ lý AI (ChatGPT / Gemini / Claude) với thanh công cụ điều khiển.
    ├── AIWebView.swift            # WKWebView tích hợp vòng lặp Polling chủ động và Auto-Injection prompt.
    ├── TranslationHUDView.swift   # Cửa sổ nổi hiển thị bản dịch nhanh khi bấm phím tắt.
    ├── SmartTextAnalysisSheet.swift # Modal bóc tách từ vựng từ văn bản dài.
    └── FlashcardStudyView...      # Chế độ ôn tập Flashcard lật thẻ 3D.
```

---

## 🎯 3. Các Nguyên Tắc & Quy Chuẩn Bắt Buộc Khi Code

### 1. Nguyên Tắc Phân Tách Từ Vựng & Ngữ Pháp (Strict Domain Separation)
- **Từ Vựng (`SavedWordItem.isGrammarFormula == false`)**:
  - Giao diện hiển thị theo 2 tab: `[ 📖 Từ điển & Ghi chú ]` và `[ ✨ Phân tích AI ]`.
  - Không chèn các nút sinh ngữ pháp làm rối phần từ điển gốc.
- **Ngữ Pháp (`SavedWordItem.isGrammarFormula == true` hoặc bắt đầu bằng `📐`)**:
  - **Không hiển thị tab Từ Điển** (vì ngữ pháp không phải là mục từ điển đơn).
  - Sử dụng component `GrammarDetailView(item: item)` để hiển thị tài liệu ngữ pháp 5 phần liền mạch.

### 2. Quản Lý Prompt Tập Trung (`AIPromptBuilder.swift`)
- **TUYỆT ĐỐI KHÔNG** hardcode chuỗi prompt AI rải rác trong các View.
- Khi cần tạo prompt mới hoặc sửa đổi khuôn mẫu hỏi ChatGPT/Gemini, hãy định nghĩa phương thức trong `AIPromptBuilder.swift`.

### 3. Nguyên Tắc Bóc Tách Dữ Liệu AI (`AIAnalysisParser.swift`)
- Luôn sử dụng `AIAnalysisParser.parse(rawText)` để chuyển đổi văn bản từ LLM thành struct `ParsedAIAnalysis`.
- Khi cần mở rộng các mục mới (ví dụ: `quizzes`, `idioms`), chỉ cần thêm trường vào `ParsedAIAnalysis` và cập nhật `switch currentSection` trong parser.

### 4. Giao Diện Native macOS (Apple HIG)
- Ưu tiên sử dụng `GroupBox`, `VisualEffectBackground(.hudWindow / .sidebar)`, `NavigationSplitView`.
- Font chữ: Tiêu đề in đậm, Công thức dùng `design: .monospaced`, Ví dụ câu dùng `design: .serif, italic`.
- Hạn chế các màu sắc chói; dùng `Color.blue`, `Color.purple`, `Color.orange`, `Color.green` với opacity nhẹ làm nền.

---

## 🚀 4. Lệnh Build, Đóng Gói & Kiểm Thử

Mỗi khi chỉnh sửa mã nguồn Swift, hãy chạy lệnh sau để build bản release, đóng gói `.app`, ký mã nguồn và khởi chạy:

```bash
./Scripts/build_app.sh && killall ToolTrL 2>/dev/null || true && sleep 1 && open build/ToolTrL.app
```

---

## 💡 5. Hướng Dẫn Mở Rộng Tính Năng (How-to Guide for AIs)

### Trường hợp 1: Thêm một loại phân tích AI mới
1. Mở `AIPromptBuilder.swift`, tạo hàm mới `public static func myNewPrompt(...) -> String`.
2. Mở `AIAnalysisParser.swift`, thêm trường vào `ParsedAIAnalysis` và thêm case tương ứng trong `parse()`.
3. Cập nhật UI trong `GrammarDetailView.swift` hoặc `VocabularyNotebookView.swift` để render card mới.

### Trường hợp 2: Thêm một nhà cung cấp AI mới vào WebView
1. Mở `QuickAIAssistantView.swift`, thêm case vào enum `AIProvider` (URL, Icon, Selector).
2. Cập nhật JavaScript inject trong `AIWebView.swift` để hỗ trợ selector ô nhập liệu của nhà cung cấp đó.
