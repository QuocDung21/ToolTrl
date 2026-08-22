# ToolTrL - macOS AI Quick Dictionary & Translator 🌐📖✨

**ToolTrL** là ứng dụng macOS native (SwiftUI & AppKit) chạy ngầm siêu nhẹ trên thanh Menu Bar. Ứng dụng cung cấp giải pháp tra từ điển, dịch thuật đa ngôn ngữ song ngữ thông minh, bóc tách ngữ pháp AI, hỏi nhanh trợ lý AI (ChatGPT / Gemini / Claude) và chụp quét chữ màn hình (OCR) với tốc độ tức thì.

---

## ✨ Tính Năng Nổi Bật

### 1. ⚡ Dịch Tức Thì Tại Con Trỏ Chuột (Popup HUD)
- Bôi đen bất kỳ từ hoặc đoạn văn bản nào ở mọi ứng dụng (Safari, Chrome, Word, Slack, VSCode, PDF, v.v.) và nhấn **`⌥ + D`** (`Option + D`).
- Cửa sổ popup kính mờ (Liquid Glassmorphism) tự động xuất hiện ngay sát con trỏ chuột.

### 2. 📸 Quét Chữ Trên Màn Hình & Hình Ảnh (Screen Area OCR)
- Nhấn **`⌥ + S`** (`Option + S`) để kích hoạt công cụ khoanh vùng ảnh màn hình.
- Tự động nhận diện chữ từ video Youtube, file PDF scan, hình ảnh hoặc các trang web chặn bôi đen bằng **Apple Vision Framework** và dịch song ngữ tức thì.

### 3. 🧠 AI Bóc Tách Đoạn Văn & Trích Xuất Ngữ Pháp (Smart Text Analyzer)
- Tự động nhận diện hơn **35+ mẫu cấu trúc & thành ngữ tiếng Anh cốt lõi** (Câu điều kiện, Subjunctive, Wish, Used to, Passive Voice, So...that, Collocations...).
- Bóc tách từ vựng trọng tâm, từ loại, phiên âm và trích dẫn câu ví dụ thực tế.
- Lưu trọn bộ vào Sổ tay từ vựng chỉ với **1-chạm (`1-Click Save`)**.

### 4. 🤖 Trợ Lý AI Tích Hợp Sâu (Quick AI Assistant)
- Nhấn **`⌥ + A`** (`Option + A`) để mở nhanh trợ lý AI (ChatGPT, Google Gemini, Claude, Perplexity).
- Hỗ trợ các mẫu câu hỏi nhanh tùy chỉnh (Prompt Templates) với biến tự động `{text}`.

### 5. 📚 Sổ Tay Từ Vựng & Thẻ Học Flashcards (`⌥ + V`)
- Quản lý từ vựng thông minh, đánh dấu sao yêu thích, đánh dấu từ đã thuộc.
- Chế độ ôn tập Flashcards lật thẻ 3D mượt mà kèm phát âm chuẩn người bản xứ (`AVSpeechSynthesizer`).

### 6. 🎨 Tùy Biến Giao Diện & Logo Ứng Dụng
- Hỗ trợ 7 bộ icon nghệ thuật (Mèo Tuxedo, Tia chớp, Ngôi sao, Sách, Địa cầu, Tên lửa, Kim cương) hoặc tải ảnh đại diện cá nhân từ máy.
- Đồng bộ thời gian thực giữa macOS Menu Bar và thanh công cụ.

### 7. 📌 Ghim Cửa Sổ Trên Cùng (Window Pinning)
- Nút **`📌`** giúp cố định cửa sổ dịch hoặc chat AI luôn nổi trên các ứng dụng khác để tiện theo dõi.

---

## ⌨️ Bảng Phím Tắt Mặc Định (Có thể tùy chỉnh trong Cài Đặt)

| Phím tắt | Chức năng |
|---|---|
| `⌥ + D` (`Option + D`) | Dịch vùng chọn văn bản tại con trỏ chuột |
| `⌥ + S` (`Option + S`) | Chụp & Quét chữ trên màn hình (OCR Screen Snip) |
| `⌥ + A` (`Option + A`) | Mở nhanh Trợ lý AI (ChatGPT / Gemini) |
| `⌥ + V` (`Option + V`) | Mở Sổ tay từ vựng & Ôn tập Flashcards |
| `ESC` | Đóng nhanh popup / hủy chụp ảnh |

---

## 🚀 Cài Đặt & Khởi Chạy

### 1. Build & Đóng gói ứng dụng:
```bash
./Scripts/build_app.sh
```

Ứng dụng sẽ được xuất ra tại thư mục: `build/ToolTrL.app`.

### 2. Khởi chạy:
```bash
open build/ToolTrL.app
```

---

## 🔒 Cấp Quyền Hệ Thống macOS

Để ToolTrL hoạt động trọn vẹn mọi tính năng:
1. **Quyền Trợ Năng (Accessibility)**: Để đọc vùng chọn văn bản khi bạn bấm phím tắt (*System Settings ➔ Privacy & Security ➔ Accessibility ➔ Bật ToolTrL*).
2. **Quyền Ghi Màn Hình (Screen Recording)**: Để sử dụng tính năng chụp quét chữ OCR (*System Settings ➔ Privacy & Security ➔ Screen Recording ➔ Bật ToolTrL*).

---

## 🛠️ Công Nghệ & Kiến Trúc
- **Ngôn ngữ**: Swift 6 (SwiftUI & AppKit)
- **AI & ML**: Apple Vision (`VNRecognizeTextRequest`), Apple NaturalLanguage (`NLTagger`, `NLLanguageRecognizer`), Apple Translation Framework
- **Quản lý dependencies**: Swift Package Manager (SPM) - Zero external third-party pods
- **Kiến trúc**: Domain-Driven Modular Flat Architecture

---

## 📄 Bản quyền
Phát triển bởi **Dũng Nguyễn Quốc** (QuocDung21). Giấy phép mã nguồn mở MIT.
