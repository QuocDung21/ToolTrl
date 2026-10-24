// NekoTrans Safari Web Extension - Popup Script

document.addEventListener('DOMContentLoaded', async () => {
    const sourceLangSelect = document.getElementById('sourceLang');
    const targetLangSelect = document.getElementById('targetLang');
    const btnTranslatePage = document.getElementById('btnTranslatePage');
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

    const statusBadge = document.querySelector('.status-badge');
    let currentTranslation = null;

    // Check NekoTrans App Bridge Connection
    chrome.runtime.sendMessage({ action: 'getAppStatus' }, (res) => {
        if (res && res.connected && statusBadge) {
            const engineLabel = res.config?.engineName || res.config?.engine || 'App';
            statusBadge.innerText = `🟢 Đã kết nối (${engineLabel})`;
            statusBadge.style.background = 'rgba(52, 199, 89, 0.15)';
            statusBadge.style.color = '#34c759';
            statusBadge.title = `Đang đồng bộ trực tiếp với NekoTrans App (Lõi: ${engineLabel})`;
            
            // Sync target language from App if available
            if (res.config?.targetLanguage) {
                targetLangSelect.value = res.config.targetLanguage;
                saveSetting('targetLang', res.config.targetLanguage);
            }
        } else if (statusBadge) {
            statusBadge.innerText = '⚪ Chế độ Web';
            statusBadge.title = 'Mở NekoTrans App để tự động dùng Apple Offline & Direct AI';
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

        segments.forEach(seg => {
            seg.classList.toggle('active', seg.dataset.mode === items.displayMode);
        });
    });

    // Save Settings Helpers
    function saveSetting(key, val) {
        chrome.storage.sync.set({ [key]: val });
    }

    sourceLangSelect.addEventListener('change', () => {
        saveSetting('sourceLang', sourceLangSelect.value);
    });

    targetLangSelect.addEventListener('change', () => {
        saveSetting('targetLang', targetLangSelect.value);
    });

    toggleBubble.addEventListener('change', () => {
        saveSetting('showSelectionBubble', toggleBubble.checked);
    });

    toggleAutoSpeak.addEventListener('change', () => {
        saveSetting('autoSpeak', toggleAutoSpeak.checked);
    });

    segments.forEach(seg => {
        seg.addEventListener('click', () => {
            segments.forEach(s => s.classList.remove('active'));
            seg.classList.add('active');
            saveSetting('displayMode', seg.dataset.mode);
        });
    });

    // Translate Page
    btnTranslatePage.addEventListener('click', () => {
        chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
            if (tabs[0] && tabs[0].id) {
                chrome.tabs.sendMessage(tabs[0].id, { action: 'startPageTranslation' }, () => {
                    btnRestorePage.style.display = 'flex';
                });
            }
        });
    });

    // Restore Page
    btnRestorePage.addEventListener('click', () => {
        chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
            if (tabs[0] && tabs[0].id) {
                chrome.tabs.sendMessage(tabs[0].id, { action: 'restorePage' }, () => {
                    btnRestorePage.style.display = 'none';
                });
            }
        });
    });

    // Quick Translate
    async function doQuickTranslate() {
        const text = quickInput.value.trim();
        if (!text) return;

        btnQuickTranslate.disabled = true;
        btnQuickTranslate.innerText = '…';

        chrome.runtime.sendMessage({
            action: 'translateText',
            text: text,
            targetLang: targetLangSelect.value,
            sourceLang: sourceLangSelect.value
        }, (res) => {
            btnQuickTranslate.disabled = false;
            btnQuickTranslate.innerText = '➔';

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

    btnCopyQuick.addEventListener('click', () => {
        if (currentTranslation) {
            navigator.clipboard.writeText(currentTranslation.translated);
            btnCopyQuick.innerText = '✓';
            setTimeout(() => { btnCopyQuick.innerText = '📋'; }, 1200);
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

    // Open NekoTrans App
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
