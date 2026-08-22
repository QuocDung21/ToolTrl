# TOOLTRL FOR WINDOWS - ARCHITECTURAL SPECIFICATION & FUTURE ROADMAP

Tài liệu đặc tả kiến trúc kỹ thuật và kế hoạch triển khai phiên bản **ToolTrL cho hệ điều hành Windows (Windows 10 / Windows 11)**.

---

## 🎯 1. Mục Tiêu Dự Án (Core Objectives)

- **Trải nghiệm đồng nhất**: Mang lại trải nghiệm tra từ điển tức thì, trợ lý AI và sổ tay từ vựng mượt mà như bản macOS.
- **Native Fluent Design**: Giao diện chuẩn Windows 11 với hiệu ứng kính mờ Mica / Acrylic.
- **Siêu nhẹ & Hiệu năng cao**: Chạy ngầm ở System Tray tốn < 60MB RAM, độ trễ mở popup < 15ms.
- **Tương thích dữ liệu chéo (Cross-compatibility)**: Chia sẻ chung định dạng file dữ liệu `vocabulary_notebook.json` với bản macOS.

---

## 🛠️ 2. Công Nghệ Đề Xuất (Recommended Technology Stack)

### **Lựa Chọn Tối Ưu: C# .NET 8 + WinUI 3 (Windows App SDK / WPF)**

| Thành phần | Công nghệ Windows | Ghi chú & Lợi thế |
|---|---|---|
| **Runtime & Language** | .NET 8 / C# 12 | Hiệu năng cao, garbage collection tối ưu, AOT Compilation |
| **Giao diện (UI)** | WinUI 3 / WPF | Hiệu ứng Mica/Acrylic, Dark/Light mode tự động theo Windows |
| **Trình duyệt nhúng AI** | Microsoft WebView2 | Dựa trên nhân Chromium Edge gốc có sẵn trên Windows |
| **Chụp quét chữ (OCR)** | `Windows.Media.Ocr.OcrEngine` | Nhận diện chữ Offline cực nhanh của Microsoft, không cần cài thêm thư viện nặng |
| **Phát âm từ vựng (TTS)** | `Windows.Media.SpeechSynthesis` | Giọng đọc tự nhiên của Windows (Microsoft David/Zira/Jenny...) |
| **Phím tắt toàn cục** | Win32 `RegisterHotKey` API | Bắt phím tắt `Alt + D`, `Alt + S`, `Alt + A`, `Alt + V` toàn hệ thống |
| **Bắt văn bản bôi đen** | Win32 `SendInput` (Ctrl + C hook) | Mô phỏng copy văn bản từ mọi ứng dụng đang active |

---

## 🗺️ 3. Bảng Ánh Xạ API: macOS ➔ Windows (API Mapping)

| Tính năng | Mã nguồn macOS (`Sources/ToolTrL/`) | Tương đương trên Windows (`ToolTrL-Windows/`) |
|---|---|---|
| **System Tray / Menu Bar** | `NSStatusItem` (`AppDelegate.swift`) | `NotifyIcon` (WinForms / Hardcodet.Wpf.TaskbarNotification) |
| **Phím tắt toàn hệ thống** | `Carbon RegisterEventHotKey` (`HotKeyManager.swift`) | `RegisterHotKey` (Win32 API qua P/Invoke) |
| **Lấy văn bản đang chọn** | `AXUIElementCopyAttributeValue` (`TextGrabber.swift`) | `SendInput` giả lập `Ctrl + C` + `Clipboard.GetText()` |
| **Bóc tách chữ màn hình** | `VNRecognizeTextRequest` (`ScreenOCRService.swift`) | `OcrEngine.RecognizeAsync()` (`Windows.Media.Ocr`) |
| **Trợ lý AI WebView** | `WKWebView` (`AIWebView.swift`) | `Microsoft.Web.WebView2.Wpf.WebView2` |
| **Bóc tách kết quả AI** | `AIAnalysisParser.swift` | `AIAnalysisParser.cs` (Regex bóc tách đa dòng) |
| **Mẫu câu lệnh AI** | `AIPromptBuilder.swift` | `AIPromptBuilder.cs` (Khuôn mẫu prompt 5 phần) |
| **Lưu trữ Sổ tay** | `VocabularyService.swift` (JSON) | `VocabularyService.cs` (System.Text.Json) |

---

## 📁 4. Cấu Trúc Thư Mục Dự Kiến (Planned Project Structure)

