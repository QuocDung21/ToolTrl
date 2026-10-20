/* ============================================================================
   NekoTrans — landing page animations
   1. Đánh dấu <html class="js"> để CSS biết JS đang chạy
   2. Reveal on scroll bằng IntersectionObserver
   3. Đếm số ở khối stats
   4. Thu gọn nav khi cuộn

   Toàn bộ đều là progressive enhancement: JS tắt thì trang vẫn nguyên vẹn.
   ========================================================================= */
(function () {
  "use strict";

  var root = document.documentElement;
  root.classList.add("js");

  var reduceMotion = window.matchMedia(
    "(prefers-reduced-motion: reduce)",
  ).matches;

  /* ------------------------------------------------------------------ *
   * 1. Reveal on scroll
   * ------------------------------------------------------------------ */

  // Gán chỉ số stagger cho con của mỗi .stagger
  document.querySelectorAll(".stagger").forEach(function (group) {
    Array.prototype.forEach.call(group.children, function (child, i) {
      child.style.setProperty("--i", String(i));
    });
  });

  var revealTargets = document.querySelectorAll(".reveal, .stagger");

  if (reduceMotion || !("IntersectionObserver" in window)) {
    // Không có IO hoặc người dùng muốn giảm chuyển động: hiện tất cả
    Array.prototype.forEach.call(revealTargets, function (el) {
      el.classList.add("is-revealed");
    });
  } else {
    var observer = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          entry.target.classList.add("is-revealed");
          observer.unobserve(entry.target);
        });
      },
      {
        // Kích hoạt khi phần tử vào được ~12% và cách đáy viewport 60px
        rootMargin: "0px 0px -60px 0px",
        threshold: 0.12,
      },
    );

    Array.prototype.forEach.call(revealTargets, function (el) {
      observer.observe(el);
    });
  }

  /* ------------------------------------------------------------------ *
   * 2. Đếm số ở khối stats
   * ------------------------------------------------------------------ */

  function countUp(el) {
    var raw = el.textContent.trim();
    // Chỉ đếm phần số đứng trước, giữ nguyên hậu tố (%, +, …)
    var match = raw.match(/^(\d+)(.*)$/);
    if (!match) return;

    var target = parseInt(match[1], 10);
    var suffix = match[2] || "";
    var duration = 900;
    var start = null;

    function step(timestamp) {
      if (start === null) start = timestamp;
      var progress = Math.min((timestamp - start) / duration, 1);
      // easeOutCubic
      var eased = 1 - Math.pow(1 - progress, 3);
      el.textContent = Math.round(target * eased) + suffix;
      if (progress < 1) {
        requestAnimationFrame(step);
      } else {
        el.textContent = target + suffix;
        el.classList.add("is-counted");
      }
    }

    el.textContent = "0" + suffix;
    requestAnimationFrame(step);
  }

  var statNums = document.querySelectorAll(".stat-num");

  if (reduceMotion || !("IntersectionObserver" in window)) {
    // Để nguyên số gốc trong HTML
  } else {
    var statObserver = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          countUp(entry.target);
          statObserver.unobserve(entry.target);
        });
      },
      { threshold: 0.6 },
    );

    Array.prototype.forEach.call(statNums, function (el) {
      statObserver.observe(el);
    });
  }

  /* ------------------------------------------------------------------ *
   * 3. Nav thu gọn khi cuộn
   * ------------------------------------------------------------------ */

  var navWrap = document.querySelector(".nav-wrap");
  if (navWrap) {
    var ticking = false;

    function updateNav() {
      navWrap.classList.toggle("is-scrolled", window.scrollY > 12);
      ticking = false;
    }

    window.addEventListener(
      "scroll",
      function () {
        if (ticking) return;
        ticking = true;
        requestAnimationFrame(updateNav);
      },
      { passive: true },
    );

    updateNav(); 
  }
})();
