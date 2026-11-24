#!/usr/bin/env bash
set -eo pipefail

# Fail fast (or auto-select Xcode) when only Command Line Tools are active.
# shellcheck source=Scripts/toolchain.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/toolchain.sh"

BUILD_FLAVOR="${1:---public}"
DERIVED_DATA=".build/XcodeDerivedData"
SPM_CACHE_DIR="${SPM_CACHE_DIR:-$HOME/.cache/nekotrans-spm}"
CONFIGURATION="Release"
IS_DEV_BUILD=0
EXTRA_SWIFT_CONDITIONS=""

case "$BUILD_FLAVOR" in
    --dev)
        CONFIGURATION="Debug"
        IS_DEV_BUILD=1
        ;;
    --dev-low|--low)
        CONFIGURATION="Debug"
        IS_DEV_BUILD=1
        LOW_PRIORITY=1
        BUILD_JOBS="${BUILD_JOBS:-4}"
        ;;
    --beta)
        CONFIGURATION="Release"
        ;;
    --strict-stripped)
        CONFIGURATION="Release"
        EXTRA_SWIFT_CONDITIONS="PUBLIC_RELEASE_STRIPPED"
        ;;
    *)
        CONFIGURATION="Release"
        ;;
esac

mkdir -p "$DERIVED_DATA" "$SPM_CACHE_DIR"

XCODEBUILD_ARGS=(
    -project NekoTrans.xcodeproj
    -scheme NekoTrans
    -configuration "$CONFIGURATION"
    -derivedDataPath "$DERIVED_DATA"
    -clonedSourcePackagesDirPath "$SPM_CACHE_DIR"
    -skipPackagePluginValidation
    -skipMacroValidation
    COMPILATION_CACHE_ENABLE_CACHING=YES
)

if [ -n "$EXTRA_SWIFT_CONDITIONS" ]; then
    XCODEBUILD_ARGS+=(SWIFT_ACTIVE_COMPILATION_CONDITIONS="$EXTRA_SWIFT_CONDITIONS")
fi

if [ -n "${BUILD_JOBS:-}" ]; then
    XCODEBUILD_ARGS+=(-jobs "$BUILD_JOBS")
fi

RUNNER=()
if [ "${LOW_PRIORITY:-0}" = "1" ] && [ -x "/usr/sbin/taskpolicy" ]; then
    RUNNER=(/usr/sbin/taskpolicy -b)
fi

if [ "$IS_DEV_BUILD" = "1" ]; then
    if [ "${LOW_PRIORITY:-0}" = "1" ]; then
        echo "🪶 Bắt đầu Incremental Build [DEV - LOW CPU/RAM QoS, jobs=${BUILD_JOBS:-auto}]..."
    else
        echo "⚡ Bắt đầu Incremental Build [DEV - chỉ biên dịch file thay đổi]..."
    fi
elif [ "$BUILD_FLAVOR" = "--beta" ]; then
    echo "🧪 Bắt đầu build NekoTrans [BETA LABS TESTER] qua Xcode..."
elif [ "$BUILD_FLAVOR" = "--strict-stripped" ]; then
    echo "🔒 Bắt đầu build NekoTrans [STRICT STRIPPED RELEASE] qua Xcode..."
else
    echo "🚀 Bắt đầu build NekoTrans [PUBLIC RELEASE] qua Xcode..."
fi

if command -v xcbeautify >/dev/null 2>&1; then
    "${RUNNER[@]}" xcodebuild "${XCODEBUILD_ARGS[@]}" build | xcbeautify
else
    if [ "$IS_DEV_BUILD" = "1" ] || [ "${QUIET:-0}" = "1" ]; then
        XCODEBUILD_ARGS+=(-quiet)
    fi
    "${RUNNER[@]}" xcodebuild "${XCODEBUILD_ARGS[@]}" build
fi

APP_NAME="NekoTrans.app"
APP_DIR="build/$APP_NAME"
BUILT_APP="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

echo "📦 Đang đóng gói $APP_NAME ($CONFIGURATION) vào thư mục build/..."
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

# Generate & Cache AppIcon.icns only when source iconset changes
ICON_CACHE=".build/AppIcon.cached.icns"
if [ -d "Resources/AppIcon.iconset" ]; then
    NEED_ICON_REBUILD=0
    if [ ! -f "$ICON_CACHE" ]; then
        NEED_ICON_REBUILD=1
    elif [ -n "$(find Resources/AppIcon.iconset -newer "$ICON_CACHE" -print -quit 2>/dev/null)" ]; then
        NEED_ICON_REBUILD=1
    fi
    if [ "$NEED_ICON_REBUILD" = "1" ]; then
        iconutil -c icns Resources/AppIcon.iconset -o "$ICON_CACHE"
    fi
    cp "$ICON_CACHE" "$RESOURCES_DIR/AppIcon.icns"
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
if [ -z "${CODESIGN_IDENTITY:-}" ]; then
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

ENTITLEMENTS_ARGS=()
if [ -f "Resources/NekoTrans.entitlements" ]; then
    ENTITLEMENTS_ARGS=(--entitlements "Resources/NekoTrans.entitlements")
fi

SIGN_TARGET="${IDENTITY:--}"
TIMESTAMP_ARGS=()
if [ "$IS_DEV_BUILD" = "1" ]; then
    TIMESTAMP_ARGS=(--timestamp=none)
