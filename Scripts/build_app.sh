#!/usr/bin/env bash
set -e

# Fail fast (or auto-select Xcode) when only Command Line Tools are active.
# shellcheck source=Scripts/toolchain.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/toolchain.sh"

BUILD_FLAVOR="${1:---public}"
DERIVED_DATA=".build/XcodeDerivedData"

if [ "$BUILD_FLAVOR" = "--beta" ]; then
    echo "🧪 Bắt đầu build NekoTrans [BETA LABS TESTER] qua Xcode..."
    xcodebuild -project NekoTrans.xcodeproj -scheme NekoTrans -configuration Release -derivedDataPath "$DERIVED_DATA" build
elif [ "$BUILD_FLAVOR" = "--strict-stripped" ]; then
    echo "🔒 Bắt đầu build NekoTrans [STRICT STRIPPED RELEASE] qua Xcode..."
    xcodebuild -project NekoTrans.xcodeproj -scheme NekoTrans -configuration Release -derivedDataPath "$DERIVED_DATA" SWIFT_ACTIVE_COMPILATION_CONDITIONS="PUBLIC_RELEASE_STRIPPED" build
else
    echo "🚀 Bắt đầu build NekoTrans [PUBLIC RELEASE] qua Xcode..."
    xcodebuild -project NekoTrans.xcodeproj -scheme NekoTrans -configuration Release -derivedDataPath "$DERIVED_DATA" build
fi

APP_NAME="NekoTrans.app"
APP_DIR="build/$APP_NAME"
BUILT_APP="$DERIVED_DATA/Build/Products/Release/$APP_NAME"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

echo "📦 Đang đóng gói $APP_NAME vào thư mục build/..."
mkdir -p "$APP_DIR"
if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "$BUILT_APP/" "$APP_DIR/"
else
    rm -rf "$APP_DIR"
    mkdir -p build
    cp -R "$BUILT_APP" "$APP_DIR"
fi

# Generate & Copy AppIcon.icns if needed
if [ -d "Resources/AppIcon.iconset" ]; then
    iconutil -c icns Resources/AppIcon.iconset -o "$RESOURCES_DIR/AppIcon.icns"
elif [ -f "Resources/AppIcon.icns" ]; then
    cp Resources/AppIcon.icns "$RESOURCES_DIR/AppIcon.icns"
fi

if [ -f "Resources/apexcharts.min.js" ]; then
    cp Resources/apexcharts.min.js "$RESOURCES_DIR/apexcharts.min.js"
fi

# Inject Usage Descriptions into Info.plist for macOS TCC transparency
INFO_PLIST="$APP_DIR/Contents/Info.plist"
if [ -f "$INFO_PLIST" ]; then
    /usr/libexec/PlistBuddy -c "Set :NSAccessibilityUsageDescription 'NekoTrans cần quyền Trợ năng để tự động trích xuất văn bản đang được chọn khi dịch nhanh.'" "$INFO_PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :NSAccessibilityUsageDescription string 'NekoTrans cần quyền Trợ năng để tự động trích xuất văn bản đang được chọn khi dịch nhanh.'" "$INFO_PLIST" 2>/dev/null || true

    /usr/libexec/PlistBuddy -c "Set :NSScreenCaptureUsageDescription 'NekoTrans cần quyền Ghi màn hình để chụp vùng văn bản khi dịch OCR (Option + S).'" "$INFO_PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :NSScreenCaptureUsageDescription string 'NekoTrans cần quyền Ghi màn hình để chụp vùng văn bản khi dịch OCR (Option + S).'" "$INFO_PLIST" 2>/dev/null || true

    /usr/libexec/PlistBuddy -c "Set :NSAppleEventsUsageDescription 'NekoTrans cần quyền Tự động hoá để lấy văn bản và liên kết từ trình duyệt web.'" "$INFO_PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :NSAppleEventsUsageDescription string 'NekoTrans cần quyền Tự động hoá để lấy văn bản và liên kết từ trình duyệt web.'" "$INFO_PLIST" 2>/dev/null || true
fi

# Find signing identity in Keychain (support explicit CODESIGN_IDENTITY or auto-detect Apple Development)
if [ -z "$CODESIGN_IDENTITY" ]; then
    IDENTITY=$(security find-identity -p codesigning -v 2>/dev/null | grep "Apple Development" | head -n 1 | awk '{print $2}' || true)
    if [ -z "$IDENTITY" ]; then
        DEFAULT_DEV_ID="AD9E1E8668E5A37FFB7535CD09A0225568530A08"
        if security find-certificate -c "Dũng Nguyễn Quốc" >/dev/null 2>&1; then
            IDENTITY="$DEFAULT_DEV_ID"
        fi
    fi
else
    IDENTITY="$CODESIGN_IDENTITY"
fi

ENTITLEMENTS_FLAG=""
if [ -f "Resources/NekoTrans.entitlements" ]; then
    ENTITLEMENTS_FLAG="--entitlements Resources/NekoTrans.entitlements"
fi

SIGN_TARGET="${IDENTITY:--}"

# Sign embedded resource bundles first without entitlements
find "$APP_DIR/Contents/Resources" -name "*.bundle" -type d 2>/dev/null | while read -r bundle; do
    codesign --force --sign "$SIGN_TARGET" "$bundle" >/dev/null 2>&1 || true
done

# Sign Sparkle XPC services, helper binaries, and Sparkle.framework (Atoll pattern)
if [ -d "$APP_DIR/Contents/Frameworks/Sparkle.framework" ]; then
    find "$APP_DIR/Contents/Frameworks/Sparkle.framework" -name "*.xpc" -type d 2>/dev/null | while read -r xpc; do
        codesign --force --options runtime --sign "$SIGN_TARGET" "$xpc" >/dev/null 2>&1 || true
    done
    find "$APP_DIR/Contents/Frameworks/Sparkle.framework" \( -name "Autoupdate" -o -name "Updater.app" \) 2>/dev/null | while read -r helper; do
        codesign --force --options runtime --sign "$SIGN_TARGET" "$helper" >/dev/null 2>&1 || true
    done
    codesign --force --options runtime --sign "$SIGN_TARGET" "$APP_DIR/Contents/Frameworks/Sparkle.framework" >/dev/null 2>&1 || true
fi

if [ -n "$IDENTITY" ]; then
    echo "🔏 Ký ứng dụng với chứng chỉ Developer (SHA-1: $IDENTITY)..."
    if ! codesign --force --options runtime $ENTITLEMENTS_FLAG --sign "$IDENTITY" "$APP_DIR"; then
        echo "⚠️ Không thể ký với chứng chỉ Developer, chuyển sang Ad-hoc signature (-)..."
        codesign --force --options runtime $ENTITLEMENTS_FLAG --sign - "$APP_DIR"
    fi
else
    echo "🔏 Ký ứng dụng với Ad-hoc signature (-)..."
    codesign --force --options runtime $ENTITLEMENTS_FLAG --sign - "$APP_DIR"
fi

echo "✅ Đóng gói và ký mã nguồn hoàn tất: $APP_DIR"

# Làm mới cache icon trong macOS LaunchServices
touch "$APP_DIR"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_DIR" >/dev/null 2>&1 || true
