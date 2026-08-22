# ToolTrL

**ToolTrL** là ứng dụng Menu Bar trên macOS giúp bạn tra từ điển, dịch nhanh đoạn văn, lưu sổ tay từ vựng và quản lý công thức ngữ pháp trực tiếp khi làm việc hay duyệt web.

---

## 🌟 Tính năng chính

### 1. Dịch nhanh tại vị trí con trỏ (`⌥ + D`)
- Bôi đen đoạn văn bản ở bất kỳ đâu (trình duyệt, file PDF, Xcode, Slack...) rồi bấm `Option + D`.
- Cửa sổ dịch nổi sẽ xuất hiện ngay bên cạnh con trỏ chuột.

### 2. Chụp và quét chữ trên màn hình (`⌥ + S`)
- Khoanh vùng bất kỳ khu vực nào trên màn hình (video Youtube, hình ảnh, trang web chặn bôi đen).
- Ứng dụng tự động nhận diện chữ (Apple Vision OCR) và hiển thị bản dịch ngay lập tức.

### 3. Sổ tay từ vựng & Cẩm nang ngữ pháp (`⌥ + V`)
- **Giao diện 3 cột hoặc dạng bảng**: Dễ dàng tìm kiếm, lọc theo từ loại, độ quan trọng hay chủ đề.
- **Phần Từ vựng**: Lưu nghĩa tiếng Việt, câu ví dụ thực tế kèm phát âm và từ điển giải nghĩa.
- **Phần Ngữ pháp**: Lưu công thức chuẩn dạng toán học, ý nghĩa/dấu hiệu nhận biết, ví dụ 3 thể (+, -, ?) và lưu ý bẫy đề thi.
- **Xem nhanh (Quick Look)**: Chọn một mục và bấm phím `Space` để xem toàn bộ thông tin chi tiết.
- **Ôn tập Flashcards**: Chế độ lật thẻ ghi nhớ 3D hỗ trợ phát âm.

### 4. Trợ lý AI hỗ trợ học (`⌥ + A`)
- Cửa sổ nổi tích hợp nhanh ChatGPT, Gemini, Claude và Perplexity.
- Tự động điền câu lệnh hỏi và hỗ trợ lưu kết quả phân tích về sổ tay chỉ với 1 nút bấm.

---

## ⌨️ Phím tắt mặc định

| Phím tắt | Thao tác |
|---|---|
| `⌥ + D` (`Option + D`) | Dịch văn bản đang chọn |
| `⌥ + S` (`Option + S`) | Chụp quét chữ trên màn hình (OCR) |
| `⌥ + A` (`Option + A`) | Mở trợ lý AI |
| `⌥ + V` (`Option + V`) | Mở Sổ tay từ vựng & ngữ pháp |
| `Space` | Xem nhanh chi tiết từ/ngữ pháp đang chọn |
| `Esc` | Đóng nhanh cửa sổ nổi |

*(Các phím tắt có thể tùy chỉnh lại trong phần Cài đặt của ứng dụng)*

---

## 🚀 Hướng dẫn cài đặt & Build từ mã nguồn

### Yêu cầu hệ thống:
- macOS 13.0 (Ventura) trở lên.
- Xcode 15+ hoặc Swift 5.9+.

### Các bước build:
```bash
# 1. Clone repository
git clone https://github.com/QuocDung21/ToolTrl.git
cd ToolTrl

# 2. Chạy script đóng gói ứng dụng
./Scripts/build_app.sh

# 3. Khởi chạy
open build/ToolTrL.app
```

---

## 🔒 Cấp quyền hệ thống trên macOS

Để ứng dụng hoạt động chính xác khi bấm phím tắt:
1. **Quyền Trợ năng (Accessibility)**: Cho phép ứng dụng đọc văn bản bạn vừa bôi đen (*Cài đặt hệ thống ➔ Quyền riêng tư & Bảo mật ➔ Trợ năng ➔ Bật ToolTrL*).
2. **Quyền Ghi màn hình (Screen Recording)**: Cho phép chụp vùng màn hình để quét chữ OCR (*Cài đặt hệ thống ➔ Quyền riêng tư & Bảo mật ➔ Ghi màn hình ➔ Bật ToolTrL*).

---

## 👨‍💻 Tác giả & Giấy phép
- Tác giả: **Dũng Nguyễn Quốc** ([@QuocDung21](https://github.com/QuocDung21))
- Mã nguồn phát hành theo giấy phép **MIT**.
