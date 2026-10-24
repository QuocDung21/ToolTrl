import SwiftUI

public struct GeneralSettingsSection: View {
    @Bindable var settings = AppSettings.shared
    @ObservedObject private var flags = FeatureFlagService.shared
    @EnvironmentObject private var l10n: Localization

    @State private var isAdvancedExpanded: Bool = false

    public init() {}

    public var body: some View {
        Form {
            // MARK: - Essential Settings (Always Visible)
            translationAndLanguageSection
            startupSection
            permissionsSection

            // MARK: - Advanced Options (Collapsed by default)
            advancedSection
        }
        .formStyle(.grouped)
    }

    // MARK: - Translation & Language Essentials

    private var translationAndLanguageSection: some View {
        Section {
            Picker(.generalTargetLanguage, selection: $settings.targetLanguage) {
                ForEach(TargetLanguage.allCases) { lang in
                    Text(lang.displayName).tag(lang.rawValue)
                }
            }

            Picker(.generalDefaultEngine, selection: $settings.translationEngine) {
                ForEach(TranslationEngine.allCases) { eng in
                    Label {
                        Text(eng.localizedTitle)
                    } icon: {
                        Image(systemName: eng.icon)
                    }
                    .tag(eng)
                }
            }

            Picker(.languageSection, selection: Binding(
                get: { l10n.preference },
                set: { l10n.setPreference($0) }
            )) {
                ForEach(LanguagePreference.allCases) { pref in
                    Text(pref.localizedTitle).tag(pref)
                }
            }
        } header: {
            Text(.sectionTranslation)
        }
    }

    // MARK: - Startup & Dock

    private var startupSection: some View {
        Section {
            Toggle(.generalLaunchAtLogin, isOn: Binding(
                get: { settings.launchAtLogin },
                set: { settings.setLaunchAtLogin($0) }
            ))

            Toggle(.generalShowInDock, isOn: $settings.showInDock)
        } header: {
            Text(.sectionStartup)
        }
    }

    // MARK: - System Permissions

    private var isAccessibilityGranted: Bool {
        TextGrabber.isAccessibilityTrusted(prompt: false)
    }

