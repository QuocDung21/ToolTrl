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

// NekoTrans Local Bridge Configuration (Unified App Core)
const BRIDGE_URL = 'http://127.0.0.1:42421';
let isBridgeConnected = false;
let bridgeConfig = null;

async function checkBridgeStatus() {
    try {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 600);
        const res = await fetch(`${BRIDGE_URL}/api/status`, { signal: controller.signal });
        clearTimeout(timeoutId);
        if (res.ok) {
            bridgeConfig = await res.json();
            isBridgeConnected = true;
            return bridgeConfig;
        }
    } catch (e) {
        isBridgeConnected = false;
        bridgeConfig = null;
    }
    return null;
}

// Active tab abort controllers to cancel in-flight network/bridge requests on tab close/navigation
const activeTabAbortControllers = new Map();

function registerTabAbortController(tabId, controller) {
    if (!tabId) return;
    const existing = activeTabAbortControllers.get(tabId);
    if (existing) {
        try { existing.abort(); } catch (e) {}
    }
    activeTabAbortControllers.set(tabId, controller);
}

function cancelTabTranslation(tabId) {
    if (!tabId) return;
    const controller = activeTabAbortControllers.get(tabId);
    if (controller) {
        try { controller.abort(); } catch (e) {}
        activeTabAbortControllers.delete(tabId);
    }
}

// Cleanup when tab is closed
if (typeof chrome !== 'undefined' && chrome.tabs && chrome.tabs.onRemoved) {
    chrome.tabs.onRemoved.addListener((tabId) => {
        cancelTabTranslation(tabId);
    });
}

// Communication Hub
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    const tabId = sender.tab ? sender.tab.id : null;

    if (request.action === 'translateText') {
        fetchTranslation(request.text, request.targetLang || 'vi', request.sourceLang || 'auto')
            .then(result => sendResponse(result))
            .catch(error => sendResponse({ success: false, error: error.message }));
        return true; // asynchronous response
    }

    if (request.action === 'translateBatch') {
        translateBatch(request.texts, request.targetLang || 'vi', request.sourceLang || 'auto', tabId)
            .then(results => sendResponse({ success: true, results }))
            .catch(error => sendResponse({ success: false, error: error.message }));
        return true; // asynchronous response
    }

    if (request.action === 'cancelPageTranslation') {
        cancelTabTranslation(tabId);
        sendResponse({ success: true });
        return true;
    }

    if (request.action === 'saveWord') {
        saveWordToApp(request.word, request.translation, request.phonetic)
            .then(result => sendResponse(result))
            .catch(error => sendResponse({ success: false, error: error.message }));
        return true;
    }

    if (request.action === 'checkWord') {
        checkWordInApp(request.word)
            .then(result => sendResponse(result))
            .catch(error => sendResponse({ isSaved: false }));
        return true;
    }

    if (request.action === 'getAppStatus') {
        checkBridgeStatus().then(status => {
            sendResponse({
                connected: isBridgeConnected,
                config: status
            });
        });
        return true;
    }

    if (request.action === 'openApp') {
        const url = request.url || 'nekotrans://open';
        // 1. Try local bridge first to open app window instantly without temporary browser tab
        fetch(`${BRIDGE_URL}/api/open-app`, { method: 'POST' })
            .then(res => {
                if (!res.ok) openNekoTransURL(url);
            })
            .catch(() => {
                openNekoTransURL(url);
            });
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

// Save word directly into NekoTrans App Vocabulary Notebook
async function saveWordToApp(word, translation, phonetic) {
    if (!word) return { success: false, error: 'Empty word' };

    // 1. Try Local Bridge first
    try {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 1200);
        const response = await fetch(`${BRIDGE_URL}/api/save-word`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ word, translation, phonetic }),
            signal: controller.signal
        });
        clearTimeout(timeoutId);
        if (response.ok) {
            const data = await response.json();
            return data;
        }
    } catch (e) {
        // Bridge unreachable
    }

    // 2. Try Safari Native Message
    if (typeof browser !== 'undefined' && browser.runtime && browser.runtime.sendNativeMessage) {
        try {
            const res = await new Promise((resolve) => {
                browser.runtime.sendNativeMessage('com.nekotrans.mac.SafariExtension', {
                    action: 'saveWord',
                    word,
                    translation,
                    phonetic
                }, resolve);
            });
            if (res && res.saved) {
                return { success: true, isSaved: true, word };
            }
        } catch (e) {}
    }

    // 3. Fallback: URL Scheme
    const url = `nekotrans://save-word?text=${encodeURIComponent(word)}&meaning=${encodeURIComponent(translation || '')}&phonetic=${encodeURIComponent(phonetic || '')}`;
    openNekoTransURL(url);
    return { success: true, isSaved: true, word };
}

