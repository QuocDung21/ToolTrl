# =============================================================================
# NekoTrans - Modern macOS AI-Powered Translator & Vocabulary Assistant
# =============================================================================

.PHONY: all build run install reinstall stop kill restart dmg test clean help

# Colors for terminal output
CYAN    := \033[36m
GREEN   := \033[32m
YELLOW  := \033[33m
RED     := \033[31m
RESET   := \033[0m

all: build

## 🔨 Build NekoTrans.app bundle (Release)
build:
	@echo "$(CYAN)🚀 Bắt đầu build NekoTrans.app...$(RESET)"
	@./Scripts/build_app.sh

## ▶️ Build và chạy ứng dụng
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

## 🧪 Chạy Unit Tests
test:
	@echo "$(CYAN)🧪 Chạy kiểm thử Xcode Test...$(RESET)"
	@. ./Scripts/toolchain.sh && xcodebuild test -project NekoTrans.xcodeproj -scheme NekoTrans -destination 'platform=macOS' -derivedDataPath .build/XcodeDerivedData
	@/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u .build/XcodeDerivedData/Build/Products/Debug/NekoTrans.app 2>/dev/null || true

## 🧹 Xoá cache và file build
clean:
	@echo "$(RED)🧹 Dọn dẹp thư mục build & .build...$(RESET)"
	@/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u build/NekoTrans.app 2>/dev/null || true
	@/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u build.noindex/NekoTrans.app 2>/dev/null || true
	@/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u .build/XcodeDerivedData/Build/Products/Release/NekoTrans.app 2>/dev/null || true
	@/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u .build/XcodeDerivedData/Build/Products/Debug/NekoTrans.app 2>/dev/null || true
	@rm -rf build build.noindex .build
	@echo "$(GREEN)✅ Đã dọn dẹp sạch sẽ!$(RESET)"

## ❓ Hiển thị danh sách các lệnh Make có sẵn
help:
	@echo "$(CYAN)================ NekoTrans Makefile ================$(RESET)"
	@echo "  $(GREEN)make$(RESET) / $(GREEN)make build$(RESET)     - Biên dịch NekoTrans.app (Release)"
	@echo "  $(GREEN)make run$(RESET)             - Biên dịch và chạy trực tiếp từ build/"
	@echo "  $(GREEN)make install$(RESET)         - Biên dịch, cài đặt vào /Applications và chạy"
	@echo "  $(GREEN)make stop$(RESET) / $(GREEN)make kill$(RESET)  - Dừng tiến trình NekoTrans"
	@echo "  $(GREEN)make restart$(RESET)          - Khởi động lại NekoTrans"
	@echo "  $(GREEN)make dmg$(RESET)              - Tạo gói cài đặt .dmg"
	@echo "  $(GREEN)make test$(RESET)             - Chạy kiểm thử tự động"
	@echo "  $(GREEN)make clean$(RESET)            - Dọn dẹp toàn bộ file build"
	@echo "$(CYAN)====================================================$(RESET)"
