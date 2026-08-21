#!/usr/bin/env bash
set -e

echo "🚀 Bắt đầu build ToolTrL release..."
swift build -c release

APP_NAME="ToolTrL.app"
APP_DIR="build/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "📦 Đang tạo cấu trúc $APP_NAME..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
cp .build/release/ToolTrL "$MACOS_DIR/ToolTrL"
chmod +x "$MACOS_DIR/ToolTrL"

# Copy AppIcon.icns
if [ -f "Resources/AppIcon.icns" ]; then
    cp Resources/AppIcon.icns "$RESOURCES_DIR/AppIcon.icns"
fi

# Copy llama-runner
if [ -d "Resources/llama-runner" ]; then
    cp -R Resources/llama-runner "$RESOURCES_DIR/"
fi

# Create Info.plist
cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>ToolTrL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.tooltrl.mac</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>ToolTrL</string>
    <key>CFBundleDisplayName</key>
    <string>ToolTrL AI Translator</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 ToolTrL. All rights reserved.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

# Find signing identity in Keychain
IDENTITY=$(security find-identity -p codesigning -v | grep "Apple Development" | head -n 1 | awk -F '"' '{print $2}' || true)

ENTITLEMENTS_FLAG=""
if [ -f "Resources/ToolTrL.entitlements" ]; then
    ENTITLEMENTS_FLAG="--entitlements Resources/ToolTrL.entitlements"
fi

if [ -n "$IDENTITY" ]; then
    echo "🔏 Ký ứng dụng với chứng chỉ Developer: $IDENTITY..."
    codesign --force --deep $ENTITLEMENTS_FLAG --sign "$IDENTITY" "$APP_DIR"
else
    echo "🔏 Ký ứng dụng với Ad-hoc signature (-)..."
    codesign --force --deep $ENTITLEMENTS_FLAG --sign - "$APP_DIR"
fi

echo "✅ Đóng gói và ký mã nguồn hoàn tất: $APP_DIR"