// Check if word is saved in NekoTrans App
async function checkWordInApp(word) {
    if (!word) return { isSaved: false };
    try {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 800);
        const response = await fetch(`${BRIDGE_URL}/api/check-word?word=${encodeURIComponent(word)}`, {
            signal: controller.signal
        });
        clearTimeout(timeoutId);
        if (response.ok) {
            return await response.json();
        }
    } catch (e) {}
    return { isSaved: false };
}

// Bridge Translation Request
async function fetchTranslationViaBridge(text, targetLang, sourceLang) {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 4000);

    const response = await fetch(`${BRIDGE_URL}/api/translate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            text: text,
            targetLang: targetLang,
            sourceLang: sourceLang
        }),
        signal: controller.signal
    });
    clearTimeout(timeoutId);

    if (!response.ok) {
        throw new Error(`Bridge HTTP ${response.status}`);
    }

    const data = await response.json();
    if (data && data.success) {
        isBridgeConnected = true;
        return {
            success: true,
            translated: data.translated,
            original: data.original || text,
            phonetic: data.phonetic || '',
            dictEntries: data.dictEntries || [],
            sourceLang: sourceLang,
            targetLang: targetLang,
            isSaved: data.isSaved || false,
            engine: data.engine || 'native'
        };
    }
    throw new Error(data.error || 'Bridge translation failed');
}

// Core Translation Engine with Multi-Tier Fallback (Bridge -> dict-chrome-ex -> MyMemory -> gtx)
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

    // 2. Priority: Try NekoTrans Local Bridge (Unified App Core)
    try {
        const bridgeRes = await fetchTranslationViaBridge(cleanText, targetLang, sourceLang);
        if (bridgeRes && bridgeRes.success) {
            setCachedTranslation(cleanText, targetLang, sourceLang, bridgeRes);
            return bridgeRes;
        }
    } catch (e) {
        // Fallback to standalone web engines below
    }

    // 3. Try Google Translate with Chrome Extension client (dict-chrome-ex)
    try {
        const res = await fetchGoogleTranslate(cleanText, targetLang, sourceLang, 'dict-chrome-ex');
        setCachedTranslation(cleanText, targetLang, sourceLang, res);
        return res;
    } catch (err) {
        // Fallback to MyMemory
    }

    // 4. Fallback: MyMemory API
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

// Bridge Batch Translation Request
async function translateBatchViaBridge(texts, targetLang, sourceLang, tabId) {
    const controller = new AbortController();
    registerTabAbortController(tabId, controller);
    const timeoutId = setTimeout(() => controller.abort(), 12000);

    try {
        const response = await fetch(`${BRIDGE_URL}/api/translate-batch`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                texts: texts,
                targetLang: targetLang,
                sourceLang: sourceLang
            }),
            signal: controller.signal
        });
        clearTimeout(timeoutId);

        if (!response.ok) {
            throw new Error(`Bridge HTTP ${response.status}`);
        }

        const data = await response.json();
        if (data && data.success && Array.isArray(data.results)) {
            isBridgeConnected = true;
            return data.results;
        }
        throw new Error(data.error || 'Bridge batch translation failed');
    } catch (err) {
        clearTimeout(timeoutId);
        throw err;
    }
}

// Smart High-Speed Packed Batch Translation
async function translateBatch(texts, targetLang = 'vi', sourceLang = 'auto', tabId = null) {
    if (!texts || texts.length === 0) return [];

    // Priority: Try NekoTrans Local Bridge (Unified App Core)
    try {
        const bridgeResults = await translateBatchViaBridge(texts, targetLang, sourceLang, tabId);
        if (bridgeResults && bridgeResults.length === texts.length) {
            return bridgeResults;
        }
    } catch (e) {
        if (e.name === 'AbortError') {
            return texts; // Tab closed or translation cancelled
        }
        // Fallback to standalone web packed translation below
    }

    const results = new Array(texts.length).fill(null);
    const DELIMITER = '\n\n|||\n\n';
    const MAX_PACK_CHARS = 1800;

    // 1. Check in-memory cache first
    const uncachedIndices = [];
    texts.forEach((text, idx) => {
        const clean = text.trim();
        if (!clean) {
            results[idx] = '';
            return;
        }
        const cached = getCachedTranslation(clean, targetLang, sourceLang);
        if (cached && cached.translated) {
            results[idx] = cached.translated;
        } else {
            uncachedIndices.push(idx);
        }
    });

    if (uncachedIndices.length === 0) {
        return results;
    }

    // 2. Pack multiple paragraphs together to minimize HTTP round-trips
    const packs = [];
    let currentPack = { indices: [], texts: [], charLen: 0 };

    for (const idx of uncachedIndices) {
        const text = texts[idx].trim();
        if (currentPack.texts.length > 0 && (currentPack.charLen + text.length > MAX_PACK_CHARS || currentPack.texts.length >= 8)) {
            packs.push(currentPack);
            currentPack = { indices: [], texts: [], charLen: 0 };
        }
        currentPack.indices.push(idx);
        currentPack.texts.push(text);
        currentPack.charLen += text.length;
    }
    if (currentPack.texts.length > 0) {
        packs.push(currentPack);
    }

    // 3. Process packs concurrently
    const concurrency = 3;
    for (let i = 0; i < packs.length; i += concurrency) {
        const chunkPacks = packs.slice(i, i + concurrency);
        const promises = chunkPacks.map(async (pack) => {
            if (pack.texts.length === 1) {
                try {
                    const res = await fetchTranslation(pack.texts[0], targetLang, sourceLang);
                    results[pack.indices[0]] = res.success ? res.translated : pack.texts[0];
                } catch {
                    results[pack.indices[0]] = pack.texts[0];
                }
                return;
            }

            // Pack multiple texts with delimiter
            const packedText = pack.texts.join(DELIMITER);
            try {
                const res = await fetchTranslation(packedText, targetLang, sourceLang);
                if (res && res.success && res.translated) {
                    const parts = res.translated.split(/\|\|\|/).map(s => s.trim());
                    if (parts.length === pack.texts.length) {
                        pack.indices.forEach((origIdx, pIdx) => {
                            const translatedPart = parts[pIdx] || pack.texts[pIdx];
                            results[origIdx] = translatedPart;
                            setCachedTranslation(pack.texts[pIdx], targetLang, sourceLang, {
                                success: true,
                                original: pack.texts[pIdx],
                                translated: translatedPart,
                                phonetic: '',
                                dictEntries: [],
                                detectedSource: res.detectedSource,
                                targetLang: targetLang
                            });
                        });
                        return;
                    }
                }
            } catch {
                // Fallback to translating individual items
            }

            // Fallback for this pack
            for (let j = 0; j < pack.texts.length; j++) {
                try {
                    const r = await fetchTranslation(pack.texts[j], targetLang, sourceLang);
                    results[pack.indices[j]] = r.success ? r.translated : pack.texts[j];
                } catch {
                    results[pack.indices[j]] = pack.texts[j];
                }
            }
        });

        await Promise.all(promises);

        // Very small pause between batches
        if (i + concurrency < packs.length) {
            await new Promise(r => setTimeout(r, 60));
        }
    }

    // Fill any missing results with original text
    for (let i = 0; i < results.length; i++) {
        if (results[i] === null) results[i] = texts[i];
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
