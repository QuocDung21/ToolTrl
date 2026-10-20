/* ============================================================================
   NekoTrans — landing page behaviour
   1. Đổi ngôn ngữ tại chỗ (không tải lại trang)
   2. Nhớ lựa chọn; lần đầu thì theo ngôn ngữ trình duyệt
   3. Năm ở chân trang

   HTML chứa sẵn bản tiếng Việt, nên trang vẫn đọc được khi JavaScript bị tắt.
   Muốn đổi ngôn ngữ mặc định thì sửa DEFAULT_LANG bên dưới.
   ========================================================================= */
(function () {
  "use strict";

  var DEFAULT_LANG = "vi"; // ngôn ngữ có sẵn trong HTML
  var STORAGE_KEY = "nekotrans.lang";
  var SUPPORTED = ["vi", "en"];

  /* localStorage ném lỗi khi mở trang qua file:// trên Chrome, nên phải bọc lại.
     Mất tính năng ghi nhớ còn hơn làm hỏng cả đoạn script. */
  function readStored() {
    try {
      return window.localStorage.getItem(STORAGE_KEY);
    } catch (e) {
      return null;
    }
  }
  function writeStored(lang) {
    try {
      window.localStorage.setItem(STORAGE_KEY, lang);
    } catch (e) {
      /* bỏ qua */
    }
  }

  function detectLang() {
    var saved = readStored();
    if (saved && SUPPORTED.indexOf(saved) !== -1) return saved;

    var preferred =
      (navigator.languages && navigator.languages[0]) ||
      navigator.language ||
      DEFAULT_LANG;
    return preferred.toLowerCase().indexOf("vi") === 0 ? "vi" : "en";
  }

  function setMeta(attribute, name, value) {
    if (!value) return;
    var el = document.querySelector("meta[" + attribute + '="' + name + '"]');
    if (el) el.setAttribute("content", value);
  }

  function applyLang(lang) {
    var dictionary = window.I18N && window.I18N[lang];
    if (!dictionary) return;

    document.documentElement.lang = lang;

    // Chuỗi thuần
    document.querySelectorAll("[data-i18n]").forEach(function (el) {
      var value = dictionary[el.getAttribute("data-i18n")];
      if (value != null) el.textContent = value;
    });

    // Chuỗi có thẻ inline (<kbd>, <strong>, <br>…) — dữ liệu tĩnh nội bộ
    document.querySelectorAll("[data-i18n-html]").forEach(function (el) {
      var value = dictionary[el.getAttribute("data-i18n-html")];
      if (value != null) el.innerHTML = value;
    });

    // Thuộc tính
    document.querySelectorAll("[data-i18n-alt]").forEach(function (el) {
      var value = dictionary[el.getAttribute("data-i18n-alt")];
      if (value != null) el.setAttribute("alt", value);
    });
    document.querySelectorAll("[data-i18n-label]").forEach(function (el) {
      var value = dictionary[el.getAttribute("data-i18n-label")];
      if (value != null) el.setAttribute("aria-label", value);
    });

    // Thẻ <title> và các thẻ meta
    if (dictionary["meta.title"]) document.title = dictionary["meta.title"];
    setMeta("name", "description", dictionary["meta.description"]);
    setMeta("property", "og:title", dictionary["meta.title"]);
    setMeta("property", "og:description", dictionary["meta.description"]);

    // Trạng thái nút chuyển ngôn ngữ
    document.querySelectorAll("[data-lang]").forEach(function (button) {
      button.setAttribute(
        "aria-pressed",
        String(button.getAttribute("data-lang") === lang),
      );
    });

    writeStored(lang);
  }

  // Một listener duy nhất cho cả nhóm nút
  document.addEventListener("click", function (event) {
    var button = event.target.closest("[data-lang]");
    if (!button) return;
    applyLang(button.getAttribute("data-lang"));
  });

  // Năm hiện tại ở chân trang
  var year = document.getElementById("year");
  if (year) year.textContent = String(new Date().getFullYear());

  applyLang(detectLang());
})();
