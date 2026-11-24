# NekoTrans

**NekoTrans** (repo `ToolTrl`) là ứng dụng Menu Bar trên **macOS 15.0+ (Sequoia)** giúp bạn tra từ điển, dịch nhanh đoạn văn (hỗ trợ Apple Translation offline, AI trực tuyến & mô hình GGUF chạy local), chụp quét chữ OCR, lưu sổ tay từ vựng và quản lý công thức ngữ pháp trực tiếp khi làm việc hay duyệt web.

---

## 🌟 Tính năng chính

### 1. Dịch nhanh tại vị trí con trỏ (`⌥ + D`)
- Bôi đen đoạn văn bản ở bất kỳ đâu (trình duyệt, file PDF, Xcode, Slack...) rồi bấm `Option + D`.
- Cửa sổ dịch nổi (HUD) xuất hiện ngay bên cạnh con trỏ chuột, hỗ trợ nhiều engine dịch (Apple Translation offline, AI API, Local GGUF).

### 2. Chụp và quét chữ trên màn hình (`⌥ + S`)
- Khoanh vùng bất kỳ khu vực nào trên màn hình (video YouTube, hình ảnh, trang web chặn bôi đen).
- Ứng dụng tự động nhận diện chữ (Apple Vision OCR) và hiển thị bản dịch ngay lập tức.

### 3. Sổ tay từ vựng & Cẩm nang ngữ pháp (`⌥ + V`)
- **Giao diện 3 cột hoặc dạng bảng**: Dễ dàng tìm kiếm, lọc theo từ loại, độ quan trọng hay chủ đề; hỗ trợ đồng bộ GitHub & AnkiConnect.
- **Phần Từ vựng**: Lưu nghĩa tiếng Việt, câu ví dụ thực tế kèm phát âm và từ điển giải nghĩa.
- **Phần Ngữ pháp**: Lưu công thức chuẩn dạng toán học, ý nghĩa/dấu hiệu nhận biết, ví dụ 3 thể (+, -, ?) và lưu ý bẫy đề thi.
- **Xem nhanh (Quick Look)**: Chọn một mục và bấm phím `Space` để xem toàn bộ thông tin chi tiết.
- **Ôn tập Flashcards**: Chế độ lật thẻ ghi nhớ 3D hỗ trợ phát âm.

### 4. Trợ lý AI hỗ trợ học (`⌥ + A`)
- Cửa sổ nổi tích hợp nhanh ChatGPT, Gemini, Claude, Perplexity và phân tích AI trực tiếp.
- Tự động điền câu lệnh hỏi và hỗ trợ lưu kết quả phân tích về sổ tay chỉ với 1 nút bấm.

### 5. Tiện ích mở rộng trình duyệt (Chrome / Safari)
- Hỗ trợ dịch trực tiếp trên trang web và kết nối với ứng dụng NekoTrans trên macOS.

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

## 🚀 Hướng dẫn cài đặt & Phát triển

### Yêu cầu hệ thống
- **macOS 15.0 (Sequoia)** trở lên (sử dụng Apple `Translation` framework).
- Để build từ mã nguồn: cần cài đặt đầy đủ **Xcode** (SwiftUI macros không chạy được nếu chỉ có Command Line Tools; `Scripts/toolchain.sh` sẽ tự động chọn Xcode phù hợp).

### Cách 1: Tải file cài đặt `.dmg` (Khuyên dùng)
1. Tải file **`NekoTrans-1.0.0.dmg`** mới nhất tại mục [Releases](https://github.com/QuocDung21/ToolTrl/releases).
2. Mở file `.dmg` vừa tải về.
3. Kéo biểu tượng **NekoTrans** vào thư mục **Applications** (Ứng dụng).
4. Mở **NekoTrans** từ Launchpad hoặc Spotlight để sử dụng ngay!

### Cách 2: Build, Test & Đóng gói từ mã nguồn
```bash
# 1. Clone repository
git clone https://github.com/QuocDung21/ToolTrl.git
cd ToolTrl

# 2. Build & chạy ứng dụng
make run

# 3. Chạy Unit Tests
make test

# 4. Tạo file cài đặt .dmg (output: build/NekoTrans-1.0.0.dmg)
make dmg

# 5. Đóng gói tiện ích mở rộng cho Chrome / Chromium
make chrome
```

---

## 🔒 Cấp quyền hệ thống trên macOS

Để ứng dụng hoạt động chính xác khi bấm phím tắt:
1. **Quyền Trợ năng (Accessibility)**: Cho phép ứng dụng đọc văn bản bạn vừa bôi đen (*Cài đặt hệ thống ➔ Quyền riêng tư & Bảo mật ➔ Trợ năng ➔ Bật NekoTrans*).
2. **Quyền Ghi màn hình (Screen Recording)**: Cho phép chụp vùng màn hình để quét chữ OCR (*Cài đặt hệ thống ➔ Quyền riêng tư & Bảo mật ➔ Ghi màn hình ➔ Bật NekoTrans*).

---

## 👨‍💻 Tác giả & Giấy phép
- Tác giả: **Dũng Nguyễn Quốc** ([@QuocDung21](https://github.com/QuocDung21))
- Mã nguồn phát hành theo giấy phép **MIT**.
