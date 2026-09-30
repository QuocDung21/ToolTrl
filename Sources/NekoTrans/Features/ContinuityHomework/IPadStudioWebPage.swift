import Foundation

/// Generates the embedded HTML5 Web Application for iPad Safari & Apple Pencil Studio (Memory & Performance Optimized)
public enum IPadStudioWebPage {
    public static func html() -> String {
        return """
        <!DOCTYPE html>
        <html lang="vi">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <title>ToolTrL • iPad Apple Pencil Studio</title>
            <style>
                :root {
                    --bg-color: #0f172a;
                    --card-bg: #1e293b;
                    --card-border: rgba(255, 255, 255, 0.1);
                    --accent-color: #3b82f6;
                    --accent-hover: #2563eb;
                    --text-main: #f8fafc;
                    --text-secondary: #94a3b8;
                    --panel-bg: rgba(30, 41, 59, 0.9);
                }
                * {
                    box-sizing: border-box;
                    margin: 0;
                    padding: 0;
                    -webkit-touch-callout: none;
                    -webkit-user-select: none;
                    user-select: none;
                }
                body {
                    background-color: var(--bg-color);
                    color: var(--text-main);
                    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    height: 100vh;
                    display: flex;
                    flex-direction: column;
                    overflow: hidden;
                }
                /* Top Header */
                header {
                    height: 52px;
                    background: var(--panel-bg);
                    backdrop-filter: blur(20px);
                    -webkit-backdrop-filter: blur(20px);
                    border-bottom: 1px solid var(--card-border);
                    display: flex;
                    align-items: center;
                    justify-content: space-between;
                    padding: 0 16px;
                    z-index: 100;
                }
                .brand {
                    display: flex;
                    align-items: center;
                    gap: 10px;
                }
                .brand-icon {
                    width: 30px;
                    height: 30px;
                    background: linear-gradient(135deg, #3b82f6, #8b5cf6);
                    border-radius: 8px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    font-size: 15px;
                }
                .brand-text h1 {
                    font-size: 14px;
                    font-weight: 700;
                    letter-spacing: -0.2px;
                }
                .brand-text p {
                    font-size: 11px;
                    color: var(--text-secondary);
                }
                .header-actions {
                    display: flex;
                    align-items: center;
                    gap: 8px;
                }
                .status-badge {
                    display: flex;
                    align-items: center;
                    gap: 6px;
                    background: rgba(16, 185, 129, 0.15);
                    color: #10b981;
                    padding: 3px 8px;
                    border-radius: 10px;
                    font-size: 11px;
                    font-weight: 600;
                }
                .status-dot {
                    width: 6px;
                    height: 6px;
                    background: #10b981;
                    border-radius: 50%;
                }

                /* Workspace */
                #workspace {
                    flex: 1;
                    position: relative;
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    justify-content: center;
                    overflow: auto;
                    padding: 16px;
                    background: radial-gradient(circle at center, #1e293b 0%, #0f172a 100%);
                }
                .canvas-container {
                    position: relative;
                    background: #ffffff;
                    border-radius: 10px;
                    box-shadow: 0 16px 36px rgba(0,0,0,0.45);
                    overflow: hidden;
                    touch-action: none;
                }
                #bgCanvas, #drawCanvas {
                    position: absolute;
                    top: 0;
                    left: 0;
                    width: 100%;
                    height: 100%;
                    display: block;
                }
                #drawCanvas {
                    cursor: crosshair;
                    z-index: 10;
                }

                /* Page Navigation Bar */
                #pageBar {
                    position: fixed;
                    top: 62px;
                    left: 50%;
                    transform: translateX(-50%);
                    background: rgba(30, 41, 59, 0.92);
                    backdrop-filter: blur(20px);
                    border: 1px solid rgba(255,255,255,0.12);
                    border-radius: 20px;
                    padding: 4px 10px;
                    display: flex;
                    align-items: center;
                    gap: 8px;
                    z-index: 90;
                    box-shadow: 0 4px 15px rgba(0,0,0,0.3);
                }
                .page-btn {
                    background: rgba(255,255,255,0.08);
                    border: none;
                    color: white;
                    padding: 4px 8px;
                    border-radius: 10px;
                    font-size: 11.5px;
                    font-weight: 600;
                    cursor: pointer;
                }
                .page-btn:disabled {
                    opacity: 0.3;
                    cursor: not-allowed;
                }
                .page-info {
                    font-size: 12px;
                    font-weight: 600;
                    color: var(--text-main);
                    min-width: 80px;
                    text-align: center;
                }

                /* Floating Toolbar */
                #toolbar {
                    position: fixed;
                    bottom: 20px;
                    left: 50%;
                    transform: translateX(-50%);
                    background: rgba(30, 41, 59, 0.94);
                    backdrop-filter: blur(25px);
                    -webkit-backdrop-filter: blur(25px);
                    border: 1px solid rgba(255, 255, 255, 0.15);
                    border-radius: 26px;
                    padding: 6px 12px;
                    display: flex;
                    align-items: center;
                    gap: 10px;
                    box-shadow: 0 10px 30px rgba(0,0,0,0.4);
                    z-index: 200;
                }
                .tool-btn {
                    background: none;
                    border: none;
                    color: var(--text-secondary);
                    padding: 6px 10px;
                    border-radius: 16px;
                    font-size: 13px;
                    font-weight: 600;
                    display: flex;
                    align-items: center;
                    gap: 4px;
                    cursor: pointer;
                    transition: all 0.15s ease;
                }
                .tool-btn.active {
                    background: var(--accent-color);
                    color: white;
                }
                .color-picker {
                    display: flex;
                    align-items: center;
                    gap: 5px;
                    padding: 0 6px;
                    border-left: 1px solid rgba(255,255,255,0.1);
                    border-right: 1px solid rgba(255,255,255,0.1);
                }
                .color-dot {
                    width: 20px;
                    height: 20px;
                    border-radius: 50%;
                    cursor: pointer;
                    border: 2px solid transparent;
                    transition: transform 0.15s;
                }
                .color-dot.active {
                    transform: scale(1.2);
                    border-color: white;
                }
                .size-slider {
                    width: 60px;
                    accent-color: var(--accent-color);
                }
                .submit-btn {
                    background: linear-gradient(135deg, #10b981, #059669);
                    color: white;
                    font-weight: 700;
                    padding: 7px 16px;
                    border-radius: 18px;
                    border: none;
                    cursor: pointer;
                    display: flex;
                    align-items: center;
                    gap: 5px;
                    font-size: 13px;
                    box-shadow: 0 4px 12px rgba(16, 185, 129, 0.35);
                }
                .submit-btn:active {
                    transform: scale(0.96);
                }

                /* Toast */
                #toast {
                    position: fixed;
                    top: 20px;
                    left: 50%;
                    transform: translateX(-50%) translateY(-100px);
                    background: #10b981;
                    color: white;
                    padding: 8px 20px;
                    border-radius: 20px;
                    font-weight: 700;
                    font-size: 13px;
                    box-shadow: 0 10px 25px rgba(16,185,129,0.4);
                    transition: transform 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275);
                    z-index: 999;
                }
                #toast.show {
                    transform: translateX(-50%) translateY(0);
                }
            </style>
        </head>
        <body>
            <!-- Header -->
            <header>
                <div class="brand">
                    <div class="brand-icon">✏️</div>
                    <div class="brand-text">
                        <h1 id="headerTitle">ToolTrL iPad Studio</h1>
                        <p id="headerSubtitle">Apple Pencil • Trình làm bài siêu nhẹ</p>
                    </div>
                </div>
                <div class="header-actions">
                    <div class="status-badge">
                        <div class="status-dot"></div>
                        <span id="connStatus">Đã kết nối</span>
                    </div>
                    <button class="tool-btn" onclick="fetchTask()" style="background:rgba(255,255,255,0.08);">🔄 Tải đề</button>
                    <input type="file" id="imageUploader" accept="image/*" style="display:none" onchange="handleImageUpload(event)">
                    <button class="tool-btn" onclick="document.getElementById('imageUploader').click()" style="background:rgba(255,255,255,0.08);">📷 Thêm ảnh</button>
                    <button class="tool-btn" onclick="clearMemoryAndReset()" style="background:rgba(239,68,68,0.15); color:#f87171;">🗑️ Xoá nét</button>
                </div>
            </header>

            <!-- Page Navigation Bar -->
            <div id="pageBar">
                <button class="page-btn" id="prevPageBtn" onclick="prevPage()">◀</button>
                <span class="page-info" id="pageIndicator">Trang 1 / 1</span>
                <button class="page-btn" id="nextPageBtn" onclick="nextPage()">▶</button>
                <button class="page-btn" onclick="addNewBlankPage()" style="background:rgba(59,130,246,0.25); color:#60a5fa;">➕ Thêm trang</button>
            </div>

            <!-- Toast -->
            <div id="toast">✅ Đã nộp bài giải sang Mac!</div>

            <!-- Workspace -->
            <div id="workspace">
                <div class="canvas-container" id="canvasContainer" style="width: 800px; height: 1100px;">
                    <canvas id="bgCanvas" width="1600" height="2200"></canvas>
                    <canvas id="drawCanvas" width="1600" height="2200"></canvas>
                </div>
            </div>

            <!-- Toolbar -->
            <div id="toolbar">
                <button class="tool-btn active" id="penBtn" onclick="setTool('pen')">✏️ Bút</button>
                <button class="tool-btn" id="highlighterBtn" onclick="setTool('highlighter')">🖍️ Dạ</button>
                <button class="tool-btn" id="eraserBtn" onclick="setTool('eraser')">🧹 Tẩy</button>

                <div class="color-picker">
                    <div class="color-dot active" style="background: #1e3a8a;" onclick="setColor('#1e3a8a', this)"></div>
                    <div class="color-dot" style="background: #dc2626;" onclick="setColor('#dc2626', this)"></div>
                    <div class="color-dot" style="background: #16a34a;" onclick="setColor('#16a34a', this)"></div>
                    <div class="color-dot" style="background: #0f172a;" onclick="setColor('#0f172a', this)"></div>
                    <div class="color-dot" style="background: #9333ea;" onclick="setColor('#9333ea', this)"></div>
                </div>

                <input type="range" class="size-slider" id="strokeSize" min="2" max="24" value="4" onchange="updateSize(this.value)">

                <button class="tool-btn" onclick="undo()">↩️</button>

                <button class="submit-btn" onclick="submitHomework()">
                    <span>🚀 Nộp Bài</span>
                </button>
            </div>

            <script>
                // State with On-Demand Lazy Loading (Zero memory freeze)
                let pages = []; // Array of { bgUrl: String|null, bgImage: Image|null, drawDataURL: String|null, history: [] }
                let currentPageIndex = 0;
                let currentTool = 'pen';
                let currentColor = '#1e3a8a';
                let currentSize = 4;
                let isDrawing = false;
                let lastPoint = null;
                let currentTaskId = '';

                const bgCanvas = document.getElementById('bgCanvas');
                const drawCanvas = document.getElementById('drawCanvas');
                const bgCtx = bgCanvas.getContext('2d');
                const drawCtx = drawCanvas.getContext('2d');

                // Initialize first page
                pages.push({ bgUrl: null, bgImage: null, drawDataURL: null, history: [] });

                function setTool(tool) {
                    currentTool = tool;
                    document.querySelectorAll('.tool-btn').forEach(b => b.classList.remove('active'));
                    if (tool === 'pen') document.getElementById('penBtn').classList.add('active');
                    if (tool === 'highlighter') document.getElementById('highlighterBtn').classList.add('active');
                    if (tool === 'eraser') document.getElementById('eraserBtn').classList.add('active');
                }

                function setColor(color, el) {
                    currentColor = color;
                    document.querySelectorAll('.color-dot').forEach(d => d.classList.remove('active'));
                    el.classList.add('active');
                    if (currentTool === 'eraser') setTool('pen');
                }

                function updateSize(val) {
                    currentSize = parseInt(val);
                }

                function getCanvasPoint(e) {
                    const rect = drawCanvas.getBoundingClientRect();
                    const scaleX = drawCanvas.width / rect.width;
                    const scaleY = drawCanvas.height / rect.height;
                    
                    let clientX = e.clientX;
                    let clientY = e.clientY;
                    if (e.touches && e.touches.length > 0) {
                        clientX = e.touches[0].clientX;
                        clientY = e.touches[0].clientY;
                    }
                    return {
                        x: (clientX - rect.left) * scaleX,
                        y: (clientY - rect.top) * scaleY,
                        pressure: e.pressure && e.pressure > 0 ? e.pressure : 0.5
                    };
                }

                function startDraw(e) {
                    e.preventDefault();
                    isDrawing = true;
                    lastPoint = getCanvasPoint(e);
                    saveHistoryState();
                    draw(e);
                }

                function draw(e) {
                    if (!isDrawing) return;
                    e.preventDefault();
                    const currentPoint = getCanvasPoint(e);

                    drawCtx.save();
                    drawCtx.lineCap = 'round';
                    drawCtx.lineJoin = 'round';

                    if (currentTool === 'eraser') {
                        drawCtx.globalCompositeOperation = 'destination-out';
                        drawCtx.lineWidth = currentSize * 6;
                    } else if (currentTool === 'highlighter') {
                        drawCtx.globalCompositeOperation = 'source-over';
                        drawCtx.strokeStyle = currentColor + '55';
                        drawCtx.lineWidth = currentSize * 4;
                    } else {
                        drawCtx.globalCompositeOperation = 'source-over';
                        drawCtx.strokeStyle = currentColor;
                        const pressureMult = e.pointerType === 'pen' ? (currentPoint.pressure * 1.5 + 0.3) : 1.0;
                        drawCtx.lineWidth = currentSize * pressureMult;
                    }

                    drawCtx.beginPath();
                    drawCtx.moveTo(lastPoint.x, lastPoint.y);
                    drawCtx.lineTo(currentPoint.x, currentPoint.y);
                    drawCtx.stroke();
                    drawCtx.restore();

                    lastPoint = currentPoint;
                }

                function stopDraw(e) {
                    if (!isDrawing) return;
                    isDrawing = false;
                    lastPoint = null;
                }

                drawCanvas.addEventListener('pointerdown', startDraw);
                drawCanvas.addEventListener('pointermove', draw);
                drawCanvas.addEventListener('pointerup', stopDraw);
                drawCanvas.addEventListener('pointercancel', stopDraw);

                function saveHistoryState() {
                    const page = pages[currentPageIndex];
                    if (page.history.length > 10) page.history.shift(); // keep max 10 states for low memory
                    page.history.push(drawCanvas.toDataURL('image/png'));
                }

                function undo() {
                    const hist = pages[currentPageIndex].history;
                    if (hist.length > 0) {
                        const prevImg = new Image();
                        prevImg.onload = () => {
                            drawCtx.clearRect(0, 0, drawCanvas.width, drawCanvas.height);
                            drawCtx.drawImage(prevImg, 0, 0);
                        };
                        prevImg.src = hist.pop();
                    } else {
                        drawCtx.clearRect(0, 0, drawCanvas.width, drawCanvas.height);
                    }
                }

                function saveCurrentPage() {
                    if (pages[currentPageIndex]) {
                        pages[currentPageIndex].drawDataURL = drawCanvas.toDataURL('image/png');
                    }
                }

                async function loadPage(index) {
                    if (index < 0 || index >= pages.length) return;
                    saveCurrentPage();
                    currentPageIndex = index;
                    await renderCurrentPage();
                    updatePageUI();
                }

                async function renderCurrentPage() {
                    const page = pages[currentPageIndex];
                    
                    // Lazy-load page image on demand if not yet loaded
                    if (!page.bgImage && page.bgUrl) {
                        const img = new Image();
                        await new Promise((resolve) => {
                            img.onload = resolve;
                            img.onerror = resolve;
                            img.src = page.bgUrl;
                        });
                        page.bgImage = img;
                    }

                    // Render Background
                    bgCtx.fillStyle = '#ffffff';
                    bgCtx.fillRect(0, 0, bgCanvas.width, bgCanvas.height);

                    if (!page.bgImage) {
                        bgCtx.strokeStyle = '#f1f5f9';
                        bgCtx.lineWidth = 1.5;
                        for (let y = 50; y < bgCanvas.height; y += 40) {
                            bgCtx.beginPath();
                            bgCtx.moveTo(0, y);
                            bgCtx.lineTo(bgCanvas.width, y);
                            bgCtx.stroke();
                        }
                    } else {
                        const img = page.bgImage;
                        const aspect = img.width / img.height;
                        let drawW = bgCanvas.width;
                        let drawH = bgCanvas.width / aspect;
                        if (drawH > bgCanvas.height) {
                            drawH = bgCanvas.height;
                            drawW = bgCanvas.height * aspect;
                        }
                        const offX = (bgCanvas.width - drawW) / 2;
                        const offY = (bgCanvas.height - drawH) / 2;
                        bgCtx.drawImage(img, offX, offY, drawW, drawH);
                    }

                    // Restore drawing
                    drawCtx.clearRect(0, 0, drawCanvas.width, drawCanvas.height);
                    if (page.drawDataURL) {
                        const strokeImg = new Image();
                        strokeImg.onload = () => {
                            drawCtx.drawImage(strokeImg, 0, 0);
                        };
                        strokeImg.src = page.drawDataURL;
                    }
                }

                function updatePageUI() {
                    document.getElementById('pageIndicator').innerText = `Trang ${currentPageIndex + 1} / ${pages.length}`;
                    document.getElementById('prevPageBtn').disabled = currentPageIndex === 0;
                    document.getElementById('nextPageBtn').disabled = currentPageIndex === pages.length - 1;
                }

                function prevPage() {
                    if (currentPageIndex > 0) loadPage(currentPageIndex - 1);
                }

                function nextPage() {
                    if (currentPageIndex < pages.length - 1) loadPage(currentPageIndex + 1);
                }

                function addNewBlankPage() {
                    saveCurrentPage();
                    pages.push({ bgUrl: null, bgImage: null, drawDataURL: null, history: [] });
                    loadPage(pages.length - 1);
                }

                function clearMemoryAndReset() {
                    if (confirm('Bạn có chắc muốn xoá toàn bộ nét vẽ trang hiện tại?')) {
                        drawCtx.clearRect(0, 0, drawCanvas.width, drawCanvas.height);
                        pages[currentPageIndex].drawDataURL = null;
                        pages[currentPageIndex].history = [];
                    }
                }

                function handleImageUpload(e) {
                    const file = e.target.files[0];
                    if (!file) return;
                    const reader = new FileReader();
                    reader.onload = (event) => {
                        const img = new Image();
                        img.onload = () => {
                            saveCurrentPage();
                            pages.push({ bgUrl: null, bgImage: img, drawDataURL: null, history: [] });
                            loadPage(pages.length - 1);
                        };
                        img.src = event.target.result;
                    };
                    reader.readAsDataURL(file);
                }

                // Super Lightweight Fetch Task (< 500 bytes JSON)
                async function fetchTask() {
                    try {
                        const res = await fetch('/api/task');
                        const data = await res.json();
                        currentTaskId = data.taskId;

                        document.getElementById('headerTitle').innerText = data.pdfFileName || 'ToolTrL iPad Studio';
                        document.getElementById('headerSubtitle').innerText = data.text || (data.hasPDF ? `Tài liệu PDF (${data.pdfPagesCount || 1} trang)` : 'Bài tập iPad');

                        if (data.hasPDF && data.pdfPagesCount > 0) {
                            pages = [];
                            for (let i = 0; i < data.pdfPagesCount; i++) {
                                pages.push({
                                    bgUrl: `/api/pdf/page/${i}?t=${data.taskId}`,
                                    bgImage: null,
                                    drawDataURL: null,
                                    history: []
                                });
                            }
                            currentPageIndex = 0;
                            await renderCurrentPage();
                            updatePageUI();
                        } else if (data.hasImage && data.imageBase64) {
                            const img = new Image();
                            img.onload = () => {
                                pages = [{ bgUrl: null, bgImage: img, drawDataURL: null, history: [] }];
                                currentPageIndex = 0;
                                renderCurrentPage();
                                updatePageUI();
                            };
                            img.src = data.imageBase64;
                        }
                    } catch (err) {
                        console.error('Fetch task error:', err);
                    }
                }

                // Optimized Submit using JPEG compression
                async function submitHomework() {
                    saveCurrentPage();
                    const submitBtn = document.querySelector('.submit-btn');
                    submitBtn.innerText = '⏳ Đang nộp...';
                    submitBtn.disabled = true;

                    try {
                        const combinedImages = [];

                        for (let i = 0; i < pages.length; i++) {
                            const page = pages[i];
                            const compCanvas = document.createElement('canvas');
                            compCanvas.width = bgCanvas.width;
                            compCanvas.height = bgCanvas.height;
                            const compCtx = compCanvas.getContext('2d');

                            compCtx.fillStyle = '#ffffff';
                            compCtx.fillRect(0, 0, compCanvas.width, compCanvas.height);

                            if (page.bgImage) {
                                const img = page.bgImage;
                                const aspect = img.width / img.height;
                                let drawW = compCanvas.width;
                                let drawH = compCanvas.width / aspect;
                                if (drawH > compCanvas.height) {
                                    drawH = compCanvas.height;
                                    drawW = compCanvas.height * aspect;
                                }
                                const offX = (compCanvas.width - drawW) / 2;
                                const offY = (compCanvas.height - drawH) / 2;
                                compCtx.drawImage(img, offX, offY, drawW, drawH);
                            }

                            if (page.drawDataURL) {
                                const strk = new Image();
                                await new Promise(r => {
                                    strk.onload = r;
                                    strk.src = page.drawDataURL;
                                });
                                compCtx.drawImage(strk, 0, 0);
                            } else if (i === currentPageIndex) {
                                compCtx.drawImage(drawCanvas, 0, 0);
                            }

                            // Use JPEG (0.82) for 10x smaller payload and instant WiFi upload
                            combinedImages.push(compCanvas.toDataURL('image/jpeg', 0.82));
                        }

                        const payload = {
                            images: combinedImages,
                            imageBase64: combinedImages[0],
                            notes: document.getElementById('headerSubtitle').innerText,
                            pageCount: combinedImages.length
                        };

                        const resp = await fetch('/api/submit', {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify(payload)
                        });

                        const result = await resp.json();
                        showToast(`✅ Đã nộp thành công ${combinedImages.length} trang sang Mac!`);
                    } catch (err) {
                        alert('Lỗi nộp bài sang Mac: ' + err.message);
                    } finally {
                        submitBtn.innerHTML = '<span>🚀 Nộp Bài</span>';
                        submitBtn.disabled = false;
                    }
                }

                function showToast(msg) {
                    const t = document.getElementById('toast');
                    t.innerText = msg;
                    t.classList.add('show');
                    setTimeout(() => t.classList.remove('show'), 3000);
                }

                window.addEventListener('load', () => {
                    renderCurrentPage();
                    updatePageUI();
                    fetchTask();
                });
            </script>
        </body>
        </html>
        """
    }
}
