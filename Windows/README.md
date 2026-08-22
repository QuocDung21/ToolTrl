# ToolTrL for Windows 🪟

Thư mục này chứa kế hoạch kiến trúc, thiết kế cấu trúc thư mục và tài liệu chuẩn bị phát triển phiên bản **ToolTrL dành cho hệ điều hành Windows 10 / 11**.

---

## 📑 Tài Liệu Kỹ Thuật

- 👉 Xem chi tiết toàn bộ đặc tả kiến trúc, bảng ánh xạ API từ macOS sang Windows và lộ trình triển khai tại: **[`ARCHITECTURE_WINDOWS.md`](./ARCHITECTURE_WINDOWS.md)**

---

## 🎯 Điểm Nổi Bật Dự Kiến Của Bản Windows:

1. **Công nghệ đề xuất**: C# .NET 8 + WinUI 3 / WPF (Native Fluent Design Mica & Acrylic).
2. **Hiệu năng**: Chạy ngầm ở System Tray tốn < 60MB RAM.
3. **Phím tắt toàn cục**:
   - `Alt + D`: Dịch nhanh văn bản đang bôi đen.
   - `Alt + S`: Quét chữ màn hình bằng `Windows.Media.Ocr`.
   - `Alt + A`: Mở nhanh Trợ lý AI (ChatGPT / Gemini qua Microsoft WebView2).
   - `Alt + V`: Mở Sổ tay từ vựng & Cẩm nang ngữ pháp.
4. **Tương thích chéo 100% với macOS**: Đồng bộ định dạng file dữ liệu `vocabulary_notebook.json`.