    private var isScreenCaptureGranted: Bool {
        if #available(macOS 10.15, *) {
            return CGPreflightScreenCaptureAccess()
        }
        return true
    }

    private var permissionsSection: some View {
        let isEn = l10n.resolvedLanguage == .english
        return Section {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Label(
                        isEn ? "Accessibility" : "Quyền Trợ năng",
                        systemImage: "figure.roll"
                    )
                    .font(.system(size: 13, weight: .medium))
                    Text(
                        isEn
                            ? "Allows automatic text selection capture when triggering translation shortcuts."
                            : "Tự động lấy văn bản đang chọn khi bấm phím tắt dịch."
                    )
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                }

                Spacer()

                if isAccessibilityGranted {
                    Label(isEn ? "Granted" : "Đã cấp", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                } else {
                    Button(isEn ? "Grant" : "Cấp quyền") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Label(
                        isEn ? "Screen Recording" : "Ghi màn hình",
                        systemImage: "viewfinder"
                    )
                    .font(.system(size: 13, weight: .medium))
                    Text(
                        isEn
                            ? "Required to capture and recognize screen text via OCR (Option + S)."
                            : "Cần thiết để chụp vùng màn hình khi dịch OCR (Option + S)."
                    )
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                }

                Spacer()

                if isScreenCaptureGranted {
                    Label(isEn ? "Granted" : "Đã cấp", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                } else {
                    Button(isEn ? "Grant" : "Cấp quyền") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        } header: {
            Text(isEn ? "Permissions" : "Quyền hệ thống")
        }
    }

    // MARK: - Advanced Options (Collapsible)

    private var advancedSection: some View {
        let isEn = l10n.resolvedLanguage == .english
        return Section {
            DisclosureGroup(isExpanded: $isAdvancedExpanded) {
                VStack(alignment: .leading, spacing: 14) {
                    // 1. Chế độ hiển thị & Tra từ
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isEn ? "DISPLAY & LOOKUP" : "HIỂN THỊ & TRA CỨU")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)

                        Picker(.generalDisplayMode, selection: $settings.translationDisplayMode) {
                            ForEach(TranslationDisplayMode.allCases) { mode in
                                Text(mode.localizedTitle).tag(mode)
                            }
                        }

                        Picker(isEn ? "Single word lookup:" : "Khi tra từ đơn:", selection: $settings.wordLookupMode) {
                            ForEach(WordLookupMode.allCases) { mode in
                                Label(LocalizedStringKey(mode.title), systemImage: mode.icon)
                                    .tag(mode)
                            }
                        }
                    }

                    Divider()

                    // 2. Thao tác nhanh
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isEn ? "QUICK ACTIONS" : "THAO TÁC NHANH")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)

                        Toggle(
                            .generalAutoTranslateOnSelection,
                            isOn: $settings.autoTranslateOnSelectionWhenPinned
                        )

                        if flags.isFeatureEnabled(.doubleCmdCTrigger) {
                            Toggle(
                                .generalDoubleCmdC,
                                isOn: $settings.enableDoubleCmdCTrigger
                            )
                        }

                        if flags.isFeatureEnabled(.selectionBubble) {
                            Toggle(
                                .generalSelectionBubble,
                                isOn: $settings.enableSelectionBubble
                            )
                        }
                    }

                    Divider()

                    // 3. Cửa sổ & Thoát
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isEn ? "WINDOW BEHAVIOR" : "HÀNH VI CỬA SỔ")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)

                        Toggle(.generalClickOutsideDismiss, isOn: $settings.clickOutsideDismiss)

                        Toggle(.generalShowMainWindowOnLaunch, isOn: Binding(
                            get: { settings.showMainWindowOnLaunch },
                            set: { settings.setShowMainWindowOnLaunch($0) }
                        ))

                        Picker(.generalQuitAction, selection: $settings.quitActionPreference) {
                            ForEach(QuitActionPreference.allCases) { action in
                                Text(action.localizedTitle).tag(action)
                            }
                        }
                    }

                    Divider()

                    // 4. Dọn dẹp & Gỡ cài đặt
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isEn ? "MAINTENANCE & DATA" : "BẢO TRÌ & DỮ LIỆU")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(.generalClearCacheTitle)
                                    .font(.system(size: 13, weight: .medium))
                                Text(.generalClearCacheSubtitle)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(.generalClearCacheButton) {
                                Task {
                                    await TranslationCache.shared.clearAll()
                                }
                            }
                            .buttonStyle(.bordered)
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(isEn ? "Uninstall NekoTrans" : "Gỡ cài đặt NekoTrans")
                                    .font(.system(size: 13, weight: .medium))
                                Text(
                                    isEn
                                        ? "Remove the application, vocabulary store, settings, and Keychain API keys."
                                        : "Xóa sạch ứng dụng, sổ từ vựng, cấu hình và khóa API trong Keychain."
                                )
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                UninstallWindowController.shared.show()
                            } label: {
                                Text(isEn ? "Uninstall..." : "Gỡ cài đặt...")
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(AppColors.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isEn ? "Advanced Options" : "Tùy chọn nâng cao")
                            .font(.system(size: 13, weight: .medium))
                        Text(
                            isEn
                                ? "Display modes, quick triggers, window behavior, cache & clean uninstall."
                                : "Chế độ hiển thị, thao tác nhanh, cửa sổ, bộ nhớ đệm và gỡ cài đặt sạch."
                        )
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text(isEn ? "Advanced" : "Nâng cao")
        }
    }
}

#Preview {
    LocalizedRootView {
        GeneralSettingsSection()
    }
    .frame(width: 600, height: 700)
}
