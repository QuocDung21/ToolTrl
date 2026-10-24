#!/bin/bash
set -euo pipefail

# =============================================================================
# NekoTrans - Package Chrome / Chromium Web Extension
# =============================================================================

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

SRC_DIR="$PROJECT_DIR/Sources/NekoTransSafariExtension/Resources"
BUILD_DIR="$PROJECT_DIR/build"
CHROME_DIST_DIR="$BUILD_DIR/NekoTrans-Chrome"
ZIP_OUTPUT="$BUILD_DIR/NekoTrans-Chrome-Extension.zip"

CYAN="\033[36m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

echo -e "${CYAN}🚀 Đang chuẩn bị đóng gói NekoTrans Extension cho Google Chrome / Chromium...${RESET}"

if [ ! -d "$SRC_DIR" ]; then
    echo "❌ Lỗi: Thư mục nguồn $SRC_DIR không tồn tại!" >&2
    exit 1
fi

# Ensure icons are fresh and synchronized
if [ -f "Resources/AppIcon.png" ]; then
    mkdir -p "$SRC_DIR/images"
    sips -z 16 16 "Resources/AppIcon.png" --out "$SRC_DIR/images/icon-16.png" >/dev/null 2>&1 || true
    sips -z 32 32 "Resources/AppIcon.png" --out "$SRC_DIR/images/icon-32.png" >/dev/null 2>&1 || true
    sips -z 48 48 "Resources/AppIcon.png" --out "$SRC_DIR/images/icon-48.png" >/dev/null 2>&1 || true
    sips -z 128 128 "Resources/AppIcon.png" --out "$SRC_DIR/images/icon-128.png" >/dev/null 2>&1 || true
    sips -z 256 256 "Resources/AppIcon.png" --out "$SRC_DIR/images/icon-256.png" >/dev/null 2>&1 || true
    sips -z 512 512 "Resources/AppIcon.png" --out "$SRC_DIR/images/icon-512.png" >/dev/null 2>&1 || true
fi

# Clean and create output directory
mkdir -p "$BUILD_DIR"
rm -rf "$CHROME_DIST_DIR" "$ZIP_OUTPUT"
mkdir -p "$CHROME_DIST_DIR"

# Copy extension files
cp "$SRC_DIR/manifest.json" "$CHROME_DIST_DIR/"
cp "$SRC_DIR/background.js" "$CHROME_DIST_DIR/"
cp "$SRC_DIR/content.js" "$CHROME_DIST_DIR/"
cp "$SRC_DIR/content.css" "$CHROME_DIST_DIR/"
cp "$SRC_DIR/popup.html" "$CHROME_DIST_DIR/"
cp "$SRC_DIR/popup.css" "$CHROME_DIST_DIR/"
cp "$SRC_DIR/popup.js" "$CHROME_DIST_DIR/"
cp -R "$SRC_DIR/images" "$CHROME_DIST_DIR/"

# Remove macOS metadata and .DS_Store files
find "$CHROME_DIST_DIR" -name ".DS_Store" -delete 2>/dev/null || true
find "$CHROME_DIST_DIR" -name "._*" -delete 2>/dev/null || true

# Create clean ZIP package without __MACOSX resource forks (-X flag)
echo -e "${CYAN}📦 Đang nén file zip phân phối...${RESET}"
(cd "$CHROME_DIST_DIR" && zip -r -X -q "$ZIP_OUTPUT" .)

ZIP_SIZE=$(du -h "$ZIP_OUTPUT" | cut -f1)

echo -e "${GREEN}✅ Đóng gói hoàn tất thành công!${RESET}"
echo -e "   📂 Thư mục Unpacked: ${YELLOW}$CHROME_DIST_DIR${RESET}"
echo -e "   📦 File ZIP:         ${YELLOW}$ZIP_OUTPUT${RESET} (${ZIP_SIZE})"
echo ""
echo -e "${CYAN}💡 Cách cài đặt và sử dụng trên Google Chrome / Edge / Brave:${RESET}"
echo -e "   1. Mở Chrome và truy cập: ${YELLOW}chrome://extensions${RESET}"
echo -e "   2. Bật công tắc '${YELLOW}Developer mode${RESET}' ở góc trên bên phải."
echo -e "   3. Bấm '${YELLOW}Load unpacked${RESET}' và chọn thư mục:"
echo -e "      👉 ${GREEN}$CHROME_DIST_DIR${RESET}"
echo -e "   4. (Hoặc dùng file ${GREEN}$ZIP_OUTPUT${RESET} để tải lên Chrome Web Store Developer Dashboard)"