fi

# In dev mode with ad-hoc signing (-), Xcode already signed nested bundles/frameworks; skip if valid.
SKIP_NESTED_SIGN=0
if [ "$IS_DEV_BUILD" = "1" ] && [ -z "$IDENTITY" ]; then
    SKIP_NESTED_SIGN=1
fi

if [ "$SKIP_NESTED_SIGN" = "0" ]; then
    # Sign embedded resource bundles first without entitlements
    find "$APP_DIR/Contents/Resources" -name "*.bundle" -type d 2>/dev/null | while read -r bundle; do
        codesign --force "${TIMESTAMP_ARGS[@]}" --sign "$SIGN_TARGET" "$bundle" >/dev/null 2>&1 || true
    done

    # Sign Sparkle XPC services, helper binaries, and all frameworks (Sparkle.framework, llama.framework)
    find "$APP_DIR/Contents/Frameworks" -name "*.xpc" -type d 2>/dev/null | while read -r xpc; do
        codesign --force --options runtime "${TIMESTAMP_ARGS[@]}" --sign "$SIGN_TARGET" "$xpc" >/dev/null 2>&1 || true
    done
    find "$APP_DIR/Contents/Frameworks" \( -name "Autoupdate" -o -name "Updater.app" \) 2>/dev/null | while read -r helper; do
        codesign --force --options runtime "${TIMESTAMP_ARGS[@]}" --sign "$SIGN_TARGET" "$helper" >/dev/null 2>&1 || true
    done
    find "$APP_DIR/Contents/Frameworks" -name "*.framework" -type d 2>/dev/null | while read -r fw; do
        codesign --force --options runtime "${TIMESTAMP_ARGS[@]}" --sign "$SIGN_TARGET" "$fw" >/dev/null 2>&1 || true
    done
fi

if [ -n "$IDENTITY" ]; then
    echo "🔏 Ký ứng dụng với chứng chỉ Developer (SHA-1: $IDENTITY)..."
    if ! codesign --force --options runtime "${TIMESTAMP_ARGS[@]}" "${ENTITLEMENTS_ARGS[@]}" --sign "$IDENTITY" "$APP_DIR"; then
        echo "⚠️ Không thể ký với chứng chỉ Developer, chuyển sang Ad-hoc signature (-)..."
        codesign --force --options runtime "${TIMESTAMP_ARGS[@]}" "${ENTITLEMENTS_ARGS[@]}" --sign - "$APP_DIR"
    fi
else
    echo "🔏 Ký ứng dụng với Ad-hoc signature (-)..."
    codesign --force --options runtime "${TIMESTAMP_ARGS[@]}" "${ENTITLEMENTS_ARGS[@]}" --sign - "$APP_DIR"
fi

echo "✅ Đóng gói và ký mã nguồn hoàn tất: $APP_DIR"

# Prevent Spotlight from indexing internal developer build folder
touch "build.noindex/.metadata_never_index" 2>/dev/null || true
touch "$DERIVED_DATA/.metadata_never_index" 2>/dev/null || true

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

sync_and_register_launch_services() {
    "$LSREGISTER" -u "$BUILT_APP" >/dev/null 2>&1 || true
    "$LSREGISTER" -u "$PWD/$DERIVED_DATA/Build/Products/Debug/$APP_NAME" >/dev/null 2>&1 || true
    "$LSREGISTER" -u "$PWD/$DERIVED_DATA/Build/Products/Release/$APP_NAME" >/dev/null 2>&1 || true

    if [ -d "/Applications/$APP_NAME" ]; then
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
        "$LSREGISTER" -f -R -trusted "$APP_DIR" >/dev/null 2>&1 || true
    fi
}

if [ "$IS_DEV_BUILD" = "1" ]; then
    # Sync /Applications synchronously if present so `open /Applications/NekoTrans.app` sees fresh changes,
    # then run slow lsregister calls asynchronously in the background.
    if [ -d "/Applications/$APP_NAME" ]; then
        if command -v rsync >/dev/null 2>&1; then
            rsync -a --delete "$APP_DIR/" "/Applications/$APP_NAME/"
        else
            rm -rf "/Applications/$APP_NAME"
            cp -R "$APP_DIR" "/Applications/"
        fi
        touch "/Applications/$APP_NAME"
    else
        touch "$APP_DIR"
    fi
    (
        "$LSREGISTER" -u "$BUILT_APP" >/dev/null 2>&1 || true
        if [ -d "/Applications/$APP_NAME" ]; then
            "$LSREGISTER" -f -R -trusted "/Applications/$APP_NAME" >/dev/null 2>&1 || true
            "$LSREGISTER" -u "$PWD/build.noindex/$APP_NAME" >/dev/null 2>&1 || true
            "$LSREGISTER" -u "$PWD/build/$APP_NAME" >/dev/null 2>&1 || true
        else
            "$LSREGISTER" -f -R -trusted "$APP_DIR" >/dev/null 2>&1 || true
        fi
    ) >/dev/null 2>&1 &
else
    if [ -d "/Applications/$APP_NAME" ]; then
        echo "📂 Đồng bộ bản cập nhật sang /Applications/$APP_NAME..."
    fi
    sync_and_register_launch_services
fi
