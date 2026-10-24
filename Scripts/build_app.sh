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
if [ -d "build" ] && [ ! -L "build" ]; then
    rm -rf build.noindex
    mv build build.noindex
    ln -s build.noindex build
elif [ ! -e "build" ]; then
    mkdir -p build.noindex
    ln -s build.noindex build
fi
mkdir -p build.noindex "$DERIVED_DATA"
touch "build.noindex/.metadata_never_index"
touch "$DERIVED_DATA/.metadata_never_index" 2>/dev/null || true

mkdir -p "$APP_DIR"
if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "$BUILT_APP/" "$APP_DIR/"
else
    rm -rf "$APP_DIR"
    mkdir -p build
    cp -R "$BUILT_APP" "$APP_DIR"
fi

# Ensure Safari Web Extension is bundled into Contents/PlugIns
if [ -d "$DERIVED_DATA/Build/Products/Release/NekoTransSafariExtension.appex" ]; then
    mkdir -p "$APP_DIR/Contents/PlugIns"
    rsync -a --delete "$DERIVED_DATA/Build/Products/Release/NekoTransSafariExtension.appex" "$APP_DIR/Contents/PlugIns/"
    EXT_RES="$APP_DIR/Contents/PlugIns/NekoTransSafariExtension.appex/Contents/Resources"
    if [ -d "$EXT_RES/Resources" ]; then
        cp -R "$EXT_RES/Resources/"* "$EXT_RES/"
        rm -rf "$EXT_RES/Resources"
    fi
fi

# Generate & Copy AppIcon.icns if needed
if [ -d "Resources/AppIcon.iconset" ]; then
    iconutil -c icns Resources/AppIcon.iconset -o "$RESOURCES_DIR/AppIcon.icns"
elif [ -f "Resources/AppIcon.icns" ]; then
    cp Resources/AppIcon.icns "$RESOURCES_DIR/AppIcon.icns"
fi

# Synchronize AppIcon into Safari Extension bundle (.appex)
EXT_APPEX_RES="$APP_DIR/Contents/PlugIns/NekoTransSafariExtension.appex/Contents/Resources"
if [ -f "$RESOURCES_DIR/AppIcon.icns" ] && [ -d "$EXT_APPEX_RES" ]; then
    cp "$RESOURCES_DIR/AppIcon.icns" "$EXT_APPEX_RES/AppIcon.icns"
fi
EXT_PLIST="$APP_DIR/Contents/PlugIns/NekoTransSafariExtension.appex/Contents/Info.plist"
if [ -f "$EXT_PLIST" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile 'AppIcon'" "$EXT_PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string 'AppIcon'" "$EXT_PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Set :CFBundleIconName 'AppIcon'" "$EXT_PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconName string 'AppIcon'" "$EXT_PLIST" 2>/dev/null || true
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

    /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile 'AppIcon'" "$INFO_PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string 'AppIcon'" "$INFO_PLIST" 2>/dev/null || true

    /usr/libexec/PlistBuddy -c "Set :CFBundleIconName 'AppIcon'" "$INFO_PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconName string 'AppIcon'" "$INFO_PLIST" 2>/dev/null || true

    # Register nekotrans:// custom URL scheme
    /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes array" "$INFO_PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0 dict" "$INFO_PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLName string 'com.nekotrans.mac'" "$INFO_PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$INFO_PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string 'nekotrans'" "$INFO_PLIST" 2>/dev/null || true
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

# Sign Sparkle XPC services, helper binaries, and all frameworks (Sparkle.framework, llama.framework)
find "$APP_DIR/Contents/Frameworks" -name "*.xpc" -type d 2>/dev/null | while read -r xpc; do
    codesign --force --options runtime --sign "$SIGN_TARGET" "$xpc" >/dev/null 2>&1 || true
done
find "$APP_DIR/Contents/Frameworks" \( -name "Autoupdate" -o -name "Updater.app" \) 2>/dev/null | while read -r helper; do
    codesign --force --options runtime --sign "$SIGN_TARGET" "$helper" >/dev/null 2>&1 || true
done
find "$APP_DIR/Contents/Frameworks" -name "*.framework" -type d 2>/dev/null | while read -r fw; do
    codesign --force --options runtime --sign "$SIGN_TARGET" "$fw" >/dev/null 2>&1 || true
done

# Sign embedded app extensions (.appex in Contents/PlugIns) with extension entitlements
find "$APP_DIR/Contents/PlugIns" -name "*.appex" -type d 2>/dev/null | while read -r appex; do
    EXT_ENTITLEMENTS="Resources/NekoTransSafariExtension.entitlements"
    if [ -f "$EXT_ENTITLEMENTS" ]; then
        codesign --force --options runtime --entitlements "$EXT_ENTITLEMENTS" --sign "$SIGN_TARGET" "$appex" >/dev/null 2>&1 || \
        codesign --force --options runtime --sign "$SIGN_TARGET" "$appex" >/dev/null 2>&1 || true
    else
        codesign --force --options runtime --sign "$SIGN_TARGET" "$appex" >/dev/null 2>&1 || true
    fi
done

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

# Prevent Spotlight from indexing internal developer build folder
touch "build.noindex/.metadata_never_index" 2>/dev/null || true
touch "$DERIVED_DATA/.metadata_never_index" 2>/dev/null || true

# Unregister intermediate builds from LaunchServices
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSREGISTER" -u "$BUILT_APP" >/dev/null 2>&1 || true
"$LSREGISTER" -u "$PWD/$DERIVED_DATA/Build/Products/Debug/$APP_NAME" >/dev/null 2>&1 || true
"$LSREGISTER" -u "$PWD/$DERIVED_DATA/Build/Products/Release/$APP_NAME" >/dev/null 2>&1 || true

# If installed in /Applications, keep it updated and register it
if [ -d "/Applications/$APP_NAME" ]; then
    echo "📂 Đồng bộ bản cập nhật sang /Applications/$APP_NAME..."
    if command -v rsync >/dev/null 2>&1; then
        rsync -a --delete "$APP_DIR/" "/Applications/$APP_NAME/"
    else
        rm -rf "/Applications/$APP_NAME"
        cp -R "$APP_DIR" "/Applications/"
    fi
    touch "/Applications/$APP_NAME"
    "$LSREGISTER" -f -R -trusted "/Applications/$APP_NAME" >/dev/null 2>&1 || true
    "$LSREGISTER" -u "$PWD/build.noindex/$APP_NAME" >/dev/null 2>&1 || true
    "$LSREGISTER" -u "$PWD/build/$APP_NAME" >/dev/null 2>&1 || true
    "$LSREGISTER" -u "$PWD/$APP_DIR" >/dev/null 2>&1 || true
    "$LSREGISTER" -u "$APP_DIR" >/dev/null 2>&1 || true
else
    touch "$APP_DIR"
    "$LSREGISTER" -f "$APP_DIR" >/dev/null 2>&1 || true
fi
