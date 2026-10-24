// NekoTrans Safari Web Extension - Modern Native Popup Script

document.addEventListener('DOMContentLoaded', async () => {
    // Elements
    const sourceLangSelect = document.getElementById('sourceLang');
    const targetLangSelect = document.getElementById('targetLang');
    const btnSwapLang = document.getElementById('btnSwapLang');
    const btnTranslatePage = document.getElementById('btnTranslatePage');
    const btnTranslateLabel = document.getElementById('btnTranslateLabel');
    const btnRestorePage = document.getElementById('btnRestorePage');
    const segments = document.querySelectorAll('.segment');
    const toggleBubble = document.getElementById('toggleBubble');
    const toggleAutoSpeak = document.getElementById('toggleAutoSpeak');
    const quickInput = document.getElementById('quickInput');
    const btnQuickTranslate = document.getElementById('btnQuickTranslate');
    const quickResult = document.getElementById('quickResult');
    const quickResultText = document.getElementById('quickResultText');
    const btnCopyQuick = document.getElementById('btnCopyQuick');
    const btnSpeakQuick = document.getElementById('btnSpeakQuick');
    const btnOpenAppQuick = document.getElementById('btnOpenAppQuick');
    const btnOpenApp = document.getElementById('btnOpenApp');
    const statusBadge = document.getElementById('statusBadge');
    const statusText = document.getElementById('statusText');

    let currentTranslation = null;
    let currentDisplayMode = 'bilingual';

    // Helper: Format engine label into compact badge text
    function formatEngineName(rawName) {
        if (!rawName) return 'App Core';
        const str = String(rawName).trim();
        if (str.includes('Apple') || str.toLowerCase().includes('apple')) return 'Apple AI';
        if (str.includes('Trí tuệ nhân tạo') || str.includes('Direct') || str.toLowerCase().includes('directai')) return 'Direct AI';
        if (str.includes('Google')) return 'Google';
        if (str.includes('DeepL')) return 'DeepL';
        if (str.includes('Bing') || str.includes('Microsoft')) return 'Bing';
        if (str.includes('Offline') || str.includes('Ngoại tuyến')) return 'Offline';
        return str.length > 12 ? str.substring(0, 10) + '…' : str;
    }

    // Helper: Update primary translate button text based on current display mode
    function updateTranslateButtonLabel(mode) {
        if (!btnTranslateLabel) return;
        if (mode === 'replace') {
            btnTranslateLabel.innerText = 'Dịch thay thế trang web';
        } else {
            btnTranslateLabel.innerText = 'Dịch song ngữ trang web';
        }
    }

    // Check App Bridge Connection
    chrome.runtime.sendMessage({ action: 'getAppStatus' }, (res) => {
        if (res && res.connected && statusBadge && statusText) {
            const rawEngine = res.config?.engineName || res.config?.engine || 'App Core';
            const compactLabel = formatEngineName(rawEngine);

            statusBadge.classList.remove('disconnected');
            statusText.innerText = compactLabel;
            statusBadge.title = `Đã kết nối với NekoTrans App\nLõi: ${rawEngine}`;

            // Sync target language from desktop app if available
            if (res.config?.targetLanguage) {
                targetLangSelect.value = res.config.targetLanguage;
                saveSetting('targetLang', res.config.targetLanguage);
            }
        } else if (statusBadge && statusText) {
            statusBadge.classList.add('disconnected');
            statusText.innerText = 'Chế độ Web';
            statusBadge.title = 'Chưa kết nối NekoTrans App (Mở App để kích hoạt Apple Offline & Direct AI)';
        }
    });

    // Check active tab translation status
    chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
        if (tabs[0] && tabs[0].id) {
            chrome.tabs.sendMessage(tabs[0].id, { action: 'getPageStatus' }, (res) => {
                if (chrome.runtime.lastError) return;
                if (res && res.isTranslated) {
                    btnRestorePage.style.display = 'flex';
                }
            });
        }
    });

    // Load Settings
    chrome.storage.sync.get({
        targetLang: 'vi',
        sourceLang: 'auto',
        displayMode: 'bilingual',
        showSelectionBubble: true,
        autoSpeak: false
    }, (items) => {
        sourceLangSelect.value = items.sourceLang || 'auto';
        targetLangSelect.value = items.targetLang || 'vi';
        toggleBubble.checked = !!items.showSelectionBubble;
        toggleAutoSpeak.checked = !!items.autoSpeak;
        currentDisplayMode = items.displayMode || 'bilingual';

        segments.forEach(seg => {
            seg.classList.toggle('active', seg.dataset.mode === currentDisplayMode);
        });
        updateTranslateButtonLabel(currentDisplayMode);
    });

    // Helper: Save setting
    function saveSetting(key, val) {
        chrome.storage.sync.set({ [key]: val });
    }

    // Language Change Listeners
    sourceLangSelect.addEventListener('change', () => {
        saveSetting('sourceLang', sourceLangSelect.value);
    });

    targetLangSelect.addEventListener('change', () => {
        saveSetting('targetLang', targetLangSelect.value);
    });

    // Language Swap Button
    if (btnSwapLang) {
        btnSwapLang.addEventListener('click', () => {
            const currentSrc = sourceLangSelect.value;
            const currentTgt = targetLangSelect.value;

            if (currentSrc === 'auto') {
                sourceLangSelect.value = currentTgt;
                targetLangSelect.value = (currentTgt === 'en' ? 'vi' : 'en');
            } else {
                sourceLangSelect.value = currentTgt;
                targetLangSelect.value = currentSrc;
            }

            saveSetting('sourceLang', sourceLangSelect.value);
            saveSetting('targetLang', targetLangSelect.value);
        });
    }

    // Mode Segmented Control
    segments.forEach(seg => {
        seg.addEventListener('click', () => {
            segments.forEach(s => s.classList.remove('active'));
            seg.classList.add('active');
            currentDisplayMode = seg.dataset.mode || 'bilingual';
            saveSetting('displayMode', currentDisplayMode);
            updateTranslateButtonLabel(currentDisplayMode);
        });
    });

    // Toggle Settings
    toggleBubble.addEventListener('change', () => {
        saveSetting('showSelectionBubble', toggleBubble.checked);
    });

    toggleAutoSpeak.addEventListener('change', () => {
        saveSetting('autoSpeak', toggleAutoSpeak.checked);
    });

    // Translate Whole Page
    btnTranslatePage.addEventListener('click', () => {
        chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
            if (tabs[0] && tabs[0].id) {
                btnTranslatePage.disabled = true;
                const originalText = btnTranslateLabel.innerText;
                btnTranslateLabel.innerText = 'Đang bắt đầu dịch...';

                chrome.tabs.sendMessage(tabs[0].id, { action: 'startPageTranslation' }, (res) => {
                    setTimeout(() => {
                        btnTranslatePage.disabled = false;
                        btnTranslateLabel.innerText = originalText;
                        btnRestorePage.style.display = 'flex';
                    }, 600);
                });
            }
        });
    });

    // Restore Original Page
    btnRestorePage.addEventListener('click', () => {
        chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
            if (tabs[0] && tabs[0].id) {
                chrome.tabs.sendMessage(tabs[0].id, { action: 'restorePage' }, () => {
                    btnRestorePage.style.display = 'none';
                });
            }
        });
    });

    // Quick Translate Functionality
    async function doQuickTranslate() {
        const text = quickInput.value.trim();
        if (!text) return;

        btnQuickTranslate.disabled = true;

        chrome.runtime.sendMessage({
            action: 'translateText',
            text: text,
            targetLang: targetLangSelect.value,
            sourceLang: sourceLangSelect.value
        }, (res) => {
            btnQuickTranslate.disabled = false;

            if (res && res.success) {
                currentTranslation = res;
                quickResultText.innerText = res.translated;
                quickResult.style.display = 'block';

                if (toggleAutoSpeak.checked) {
                    speak(res.original, res.detectedSource);
                }
            } else {
                quickResultText.innerText = 'Lỗi dịch: ' + (res ? res.error : 'Không thể kết nối');
                quickResult.style.display = 'block';
            }
        });
    }

    btnQuickTranslate.addEventListener('click', doQuickTranslate);
    quickInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            doQuickTranslate();
        }
    });

    // Quick Result Toolbar Actions
    btnCopyQuick.addEventListener('click', () => {
        if (currentTranslation) {
            navigator.clipboard.writeText(currentTranslation.translated);
            const originalHTML = btnCopyQuick.innerHTML;
            btnCopyQuick.innerHTML = '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#34c759" stroke-width="2.5"><polyline points="20 6 9 17 4 12"></polyline></svg>';
            setTimeout(() => {
                btnCopyQuick.innerHTML = originalHTML;
            }, 1200);
        }
    });

    btnSpeakQuick.addEventListener('click', () => {
        if (currentTranslation) {
            speak(currentTranslation.original, currentTranslation.detectedSource);
        }
    });

    btnOpenAppQuick.addEventListener('click', () => {
        if (currentTranslation) {
            const url = `nekotrans://translate?text=${encodeURIComponent(currentTranslation.original)}`;
            chrome.runtime.sendMessage({ action: 'openApp', url: url });
        }
    });

    // Open NekoTrans App Main Window
    btnOpenApp.addEventListener('click', () => {
        chrome.runtime.sendMessage({ action: 'openApp', url: 'nekotrans://' });
    });

    function speak(text, lang) {
        if (!window.speechSynthesis) return;
        window.speechSynthesis.cancel();
        const utt = new SpeechSynthesisUtterance(text);
        if (lang && lang !== 'auto') utt.lang = lang;
        utt.rate = 0.95;
        window.speechSynthesis.speak(utt);
    }
});
