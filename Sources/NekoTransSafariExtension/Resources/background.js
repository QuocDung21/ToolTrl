// NekoTrans Safari Web Extension - Background Service Worker

const DEFAULT_SETTINGS = {
    targetLang: 'vi',
    sourceLang: 'auto',
    displayMode: 'bilingual', // 'bilingual' | 'replace'
    showSelectionBubble: true,
    autoSpeak: false,
    fontSize: 'normal'
};

// Initialize context menus & default settings on install
chrome.runtime.onInstalled.addListener(() => {
    chrome.storage.sync.get(DEFAULT_SETTINGS, (items) => {
        chrome.storage.sync.set(items);
    });

    createContextMenus();
});

function createContextMenus() {
    chrome.contextMenus.removeAll(() => {
        chrome.contextMenus.create({
            id: 'nekotrans-translate-selection',
            title: '🐱 Dịch đoạn đã chọn với NekoTrans',
            contexts: ['selection']
        });

        chrome.contextMenus.create({
            id: 'nekotrans-translate-page',
            title: '🌐 Dịch song ngữ trang web này',
            contexts: ['page']
        });

        chrome.contextMenus.create({
            id: 'nekotrans-restore-page',
            title: '🔄 Khôi phục trang gốc',
            contexts: ['page']
        });

        chrome.contextMenus.create({
            id: 'nekotrans-open-app',
            title: '🚀 Mở ứng dụng NekoTrans',
            contexts: ['action']
        });
    });
}

// Handle context menu clicks
chrome.contextMenus.onClicked.addListener((info, tab) => {
    if (!tab || !tab.id) return;

    if (info.menuItemId === 'nekotrans-translate-selection') {
        chrome.tabs.sendMessage(tab.id, {
            action: 'translateSelection',
            text: info.selectionText
        });
    } else if (info.menuItemId === 'nekotrans-translate-page') {
        chrome.tabs.sendMessage(tab.id, {
            action: 'startPageTranslation'
        });
    } else if (info.menuItemId === 'nekotrans-restore-page') {
        chrome.tabs.sendMessage(tab.id, {
            action: 'restorePage'
        });
    } else if (info.menuItemId === 'nekotrans-open-app') {
        openNekoTransURL('nekotrans://');
    }
});

// Handle keyboard commands
chrome.commands.onCommand.addListener((command) => {
    if (command === 'toggle-page-translation') {
        chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
            if (tabs[0] && tabs[0].id) {
                chrome.tabs.sendMessage(tabs[0].id, {
                    action: 'togglePageTranslation'
                });
            }
        });
    }
});

// Communication Hub
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (request.action === 'translateText') {
        fetchTranslation(request.text, request.targetLang || 'vi', request.sourceLang || 'auto')
            .then(result => sendResponse(result))
            .catch(error => sendResponse({ success: false, error: error.message }));
        return true; // asynchronous response
    }

    if (request.action === 'translateBatch') {
        translateBatch(request.texts, request.targetLang || 'vi', request.sourceLang || 'auto')
            .then(results => sendResponse({ success: true, results }))
            .catch(error => sendResponse({ success: false, error: error.message }));
        return true; // asynchronous response
    }

    if (request.action === 'openApp') {
        const url = request.url || 'nekotrans://';
        openNekoTransURL(url);
        sendResponse({ success: true });
        return true;
    }

    if (request.action === 'sendNative') {
        if (typeof browser !== 'undefined' && browser.runtime && browser.runtime.sendNativeMessage) {
            browser.runtime.sendNativeMessage('com.nekotrans.mac.SafariExtension', request.message, (response) => {
                sendResponse(response);
            });
            return true;
        } else {
            sendResponse({ error: 'Native messaging not available' });
        }
    }
});

// Core Translation Engine
async function fetchTranslation(text, targetLang = 'vi', sourceLang = 'auto') {
    if (!text || !text.trim()) {
        return { success: false, error: 'Empty text' };
    }

    const cleanText = text.trim();
    const url = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=${encodeURIComponent(sourceLang)}&tl=${encodeURIComponent(targetLang)}&dt=t&dt=bd&dt=rm&q=${encodeURIComponent(cleanText)}`;

    const response = await fetch(url);
    if (!response.ok) {
        throw new Error(`Translation request failed with status: ${response.status}`);
    }

    const data = await response.json();

    let translated = '';
    let phonetic = '';
    let detectedSource = data[2] || sourceLang;

    // Parse translated sentences & phonetic transliteration
    if (Array.isArray(data[0])) {
        for (const item of data[0]) {
            if (item && item[0]) {
                translated += item[0];
            }
            if (item && item[3]) {
                phonetic = item[3];
            }
        }
    }

    // Parse dictionary definitions & parts of speech
    let dictEntries = [];
    if (Array.isArray(data[1])) {
        for (const dict of data[1]) {
            const pos = dict[0]; // e.g. "noun", "verb"
            const terms = dict[1] || []; // alternate terms
            dictEntries.push({ pos, terms: terms.slice(0, 5) });
        }
    }

    return {
        success: true,
        original: cleanText,
        translated: translated.trim(),
        phonetic: phonetic.trim(),
        dictEntries: dictEntries,
        detectedSource: detectedSource,
        targetLang: targetLang
    };
}

// Batch Translation with Concurrency Control
async function translateBatch(texts, targetLang = 'vi', sourceLang = 'auto') {
    const results = [];
    const concurrency = 5;

    for (let i = 0; i < texts.length; i += concurrency) {
        const slice = texts.slice(i, i + concurrency);
        const promises = slice.map(async (text) => {
            try {
                const res = await fetchTranslation(text, targetLang, sourceLang);
                return res.success ? res.translated : text;
            } catch (e) {
                return text;
            }
        });
        const batchResults = await Promise.all(promises);
        results.push(...batchResults);
    }

    return results;
}

function openNekoTransURL(url) {
    chrome.tabs.create({ url: url, active: false }, (newTab) => {
        // Automatically close the temporary scheme redirect tab after a short delay
        setTimeout(() => {
            if (newTab && newTab.id) {
                chrome.tabs.remove(newTab.id);
            }
        }, 800);
    });
}