```
ToolTrL-Windows/
├── ToolTrL.sln                     # Visual Studio Solution
├── ToolTrL/
│   ├── App.xaml / App.xaml.cs       # Application Lifecycle & System Tray initialization
│   │
│   ├── Core/
│   │   ├── HotKeyManager.cs         # Win32 RegisterHotKey listener (Alt+D, Alt+S, Alt+A, Alt+V)
│   │   ├── TextGrabber.cs           # Foreground window selection text retriever (Ctrl+C simulation)
│   │   ├── ScreenOCRService.cs      # Windows.Media.Ocr screen region snip & text recognizer
│   │   ├── SpeechService.cs         # Windows.Media.SpeechSynthesis text-to-speech engine
│   │   ├── TranslationService.cs    # Google Translate REST client with LRU MemoryCache
│   │   ├── VocabularyService.cs     # JSON Storage & CRUD operations for notebook items
│   │   ├── AIPromptBuilder.cs       # [Single Source of Truth] 100% logic copied from macOS version
│   │   └── AIAnalysisParser.cs      # Regex multiline LLM parser
│   │
│   ├── Models/
│   │   ├── SavedWordItem.cs         # Matches macOS SavedWordItem schema 1:1
│   │   └── ParsedAIAnalysis.cs      # Matches macOS ParsedAIAnalysis schema 1:1
│   │
│   └── UI/
│       ├── TranslationHUDWindow.xaml # Floating HUD near mouse cursor (Mica/Acrylic background)
│       ├── ScreenSnipOverlay.xaml    # Snipping tool transparent overlay window for OCR
│       ├── QuickAIWindow.xaml        # Floating WebView2 assistant (ChatGPT, Gemini, Claude)
│       ├── VocabularyNotebook.xaml   # 3-Pane / DataGrid Notebook window
│       └── GrammarDetailControl.xaml # Dedicated 5-section grammar document viewer
│
└── Resources/
    └── AppIcon.ico                  # Windows application icon
```

---

## 📊 5. Khả Năng Đồng Bộ Dữ Liệu Chéo (macOS 🔁 Windows)

Dữ liệu Sổ tay từ vựng lưu trữ dưới dạng JSON chuẩn:
```json
[
  {
    "id": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
    "word": "📐 Hiện tại đơn",
    "translation": "Diễn tả hành động lặp đi lặp lại...",
    "phonetic": "S + V(s/es) + O",
    "exampleEn": "I play tennis every weekend.",
    "aiPartOfSpeech": "Ngữ Pháp",
    "aiThematicGenre": "Cấu Trúc & Ngữ Pháp",
    "aiPriority": "high",
    "isFavorite": true,
    "isMastered": false,
    "savedDate": "2026-08-22T15:30:00Z",
    "aiDetailedAnalysis": "### 1. 📐 CÔNG THỨC CHUẨN..."
  }
]
```
👉 **Người dùng có thể xuất file JSON từ máy Mac và nhập trực tiếp vào máy Windows (hoặc ngược lại) mà không bị mất bất kỳ dữ liệu hay định dạng nào.**

---

## 🚀 6. Các Giai Đoạn Triển Khai (Implementation Roadmap)

### Giai Đoạn 1: Nền Tảng Chạy Ngầm & Dịch Nhanh (1 - 2 tuần)
- Tạo Solution .NET 8 / WPF hoặc WinUI 3.
- Cài đặt System Tray (`NotifyIcon`) và phím tắt toàn cục Win32 (`Alt + D`).
- Cửa sổ nổi HUD dịch nhanh tại vị trí con trỏ chuột với hiệu ứng kính mờ Windows 11.

### Giai Đoạn 2: Trợ Lý AI & Quét Chữ OCR (1 tuần)
- Tích hợp `Microsoft.Web.WebView2` cho cửa sổ Chat AI (`Alt + A`).
- Xây dựng màn hình chụp vùng ảnh màn hình và nhận diện bằng `Windows.Media.Ocr` (`Alt + S`).

### Giai Đoạn 3: Sổ Tay Từ Vựng & Cẩm Nang Ngữ Pháp (1 - 2 tuần)
- Giao diện Sổ tay 3 cột / Bảng dữ liệu DataGrid (`Alt + V`).
- Chế độ hiển thị Cẩm nang Ngữ pháp 5 phần (`GrammarDetailControl`).
- Ôn tập Flashcards 3D và tính năng Đồng bộ / Import / Export JSON.
- Đóng gói bộ cài đặt `ToolTrL-Setup.exe` (sử dụng Inno Setup / WiX).
