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

// In-Memory Translation Cache
const TRANSLATION_CACHE = new Map();
const MAX_CACHE_SIZE = 1200;

function getCachedTranslation(text, targetLang, sourceLang) {
    const key = `${sourceLang}|${targetLang}|${text}`;
    return TRANSLATION_CACHE.get(key);
}

function setCachedTranslation(text, targetLang, sourceLang, result) {
    if (TRANSLATION_CACHE.size >= MAX_CACHE_SIZE) {
        const firstKey = TRANSLATION_CACHE.keys().next().value;
        TRANSLATION_CACHE.delete(firstKey);
    }
    const key = `${sourceLang}|${targetLang}|${text}`;
    TRANSLATION_CACHE.set(key, result);
}

// Core Translation Engine with Multi-Tier Fallback
async function fetchTranslation(text, targetLang = 'vi', sourceLang = 'auto') {
    if (!text || !text.trim()) {
        return { success: false, error: 'Empty text' };
    }

    const cleanText = text.trim();

    // 1. Check in-memory cache first
    const cached = getCachedTranslation(cleanText, targetLang, sourceLang);
    if (cached) {
        return cached;
    }

    // 2. Try Google Translate with Chrome Extension client (dict-chrome-ex)
    try {
        const res = await fetchGoogleTranslate(cleanText, targetLang, sourceLang, 'dict-chrome-ex');
        setCachedTranslation(cleanText, targetLang, sourceLang, res);
        return res;
    } catch (err) {
        // If 429 or other error, fallback to MyMemory
    }

    // 3. Fallback: MyMemory API
    try {
        const res = await fetchMyMemory(cleanText, targetLang, sourceLang);
        setCachedTranslation(cleanText, targetLang, sourceLang, res);
        return res;
    } catch (err) {
        // Fallback to Google GTX
    }

    // 4. Fallback: Google GTX client
    try {
        const res = await fetchGoogleTranslate(cleanText, targetLang, sourceLang, 'gtx');
        setCachedTranslation(cleanText, targetLang, sourceLang, res);
        return res;
    } catch (err) {
        throw new Error('Dịch vụ dịch tạm thời bị giới hạn tốc độ. Vui lòng thử lại sau vài giây.');
    }
}

// Google Translate Endpoint
async function fetchGoogleTranslate(cleanText, targetLang, sourceLang, client = 'dict-chrome-ex') {
    const url = `https://translate.googleapis.com/translate_a/single?client=${encodeURIComponent(client)}&sl=${encodeURIComponent(sourceLang)}&tl=${encodeURIComponent(targetLang)}&dt=t&dt=bd&dt=rm&q=${encodeURIComponent(cleanText)}`;

    const response = await fetch(url);
    if (!response.ok) {
        const error = new Error(`Google Translate error ${response.status}`);
        error.status = response.status;
        throw error;
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
            const pos = dict[0];
            const terms = dict[1] || [];
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

// MyMemory API Fallback
async function fetchMyMemory(cleanText, targetLang, sourceLang) {
    const sl = sourceLang === 'auto' ? 'en' : sourceLang;
    const url = `https://api.mymemory.translated.net/get?q=${encodeURIComponent(cleanText)}&langpair=${encodeURIComponent(sl)}|${encodeURIComponent(targetLang)}`;

    const response = await fetch(url);
    if (!response.ok) {
        throw new Error(`MyMemory error ${response.status}`);
    }

    const data = await response.json();
    if (data.responseStatus !== 200 || !data.responseData || !data.responseData.translatedText) {
        throw new Error(data.responseDetails || 'MyMemory translation rejected');
    }

    return {
        success: true,
        original: cleanText,
        translated: data.responseData.translatedText.trim(),
        phonetic: '',
        dictEntries: [],
        detectedSource: sl,
        targetLang: targetLang
    };
}

// Batch Translation with polite throttling & caching
async function translateBatch(texts, targetLang = 'vi', sourceLang = 'auto') {
    const results = [];
    const concurrency = 3;

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

        // Polite delay between batches to respect rate limits
        if (i + concurrency < texts.length) {
            await new Promise(r => setTimeout(r, 120));
        }
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
