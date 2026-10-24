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
    var siteData = window.SITE_DATA || {};

    function interpolate(value) {
      return String(value).replace(/\{\{([\w.]+)\}\}/g, function (_, path) {
        var current = siteData;
        path.split(".").forEach(function (part) {
          current = current == null ? undefined : current[part];
        });
        if (current && typeof current === "object" && current[lang] != null) {
          current = current[lang];
        }
        return current == null ? "" : current;
      });
    }

    document.querySelectorAll("[data-site-value]").forEach(function (el) {
      var current = siteData;
      el.getAttribute("data-site-value").split(".").forEach(function (part) {
        current = current == null ? undefined : current[part];
      });
      if (current == null) return;
      var prefix = el.getAttribute("data-site-prefix") || "";
      var suffix = el.getAttribute("data-site-suffix") || "";
      el.textContent = prefix + current + suffix;
    });

    // Tự động cập nhật liên kết từ siteData.links cho các thẻ có data-placeholder
    if (siteData.links) {
      var linkMap = {
        "download-url": siteData.links.download,
        "source-url": siteData.links.source,
        "changelog-url": siteData.links.changelog,
        "support-url": siteData.links.support,
        "privacy-url": siteData.links.privacy
      };
      document.querySelectorAll("[data-placeholder]").forEach(function (el) {
        var placeholderKey = el.getAttribute("data-placeholder");
        if (linkMap[placeholderKey]) {
          el.setAttribute("href", linkMap[placeholderKey]);
        }
      });
    }

    document.documentElement.lang = lang;

    // Chuỗi thuần
    document.querySelectorAll("[data-i18n]").forEach(function (el) {
      var value = dictionary[el.getAttribute("data-i18n")];
      if (value != null) el.textContent = interpolate(value);
    });

    // Chuỗi có thẻ inline (<kbd>, <strong>, <br>…) — dữ liệu tĩnh nội bộ
    document.querySelectorAll("[data-i18n-html]").forEach(function (el) {
      var value = dictionary[el.getAttribute("data-i18n-html")];
      if (value != null) el.innerHTML = interpolate(value);
    });

    // Thuộc tính
    document.querySelectorAll("[data-i18n-alt]").forEach(function (el) {
      var value = dictionary[el.getAttribute("data-i18n-alt")];
      if (value != null) el.setAttribute("alt", interpolate(value));
    });
    document.querySelectorAll("[data-i18n-label]").forEach(function (el) {
      var value = dictionary[el.getAttribute("data-i18n-label")];
      if (value != null) el.setAttribute("aria-label", interpolate(value));
    });

    // Thẻ <title> và các thẻ meta
    if (dictionary["meta.title"]) document.title = interpolate(dictionary["meta.title"]);
    setMeta("name", "description", interpolate(dictionary["meta.description"]));
    setMeta("property", "og:title", interpolate(dictionary["meta.title"]));
    setMeta("property", "og:description", interpolate(dictionary["meta.description"]));

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
    var target = event.target;
    var button = target && target.closest ? target.closest("[data-lang]") : null;
    if (!button) return;
    var lang = button.getAttribute("data-lang");
    if (SUPPORTED.indexOf(lang) === -1) return;
    applyLang(lang);
  });

  // Năm hiện tại ở chân trang
  var year = document.getElementById("year");
  if (year) year.textContent = String(new Date().getFullYear());

  applyLang(detectLang());
})();
