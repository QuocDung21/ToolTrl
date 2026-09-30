#!/usr/bin/env bash
set -e

# Fail fast (or auto-select Xcode) when only Command Line Tools are active.
# shellcheck source=Scripts/toolchain.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/toolchain.sh"

BUILD_FLAVOR="${1:---public}"

if [ "$BUILD_FLAVOR" = "--beta" ]; then
    echo "🧪 Bắt đầu build NekoTrans [BETA LABS TESTER]..."
    swift build -c release
elif [ "$BUILD_FLAVOR" = "--strict-stripped" ]; then
    echo "🔒 Bắt đầu build NekoTrans [STRICT STRIPPED RELEASE]..."
    swift build -c release -Xswiftc -DPUBLIC_RELEASE_STRIPPED
else
    echo "🚀 Bắt đầu build NekoTrans [PUBLIC RELEASE] (Tính năng thử nghiệm được bảo vệ an toàn)..."
    swift build -c release
fi

APP_NAME="NekoTrans.app"
APP_DIR="build/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "📦 Đang tạo cấu trúc $APP_NAME..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
cp .build/release/NekoTrans "$MACOS_DIR/NekoTrans"
chmod +x "$MACOS_DIR/NekoTrans"

# Generate & Copy AppIcon.icns
if [ -d "Resources/AppIcon.iconset" ]; then
    iconutil -c icns Resources/AppIcon.iconset -o "$RESOURCES_DIR/AppIcon.icns"
elif [ -f "Resources/AppIcon.icns" ]; then
    cp Resources/AppIcon.icns "$RESOURCES_DIR/AppIcon.icns"
fi

if [ -f "Resources/apexcharts.min.js" ]; then
    cp Resources/apexcharts.min.js "$RESOURCES_DIR/apexcharts.min.js"
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
    <string>NekoTrans</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.nekotrans.mac</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>NekoTrans</string>
    <key>CFBundleDisplayName</key>
    <string>NekoTrans AI Translator</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 NekoTrans. All rights reserved.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

# Find signing identity in Keychain (use SHA-1 hash to avoid UTF-8 character encoding issues)
IDENTITY=$(security find-identity -p codesigning -v | grep "Apple Development" | head -n 1 | awk '{print $2}' || true)

ENTITLEMENTS_FLAG=""
if [ -f "Resources/NekoTrans.entitlements" ]; then
    ENTITLEMENTS_FLAG="--entitlements Resources/NekoTrans.entitlements"
fi

if [ -n "$IDENTITY" ]; then
    echo "🔏 Ký ứng dụng với chứng chỉ Developer (SHA-1: $IDENTITY)..."
    if ! codesign --force --deep $ENTITLEMENTS_FLAG --sign "$IDENTITY" "$APP_DIR"; then
        echo "⚠️ Không thể ký với chứng chỉ Developer, chuyển sang Ad-hoc signature (-)..."
        codesign --force --deep $ENTITLEMENTS_FLAG --sign - "$APP_DIR"
    fi
else
    echo "🔏 Ký ứng dụng với Ad-hoc signature (-)..."
    codesign --force --deep $ENTITLEMENTS_FLAG --sign - "$APP_DIR"
fi

echo "✅ Đóng gói và ký mã nguồn hoàn tất: $APP_DIR"

# Làm mới cache icon trong macOS LaunchServices
touch "$APP_DIR"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R "$APP_DIR" >/dev/null 2>&1 || true
