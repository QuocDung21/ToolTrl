// NekoTrans Safari Web Extension - Content Script

(function () {
    if (window.__nekotrans_loaded__) return;
    window.__nekotrans_loaded__ = true;

    let settings = {
        targetLang: 'vi',
        sourceLang: 'auto',
        displayMode: 'bilingual',
        showSelectionBubble: true,
        autoSpeak: false
    };

    // Load initial settings
    if (chrome && chrome.storage && chrome.storage.sync) {
        chrome.storage.sync.get(settings, (items) => {
            if (items) settings = { ...settings, ...items };
        });
    }

    let selectionBubble = null;
    let translationCard = null;
    let pageHUD = null;
    let isTranslatingPage = false;
    let pageTranslatedCount = 0;
    let totalPageBlocks = 0;

    // MARK: - Selection Translation Event Listeners

    document.addEventListener('mouseup', handleMouseUp);
    document.addEventListener('mousedown', handleMouseDown);
    document.addEventListener('keydown', handleKeyDown);

    function handleMouseDown(e) {
        // If clicking outside translation card or bubble, dismiss them
        if (translationCard && !translationCard.contains(e.target)) {
            removeTranslationCard();
        }
        if (selectionBubble && !selectionBubble.contains(e.target)) {
            removeSelectionBubble();
        }
    }

    function handleKeyDown(e) {
        if (e.key === 'Escape') {
            removeTranslationCard();
            removeSelectionBubble();
        }
    }

    function handleMouseUp(e) {
        // Ignore clicks inside our own UI
        if (translationCard && translationCard.contains(e.target)) return;
        if (selectionBubble && selectionBubble.contains(e.target)) return;

        setTimeout(() => {
            const selection = window.getSelection();
            if (!selection || selection.isCollapsed) {
                removeSelectionBubble();
                return;
            }

            const selectedText = selection.toString().trim();
            if (!selectedText || selectedText.length < 1 || selectedText.length > 3000) {
                removeSelectionBubble();
                return;
            }

            if (!settings.showSelectionBubble) return;

            // Calculate position near end of selection
            try {
                const range = selection.getRangeAt(0);
                const rect = range.getBoundingClientRect();
                if (rect.width === 0 && rect.height === 0) return;

                showSelectionBubble(rect, selectedText);
            } catch (err) {
                // Ignore range selection errors
            }
        }, 10);
    }

    // MARK: - Selection Bubble UI

    function showSelectionBubble(rect, text) {
        removeSelectionBubble();

        const bubble = document.createElement('div');
        bubble.id = 'nekotrans-selection-bubble';
        const iconUrl = (typeof chrome !== 'undefined' && chrome.runtime && chrome.runtime.getURL)
            ? chrome.runtime.getURL('images/icon-32.png')
            : '';
        if (iconUrl) {
            bubble.innerHTML = `<img src="${iconUrl}" alt="NekoTrans" class="nekotrans-bubble-icon">`;
        } else {
            bubble.innerHTML = '🐱';
        }
        bubble.title = 'Dịch với NekoTrans';

        const scrollX = window.scrollX || window.pageXOffset;
        const scrollY = window.scrollY || window.pageYOffset;

        const left = scrollX + rect.right + 4;
        const top = scrollY + rect.bottom - 16;

        bubble.style.left = `${left}px`;
        bubble.style.top = `${top}px`;

        bubble.addEventListener('click', (e) => {
            e.stopPropagation();
            removeSelectionBubble();
            showTranslationCard(rect, text);
        });

        document.body.appendChild(bubble);
        selectionBubble = bubble;
    }

    function removeSelectionBubble() {
        if (selectionBubble) {
            selectionBubble.remove();
            selectionBubble = null;
        }
    }

    // MARK: - Floating Translation Card

    async function showTranslationCard(rect, text) {
        removeTranslationCard();

        const card = document.createElement('div');
        card.id = 'nekotrans-translation-card';

        const scrollX = window.scrollX || window.pageXOffset;
        const scrollY = window.scrollY || window.pageYOffset;

        // Position smartly relative to viewport
        let left = scrollX + rect.left;
        let top = scrollY + rect.bottom + 8;

        if (left + 360 > window.innerWidth + scrollX - 16) {
            left = window.innerWidth + scrollX - 376;
        }
        if (left < scrollX + 16) left = scrollX + 16;

        card.style.left = `${left}px`;
        card.style.top = `${top}px`;

        const iconUrl16 = (typeof chrome !== 'undefined' && chrome.runtime && chrome.runtime.getURL)
            ? chrome.runtime.getURL('images/icon-16.png')
            : '';
        const brandIconHtml = iconUrl16
            ? `<img src="${iconUrl16}" class="nekotrans-brand-icon" alt="">`
            : '🐱';

        // Initial Loading State
        card.innerHTML = `
            <div class="nekotrans-card-header">
                <div class="nekotrans-card-brand">${brandIconHtml} <span>NekoTrans</span></div>
                <div class="nekotrans-card-actions">
                    <button class="nekotrans-btn-icon" id="nekotrans-close-card" title="Đóng">✕</button>
                </div>
            </div>
            <div class="nekotrans-card-body">
                <div class="nekotrans-source-box">
                    <div class="nekotrans-source-text">${escapeHtml(text.slice(0, 160))}${text.length > 160 ? '...' : ''}</div>
                </div>
                <div class="nekotrans-translated-text" style="color: #64748b; font-style: italic;">Đang dịch...</div>
            </div>
        `;

        document.body.appendChild(card);
        translationCard = card;

        card.querySelector('#nekotrans-close-card').addEventListener('click', removeTranslationCard);

        // Fetch Translation
        chrome.runtime.sendMessage({
            action: 'translateText',
            text: text,
            targetLang: settings.targetLang,
            sourceLang: settings.sourceLang
        }, (res) => {
            if (!res || !translationCard) return;

            if (!res.success) {
                const body = translationCard.querySelector('.nekotrans-card-body');
                if (body) {
                    body.innerHTML = `<div style="color: #ef4444;">⚠️ Lỗi dịch: ${escapeHtml(res.error || 'Không thể kết nối')}</div>`;
                }
                return;
            }

            renderCardContent(card, res, text);
        });
    }

    function renderCardContent(card, data, originalText) {
        const body = card.querySelector('.nekotrans-card-body');
        if (!body) return;

        let dictHtml = '';
        if (data.dictEntries && data.dictEntries.length > 0) {
            dictHtml = '<div class="nekotrans-dict-section">';
            for (const dict of data.dictEntries) {
                dictHtml += `
                    <div style="margin-bottom: 4px;">
                        <span class="nekotrans-pos-tag">${escapeHtml(dict.pos)}</span>
                        <span class="nekotrans-terms-list">${escapeHtml(dict.terms.join(', '))}</span>
                    </div>
                `;
            }
            dictHtml += '</div>';
        }

        const phoneticHtml = data.phonetic ? `<div class="nekotrans-phonetic">/${escapeHtml(data.phonetic)}/</div>` : '';

        body.innerHTML = `
            <div class="nekotrans-source-box">
                <div class="nekotrans-source-text">${escapeHtml(data.original.slice(0, 200))}${data.original.length > 200 ? '...' : ''}</div>
                ${phoneticHtml}
            </div>
            <div class="nekotrans-translated-text">${escapeHtml(data.translated)}</div>
            ${dictHtml}
        `;

        // Update Header Actions
        const actions = card.querySelector('.nekotrans-card-actions');
        if (actions) {
            actions.innerHTML = `
                <button class="nekotrans-btn-icon" id="nekotrans-speak-btn" title="Phát âm">🔊</button>
                <button class="nekotrans-btn-icon" id="nekotrans-copy-btn" title="Sao chép">📋</button>
                <button class="nekotrans-btn-icon" id="nekotrans-save-btn" title="Lưu vào Sổ tay">🔖</button>
                <button class="nekotrans-btn-icon" id="nekotrans-app-btn" title="Mở trong NekoTrans">↗️</button>
                <button class="nekotrans-btn-icon" id="nekotrans-close-card" title="Đóng">✕</button>
            `;

            actions.querySelector('#nekotrans-close-card').addEventListener('click', removeTranslationCard);

            actions.querySelector('#nekotrans-speak-btn').addEventListener('click', () => {
                speakText(data.original, data.detectedSource);
            });

            actions.querySelector('#nekotrans-copy-btn').addEventListener('click', (e) => {
                navigator.clipboard.writeText(data.translated);
                e.target.innerHTML = '✓';
                setTimeout(() => { if (e.target) e.target.innerHTML = '📋'; }, 1500);
            });

            actions.querySelector('#nekotrans-save-btn').addEventListener('click', (e) => {
                const saveUrl = `nekotrans://save-word?text=${encodeURIComponent(data.original)}&meaning=${encodeURIComponent(data.translated)}&phonetic=${encodeURIComponent(data.phonetic || '')}`;
                chrome.runtime.sendMessage({ action: 'openApp', url: saveUrl });
                e.target.innerHTML = '✓';
                setTimeout(() => { if (e.target) e.target.innerHTML = '🔖'; }, 1500);
            });

            actions.querySelector('#nekotrans-app-btn').addEventListener('click', () => {
                const appUrl = `nekotrans://translate?text=${encodeURIComponent(data.original)}`;
                chrome.runtime.sendMessage({ action: 'openApp', url: appUrl });
            });
        }

        // Add Card Footer
        let footer = card.querySelector('.nekotrans-card-footer');
        if (!footer) {
            footer = document.createElement('div');
            footer.className = 'nekotrans-card-footer';
            footer.innerHTML = `
                <span>NekoTrans Web</span>
                <a class="nekotrans-link-app" id="nekotrans-open-main">Mở NekoTrans</a>
            `;
            card.appendChild(footer);

            footer.querySelector('#nekotrans-open-main').addEventListener('click', () => {
                chrome.runtime.sendMessage({ action: 'openApp', url: 'nekotrans://' });
            });
        }

        if (settings.autoSpeak) {
            speakText(data.original, data.detectedSource);
        }
    }

    function removeTranslationCard() {
        if (translationCard) {
            translationCard.remove();
            translationCard = null;
        }
    }

    function speakText(text, lang) {
        if (!window.speechSynthesis) return;
        window.speechSynthesis.cancel();

        const utterance = new SpeechSynthesisUtterance(text);
        if (lang && lang !== 'auto') {
            utterance.lang = lang;
        }
        utterance.rate = 0.95;
        window.speechSynthesis.speak(utterance);
    }

    // MARK: - Full Web Page Bilingual Translation

    async function startPageTranslation() {
        if (isTranslatingPage) return;
        isTranslatingPage = true;

        const rawBlocks = getTranslatableBlocks();
        totalPageBlocks = rawBlocks.length;
        pageTranslatedCount = 0;

        if (totalPageBlocks === 0) {
            showPageHUD('Không tìm thấy nội dung để dịch', false);
            isTranslatingPage = false;
            return;
        }

        // Ưu tiên dịch các đoạn đang hiển thị trên màn hình trước để người dùng đọc ngay lập tức!
        const blocks = sortBlocksByViewport(rawBlocks);

        showPageHUD(`Đang dịch ưu tiên màn hình... (0/${totalPageBlocks})`, true);

        // Process in progressive chunks of 10
        const chunkSize = 10;
        for (let i = 0; i < blocks.length; i += chunkSize) {
            if (!isTranslatingPage) break; // User stopped translation

            const chunkBlocks = blocks.slice(i, i + chunkSize);
            const chunkTexts = chunkBlocks.map(b => b.innerText.trim());

            try {
                const res = await new Promise((resolve) => {
                    chrome.runtime.sendMessage({
                        action: 'translateBatch',
                        texts: chunkTexts,
                        targetLang: settings.targetLang,
                        sourceLang: settings.sourceLang
                    }, resolve);
                });

                if (res && res.success && res.results) {
                    chunkBlocks.forEach((elem, idx) => {
                        const translated = res.results[idx];
                        if (translated && translated !== chunkTexts[idx]) {
                            applyBlockTranslation(elem, translated);
                        }
                    });
                }
            } catch (err) {
                // Continue with next chunk
            }

            pageTranslatedCount = Math.min(i + chunkSize, totalPageBlocks);
            updatePageHUD(`Đang dịch: ${pageTranslatedCount}/${totalPageBlocks} đoạn`, true);
        }

        if (isTranslatingPage) {
            isTranslatingPage = false;
            showPageHUD(`✅ Đã dịch song ngữ (${pageTranslatedCount}/${totalPageBlocks} đoạn)`, false);
        }
    }

    // Sort blocks so visible content is translated in the very first batch
    function sortBlocksByViewport(blocks) {
        return blocks.slice().sort((a, b) => {
            const rectA = a.getBoundingClientRect();
            const rectB = b.getBoundingClientRect();

            const inViewportA = rectA.top < window.innerHeight + 300 && rectA.bottom > -100;
            const inViewportB = rectB.top < window.innerHeight + 300 && rectB.bottom > -100;

            if (inViewportA && !inViewportB) return -1;
            if (!inViewportA && inViewportB) return 1;

            return rectA.top - rectB.top;
        });
    }

    function getTranslatableBlocks() {
        const selectors = 'p, h1, h2, h3, h4, h5, h6, blockquote, article, li, dd, dt';
        const elements = Array.from(document.querySelectorAll(selectors));

        return elements.filter((el) => {
            // Skip existing translated elements or NekoTrans UI
            if (el.closest('#nekotrans-translation-card') || el.closest('#nekotrans-page-hud')) return false;
            if (el.classList.contains('nekotrans-bilingual-block')) return false;
            if (el.getAttribute('data-nekotrans-translated')) return false;

            // Skip code, script, style, inputs, headers, footers, navbars
            if (el.closest('pre') || el.closest('code') || el.closest('noscript')) return false;
            if (el.closest('nav') || el.closest('header') || el.closest('footer')) return false;

            const text = el.innerText ? el.innerText.trim() : '';
            // Must have at least 3 characters and contain readable text
            if (text.length < 3) return false;
            if (!/[a-zA-ZÀ-ỹ\u4e00-\u9fa5\u3040-\u309f\u30a0-\u30ff]/.test(text)) return false;

            return true;
        });
    }

    function applyBlockTranslation(element, translatedText) {
        element.setAttribute('data-nekotrans-translated', 'true');

        if (settings.displayMode === 'replace') {
            element.setAttribute('data-nekotrans-original-text', element.innerText);
            element.innerText = translatedText;
        } else {
            // Bilingual mode: append translated block immediately after
            const div = document.createElement('div');
            div.className = 'nekotrans-bilingual-block';
            div.innerText = translatedText;
            div.setAttribute('data-nekotrans-bilingual', 'true');

            // Insert after element
            if (element.nextSibling) {
                element.parentNode.insertBefore(div, element.nextSibling);
            } else {
                element.parentNode.appendChild(div);
            }
        }
    }

    function restorePage() {
        isTranslatingPage = false;

        // Remove bilingual blocks
        const bilingualBlocks = document.querySelectorAll('.nekotrans-bilingual-block');
        bilingualBlocks.forEach(b => b.remove());

        // Restore replaced text
        const replacedElements = document.querySelectorAll('[data-nekotrans-original-text]');
        replacedElements.forEach(el => {
            const original = el.getAttribute('data-nekotrans-original-text');
            if (original) el.innerText = original;
            el.removeAttribute('data-nekotrans-original-text');
            el.removeAttribute('data-nekotrans-translated');
        });

        // Clear translated flags
        const translatedElements = document.querySelectorAll('[data-nekotrans-translated]');
        translatedElements.forEach(el => el.removeAttribute('data-nekotrans-translated'));

        removePageHUD();
    }

    // MARK: - Page HUD UI

    function showPageHUD(statusText, isLoading = false) {
        removePageHUD();

        const iconUrl16 = (typeof chrome !== 'undefined' && chrome.runtime && chrome.runtime.getURL)
            ? chrome.runtime.getURL('images/icon-16.png')
            : '';
        const hudLogoHtml = iconUrl16
            ? `<img src="${iconUrl16}" class="nekotrans-hud-logo" alt="">`
            : '<span>🐱</span>';

        const hud = document.createElement('div');
        hud.id = 'nekotrans-page-hud';
        hud.innerHTML = `
            ${hudLogoHtml}
            <span id="nekotrans-hud-text">${escapeHtml(statusText)}</span>
            <button id="nekotrans-hud-stop" style="display: ${isLoading ? 'inline-block' : 'none'};">Dừng</button>
            <button id="nekotrans-hud-restore">Khôi phục</button>
            <button id="nekotrans-hud-close">✕</button>
        `;

        document.body.appendChild(hud);
        pageHUD = hud;

        const stopBtn = hud.querySelector('#nekotrans-hud-stop');
        if (stopBtn) {
            stopBtn.addEventListener('click', () => {
                isTranslatingPage = false;
                stopBtn.style.display = 'none';
                updatePageHUD(`Đã dừng dịch (${pageTranslatedCount}/${totalPageBlocks} đoạn)`, false);
            });
        }

        hud.querySelector('#nekotrans-hud-restore').addEventListener('click', restorePage);
        hud.querySelector('#nekotrans-hud-close').addEventListener('click', removePageHUD);
    }

    function updatePageHUD(statusText, isLoading = true) {
        if (!pageHUD) return;
        const textSpan = pageHUD.querySelector('#nekotrans-hud-text');
        if (textSpan) textSpan.innerText = statusText;

        const stopBtn = pageHUD.querySelector('#nekotrans-hud-stop');
        if (stopBtn) {
            stopBtn.style.display = isLoading ? 'inline-block' : 'none';
        }
    }

    function removePageHUD() {
        if (pageHUD) {
            pageHUD.remove();
            pageHUD = null;
        }
    }

    // MARK: - Extension Messages Listener

    chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
        if (request.action === 'translateSelection') {
            const selection = window.getSelection();
            let rect = { left: window.innerWidth / 2 - 180, bottom: 120 };
            if (selection && !selection.isCollapsed) {
                try { rect = selection.getRangeAt(0).getBoundingClientRect(); } catch (e) {}
            }
            showTranslationCard(rect, request.text);
            sendResponse({ success: true });
        } else if (request.action === 'startPageTranslation') {
            startPageTranslation();
            sendResponse({ success: true });
        } else if (request.action === 'restorePage') {
            restorePage();
            sendResponse({ success: true });
        } else if (request.action === 'togglePageTranslation') {
            const hasTranslations = document.querySelectorAll('.nekotrans-bilingual-block, [data-nekotrans-translated]').length > 0;
            if (hasTranslations) {
                restorePage();
            } else {
                startPageTranslation();
            }
            sendResponse({ success: true });
        }
    });

    function escapeHtml(string) {
        if (!string) return '';
        return String(string)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }
})();
