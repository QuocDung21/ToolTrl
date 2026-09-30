#!/usr/bin/env bash
# Shared toolchain guard, sourced by Scripts/build_app.sh and the Makefile.
#
# Why this exists: SwiftUI's `@State` / `#Preview` macros are expanded by macro
# plugins (libSwiftUIMacros.dylib, libPreviewsMacros.dylib) that ship ONLY inside
# Xcode. When `xcode-select -p` points at /Library/Developer/CommandLineTools,
# every SwiftUI file fails with:
#     external macro implementation type 'SwiftUIMacros.StateMacro' could not be found
#
# This helper switches DEVELOPER_DIR to a real Xcode when one is installed, and
# otherwise fails fast with an actionable message instead of a wall of macro errors.
#
# Usage:  . "$(dirname "$0")/toolchain.sh"

if [ -n "${NEKOTRANS_TOOLCHAIN_READY:-}" ]; then
    return 0 2>/dev/null || true
fi

_neko_active_developer_dir() {
    if [ -n "${DEVELOPER_DIR:-}" ]; then
        echo "$DEVELOPER_DIR"
    else
        xcode-select -p 2>/dev/null || true
    fi
}

neko_ensure_xcode_toolchain() {
    local active_dir
    active_dir="$(_neko_active_developer_dir)"

    # Already on a full Xcode: nothing to do.
    case "$active_dir" in
        */CommandLineTools|"")
            ;;
        *)
            if [ -x "$active_dir/usr/bin/xcodebuild" ] || [ -d "$active_dir/Platforms/MacOSX.platform" ]; then
                export NEKOTRANS_TOOLCHAIN_READY=1
                return 0
            fi
            ;;
    esac

    local candidates=(
        /Applications/Xcode.app
        /Applications/Xcode-*.app
    )
    local candidate
    for candidate in "${candidates[@]}"; do
        if [ -d "$candidate/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins" ]; then
            export DEVELOPER_DIR="$candidate/Contents/Developer"
            export NEKOTRANS_TOOLCHAIN_READY=1
            echo "🔧 Dùng Xcode tại $candidate (Command Line Tools thiếu SwiftUI macro plugins)."
            return 0
        fi
    done

    echo "❌ Không tìm thấy Xcode đầy đủ — chỉ có Command Line Tools." >&2
    echo "   SwiftUI macros (@State, #Preview) không thể biên dịch nếu thiếu Xcode." >&2
    echo "   Cách sửa: cài Xcode, rồi chạy:" >&2
    echo "     sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
    return 1
}

neko_ensure_xcode_toolchain
