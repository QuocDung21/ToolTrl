# =============================================================================
# NekoTrans - Modern macOS AI-Powered Translator & Vocabulary Assistant
# =============================================================================

.PHONY: all build dev dev-run dev-low low low-run run install reinstall stop kill restart dmg test clean clean-all help

# Colors for terminal output
CYAN    := \033[36m
GREEN   := \033[32m
YELLOW  := \033[33m
RED     := \033[31m
RESET   := \033[0m

SPM_CACHE_DIR ?= $(HOME)/.cache/nekotrans-spm

all: build

## ⚡ Incremental Build (Debug) - chỉ biên dịch các file vừa thay đổi (~2-5s)
dev:
	@./Scripts/build_app.sh --dev

## ⚡ Incremental Build (Debug) và khởi chạy ngay
dev-run: dev
	@echo "$(YELLOW)🛑 Dừng tiến trình NekoTrans cũ nếu đang chạy...$(RESET)"
	@killall NekoTrans 2>/dev/null || killall ToolTrL 2>/dev/null || true
	@sleep 0.5
	@if [ -d "/Applications/NekoTrans.app" ]; then \
		echo "$(GREEN)✨ Mở /Applications/NekoTrans.app...$(RESET)"; \
		open /Applications/NekoTrans.app; \
	else \
		echo "$(GREEN)✨ Mở NekoTrans.app từ build/...$(RESET)"; \
		open build/NekoTrans.app; \
	fi

## 🪶 Incremental Build tiết kiệm CPU/RAM (Background QoS / E-cores, tối đa 4 luồng)
dev-low low:
	@./Scripts/build_app.sh --dev-low

## 🪶 Incremental Build tiết kiệm CPU/RAM và khởi chạy ngay
low-run: dev-low
	@killall NekoTrans 2>/dev/null || killall ToolTrL 2>/dev/null || true
	@sleep 0.5
	@if [ -d "/Applications/NekoTrans.app" ]; then \
		open /Applications/NekoTrans.app; \
	else \
		open build/NekoTrans.app; \
	fi

## 🔨 Build NekoTrans.app bundle (Release - Whole Module Optimization)
build:
	@echo "$(CYAN)🚀 Bắt đầu build NekoTrans.app (Release)...$(RESET)"
	@./Scripts/build_app.sh

## ▶️ Build (Release) và chạy ứng dụng
run: build
	@echo "$(YELLOW)🛑 Dừng tiến trình NekoTrans cũ nếu đang chạy...$(RESET)"
	@killall NekoTrans 2>/dev/null || killall ToolTrL 2>/dev/null || true
	@sleep 1
	@if [ -d "/Applications/NekoTrans.app" ]; then \
		echo "$(GREEN)✨ Mở /Applications/NekoTrans.app...$(RESET)"; \
		open /Applications/NekoTrans.app; \
	else \
		echo "$(GREEN)✨ Mở NekoTrans.app từ build/...$(RESET)"; \
		open build/NekoTrans.app; \
	fi

## 📦 Build và cài đặt đè vào /Applications/NekoTrans.app rồi chạy
install: build
	@echo "$(YELLOW)🛑 Dừng tiến trình NekoTrans cũ...$(RESET)"
	@killall NekoTrans 2>/dev/null || killall ToolTrL 2>/dev/null || true
	@sleep 1
	@echo "$(CYAN)📂 Cài đặt vào /Applications/NekoTrans.app...$(RESET)"
	@mkdir -p /Applications/NekoTrans.app
	@if command -v rsync >/dev/null 2>&1; then \
		rsync -a --delete build/NekoTrans.app/ /Applications/NekoTrans.app/; \
	else \
		rm -rf /Applications/NekoTrans.app /Applications/ToolTrL.app; \
		cp -R build/NekoTrans.app /Applications/; \
	fi
	@touch /Applications/NekoTrans.app
	@/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/NekoTrans.app >/dev/null 2>&1 || true
	@echo "$(GREEN)🚀 Khởi chạy /Applications/NekoTrans.app...$(RESET)"
	@open /Applications/NekoTrans.app

reinstall: install

## 🛑 Dừng toàn bộ tiến trình NekoTrans đang chạy
stop kill:
	@echo "$(RED)🛑 Đang dừng NekoTrans...$(RESET)"
	@killall NekoTrans 2>/dev/null || killall ToolTrL 2>/dev/null && echo "$(GREEN)✅ Đã dừng NekoTrans$(RESET)" || echo "$(YELLOW)ℹ️ NekoTrans không chạy$(RESET)"

## 🔄 Khởi động lại ứng dụng
restart:
	@killall NekoTrans 2>/dev/null || killall ToolTrL 2>/dev/null || true
	@sleep 1
	@if [ -d "/Applications/NekoTrans.app" ]; then \
		echo "$(GREEN)🚀 Khởi chạy /Applications/NekoTrans.app...$(RESET)"; \
		open /Applications/NekoTrans.app; \
	else \
		echo "$(GREEN)🚀 Khởi chạy build/NekoTrans.app...$(RESET)"; \
		open build/NekoTrans.app; \
	fi

## 💿 Đóng gói bộ cài đặt DMG
dmg:
	@echo "$(CYAN)💿 Tạo file cài đặt DMG...$(RESET)"
	@./Scripts/create_dmg.sh

## 🧪 Chạy Unit Tests (có bật Compilation Cache & SPM Cache)
test:
	@echo "$(CYAN)🧪 Chạy kiểm thử Xcode Test...$(RESET)"
	@mkdir -p "$(SPM_CACHE_DIR)"
	@set -eo pipefail; . ./Scripts/toolchain.sh && \
	if command -v xcbeautify >/dev/null 2>&1; then \
		xcodebuild test -project NekoTrans.xcodeproj -scheme NekoTrans -destination 'platform=macOS' \
			-derivedDataPath .build/XcodeDerivedData -clonedSourcePackagesDirPath "$(SPM_CACHE_DIR)" \
			-skipPackagePluginValidation -skipMacroValidation COMPILATION_CACHE_ENABLE_CACHING=YES | xcbeautify; \
	else \
		xcodebuild test -project NekoTrans.xcodeproj -scheme NekoTrans -destination 'platform=macOS' \
			-derivedDataPath .build/XcodeDerivedData -clonedSourcePackagesDirPath "$(SPM_CACHE_DIR)" \
			-skipPackagePluginValidation -skipMacroValidation COMPILATION_CACHE_ENABLE_CACHING=YES; \
	fi
	@/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u .build/XcodeDerivedData/Build/Products/Debug/NekoTrans.app 2>/dev/null || true

## 🧹 Xoá file build trung gian (giữ lại cache SPM để build lại nhanh)
clean:
	@echo "$(RED)🧹 Dọn dẹp thư mục build & .build (giữ cache SPM tại $(SPM_CACHE_DIR))...$(RESET)"
	@/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u build/NekoTrans.app 2>/dev/null || true
	@/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u build.noindex/NekoTrans.app 2>/dev/null || true
	@/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u .build/XcodeDerivedData/Build/Products/Release/NekoTrans.app 2>/dev/null || true
	@/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u .build/XcodeDerivedData/Build/Products/Debug/NekoTrans.app 2>/dev/null || true
	@rm -rf build build.noindex .build
	@echo "$(GREEN)✅ Đã dọn dẹp sạch sẽ!$(RESET)"

## 🧨 Xoá toàn bộ cả file build lẫn cache SPM
clean-all: clean
	@echo "$(RED)🧨 Xoá thêm cache SPM tại $(SPM_CACHE_DIR)...$(RESET)"
	@rm -rf "$(SPM_CACHE_DIR)"
	@echo "$(GREEN)✅ Đã xoá toàn bộ build và SPM cache!$(RESET)"

## ❓ Hiển thị danh sách các lệnh Make có sẵn
help:
	@echo "$(CYAN)================ NekoTrans Makefile ================$(RESET)"
	@echo "  $(GREEN)make dev$(RESET)             - Incremental Build (Debug) chỉ dịch file vừa sửa (~2-5s)"
	@echo "  $(GREEN)make dev-run$(RESET)         - Incremental Build (Debug) và mở ngay ứng dụng"
	@echo "  $(GREEN)make dev-low$(RESET) / $(GREEN)low$(RESET)   - Incremental Build nhẹ nền (E-cores, chống nóng/lag máy)"
	@echo "  $(GREEN)make low-run$(RESET)         - Incremental Build nhẹ nền và mở ngay ứng dụng"
	@echo "  $(GREEN)make$(RESET) / $(GREEN)make build$(RESET)     - Biên dịch bản chuẩn tối ưu (Release)"
	@echo "  $(GREEN)make run$(RESET)             - Biên dịch bản Release và khởi chạy"
	@echo "  $(GREEN)make install$(RESET)         - Biên dịch Release, cài vào /Applications và chạy"
	@echo "  $(GREEN)make stop$(RESET) / $(GREEN)make kill$(RESET)  - Dừng tiến trình NekoTrans"
	@echo "  $(GREEN)make restart$(RESET)          - Khởi động lại NekoTrans"
	@echo "  $(GREEN)make dmg$(RESET)              - Tạo gói cài đặt .dmg"
	@echo "  $(GREEN)make test$(RESET)             - Chạy kiểm thử tự động"
	@echo "  $(GREEN)make clean$(RESET)            - Dọn dẹp thư mục build (giữ lại cache thư viện SPM)"
	@echo "  $(GREEN)make clean-all$(RESET)        - Xoá sạch cả build lẫn cache thư viện SPM"
	@echo "$(CYAN)====================================================$(RESET)"
