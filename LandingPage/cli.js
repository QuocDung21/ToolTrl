/* ============================================================================
   NekoTrans — Interactive CLI Engine (cli.js)
   Fully interactive terminal simulation:
   - Command interpreter with tab completion and history
   - Synchronized with SITE_DATA from site-data.js
   - Bilingual support (VI / EN)
   - Web Audio mechanical keyboard synthesizer (optional audio)
   - Real-time theme switcher (Default, Matrix, Amber, Cyberpunk, Dracula)
   - Zero external dependencies
   ========================================================================= */

(function () {
  "use strict";

  // State
  var state = {
    lang: "vi",
    theme: "default",
    soundEnabled: false,
    history: [],
    historyIndex: -1,
    fullscreen: false
  };

  // Audio Synth (Zero external files, Web Audio API)
  var audioCtx = null;
  function playKeyClick() {
    if (!state.soundEnabled) return;
    try {
      if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)();
      if (audioCtx.state === "suspended") audioCtx.resume();
      var osc = audioCtx.createOscillator();
      var gain = audioCtx.createGain();
      osc.type = "sine";
      osc.frequency.setValueAtTime(600 + Math.random() * 200, audioCtx.currentTime);
      gain.gain.setValueAtTime(0.015, audioCtx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.0001, audioCtx.currentTime + 0.04);
      osc.connect(gain);
      gain.connect(audioCtx.destination);
      osc.start();
      osc.stop(audioCtx.currentTime + 0.04);
    } catch (e) {
      // Audio not supported or blocked
    }
  }

  function playEnterBeep() {
    if (!state.soundEnabled) return;
    try {
      if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)();
      if (audioCtx.state === "suspended") audioCtx.resume();
      var osc = audioCtx.createOscillator();
      var gain = audioCtx.createGain();
      osc.type = "triangle";
      osc.frequency.setValueAtTime(440, audioCtx.currentTime);
      osc.frequency.exponentialRampToValueAtTime(880, audioCtx.currentTime + 0.08);
      gain.gain.setValueAtTime(0.03, audioCtx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.0001, audioCtx.currentTime + 0.08);
      osc.connect(gain);
      gain.connect(audioCtx.destination);
      osc.start();
      osc.stop(audioCtx.currentTime + 0.08);
    } catch (e) {
      // Audio not supported
    }
  }

  // Language Dictionary for CLI Output
  var CLI_TEXTS = {
    vi: {
      welcome: "Hệ điều hành NekoTrans OS đã sẵn sàng.\nNhập <span class='cli-cyan'>help</span> hoặc bấm các lệnh nhanh phía trên để bắt đầu.",
      helpTitle: "DANH MỤC LỆNH KHẢ DỤNG",
      helpDesc: "Gõ lệnh và nhấn Enter, hoặc click các thẻ lệnh gợi ý.",
      aboutTitle: "GIỚI THIỆU NEKOTRANS",
      aboutText: "NekoTrans là ứng dụng dịch thuật và học từ vựng thông minh cho macOS.\n" +
                "Được tối ưu native 100% bằng Swift, NekoTrans cho phép bạn bôi đen bất kỳ văn bản nào\n" +
                "trên màn hình để tra cứu tức thì qua bảng nổi (HUD), lưu vào sổ tay, và kích hoạt AI phân tích.",
      featuresTitle: "TÍNH NĂNG NỔI BẬT",
      shortcutsTitle: "BẢNG PHÍM TẮT TOÀN HỆ THỐNG",
      providersTitle: "CÁC MÔ HÌNH AI & DỊCH THUẬT HỖ TRỢ",
      specsTitle: "THÔNG SỐ KỸ THUẬT & HỆ THỐNG",
      downloadTitle: "TẢI VỀ & CÀI ĐẶT NEKOTRANS",
      downloadDesc: "Cài đặt ứng dụng qua Homebrew hoặc tải file cài đặt .dmg trực tiếp:",
      demoPrompt: "Nhập một từ hoặc câu để thử nghiệm (ví dụ: <span class='cli-yellow'>demo ubiquitous</span> hoặc <span class='cli-yellow'>demo serendipity</span>):",
      commandNotFound: "Lệnh không hợp lệ: '{{cmd}}'. Gõ <span class='cli-cyan'>help</span> để xem danh sách lệnh.",
      cleared: "Màn hình đã được xoá sạch. Gõ <span class='cli-cyan'>help</span> để xem các lệnh.",
      themeSwitched: "Đã chuyển theme sang: <span class='cli-cyan'>{{theme}}</span>",
      langSwitched: "Đã đổi ngôn ngữ sang: <span class='cli-cyan'>Tiếng Việt</span>",
      downloadBtn: "Tải file .dmg ngay",
      sourceBtn: "Xem mã nguồn GitHub",
      copyBrew: "Sao chép lệnh cài",
      copied: "Đã chép!",
      exitMsg: "Đang mở giao diện đồ họa...",
      guiMsg: "Đang chuyển sang bản giao diện web thông thường...",
      sudoDenied: "quyền root bị từ chối: NekoTrans tuân thủ bảo mật macOS tuyệt đối (Sandboxed & Keychain).",
      files: ["README.md", "NekoTrans.app", "config.json", "shortcuts.conf", "vocabulary.db"]
    },
    en: {
      welcome: "NekoTrans OS environment ready.\nType <span class='cli-cyan'>help</span> or click command chips above to explore.",
      helpTitle: "AVAILABLE COMMANDS",
      helpDesc: "Type command and press Enter, or click quick chips.",
      aboutTitle: "ABOUT NEKOTRANS",
      aboutText: "NekoTrans is a native macOS translation & vocabulary learning companion.\n" +
                "Built 100% natively in Swift, it lets you select any text on your screen\n" +
                "to get instant floating HUD translations, save words to a notebook, and query AI engines.",
      featuresTitle: "KEY FEATURES",
      shortcutsTitle: "GLOBAL SYSTEM SHORTCUTS",
      providersTitle: "SUPPORTED AI & TRANSLATION ENGINES",
      specsTitle: "TECHNICAL SPECIFICATIONS",
      downloadTitle: "DOWNLOAD & INSTALL NEKOTRANS",
      downloadDesc: "Install via Homebrew or download direct .dmg installer:",
      demoPrompt: "Type a word or sentence to test (e.g. <span class='cli-yellow'>demo ubiquitous</span> or <span class='cli-yellow'>demo serendipity</span>):",
      commandNotFound: "Command not found: '{{cmd}}'. Type <span class='cli-cyan'>help</span> for available commands.",
      cleared: "Screen cleared. Type <span class='cli-cyan'>help</span> for command list.",
      themeSwitched: "Theme changed to: <span class='cli-cyan'>{{theme}}</span>",
      langSwitched: "Language switched to: <span class='cli-cyan'>English</span>",
      downloadBtn: "Download .dmg now",
      sourceBtn: "View on GitHub",
      copyBrew: "Copy Brew command",
      copied: "Copied!",
      exitMsg: "Opening GUI interface...",
      guiMsg: "Redirecting to standard web landing page...",
      sudoDenied: "root permission denied: NekoTrans strictly honors macOS security (Sandboxed & Keychain).",
      files: ["README.md", "NekoTrans.app", "config.json", "shortcuts.conf", "vocabulary.db"]
    }
  };

  // Sample Interactive Vocabulary Database for CLI demo
  var DEMO_DICTIONARY = {
    "ubiquitous": {
      word: "ubiquitous",
      phonetic: "/juːˈbɪk.wɪ.təs/",
      pos: "Adjective (tính từ)",
      meaning: {
        vi: "Có mặt ở khắp mọi nơi, phổ biến cùng một lúc",
        en: "Present, appearing, or found everywhere"
      },
      example: {
        vi: "Smartphones have become ubiquitous in daily life. (Điện thoại thông minh đã trở nên phổ biến ở khắp mọi nơi trong đời sống.)",
        en: "Smartphones have become ubiquitous in daily life."
      },
      family: "ubiquity (n), ubiquitously (adv)",
      collocations: "ubiquitous presence, become ubiquitous, ubiquitous computing",
      mnemonic: {
        vi: "U-BI-QUI-TOUS: Liên tưởng 'ở đâu cũng (u) bị (bi) quý (qui) tới tấp (tous)' -> có mặt khắp mọi nơi.",
        en: "Sounds like 'you be quick with us' everywhere you go."
      }
    },
    "ephemeral": {
      word: "ephemeral",
      phonetic: "/ɪˈfem.ər.əl/",
      pos: "Adjective (tính từ)",
      meaning: {
        vi: "Phù du, chóng tàn, tồn tại trong thời gian rất ngắn",
        en: "Lasting for a very short time; fleeting"
      },
      example: {
        vi: "Fashions are ephemeral: what is popular today disappears tomorrow.",
        en: "Fashions are ephemeral: what is popular today disappears tomorrow."
      },
      family: "ephemerality (n), ephemerally (adv)",
      collocations: "ephemeral pleasure, ephemeral nature, ephemeral art",
      mnemonic: {
        vi: "E-PHE-MERAL: Nghĩ tới 'phê một lát' là hết -> chóng tàn, ngắn ngủi.",
        en: "Think of an 'ephemeris' or morning dew drying up in moments."
      }
    },
    "serendipity": {
      word: "serendipity",
      phonetic: "/ˌser.ənˈdɪp.ə.ti/",
      pos: "Noun (danh từ)",
      meaning: {
        vi: "Sự tình cờ may mắn, sự may mắn tìm thấy điều tốt lành bất ngờ",
        en: "The occurrence of events by chance in a happy or beneficial way"
      },
      example: {
        vi: "Finding this job was pure serendipity. (Tìm thấy công việc này hoàn toàn là một cơ duyên may mắn.)",
        en: "Finding this job was pure serendipity."
      },
      family: "serendipitous (adj), serendipitously (adv)",
      collocations: "pure serendipity, serendipitous discovery, happy serendipity",
      mnemonic: {
        vi: "Bắt nguồn từ câu chuyện ba hoàng tử đảo Serendip luôn tìm thấy may mắn trên đường.",
        en: "Coined by Horace Walpole from the Persian fairy tale 'The Three Princes of Serendip'."
      }
    },
    "resilience": {
      word: "resilience",
      phonetic: "/rɪˈzɪl.jəns/",
      pos: "Noun (danh từ)",
      meaning: {
        vi: "Khả năng phục hồi, sự kiên cường vượt qua nghịch cảnh",
        en: "The capacity to recover quickly from difficulties; toughness"
      },
      example: {
        vi: "Her mental resilience helped her overcome the greatest challenges.",
        en: "Her mental resilience helped her overcome the greatest challenges."
      },
      family: "resilient (adj), resiliently (adv)",
      collocations: "emotional resilience, build resilience, show great resilience",
      mnemonic: {
        vi: "Re-silience: bật ngược trở lại vị trí ban đầu như lò xo thép.",
        en: "Latin 'resilire' — to rebound or spring back."
      }
    }
  };

  // ASCII Banners
  var ASCII_CAT_LOGO = 
