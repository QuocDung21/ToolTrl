# NekoTrans — landing page

Trang giới thiệu sản phẩm cho **NekoTrans**, viết bằng HTML/CSS thuần.
Không có build step, không phụ thuộc CDN, không dùng font tải ngoài — mở file là chạy.

> Thư mục này không liên quan tới Swift Package. `Package.swift` chỉ trỏ vào
> `Sources/` và `Tests/`, nên thêm/sửa trang này không ảnh hưởng build app.

## Xem thử

```bash
# cách nhanh nhất
open LandingPage/index.html

# hoặc chạy qua local server (giống môi trường thật hơn)
cd LandingPage && python3 -m http.server 8080
# rồi mở http://localhost:8080
```

## Cấu trúc

```
LandingPage/
├── index.html              # Landing page chuẩn (GUI)
├── styles.css              # design tokens + layout + responsive + dark mode
├── cli.html                # Landing page phong cách Terminal / Command Line
├── cli.css                 # Theme retro terminal (Obsidian, Matrix, Amber, Cyberpunk, Dracula)
├── cli.js                  # Engine tương tác CLI, lệnh tra từ, giả lập âm thanh phím
├── i18n.js                 # bản dịch tiếng Việt và tiếng Anh
├── site-data.js            # thông số dùng chung cho nội dung và thống kê
├── app.js                  # đổi ngôn ngữ, ghi nhớ lựa chọn, cập nhật meta
├── assets/
│   ├── favicon.svg         # logo mèo
│   ├── hero-hud.svg        # mock bảng dịch nổi (dùng ở mục 00)
│   ├── notebook.svg        # mock sổ tay từ vựng (mục 02)
│   └── flashcard.svg       # mock thẻ ôn tập (mục 03)
└── README.md
```

## Đa ngôn ngữ

Trang hỗ trợ tiếng Việt (`vi`) và tiếng Anh (`en`). Bộ chọn nằm ở thanh điều
hướng; lựa chọn được ghi nhớ trong `localStorage` và lần đầu sẽ tự nhận diện
ngôn ngữ trình duyệt (mặc định là tiếng Anh nếu không phải tiếng Việt). Nội
dung mặc định trong HTML vẫn là tiếng Việt để trang có thể đọc được khi
JavaScript bị tắt.

Khi thêm hoặc sửa nội dung, thêm cùng một khoá vào cả hai dictionary trong
`i18n.js`, rồi gắn `data-i18n`, `data-i18n-html`, `data-i18n-alt` hoặc
`data-i18n-label` tương ứng trong `index.html`.

Các icon nhỏ trong phần Tính năng nằm trong một **sprite SVG inline** ở đầu
`index.html` (`<symbol id="i-...">`) và được gọi bằng `<use href="#i-...">`.
Thêm icon mới thì thêm một `<symbol>` vào sprite đó.

## Việc cần làm trước khi publish

### 1. Cấu hình liên kết

Mọi chỗ cần link thật đều được đánh dấu bằng `data-placeholder` và được **tự động bind từ `site-data.js` (`SITE_DATA.links`)** khi trang tải:

| `data-placeholder` | Số chỗ | Trường trong `SITE_DATA.links` |
|---|---|---|
| `download-url` | 3 | `download` (Link tải release `.dmg` / `.zip`) |
| `source-url` | 2 | `source` (Repo GitHub) |
| `changelog-url` | 1 | `changelog` (Trang releases / có gì mới) |
| `support-url` | 1 | `support` (Kênh issues / hỗ trợ) |
| `privacy-url` | 1 | `privacy` (Chính sách quyền riêng tư) |

Khi cần đổi link, chỉ cần sửa một nơi duy nhất tại `LandingPage/site-data.js`.

### 2. Nguồn thông số kỹ thuật (`site-data.js`)

