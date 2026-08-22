#!/usr/bin/env bash
set -e

# 1. Build .app bundle first
./Scripts/build_app.sh

echo "📦 Bắt đầu tạo bộ cài đặt DMG cho ToolTrL..."

DMG_NAME="ToolTrL-1.0.0.dmg"
BUILD_DIR="build"
APP_PATH="$BUILD_DIR/ToolTrL.app"
DMG_STAGE_DIR="$BUILD_DIR/dmg_stage"
OUTPUT_DMG="$BUILD_DIR/$DMG_NAME"

rm -rf "$DMG_STAGE_DIR" "$OUTPUT_DMG"
mkdir -p "$DMG_STAGE_DIR"

# Copy App to staging
cp -R "$APP_PATH" "$DMG_STAGE_DIR/"

# Create /Applications symlink for drag and drop installation
ln -s /Applications "$DMG_STAGE_DIR/Applications"

# Create disk image
echo "💿 Đang nén thành file DMG ($DMG_NAME)..."
hdiutil create -volname "ToolTrL Installer" -srcfolder "$DMG_STAGE_DIR" -ov -format UDZO "$OUTPUT_DMG"

# Clean up stage
rm -rf "$DMG_STAGE_DIR"

echo "✅ Tạo file cài đặt DMG thành công tại: $OUTPUT_DMG"
ls -lh "$OUTPUT_DMG"
