# ToolTrL - macOS AI Quick Dictionary & Translator 🌐📖

**ToolTrL** là ứng dụng macOS native (SwiftUI & AppKit) chạy ngầm trên thanh Menu Bar, cho phép bạn bôi đen bất kỳ từ hoặc đoạn văn bản nào ở bất cứ đâu (trình duyệt web, ứng dụng chat, PDF, trình soạn thảo mã nguồn, v.v.), bấm phím tắt và nhận ngay bản dịch cùng giải nghĩa từ điển macOS với AI.

---

## ✨ Tính năng nổi bật

- ⚡ **Dịch tức thì ở mọi nơi**: Bôi đen chữ và nhấn `Option + D` (hoặc `⌥D`) để hiển thị popup HUD ngay tại vị trí con trỏ chuột.
- 🧠 **macOS AI & Apple Translation**: Tích hợp Apple `Translation` framework & `NaturalLanguage` tự động nhận diện ngôn ngữ.
- 📚 **Tích hợp Từ điển macOS (macOS Native Dictionary)**: Tra cứu nhanh phiên âm, từ loại, định nghĩa chuẩn xác từ hệ thống từ điển macOS với `DCSCopyTextDefinition`.
- 🗣️ **Phát âm từ vựng (Text-to-Speech)**: Nghe phát âm từ gốc và bản dịch bằng giọng đọc bản xứ (`AVSpeechSynthesizer`).
- 📋 **Sao chép 1-chạm**: Nút copy nhanh bản dịch hoặc phím tắt `⌘C`.
- 🔍 **Tìm kiếm / Nhập thủ công**: Ô tìm kiếm tích hợp cho phép tra bất kỳ từ mới nào mà không cần bôi đen trước.
- 🎨 **Giao diện Glassmorphism / Liquid HUD**: Thiết kế mờ sang trọng chuẩn phong cách Apple, hỗ trợ Dark/Light Mode.
- 🪶 **Siêu nhẹ & Tiết kiệm pin**: Chạy ngầm trên Menu Bar, không chiếm diện tích Dock (`LSUIElement`).

---

## ⌨️ Phím tắt mặc định

| Phím tắt | Chức năng |
|---|---|
| `Option + D` (`⌥D`) | Dịch văn bản / từ đang được bôi đen tại vị trí chuột |
| `Option + Cmd + T` (`⌥⌘T`) | Mở nhanh cửa sổ tra cứu |
| `ESC` | Đóng cửa sổ dịch popup |
| `Enter` | Dịch nội dung vừa gõ trong thanh tìm kiếm |

---

## 🚀 Cài đặt & Khởi chạy

### 1. Build ứng dụng
Chạy lệnh đóng gói ứng dụng:
```bash
./Scripts/build_app.sh
```

Ứng dụng sẽ được xuất ra tại thư mục: `build/ToolTrL.app`.

### 2. Cài đặt vào máy
Bạn có thể kéo `ToolTrL.app` vào thư mục `/Applications` hoặc mở trực tiếp:
```bash
open build/ToolTrL.app
```

---

## 🔒 Cấp quyền Trợ năng (Accessibility Permission)

Để ToolTrL có thể đọc được chữ bạn đã bôi đen ở các ứng dụng khác mà không cần bạn phải ấn `Cmd + C`, macOS yêu cầu cấp quyền Trợ năng:

1. Mở **Cài đặt hệ thống (System Settings)** > **Quyền riêng tư & Bảo mật (Privacy & Security)**.
2. Chọn **Trợ năng (Accessibility)**.
3. Bật cho phép **ToolTrL**.
4. (Nếu chưa thấy trong danh sách, bấm dấu `+` và chọn file `ToolTrL.app`).