"  _   _      _        _____                     \n" +
" | \\ | | ___| | _____|_   _| __ __ _ _ __  ___  \n" +
" |  \\| |/ _ \\ |/ / _ \\ | || '__/ _` | '_ \\/ __| \n" +
" | |\\  |  __/   < (_) || || | | (_| | | | \\__ \\ \n" +
" |_| \\_|\\___|_|\\_\\___/ |_||_|  \\__,_|_| |_|___/ \n" +
"             /\\_/\\  Native macOS Translation & AI  \n" +
"            ( o.o )  100% Offline & Private        \n" +
"             > ^ <                                 ";

  var NEOFETCH_ART = 
"       /\\_/\\         \n" +
"      ( o.o )        \n" +
"       > ^ <         \n" +
"      /|   |\\        \n" +
"     (_|   |_)       \n" +
"       \"\" \"\"         ";

  // Elements
  var outputEl, inputEl, terminalWindowEl, themeSelectEl, soundBtnEl, fullscreenBtnEl;

  function focusInput() {
    if (inputEl && typeof inputEl.focus === "function") {
      inputEl.focus();
    }
  }

  // Initialize
  function init() {
    outputEl = document.getElementById("terminal-output");
    inputEl = document.getElementById("cli-input");
    terminalWindowEl = document.getElementById("terminal-window");
    themeSelectEl = document.getElementById("theme-select");
    soundBtnEl = document.getElementById("btn-sound");
    fullscreenBtnEl = document.getElementById("btn-fullscreen");

    // Detect language
    try {
      var savedLang = localStorage.getItem("nekotrans.lang");
      if (savedLang === "vi" || savedLang === "en") {
        state.lang = savedLang;
      } else {
        var pref = (navigator.languages && navigator.languages[0]) || navigator.language || "vi";
        state.lang = pref.toLowerCase().indexOf("vi") === 0 ? "vi" : "en";
      }
    } catch (e) {}

    // Detect theme
    try {
      var savedTheme = localStorage.getItem("nekotrans.cli_theme");
      if (savedTheme) {
        setTheme(savedTheme);
      }
    } catch (e) {}

    updateLangButtons();

    // Event listeners
    if (inputEl) {
      inputEl.addEventListener("keydown", handleInputKeydown);
      inputEl.addEventListener("input", function () {
        playKeyClick();
      });
    }

    // Click anywhere on terminal body focuses input
    var termBody = document.getElementById("terminal-body");
  if (termBody) {
    termBody.addEventListener("click", function (e) {
      if (!e.target.closest("a") && !e.target.closest("button")) {
        focusInput();
      }
    });
  }

    // Chips click handler
    var chipsContainer = document.getElementById("chips-bar");
    if (chipsContainer) {
      chipsContainer.addEventListener("click", function (e) {
        var chip = e.target.closest("[data-cmd]");
        if (chip) {
          var cmd = chip.getAttribute("data-cmd");
          executeCommand(cmd);
          focusInput();
        }
      });
    }

    // Top buttons
    if (themeSelectEl) {
      themeSelectEl.value = state.theme;
      themeSelectEl.addEventListener("change", function () {
        setTheme(this.value);
      });
    }

    if (soundBtnEl) {
      soundBtnEl.addEventListener("click", function () {
        state.soundEnabled = !state.soundEnabled;
        this.innerHTML = state.soundEnabled ? "🔊 Sound: ON" : "🔇 Sound: OFF";
        this.classList.toggle("active", state.soundEnabled);
        if (state.soundEnabled) playEnterBeep();
      });
    }

    if (fullscreenBtnEl) {
      fullscreenBtnEl.addEventListener("click", toggleFullscreen);
    }

    var langViBtn = document.getElementById("btn-lang-vi");
    var langEnBtn = document.getElementById("btn-lang-en");
    if (langViBtn) {
      langViBtn.addEventListener("click", function () { setLanguage("vi"); });
    }
    if (langEnBtn) {
      langEnBtn.addEventListener("click", function () { setLanguage("en"); });
    }

    // Window traffic lights
    var dotClose = document.getElementById("dot-close");
    var dotMin = document.getElementById("dot-min");
    var dotMax = document.getElementById("dot-max");
    if (dotClose) {
      dotClose.addEventListener("click", function () {
        appendOutput("<span class='cli-yellow'>[System]</span> NekoTrans process remains resident in menu bar for instant translations (⌥D).");
      });
    }
    if (dotMin) {
      dotMin.addEventListener("click", function () {
        var isHidden = termBody.style.display === "none";
        termBody.style.display = isHidden ? "flex" : "none";
      });
    }
    if (dotMax) {
      dotMax.addEventListener("click", toggleFullscreen);
    }

    // Boot sequence output
    renderBootSequence();
  }

  function toggleFullscreen() {
    state.fullscreen = !state.fullscreen;
    terminalWindowEl.classList.toggle("fullscreen", state.fullscreen);
    if (fullscreenBtnEl) {
      fullscreenBtnEl.innerHTML = state.fullscreen ? "⤓ Restore" : "⤢ Fullscreen";
    }
  }

  function setTheme(theme) {
    state.theme = theme;
    document.body.setAttribute("data-theme", theme);
    if (themeSelectEl) themeSelectEl.value = theme;
    try {
      localStorage.setItem("nekotrans.cli_theme", theme);
    } catch (e) {}
  }

  function setLanguage(lang) {
    if (lang !== "vi" && lang !== "en") return;
    state.lang = lang;
    try {
      localStorage.setItem("nekotrans.lang", lang);
    } catch (e) {}
    updateLangButtons();
    var t = CLI_TEXTS[state.lang];
    appendOutput("<div class='cli-green'>✓ " + t.langSwitched + "</div>");
  }

  function updateLangButtons() {
    var langViBtn = document.getElementById("btn-lang-vi");
    var langEnBtn = document.getElementById("btn-lang-en");
    if (langViBtn) langViBtn.classList.toggle("active", state.lang === "vi");
    if (langEnBtn) langEnBtn.classList.toggle("active", state.lang === "en");
  }

  function renderBootSequence() {
    var siteData = window.SITE_DATA || {};
    var ver = siteData.version || "1.0.0";
    var macos = siteData.minimumMacOS || "15.0";
    var t = CLI_TEXTS[state.lang];

    var html = "<div class='output-block'>";
    html += "<pre class='ascii-banner'>" + ASCII_CAT_LOGO + "</pre>";
    html += "<div class='cli-dim'>Last login: " + new Date().toLocaleString() + " on ttys001 (Apple Silicon arm64)</div>";
    html += "<div class='cli-dim'>Darwin 24.0.0 (macOS " + macos + "+ Sequoia) · NekoTrans v" + ver + "</div>";
    html += "<div style='margin-top: 6px;'>" + t.welcome + "</div>";
    html += "</div>";

    outputEl.innerHTML = html;
    scrollToBottom();
    focusInput();
  }

  // Keyboard Navigation & Command Input
  function handleInputKeydown(e) {
    if (e.key === "Enter") {
      e.preventDefault();
      var cmd = inputEl.value.trim();
      inputEl.value = "";
      if (cmd) {
        state.history.push(cmd);
        state.historyIndex = state.history.length;
      }
      playEnterBeep();
      executeCommand(cmd);
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      if (state.history.length > 0 && state.historyIndex > 0) {
        state.historyIndex--;
        inputEl.value = state.history[state.historyIndex];
      }
    } else if (e.key === "ArrowDown") {
      e.preventDefault();
      if (state.historyIndex < state.history.length - 1) {
        state.historyIndex++;
        inputEl.value = state.history[state.historyIndex];
      } else {
        state.historyIndex = state.history.length;
        inputEl.value = "";
      }
    } else if (e.key === "Tab") {
      e.preventDefault();
      handleTabCompletion();
    } else if (e.ctrlKey && e.key === "l") {
      e.preventDefault();
      executeCommand("clear");
    } else if (e.ctrlKey && e.key === "c") {
      e.preventDefault();
      appendOutput("<div class='command-echo-line'><span class='cli-dim'>^C</span></div>");
      inputEl.value = "";
    }
  }

  var ALL_COMMANDS = [
    "help", "about", "features", "shortcuts", "providers", 
    "demo", "specs", "download", "install", "brew", "neofetch", 
    "nekofetch", "theme", "lang", "clear", "cls", "gui", "web", 
    "history", "whoami", "date", "cat", "ls", "echo", "sudo", "exit"
  ];

  function handleTabCompletion() {
    var val = inputEl.value.toLowerCase();
    if (!val) return;
    var matches = ALL_COMMANDS.filter(function (c) {
      return c.indexOf(val) === 0;
    });
    if (matches.length === 1) {
      inputEl.value = matches[0];
    } else if (matches.length > 1) {
      appendOutput("<div class='command-echo-line'><span class='prompt-symbol'>$</span> " + val + "</div>");
      appendOutput("<div class='cli-dim'>" + matches.join("   ") + "</div>");
    }
  }

  // Execute and route commands
  function executeCommand(rawInput) {
    rawInput = (rawInput || "").trim();
    if (!rawInput) {
      appendOutput("<div class='command-echo-line'><span class='prompt-symbol'>$</span></div>");
      return;
    }

    // Echo input
    var echoHtml = "<div class='command-echo-line'>" +
      "<span class='prompt-user'>guest</span>" +
      "<span class='prompt-at'>@</span>" +
      "<span class='prompt-host'>nekotrans</span>" +
      "<span class='prompt-colon'>:</span>" +
      "<span class='prompt-path'>~</span>" +
      "<span class='prompt-symbol'>$</span> " +
      "<span class='cli-bright'>" + escapeHtml(rawInput) + "</span>" +
      "</div>";

    var parts = rawInput.split(/\s+/);
    var mainCmd = parts[0].toLowerCase();
    var args = parts.slice(1);
    var argStr = args.join(" ");

    var responseHtml = "";
    var t = CLI_TEXTS[state.lang];
    var siteData = window.SITE_DATA || {};

    switch (mainCmd) {
      case "help":
      case "?":
      case "--help":
      case "-h":
        responseHtml = renderHelp();
        break;

      case "about":
      case "info":
        responseHtml = renderAbout();
        break;

      case "features":
      case "feat":
        responseHtml = renderFeatures();
        break;

      case "shortcuts":
      case "keys":
        responseHtml = renderShortcuts();
        break;

      case "providers":
      case "ai":
      case "models":
        responseHtml = renderProviders();
        break;

      case "specs":
      case "sys":
      case "system":
        responseHtml = renderSpecs();
        break;

      case "download":
      case "install":
      case "brew":
        responseHtml = renderDownload();
        break;

      case "demo":
      case "translate":
        responseHtml = renderDemo(argStr);
        break;

      case "neofetch":
      case "nekofetch":
        responseHtml = renderNeofetch();
        break;

      case "theme":
        if (args[0]) {
          var chosenTheme = args[0].toLowerCase();
          if (["default", "matrix", "amber", "cyberpunk", "dracula"].indexOf(chosenTheme) !== -1) {
            setTheme(chosenTheme);
            responseHtml = "<div class='cli-green'>✓ " + t.themeSwitched.replace("{{theme}}", chosenTheme) + "</div>";
          } else {
            responseHtml = "<div class='cli-red'>Theme không hợp lệ. Chọn: <span class='cli-cyan'>default, matrix, amber, cyberpunk, dracula</span></div>";
          }
        } else {
          responseHtml = "<div class='cli-yellow'>Theme hiện tại: " + state.theme + ". Dùng: <span class='cli-cyan'>theme [default|matrix|amber|cyberpunk|dracula]</span></div>";
        }
        break;

      case "lang":
        if (args[0]) {
          var newLang = args[0].toLowerCase();
          if (newLang === "vi" || newLang === "en") {
            setLanguage(newLang);
            return;
          } else {
            responseHtml = "<div class='cli-red'>Ngôn ngữ hỗ trợ: <span class='cli-cyan'>lang vi</span> hoặc <span class='cli-cyan'>lang en</span></div>";
          }
        } else {
          responseHtml = "<div class='cli-yellow'>Ngôn ngữ hiện tại: " + state.lang + ". Dùng: <span class='cli-cyan'>lang vi</span> hoặc <span class='cli-cyan'>lang en</span></div>";
        }
        break;

      case "clear":
      case "cls":
        outputEl.innerHTML = "";
        appendOutput("<div class='cli-dim'>" + t.cleared + "</div>");
        scrollToBottom();
        return;

      case "gui":
      case "web":
        responseHtml = "<div class='cli-green'>" + t.guiMsg + "</div>";
        setTimeout(function () {
          window.location.href = "index.html";
        }, 600);
        break;

      case "exit":
        responseHtml = "<div class='cli-cyan'>" + t.exitMsg + "</div>";
        setTimeout(function () {
          window.location.href = "index.html";
        }, 700);
        break;

      case "history":
        responseHtml = "<div class='cli-dim'>" + state.history.map(function (h, i) {
          return "  " + (i + 1) + "  " + escapeHtml(h);
        }).join("<br>") + "</div>";
        break;

      case "whoami":
        responseHtml = "<div class='cli-cyan'>guest (macOS Power Learner & Developer)</div>";
        break;

      case "date":
        responseHtml = "<div class='cli-bright'>" + new Date().toString() + "</div>";
        break;

      case "ls":
        responseHtml = "<div class='cli-cyan'>" + t.files.join("&nbsp;&nbsp;&nbsp;&nbsp;") + "</div>";
        break;

      case "cat":
        if (args[0] === "README.md") {
          responseHtml = "<div class='cli-box'><strong># NekoTrans</strong><br>Native macOS translation & AI companion.<br>macOS 15.0+ Sequoia · Swift 6 / SwiftUI</div>";
        } else if (args[0] === "config.json") {
          responseHtml = "<pre class='cli-yellow'>{\n  \"version\": \"" + (siteData.version || "1.0.0") + "\",\n  \"offlineFirst\": true,\n  \"keychainSecured\": true\n}</pre>";
        } else {
          responseHtml = "<div class='cli-red'>cat: " + escapeHtml(args[0] || "") + ": File không tồn tại hoặc là thư mục nhị phân.</div>";
        }
        break;

      case "echo":
        responseHtml = "<div>" + escapeHtml(argStr) + "</div>";
        break;

      case "sudo":
        responseHtml = "<div class='cli-red'>" + t.sudoDenied + "</div>";
        break;

      default:
        responseHtml = "<div class='cli-red'>" + t.commandNotFound.replace("{{cmd}}", escapeHtml(mainCmd)) + "</div>";
        break;
    }

    appendOutput("<div class='output-block'>" + echoHtml + "<div class='command-response'>" + responseHtml + "</div></div>");
    scrollToBottom();
  }

  function appendOutput(html) {
    var div = document.createElement("div");
    div.innerHTML = html;
    outputEl.appendChild(div);
  }

  function scrollToBottom() {
    var termBody = document.getElementById("terminal-body");
    if (termBody) {
      setTimeout(function () {
        termBody.scrollTop = termBody.scrollHeight;
      }, 10);
    }
  }

  // Render Handlers
  function renderHelp() {
    var t = CLI_TEXTS[state.lang];
    var isVi = state.lang === "vi";
    return "<div class='cli-box'>" +
      "<div class='cli-box-header'>📖 " + t.helpTitle + "</div>" +
      "<div class='cli-dim' style='margin-bottom: 8px;'>" + t.helpDesc + "</div>" +
      "<table class='cli-table'>" +
      "<tr><th style='width: 140px;'>Lệnh</th><th>Mô tả</th><th>Ví dụ</th></tr>" +
      "<tr><td><span class='cli-cyan'>about</span></td><td>" + (isVi ? "Giới thiệu tổng quan về NekoTrans" : "About NekoTrans application") + "</td><td class='cli-dim'>about</td></tr>" +
      "<tr><td><span class='cli-cyan'>features</span></td><td>" + (isVi ? "6 tính năng cốt lõi (HUD, OCR, Flashcard, AI...)" : "6 core features (HUD, OCR, Flashcards, AI...)") + "</td><td class='cli-dim'>features</td></tr>" +
      "<tr><td><span class='cli-cyan'>shortcuts</span></td><td>" + (isVi ? "Bảng phím tắt toàn hệ thống macOS" : "Global macOS keyboard shortcuts table") + "</td><td class='cli-dim'>shortcuts</td></tr>" +
      "<tr><td><span class='cli-cyan'>providers</span></td><td>" + (isVi ? "Các mô hình AI và công nghệ dịch hỗ trợ" : "Supported AI engines & translation providers") + "</td><td class='cli-dim'>providers</td></tr>" +
      "<tr><td><span class='cli-cyan'>demo [word]</span></td><td>" + (isVi ? "Thử nghiệm tra cứu từ vựng & AI phân tích tương tác" : "Interactive live vocabulary & AI breakdown demo") + "</td><td class='cli-yellow'>demo ubiquitous</td></tr>" +
      "<tr><td><span class='cli-cyan'>download</span></td><td>" + (isVi ? "Tải bản cài đặt .dmg hoặc lệnh Homebrew" : "Download .dmg installer or Homebrew command") + "</td><td class='cli-dim'>download</td></tr>" +
      "<tr><td><span class='cli-cyan'>specs</span></td><td>" + (isVi ? "Yêu cầu hệ thống, kiến trúc & kích thước" : "System requirements, architecture & size") + "</td><td class='cli-dim'>specs</td></tr>" +
      "<tr><td><span class='cli-cyan'>neofetch</span></td><td>" + (isVi ? "Hiển thị thông tin hệ thống dạng ASCII Art" : "Display system info with ASCII Art") + "</td><td class='cli-dim'>neofetch</td></tr>" +
      "<tr><td><span class='cli-cyan'>theme [name]</span></td><td>" + (isVi ? "Đổi giao diện terminal (matrix, amber, cyberpunk, dracula)" : "Change terminal theme") + "</td><td class='cli-dim'>theme cyberpunk</td></tr>" +
      "<tr><td><span class='cli-cyan'>lang [vi|en]</span></td><td>" + (isVi ? "Đổi ngôn ngữ giao diện (VI / EN)" : "Switch language (VI / EN)") + "</td><td class='cli-dim'>lang en</td></tr>" +
      "<tr><td><span class='cli-cyan'>gui</span></td><td>" + (isVi ? "Chuyển về giao diện Landing Page thông thường" : "Switch to standard GUI landing page") + "</td><td class='cli-dim'>gui</td></tr>" +
      "<tr><td><span class='cli-cyan'>clear</span></td><td>" + (isVi ? "Xoá sạch màn hình terminal (Ctrl+L)" : "Clear the terminal screen (Ctrl+L)") + "</td><td class='cli-dim'>clear</td></tr>" +
      "</table>" +
      "</div>";
  }

  function renderAbout() {
    var t = CLI_TEXTS[state.lang];
    var isVi = state.lang === "vi";
    return "<div class='cli-box'>" +
      "<div class='cli-box-header'>🐱 " + t.aboutTitle + "</div>" +
      "<div style='white-space: pre-line; line-height: 1.6; margin-bottom: 12px;'>" + t.aboutText + "</div>" +
      "<div class='cli-card-grid'>" +
      "<div class='cli-card'><div class='cli-card-title'>⚡ Native Swift 6</div><div class='cli-card-desc'>" + (isVi ? "Viết bằng SwiftUI & AppKit thuần, mở là hiện ngay, không tốn RAM Electron." : "Built in pure SwiftUI & AppKit, zero Electron memory footprint, ultra responsive.") + "</div></div>" +
      "<div class='cli-card'><div class='cli-card-title'>🔒 100% Riêng tư</div><div class='cli-card-desc'>" + (isVi ? "Dịch offline qua Apple Translation framework. API key lưu an toàn trong macOS Keychain." : "Offline Apple Translation engine. API keys safely stored in macOS Keychain.") + "</div></div>" +
      "<div class='cli-card'><div class='cli-card-title'>🎯 Không làm đứt mạch</div><div class='cli-card-desc'>" + (isVi ? "Bảng dịch nổi ngay cạnh con trỏ chuột, không cần chuyển qua app hay trình duyệt khác." : "Floating HUD beside your cursor so you stay immersed in your reading workflow.") + "</div></div>" +
      "</div>" +
      "</div>";
  }

  function renderFeatures() {
    var isVi = state.lang === "vi";
    var siteData = window.SITE_DATA || {};
    var shortcuts = siteData.shortcuts || {};

    var features = [
      {
        title: "01. Floating Translation HUD",
        key: shortcuts.translate || "⌥D",
        desc: isVi 
          ? "Bôi đen từ hoặc câu, ấn phím tắt: Bảng dịch nổi xuất hiện ngay dưới con trỏ với phiên âm, từ loại, nghĩa cô đọng và phát âm audio giọng chuẩn bản ngữ."
          : "Select text and hit the shortcut: A non-activating floating HUD appears right beside your cursor with phonetics, meanings, and crystal-clear native audio."
      },
      {
        title: "02. Screen OCR Snipping",
        key: shortcuts.ocr || "⌥S",
        desc: isVi 
          ? "Kéo vùng chọn bất kỳ trên màn hình (ảnh, PDF khoá text, video phụ đề, app bảo vệ): Apple Vision Engine nhận diện chữ tức thì và dịch ngay lập tức."
          : "Drag-select any screen region (images, scanned PDFs, video subtitles): Apple Vision engine extracts text with high accuracy and translates on the fly."
      },
      {
        title: "03. Smart Vocabulary Notebook",
        key: shortcuts.notebook || "⌥V",
        desc: isVi 
          ? "Lưu từ vựng kèm ngữ cảnh gốc. Tự động nhận diện công thức ngữ pháp để hiển thị giao diện chuyên biệt; lọc theo từ loại, chủ đề, tag cá nhân."
          : "Save words with original reading context. Auto-detects grammar formulas to render custom views; filter by POS, thematic tags, or mastery levels."
      },
      {
        title: "04. Spaced Repetition Flashcards",
        key: "Flashcard",
        desc: isVi 
          ? "Thuật toán ngắt quãng giúp bạn ghi nhớ sâu. Luyện tập lật thẻ hai chiều (Anh-Việt, Việt-Anh), hỗ trợ đồng bộ mượt mà sang AnkiConnect."
          : "Spaced-repetition review modes to fix new words into long-term memory. Dual-sided review with native AnkiConnect integration."
      },
      {
        title: "05. 6-Dimensional AI Deep Analysis",
        key: shortcuts.ai || "⌥A",
        desc: isVi 
          ? "Phân tích toàn diện: Từ loại & tầng nghĩa, họ từ (Word Family), cụm từ thường đi kèm (Collocations), phân biệt sắc thái ngữ nghĩa, ví dụ câu thực tế và mẹo ghi nhớ."
          : "Comprehensive breakdown: POS & senses, word families, high-frequency collocations, subtle nuance differences, real-world examples, and memory mnemonics."
      },
      {
        title: "06. In-Place Translate & Polish",
        key: shortcuts.translateAndReplace || "⌥⇧T",
        desc: isVi 
          ? "Dịch và thay thế trực tiếp đoạn văn bạn đang gõ trong bất kỳ ô nhập liệu nào. Phím " + (shortcuts.polishAndReplace || "⌥⇧P") + " giúp trau chuốt câu từ chuyên nghiệp."
          : "Directly translate and replace selected text inside any input box on macOS. Press " + (shortcuts.polishAndReplace || "⌥⇧P") + " to polish tone and style."
      }
    ];

    var html = "<div class='cli-box'>" +
      "<div class='cli-box-header'>✨ " + (isVi ? "6 TÍNH NĂNG ĐỘC QUYỀN TRÊN MACOS" : "6 EXCLUSIVE MACOS FEATURES") + "</div>" +
      "<div class='cli-card-grid'>";

    features.forEach(function (f) {
      html += "<div class='cli-card'>" +
        "<div class='cli-card-title'>" + f.title + " <span class='cli-key-pill' style='margin-left: auto;'>" + f.key + "</span></div>" +
        "<div class='cli-card-desc'>" + f.desc + "</div>" +
        "</div>";
    });

    html += "</div></div>";
    return html;
  }

  function renderShortcuts() {
    var isVi = state.lang === "vi";
    var siteData = window.SITE_DATA || {};
    var s = siteData.shortcuts || {
      translate: "⌥D",
      ocr: "⌥S",
      ai: "⌥A",
      notebook: "⌥V",
      silentOCR: "⌥⇧S",
      translateAndReplace: "⌥⇧T",
      polishAndReplace: "⌥⇧P"
    };

    return "<div class='cli-box'>" +
      "<div class='cli-box-header'>⌨️ " + (isVi ? "BẢNG PHÍM TẮT TOÀN CỤC MACOS" : "GLOBAL MACOS KEYBOARD SHORTCUTS") + "</div>" +
      "<table class='cli-table'>" +
      "<tr><th>Hành động</th><th>Phím tắt</th><th>Chức năng</th></tr>" +
      "<tr><td><span class='cli-cyan'>" + (isVi ? "Dịch văn bản nổi" : "Floating Translation") + "</span></td><td><span class='cli-key-pill'>" + s.translate + "</span></td><td>" + (isVi ? "Bật HUD tra từ hoặc dịch câu ngay tại con trỏ" : "Open floating translation HUD at cursor") + "</td></tr>" +
      "<tr><td><span class='cli-cyan'>" + (isVi ? "Chụp màn hình OCR" : "Screen OCR Snip") + "</span></td><td><span class='cli-key-pill'>" + s.ocr + "</span></td><td>" + (isVi ? "Kéo vùng chọn màn hình để nhận diện & dịch" : "Snip screen region to extract & translate") + "</td></tr>" +
      "<tr><td><span class='cli-cyan'>" + (isVi ? "OCR im lặng" : "Silent OCR") + "</span></td><td><span class='cli-key-pill'>" + s.silentOCR + "</span></td><td>" + (isVi ? "Nhận diện chữ vào bộ nhớ tạm không bật bảng popup" : "Extract text straight to clipboard without popup") + "</td></tr>" +
      "<tr><td><span class='cli-cyan'>" + (isVi ? "Trợ lý AI nhanh" : "Quick AI Assistant") + "</span></td><td><span class='cli-key-pill'>" + s.ai + "</span></td><td>" + (isVi ? "Mở bảng tương tác AI giải thích ngữ cảnh chi tiết" : "Open smart AI context dialog") + "</td></tr>" +
      "<tr><td><span class='cli-cyan'>" + (isVi ? "Mở sổ tay từ vựng" : "Vocabulary Notebook") + "</span></td><td><span class='cli-key-pill'>" + s.notebook + "</span></td><td>" + (isVi ? "Mở cửa sổ sổ tay, tìm kiếm & quản lý flashcards" : "Open notebook, filter tags & practice flashcards") + "</td></tr>" +
      "<tr><td><span class='cli-cyan'>" + (isVi ? "Dịch & thay thế tại chỗ" : "Translate & Replace") + "</span></td><td><span class='cli-key-pill'>" + s.translateAndReplace + "</span></td><td>" + (isVi ? "Dịch ngay trong khung soạn thảo mà không cần copy paste" : "In-place translate selected text in any editor") + "</td></tr>" +
      "<tr><td><span class='cli-cyan'>" + (isVi ? "Trau chuốt văn phong" : "Polish & Replace") + "</span></td><td><span class='cli-key-pill'>" + s.polishAndReplace + "</span></td><td>" + (isVi ? "AI sửa ngữ pháp và nâng cao phong cách câu" : "AI rewrite and polish text styling in-place") + "</td></tr>" +
      "</table>" +
      "</div>";
  }

  function renderProviders() {
    var isVi = state.lang === "vi";
    var siteData = window.SITE_DATA || {};
    var providers = siteData.aiProviders || [
      { id: "openai", name: "OpenAI" },
      { id: "anthropic", name: "Claude" },
      { id: "gemini", name: "Gemini" },
      { id: "deepseek", name: "DeepSeek" },
      { id: "groq", name: "Groq" },
      { id: "gguf", name: "GGUF Metal" }
    ];

    var html = "<div class='cli-box'>" +
      "<div class='cli-box-header'>🤖 " + (isVi ? "CÁC ĐỘNG CƠ DỊCH & MÔ HÌNH AI ĐƯỢC HỖ TRỢ" : "SUPPORTED AI & TRANSLATION ENGINES") + "</div>" +
      "<div class='cli-dim' style='margin-bottom: 10px;'>" + 
      (isVi ? "Bạn toàn quyền lựa chọn động cơ phù hợp nhất: từ dịch tức thì không cần mạng cho đến các mô hình ngôn ngữ lớn nhất." : "Choose whatever engine fits your task: from 100% offline private engines to frontier LLMs.") + 
      "</div>" +
      "<div class='cli-card-grid'>";

    providers.forEach(function (p) {
      var badge = p.id === "gguf" ? "100% Offline (Metal)" : "Cloud API";
      var desc = "";
      if (p.id === "openai") desc = "GPT-4o, GPT-4o-mini với độ chuẩn ngữ nghĩa cao nhất.";
      else if (p.id === "anthropic") desc = "Claude 3.5 Sonnet sắc bén trong phân tích văn chương và ngữ cảnh phức tạp.";
      else if (p.id === "gemini") desc = "Gemini 1.5 Pro / Flash với tốc độ xử lý ngữ cảnh dài vượt trội.";
      else if (p.id === "deepseek") desc = "DeepSeek V3 / R1 tốc độ cao và chi phí tối ưu.";
      else if (p.id === "groq") desc = "Tốc độ siêu tốc LPU ~500 tokens/giây, phản hồi tức thì.";
      else if (p.id === "gguf") desc = "Chạy local hoàn toàn trên Apple Silicon qua Metal GPU, bảo mật tuyệt đối không gửi byte nào lên mạng.";

      html += "<div class='cli-card'>" +
        "<div class='cli-card-title'>" + p.name + " <span class='top-brand-badge'>" + badge + "</span></div>" +
        "<div class='cli-card-desc'>" + desc + "</div>" +
        "</div>";
    });

    html += "</div>" +
      "<div style='margin-top: 8px;' class='cli-dim'>🔒 " + (isVi ? "Mọi API key đều được lưu trong macOS Keychain, không bao giờ gửi về máy chủ trung gian." : "All credentials stay safely in macOS Keychain, never routed through third-party servers.") + "</div>" +
      "</div>";
    return html;
  }

  function renderSpecs() {
    var isVi = state.lang === "vi";
    var siteData = window.SITE_DATA || {};

    return "<div class='cli-box'>" +
      "<div class='cli-box-header'>⚙️ " + (isVi ? "THÔNG SỐ KỸ THUẬT & HỆ THỐNG" : "SYSTEM SPECIFICATIONS") + "</div>" +
      "<table class='cli-table'>" +
      "<tr><td class='cli-cyan'>Hệ điều hành:</td><td>macOS 15.0+ (Sequoia)</td></tr>" +
      "<tr><td class='cli-cyan'>Kiến trúc hỗ trợ:</td><td>Apple Silicon (M1/M2/M3/M4) & Intel Core 64-bit</td></tr>" +
      "<tr><td class='cli-cyan'>Ngôn ngữ phát triển:</td><td>Swift 6 Toolchain · SwiftUI & AppKit Native</td></tr>" +
      "<tr><td class='cli-cyan'>Dung lượng bộ cài:</td><td>~" + (siteData.releaseSize || "14 MB") + " (Cực nhẹ, khởi động dưới 0.1 giây)</td></tr>" +
      "<tr><td class='cli-cyan'>Bộ nhớ tiêu thụ:</td><td>~25-45 MB RAM (Nhẹ hơn 10x so với app nền Electron/Web)</td></tr>" +
      "<tr><td class='cli-cyan'>Bảo mật:</td><td>Apple Keychain, App Sandbox, zero telemetry</td></tr>" +
      "<tr><td class='cli-cyan'>Động cơ Offline:</td><td>Apple Translation Framework + Apple Vision OCR</td></tr>" +
      "</table>" +
      "</div>";
  }

  function renderDownload() {
    var isVi = state.lang === "vi";
    var siteData = window.SITE_DATA || {};
    var links = siteData.links || {};
    var downloadUrl = links.download || "https://github.com/QuocDung21/ToolTrl/releases/latest";
    var sourceUrl = links.source || "https://github.com/QuocDung21/ToolTrl";

    return "<div class='cli-box'>" +
      "<div class='cli-box-header'>🚀 " + (isVi ? "TẢI VỀ & CÀI ĐẶT NEKOTRANS" : "DOWNLOAD & INSTALL NEKOTRANS") + "</div>" +
      "<div style='margin-bottom: 12px;'>" + 
      (isVi ? "NekoTrans phân phối miễn phí và minh bạch. Bạn có thể cài qua Homebrew hoặc tải trực tiếp bản .dmg:" : "NekoTrans is distributed cleanly. You can install via Homebrew or grab the .dmg:") + 
      "</div>" +
      "<div style='background: rgba(0,0,0,0.5); padding: 12px; border-radius: 6px; border: 1px solid var(--term-border); margin-bottom: 12px; display: flex; justify-content: space-between; align-items: center;'>" +
      "<code>brew install --cask nekotrans</code>" +
      "<button class='top-btn' onclick='navigator.clipboard.writeText(\"brew install --cask nekotrans\"); this.innerText=\"✓ " + (isVi ? "Đã chép" : "Copied") + "\";'>📋 " + (isVi ? "Sao chép" : "Copy") + "</button>" +
      "</div>" +
      "<div style='display: flex; gap: 10px; flex-wrap: wrap;'>" +
      "<a class='cli-btn-action' href='" + downloadUrl + "' target='_blank'>⬇️ " + (isVi ? "Tải bản .DMG (macOS 15.0+)" : "Download .DMG (macOS 15.0+)") + "</a>" +
      "<a class='cli-btn-action cli-btn-secondary' href='" + sourceUrl + "' target='_blank'>🐙 GitHub Repository</a>" +
      "</div>" +
      "</div>";
  }

  function renderDemo(wordQuery) {
    var isVi = state.lang === "vi";
    var query = (wordQuery || "").trim().toLowerCase();

    if (!query) {
      return "<div class='cli-box'>" +
        "<div class='cli-box-header'>🔍 LIVE TRANSLATION DEMO</div>" +
        "<div>" + (isVi ? "Vui lòng nhập từ muốn tra cứu. Ví dụ:" : "Please specify a word to lookup. Examples:") + "</div>" +
        "<div style='margin-top: 8px; display: flex; gap: 8px; flex-wrap: wrap;'>" +
        "<button class='chip-btn' onclick='window.runCliCommand(\"demo ubiquitous\")'>demo ubiquitous</button>" +
        "<button class='chip-btn' onclick='window.runCliCommand(\"demo ephemeral\")'>demo ephemeral</button>" +
        "<button class='chip-btn' onclick='window.runCliCommand(\"demo serendipity\")'>demo serendipity</button>" +
        "<button class='chip-btn' onclick='window.runCliCommand(\"demo resilience\")'>demo resilience</button>" +
        "</div>" +
        "</div>";
    }

    var entry = DEMO_DICTIONARY[query];
    if (!entry) {
      // Simulate real AI breakdown for any custom input
      return "<div class='demo-result-card'>" +
        "<div style='display: flex; justify-content: space-between; align-items: baseline;'>" +
        "<span style='font-size: 18px; font-weight: 700; color: var(--c-cyan);'>" + escapeHtml(query) + "</span>" +
        "<span class='demo-phonetic'>[AI Context Analysis]</span>" +
        "</div>" +
        "<div style='margin: 8px 0; color: var(--c-green);'>✓ " + (isVi ? "Đã dịch sang tiếng Việt:" : "Translated to target language:") + "</div>" +
        "<div class='cli-box' style='background: rgba(255,255,255,0.02);'>" +
        "<strong>Bản dịch gợi ý:</strong> " + (isVi ? "Từ/cụm từ '" + escapeHtml(query) + "' trong ngữ cảnh câu tương đương." : "Target translation for '" + escapeHtml(query) + "'") + "<br>" +
        "<span class='cli-dim'>" + (isVi ? "💡 Trong app thật, NekoTrans kết nối trực tiếp Apple Translation Framework & AI của bạn để phân tích 6 chiều chi tiết." : "💡 In the native app, NekoTrans queries Apple Translation framework & your AI for full 6-dimensional parsing.") + "</span>" +
        "</div>" +
        "</div>";
    }

    var meaningText = isVi ? entry.meaning.vi : entry.meaning.en;
    var exampleText = isVi ? entry.example.vi : entry.example.en;
    var mnemonicText = isVi ? entry.mnemonic.vi : entry.mnemonic.en;

    return "<div class='demo-result-card'>" +
      "<div style='display: flex; justify-content: space-between; align-items: baseline; flex-wrap: wrap; gap: 8px;'>" +
      "<div>" +
      "<span style='font-size: 18px; font-weight: 700; color: var(--c-cyan);'>" + entry.word + "</span> " +
      "<span class='demo-phonetic'>" + entry.phonetic + "</span> " +
      "<span class='cli-dim'>· " + entry.pos + "</span>" +
      "</div>" +
      "<span class='top-brand-badge'>NekoTrans HUD Mock</span>" +
      "</div>" +

      "<div style='margin-top: 10px; font-size: 14px; font-weight: 600; color: var(--term-bright);'>" +
      "📖 " + meaningText +
      "</div>" +

      "<div style='margin-top: 6px; font-style: italic; color: var(--term-text);'>" +
      "\"" + exampleText + "\"" +
      "</div>" +

      "<div class='demo-ai-box'>" +
      "<div style='font-weight: 700; color: var(--c-purple); margin-bottom: 6px;'>🤖 AI Deep Analysis (6 Chiều)</div>" +
      "<div style='font-size: 12.5px; display: flex; flex-direction: column; gap: 4px;'>" +
      "<div><span class='cli-yellow'>• Họ từ (Word Family):</span> " + entry.family + "</div>" +
      "<div><span class='cli-yellow'>• Collocations:</span> " + entry.collocations + "</div>" +
      "<div><span class='cli-yellow'>• Mẹo ghi nhớ (Mnemonic):</span> " + mnemonicText + "</div>" +
      "</div>" +
      "</div>" +

      "<div style='margin-top: 10px; display: flex; gap: 8px;'>" +
      "<button class='top-btn' onclick='window.runCliCommand(\"download\")'>💾 Lưu vào sổ tay (⌥V)</button>" +
      "<button class='top-btn' onclick='window.runCliCommand(\"demo serendipity\")'>Thử từ khác ➔</button>" +
      "</div>" +

      "</div>";
  }

  function renderNeofetch() {
    var siteData = window.SITE_DATA || {};
    var ver = siteData.version || "1.0.0";
    var macos = siteData.minimumMacOS || "15.0";

    return "<div class='neofetch-wrap'>" +
      "<pre class='neofetch-art'>" + NEOFETCH_ART + "</pre>" +
      "<div class='neofetch-info'>" +
      "<div style='font-weight: 700; color: var(--c-pink); margin-bottom: 4px;'>guest@nekotrans-macbook</div>" +
      "<div style='color: var(--term-dim); margin-bottom: 8px;'>------------------------</div>" +
      "<div class='neofetch-row'><span class='neofetch-label'>OS:</span><span>macOS " + macos + "+ Sequoia (Darwin arm64)</span></div>" +
      "<div class='neofetch-row'><span class='neofetch-label'>Host:</span><span>MacBook Pro (Apple Silicon M-Series)</span></div>" +
      "<div class='neofetch-row'><span class='neofetch-label'>App:</span><span>NekoTrans v" + ver + "</span></div>" +
      "<div class='neofetch-row'><span class='neofetch-label'>Engine:</span><span>Apple Native Translation + Vision OCR</span></div>" +
      "<div class='neofetch-row'><span class='neofetch-label'>Uptime:</span><span>Instant Wake (Menu Bar Resident)</span></div>" +
      "<div class='neofetch-row'><span class='neofetch-label'>Memory:</span><span>~" + (siteData.releaseSize || "14 MB") + " footprint</span></div>" +
      "<div class='neofetch-row'><span class='neofetch-label'>Shortcuts:</span><span>⌥D (HUD), ⌥S (OCR), ⌥V (Notebook)</span></div>" +
      "<div class='neofetch-row'><span class='neofetch-label'>Colors:</span><span>" +
      "<span style='color:var(--c-red)'>●</span> " +
      "<span style='color:var(--c-green)'>●</span> " +
      "<span style='color:var(--c-yellow)'>●</span> " +
      "<span style='color:var(--c-blue)'>●</span> " +
      "<span style='color:var(--c-purple)'>●</span> " +
      "<span style='color:var(--c-cyan)'>●</span>" +
      "</span></div>" +
      "</div>" +
      "</div>";
  }

  function escapeHtml(str) {
    return String(str)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#039;");
  }

  // Global helper for click buttons
  window.runCliCommand = function (cmd) {
    if (inputEl) {
      inputEl.value = cmd;
      playEnterBeep();
      executeCommand(cmd);
      inputEl.value = "";
      focusInput();
    }
  };

  // Run on DOM ready
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