Các thông số hiển thị trên trang không nằm rải rác trong HTML hoặc bản dịch.
Chúng được bind từ `site-data.js` khi trang chạy: số provider, số phần phân
tích, phiên bản macOS tối thiểu, kích thước bản phát hành, phím tắt và links. Khi
thay đổi code hoặc artifact release, chỉ cập nhật nguồn dữ liệu này; nội dung
giao diện sẽ tự dùng giá trị mới ở cả tiếng Việt và tiếng Anh.

### 3. Phần giá (chưa có, cố ý)

Trang **không** nêu giá hay mô hình bán, vì tôi không biết bạn chọn gì và không
muốn ghi một điều sai. Khi đã quyết, chèn khối này ngay trước mục `#tai-ve`:

```html
<!-- Thêm ngay trên <section class="cta" id="tai-ve"> -->
<section class="section" id="gia">
  <p class="label">06 <span aria-hidden="true">·</span> Giá</p>
  <h2 class="h2">Một lần mua, dùng tiếp miễn phí</h2>
  <div class="twocol">
    <p class="twocol-lead">
      Trả một lần cho bản đầy đủ. Cập nhật và sửa lỗi miễn phí về sau.
    </p>
    <ul class="ticks">
      <li><strong>Dùng thử 14 ngày.</strong> Không cần thẻ, không cần tài khoản.</li>
      <li><strong>Kích hoạt trên hai máy Mac</strong> của cùng một người.</li>
      <li><strong>Hoàn tiền trong 14 ngày</strong> nếu không hợp.</li>
    </ul>
  </div>
</section>
```

…rồi sửa lại số thứ tự các mục phía sau (mục cuối hiện là `05`).

### 4. Ảnh chụp thật (tuỳ chọn)

Ba hình minh hoạ hiện tại là **SVG tự vẽ**, mô phỏng giao diện thật của app
(đúng bố cục bảng dịch, đúng khung công thức ngữ pháp). Nếu muốn dùng ảnh chụp
màn hình thật thì chỉ cần thay `src` trong `index.html`:

```html
<img src="assets/hero-hud.svg" width="1200" height="760" alt="...">
<!-- thành -->
<img src="assets/screenshot-hud.png" width="1200" height="760" alt="...">
```

Nên xuất ảnh ở bề rộng gấp đôi (2400px cho khung 1200px) để nét trên màn hình
Retina, và giữ `width`/`height` để trang không bị nhảy layout khi tải.

## Ghi chú thiết kế

- **Bảng màu lấy từ chính app**: `AppColors.accent` là xanh dương, `AppColors.phonetic`
  là cam — nên trang dùng xanh `#2F6FE4` làm màu nhấn và cam `#EF7A18` cho chữ 猫
  ở tiêu đề. Nền giấy ấm theo phong cách của ảnh tham chiếu.
- **Typography**: tiêu đề dùng serif hệ thống (`Iowan Old Style` → Palatino → Georgia),
  nội dung dùng sans hệ thống. Không tải font từ mạng nên trang không phụ thuộc dịch vụ ngoài.
- **Dark mode**: theo `prefers-color-scheme`, chỉ đổi token màu. Hai loại nút
  `.btn-dark` / `.btn-light` cố ý **không** dùng token `--ink` vì chúng sẽ đảo màu
  và thành chữ trắng trên nền trắng.
- **Responsive**: 3 breakpoint — 1020px (lưới 3→2 cột, các khối split xếp dọc),
  860px (ẩn menu ngang, mọi lưới về 1 cột, cỡ chữ nhỏ lại).
- **Khả dụng**: có skip-link, mọi ảnh đều có `alt`, `:focus-visible` rõ ràng,
  và tôn trọng `prefers-reduced-motion`.

## Đã kiểm chứng

- Không có anchor gãy, không có `<use>` trỏ sai, không thiếu file cục bộ.
- 3/3 ảnh có `alt`; mọi `var(--…)` trong CSS đều được định nghĩa.
- Đã render thật bằng WebKit ở 1440px (sáng/tối) và 430px để kiểm tra bố cục.
