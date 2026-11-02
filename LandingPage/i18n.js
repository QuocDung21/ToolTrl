/* ============================================================================
   NekoTrans — landing page translations
   Một nguồn duy nhất cho cả hai ngôn ngữ. Khoá đặt theo thứ tự xuất hiện
   trong index.html để dễ đối chiếu.

   Quy ước:
   - khoá thường        -> gán bằng textContent
   - khoá có hậu tố Html -> gán bằng innerHTML (chuỗi có <kbd>, <strong>, <br>…)
   Đây là dữ liệu tĩnh nội bộ, không phải input của người dùng.
   ========================================================================= */
window.I18N = {

  vi: {
    /* --- Meta ------------------------------------------------------------- */
    "meta.title": "NekoTrans — Dịch và học từ vựng ngay trên màn hình Mac",
    "meta.description": "Bôi đen là dịch. Lưu từ vào sổ tay, nghe phát âm, ôn bằng flashcard. Ứng dụng menu bar cho macOS {{minimumMacOS}}+, dữ liệu ở lại máy.",

    /* --- Chung ------------------------------------------------------------ */
    "action.download": "Tải cho Mac",
    "action.seeFeatures": "Xem tính năng",
    "action.source": "Xem mã nguồn",

    /* --- Điều hướng ------------------------------------------------------- */
    "nav.skip": "Bỏ qua điều hướng",
    "nav.ariaLabel": "Điều hướng chính",
    "nav.seeIt": "Xem qua",
    "nav.features": "Tính năng",
    "nav.notebook": "Sổ tay",
    "nav.privacy": "Riêng tư",
    "nav.requirements": "Yêu cầu",
    "nav.faq": "Hỏi đáp",
    "nav.langLabel": "Ngôn ngữ",
    "nav.cli": "CLI",

    /* --- Hero ------------------------------------------------------------- */
    "hero.eyebrow": "Phiên bản 1.0 · Dành cho macOS",
    "hero.lead": "Bôi đen một câu trên màn hình là có bản dịch ngay bên cạnh. Từ nào đáng học thì lưu vào sổ tay, nghe phát âm, rồi ôn bằng flashcard.",
    "hero.metaHtml": "Không cần tài khoản <span aria-hidden=\"true\">·</span> Dữ liệu ở lại máy <span aria-hidden=\"true\">·</span> Bảo mật bằng Keychain <span aria-hidden=\"true\">·</span> macOS {{minimumMacOS}} trở lên <span aria-hidden=\"true\">·</span> Cập nhật miễn phí",
    "hero.note": "Bản dựng ký sẵn, mở là chạy. Gỡ bằng cách kéo vào Thùng rác.",

    /* --- Quy trình 3 bước siêu tốc --------------------------------------- */
    "steps.ariaLabel": "Quy trình sử dụng trong 3 bước",
    "steps.s1Title": "Bôi đen văn bản",
    "steps.s1Desc": "Chọn bất kỳ từ hay câu nào trong Safari, Chrome, PDF, Mail, Xcode hay Slack.",
    "steps.s2Title": "Nhấn phím <kbd>{{shortcuts.translate}}</kbd>",
    "steps.s2Desc": "Bảng dịch nổi ngay sát con trỏ chuột trong 0.2s — không cần chuyển ứng dụng.",
    "steps.s3Title": "Xem nghĩa & Lưu từ",
    "steps.s3Desc": "Xem phiên âm IPA, nghe phát âm và bấm lưu vào sổ tay để ôn lại bằng flashcard.",

    /* --- 00 · Xem qua ----------------------------------------------------- */
    "s00.labelHtml": "00 <span aria-hidden=\"true\">·</span> Xem qua",
    "s00.h2": "Một tiện ích, cả bộ công cụ",
    "s00.lead": "Dịch, tra từ, lưu từ vựng, chép màn hình, ôn tập và thống kê — gói trong một ứng dụng menu bar, không mở thêm cửa sổ nào khi bạn đang đọc.",
    "s00.imgAlt": "Bôi đen một câu trên trang web, bảng dịch NekoTrans hiện ngay bên cạnh con trỏ",
    "s00.caption": "Bảng dịch nổi gần con trỏ. Ghim lại thì nó tự dịch mỗi khi bạn bôi đen.",

    /* --- 01 · Tính năng --------------------------------------------------- */
    "s01.labelHtml": "01 <span aria-hidden=\"true\">·</span> Tính năng",
    "s01.h2": "Sáu việc bạn làm mỗi ngày",
    "s01.lead": "Mỗi tính năng đều có phím tắt riêng và đổi được trong Cài đặt.",
    "f1.title": "Bôi đen là dịch",
    "f1.bodyHtml": "Nhấn <kbd>{{shortcuts.translate}}</kbd> (hoặc bấm bong bóng nổi cạnh vùng chọn) để dịch đoạn đang bôi đen. Bảng dịch hiện ngay dưới con trỏ, không cần chuyển ứng dụng.",
    "f2.title": "Nhiều engine, tự chọn cái nhanh nhất",
    "f2.body": "Apple dịch on-device, Google, DeepL, MyMemory và {{aiProviders.length}} nhà cung cấp AI. NekoTrans chạy song song rồi lấy kết quả về trước — engine lỗi sẽ tự tạm nghỉ thay vì treo bảng dịch.",
    "f3.title": "Tra từ điển có phiên âm",
    "f3.bodyHtml": "Phiên âm IPA, nghĩa tiếng Việt, ví dụ, từ đồng nghĩa và phát âm bản xứ. Từ chia thì vẫn tra được: gõ <em>went</em> sẽ hiểu là <em>go</em>.",
    "f4.title": "Chụp màn hình để lấy chữ",
    "f4.bodyHtml": "Nhấn <kbd>{{shortcuts.ocr}}</kbd>, khoanh vùng có chữ, NekoTrans đọc chữ trong ảnh và dịch luôn. Dùng cho ảnh chụp, video, hay đoạn chữ không copy được.",
    "f5.title": "Tìm từ vựng trong Spotlight",
    "f5.bodyHtml": "Mọi mục trong sổ tay được đánh chỉ mục vào Spotlight, nên <kbd>⌘Space</kbd> rồi gõ từ là ra ngay nghĩa đã lưu.",
    "f6.title": "Sao lưu lên GitHub Gist",
    "f6.body": "Đồng bộ hai chiều sổ tay và thống kê vào một Gist riêng tư, dữ liệu nén LZFSE trước khi gửi. Đổi máy thì khôi phục lại trong một lần bấm.",
    "s01.also": "Kèm theo: chạy ở menu bar không chiếm Dock, phím tắt tuỳ biến, hiển thị song ngữ hoặc chỉ dịch, thống kê mục tiêu học tập, và tích hợp sâu Spotlight & Phím tắt (Shortcuts) trên macOS.",

    /* --- 02 · Sổ tay ------------------------------------------------------ */
    "s02.labelHtml": "02 <span aria-hidden=\"true\">·</span> Sổ tay",
    "s02.h2": "Từ vựng và ngữ pháp, tách bạch",
    "s02.lead": "Mỗi mục lưu vào sổ tay đều được gắn loại ngay lúc tạo, nên từ vựng và công thức ngữ pháp có cách hiển thị riêng, không lẫn vào nhau.",
    "s02.twocolLead": "Công thức ngữ pháp nằm ở khung riêng bằng chữ đẳng khoảng màu xanh, ngay trên đầu mục — không trộn lẫn với phần nghĩa.",
    "s02.t1Html": "<strong>Phân tích AI sáu phần.</strong> Từ loại và tầng nghĩa, họ từ, collocation, sắc thái dễ nhầm, ví dụ, mẹo ghi nhớ.",
    "s02.t2Html": "<strong>Tự chống trùng.</strong> Lưu lại cùng một từ thì cập nhật mục cũ, không tạo thêm dòng.",
    "s02.t3Html": "<strong>Tìm kiếm và lọc.</strong> Lọc theo từ vựng, ngữ pháp, yêu thích, đã ghi nhớ.",
    "s02.imgAlt": "Sổ tay từ vựng: danh sách từ kèm phiên âm, bộ lọc theo loại, và khung công thức ngữ pháp riêng",
    "s02.caption": "Sổ tay: danh sách bên trái, chi tiết bên phải. Công thức ngữ pháp luôn ở khung riêng.",

    /* --- 03 · Ôn tập ------------------------------------------------------ */
    "s03.labelHtml": "03 <span aria-hidden=\"true\">·</span> Ôn tập",
    "s03.h2": "Học lại đúng thứ bạn sắp quên",
    "s03.body": "Thẻ lật hai mặt lấy dữ liệu từ chính sổ tay: mặt trước là từ hoặc công thức, mặt sau là nghĩa và ví dụ.",
    "s03.t1Html": "<strong>Đánh dấu đã nhớ / chưa nhớ</strong> để lần sau chỉ ôn phần còn yếu.",
    "s03.t2Html": "<strong>Lọc theo bộ thẻ:</strong> tất cả, chỉ từ vựng, chỉ ngữ pháp, mục yêu thích.",
    "s03.t3Html": "<strong>Thống kê theo ngày</strong> để biết mình có đang giữ nhịp hay không.",
    "s03.imgAlt": "Thẻ flashcard công thức ngữ pháp với hai lựa chọn Đã nhớ và Chưa nhớ",

    /* --- 04 · Riêng tư ---------------------------------------------------- */
    "s04.labelHtml": "04 <span aria-hidden=\"true\">·</span> Riêng tư",
    "s04.h2": "Khoá API nằm trong Keychain, không phải trong file cấu hình",
    "s04.lead": "Nhiều ứng dụng dịch lưu khoá API dạng văn bản thường trong thư mục cấu hình — đọc được bằng bất kỳ tiến trình nào. NekoTrans thì không.",
    "p1.title": "Khoá và token trong Keychain",
    "p1.body": "Sáu khoá API và token GitHub đều nằm trong Keychain của macOS. Bản cũ còn sót trong cấu hình sẽ được chuyển sang Keychain ở lần chạy đầu, rồi xoá đi.",
    "p2.title": "Dữ liệu học ở lại máy",
    "p2.body": "Sổ tay, lịch sử dịch, thống kê và cache đều nằm trong thư mục Application Support của bạn. Không có máy chủ trung gian nào của NekoTrans.",
    "p3.title": "Chỉ gọi ra ngoài khi bạn yêu cầu",
    "p3.body": "NekoTrans chỉ kết nối tới engine bạn chọn, và tới GitHub nếu bạn tự bật đồng bộ. Không có tài khoản, không telemetry, không quảng cáo.",
    "p4.title": "Nội dung bạn dịch không vào log",
    "p4.body": "Nhật ký chỉ ghi lỗi kỹ thuật. Phần chữ bạn bôi đen được đánh dấu riêng tư, nên không xuất hiện trong Console hay khi bạn gửi log cho ai đó.",

    /* --- 05 · Yêu cầu ----------------------------------------------------- */
    "s05.labelHtml": "05 <span aria-hidden=\"true\">·</span> Yêu cầu",
    "s05.h2": "Trước khi tải",
    "spec.os.dt": "Hệ điều hành",
    "spec.os.ddHtml": "macOS {{minimumMacOS}} trở lên (Sequoia). Bản dịch on-device dùng framework Translation của Apple, chỉ có từ macOS {{minimumMacOS}}.",
    "spec.arch.dt": "Kiến trúc",
    "spec.arch.dd": "Universal Binary (chạy mượt trên cả Apple Silicon M1–M4 và Intel).",
    "spec.size.dt": "Dung lượng",
    "spec.size.dd": "Khoảng {{releaseSize}}. Không kèm model AI nào — engine on-device do macOS cung cấp.",
    "spec.perm.dt": "Quyền cần cấp",
    "spec.perm.ddHtml": "<strong>Trợ năng</strong> để lấy đoạn văn bản đang chọn · <strong>Ghi màn hình</strong> cho tính năng chụp chữ màn hình (OCR).",
    "spec.account.dt": "Tài khoản",
    "spec.account.dd": "Không cần. Chỉ khi bạn muốn dùng engine AI trả phí thì nhập khoá API của riêng bạn — khoá được lưu trong Keychain.",
    "spec.uninstall.dt": "Gỡ cài đặt",
    "spec.uninstall.ddHtml": "Kéo ứng dụng vào Thùng rác. Dữ liệu học nằm trong <code>~/Library/Application Support/NekoTrans</code> nếu bạn muốn xoá sạch.",

    /* --- 06 · FAQ --------------------------------------------------------- */
    "s06.labelHtml": "06 <span aria-hidden=\"true\">·</span> Hỏi đáp",
    "s06.h2": "Câu hỏi thường gặp",
    "s06.lead": "Những điều người dùng Mac thường quan tâm trước khi cài đặt.",
    "faq.q1": "NekoTrans có cần kết nối Internet để hoạt động không?",
    "faq.a1": "Không bắt buộc. NekoTrans tích hợp Apple Translation framework và mô hình GGUF Metal để dịch hoàn toàn offline trên máy. Các engine đám mây (Google, DeepL, OpenAI, Claude...) chỉ gửi yêu cầu khi bạn chủ động lựa chọn.",
    "faq.q2": "Khóa API và dữ liệu của tôi có an toàn không?",
    "faq.a2": "Tuyệt đối an toàn. Mọi API key và token GitHub đều nằm trong macOS Keychain — bảo mật phần cứng qua Secure Enclave. Dữ liệu học tập và lịch sử dịch lưu hoàn toàn trong Application Support trên máy của bạn, không có bất kỳ máy chủ trung gian nào.",
    "faq.q3": "Ứng dụng hỗ trợ dòng máy Mac nào?",
    "faq.a3": "NekoTrans hỗ trợ cả chip Apple Silicon (M1/M2/M3/M4) và chip Intel (Universal Binary). Yêu cầu hệ điều hành macOS 15.0 Sequoia trở lên để sử dụng Apple Translation framework.",
    "faq.q4": "Tôi có thể đồng bộ sang máy Mac khác không?",
    "faq.a4": "Hoàn toàn được. Bạn có thể đồng bộ hai chiều sổ tay từ vựng và thống kê học tập qua GitHub Gist riêng tư (dữ liệu được nén LZFSE trước khi gửi). Đổi máy chỉ cần nhập token là khôi phục toàn bộ trong một click.",

    /* --- CTA cuối --------------------------------------------------------- */
    "cta.h2": "Cài xong là dịch được ngay",
    "cta.bodyHtml": "Không đăng ký, không cấu hình. Tải về, mở lên, bôi đen một câu bất kỳ và nhấn <kbd>{{shortcuts.translate}}</kbd>.",

    /* --- Chân trang ------------------------------------------------------- */
    "footer.note": "Ứng dụng dịch và học từ vựng cho macOS. Dữ liệu của bạn ở lại máy.",
    "footer.source": "Mã nguồn",
    "footer.changelog": "Có gì mới",
    "footer.support": "Hỗ trợ",
    "footer.privacy": "Quyền riêng tư",
    "footer.cli": "Bản dòng lệnh (CLI)",
    "footer.trademark": "Apple, macOS là thương hiệu của Apple Inc."
  },

  en: {
    /* --- Meta ------------------------------------------------------------- */
    "meta.title": "NekoTrans — Translate and learn vocabulary right on your Mac",
    "meta.description": "Select text and it is translated. Save words to a notebook, hear them pronounced, review with flashcards. A menu bar app for macOS {{minimumMacOS}}+ that keeps your data on your Mac.",

    /* --- Shared ----------------------------------------------------------- */
    "action.download": "Download for Mac",
    "action.seeFeatures": "See features",
    "action.source": "View source",

    /* --- Navigation ------------------------------------------------------- */
    "nav.skip": "Skip to content",
    "nav.ariaLabel": "Main navigation",
    "nav.seeIt": "See it",
    "nav.features": "Features",
    "nav.notebook": "Notebook",
    "nav.privacy": "Privacy",
    "nav.requirements": "Requirements",
    "nav.faq": "FAQ",
    "nav.langLabel": "Language",
    "nav.cli": "CLI",

    /* --- Hero ------------------------------------------------------------- */
    "hero.eyebrow": "Version 1.0 · Built for macOS",
    "hero.lead": "Select a sentence anywhere on screen and the translation appears right beside it. Save the words worth learning, hear them pronounced, then review with flashcards.",
    "hero.metaHtml": "No account needed <span aria-hidden=\"true\">·</span> Data stays on your Mac <span aria-hidden=\"true\">·</span> Secured with Keychain <span aria-hidden=\"true\">·</span> macOS {{minimumMacOS}} or later <span aria-hidden=\"true\">·</span> Free updates",
    "hero.note": "Signed build — just open it. Uninstall by dragging it to the Trash.",

    /* --- 3 quick steps ---------------------------------------------------- */
    "steps.ariaLabel": "How it works in 3 steps",
    "steps.s1Title": "Select text anywhere",
    "steps.s1Desc": "Highlight any word or sentence in Safari, Chrome, PDF, Mail, Xcode, or Slack.",
    "steps.s2Title": "Press <kbd>{{shortcuts.translate}}</kbd>",
    "steps.s2Desc": "The translation panel appears right beside your cursor in 0.2s — no app switching.",
    "steps.s3Title": "Learn & Save in 1 click",
    "steps.s3Desc": "View IPA phonetics, listen to native audio, and save to notebook for flashcard review.",

    /* --- 00 · See it ------------------------------------------------------ */
    "s00.labelHtml": "00 <span aria-hidden=\"true\">·</span> See it",
    "s00.h2": "One menu bar app, the whole toolkit",
    "s00.lead": "Translate, look words up, save vocabulary, capture text from screen, review and track progress — all in a menu bar app that never pulls you out of what you are reading.",
    "s00.imgAlt": "Selecting a sentence on a web page, with the NekoTrans translation panel appearing next to the cursor",
    "s00.caption": "The translation panel floats next to your cursor. Pin it and it translates every selection on its own.",

    /* --- 01 · Features ---------------------------------------------------- */
    "s01.labelHtml": "01 <span aria-hidden=\"true\">·</span> Features",
    "s01.h2": "Six things you do every day",
    "s01.lead": "Every feature has its own shortcut, and all of them can be changed in Settings.",
    "f1.title": "Select text, get a translation",
    "f1.bodyHtml": "Press <kbd>{{shortcuts.translate}}</kbd> — or click the bubble next to your selection — to translate the highlighted text. The panel opens under your cursor, so you never switch apps.",
    "f2.title": "Many engines, fastest one wins",
    "f2.body": "Apple's on-device translation, Google, DeepL, MyMemory and {{aiProviders.length}} AI providers. NekoTrans runs them in parallel and keeps the first result back — a failing engine backs off instead of freezing the panel.",
    "f3.title": "Dictionary with phonetics",
    "f3.bodyHtml": "IPA, Vietnamese meanings, examples, synonyms and native audio. Inflected words work too: type <em>went</em> and it understands <em>go</em>.",
    "f4.title": "Capture text from your screen",
    "f4.bodyHtml": "Press <kbd>{{shortcuts.ocr}}</kbd>, drag over any text, and NekoTrans reads it out of the image and translates it. Handy for screenshots, videos and text you cannot select.",
    "f5.title": "Find vocabulary in Spotlight",
    "f5.bodyHtml": "Every notebook entry is indexed into Spotlight, so <kbd>⌘Space</kbd> and the word brings up the meaning you saved.",
    "f6.title": "Back up to a GitHub Gist",
    "f6.body": "Two-way sync of your notebook and statistics into a private Gist, LZFSE-compressed before anything leaves your Mac. Change machines and restore in one click.",
    "s01.also": "Also included: runs quietly in the menu bar, remappable shortcuts, bilingual or translation-only display modes, daily streak statistics, and deep integration with Spotlight & Shortcuts on macOS.",

    /* --- 02 · Notebook ---------------------------------------------------- */
    "s02.labelHtml": "02 <span aria-hidden=\"true\">·</span> Notebook",
    "s02.h2": "Vocabulary and grammar, kept apart",
    "s02.lead": "Every entry is typed the moment you save it, so words and grammar formulas each keep their own layout instead of blurring together.",
    "s02.twocolLead": "Grammar formulas live in their own panel, in blue monospaced type at the top of the entry — never mixed into the meaning.",
    "s02.t1Html": "<strong>Six-section AI analysis.</strong> Part of speech and senses, word family, collocations, easily confused nuances, examples, mnemonics.",
    "s02.t2Html": "<strong>Deduplicated for you.</strong> Saving the same word again updates the existing entry instead of adding a row.",
    "s02.t3Html": "<strong>Search and filter.</strong> Filter by vocabulary, grammar, favourites or mastered.",
    "s02.imgAlt": "Vocabulary notebook: a word list with phonetics, type filters, and a separate grammar formula panel",
    "s02.caption": "The notebook: list on the left, details on the right. Grammar formulas always get their own panel.",

    /* --- 03 · Review ------------------------------------------------------ */
    "s03.labelHtml": "03 <span aria-hidden=\"true\">·</span> Review",
    "s03.h2": "Drill exactly what you are about to forget",
    "s03.body": "The two-sided cards are built from your own notebook: the front is the word or formula, the back is the meaning and examples.",
    "s03.t1Html": "<strong>Mark as remembered or not</strong> so the next session only drills your weak spots.",
    "s03.t2Html": "<strong>Filter the deck:</strong> all, vocabulary only, grammar only, or favourites.",
    "s03.t3Html": "<strong>Daily statistics</strong> so you can tell whether you are keeping the streak.",
    "s03.imgAlt": "Grammar flashcard showing the Remembered and Not yet options",

    /* --- 04 · Privacy ----------------------------------------------------- */
    "s04.labelHtml": "04 <span aria-hidden=\"true\">·</span> Privacy",
    "s04.h2": "API keys live in the Keychain, not in a config file",
    "s04.lead": "Plenty of translation apps keep API keys as plain text in a configuration folder, readable by any process on the machine. NekoTrans does not.",
    "p1.title": "Keys and tokens in the Keychain",
    "p1.body": "All six API keys and the GitHub token are stored in the macOS Keychain. Anything left behind in the old configuration is moved into the Keychain on first launch, then removed.",
    "p2.title": "Study data stays on your Mac",
    "p2.body": "Notebook, translation history, statistics and cache all live in your own Application Support folder. There is no NekoTrans server in between.",
    "p3.title": "Outbound calls only when you ask",
    "p3.body": "NekoTrans connects to the engine you choose, and to GitHub only if you turn sync on yourself. No account, no telemetry, no ads.",
    "p4.title": "What you translate never reaches the logs",
    "p4.body": "Logs record technical errors only. The text you select is marked private, so it never shows up in Console or in a log you send to someone.",

    /* --- 05 · Requirements ------------------------------------------------ */
    "s05.labelHtml": "05 <span aria-hidden=\"true\">·</span> Requirements",
    "s05.h2": "Before you download",
    "spec.os.dt": "Operating system",
    "spec.os.ddHtml": "macOS {{minimumMacOS}} or later (Sequoia). On-device translation uses Apple's Translation framework, which is only available from macOS {{minimumMacOS}}.",
    "spec.arch.dt": "Architecture",
    "spec.arch.dd": "Universal Binary (runs natively on both Apple Silicon M-series and Intel Macs).",
    "spec.size.dt": "Size",
    "spec.size.dd": "About {{releaseSize}}. It ships no AI models of its own — the on-device engine comes with macOS.",
    "spec.perm.dt": "Permissions",
    "spec.perm.ddHtml": "<strong>Accessibility</strong> to read the text you select · <strong>Screen Recording</strong> for screen OCR text capture.",
    "spec.account.dt": "Account",
    "spec.account.dd": "Not required. Only if you want a paid AI engine do you enter your own API key — and it is stored in the Keychain.",
    "spec.uninstall.dt": "Uninstall",
    "spec.uninstall.ddHtml": "Drag the app to the Trash. Study data lives in <code>~/Library/Application Support/NekoTrans</code> if you want to wipe it too.",

    /* --- 06 · FAQ --------------------------------------------------------- */
    "s06.labelHtml": "06 <span aria-hidden=\"true\">·</span> FAQ",
    "s06.h2": "Frequently Asked Questions",
    "s06.lead": "Everything you might want to know before downloading.",
    "faq.q1": "Does NekoTrans require an Internet connection to work?",
    "faq.a1": "Not required. NekoTrans integrates Apple's on-device Translation framework and local GGUF Metal models to translate completely offline. Cloud engines (Google, DeepL, OpenAI, Claude...) only connect when explicitly selected.",
    "faq.q2": "Are my API keys and study data secure?",
    "faq.a2": "Completely safe. All API keys and GitHub tokens are stored directly in the macOS Keychain — hardware-secured via Secure Enclave. Your study notebook and translation history stay exclusively in your Mac's Application Support folder, with zero intermediary servers.",
    "faq.q3": "Which Mac models are supported?",
    "faq.a3": "NekoTrans runs natively on both Apple Silicon (M1/M2/M3/M4) and Intel Macs (Universal Binary). Requires macOS 15.0 Sequoia or later to leverage Apple's Translation framework.",
    "faq.q4": "Can I sync my data to another Mac?",
    "faq.a4": "Yes, absolutely. You can perform two-way sync of your vocabulary notebook and statistics via a private GitHub Gist (LZFSE-compressed). Switching Macs only takes one click to restore everything.",

    /* --- Final CTA -------------------------------------------------------- */
    "cta.h2": "Install it and translate something",
    "cta.bodyHtml": "No sign-up, no configuration. Download it, open it, select any sentence and press <kbd>{{shortcuts.translate}}</kbd>.",

    /* --- Footer ----------------------------------------------------------- */
    "footer.note": "A translator and vocabulary builder for macOS. Your data stays on your Mac.",
    "footer.source": "Source",
    "footer.changelog": "What's new",
    "footer.support": "Support",
    "footer.privacy": "Privacy",
    "footer.cli": "Terminal Edition",
    "footer.trademark": "Apple and macOS are trademarks of Apple Inc."
  }
};
