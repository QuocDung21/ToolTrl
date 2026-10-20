import SwiftUI

public struct GeneralSettingsSection: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject private var flags = FeatureFlagService.shared
    @EnvironmentObject private var l10n: Localization

    public init() {}

    public var body: some View {
        Form {
            languageSection
            startupSection
            permissionsSection
            translationSection
            interactionSection
            cacheSection
        }
        .formStyle(.grouped)
    }

    // MARK: - Language & Localization

    private var languageSection: some View {
        Section {
            Picker(.languageSection, selection: Binding(
                get: { l10n.preference },
                set: { l10n.setPreference($0) }
            )) {
                ForEach(LanguagePreference.allCases) { pref in
                    Text(pref.localizedTitle).tag(pref)
                }
            }
        } header: {
            Text(.languageSection)
        }
    }

    // MARK: - Startup & System

    private var startupSection: some View {
        Section {
            Toggle(.generalLaunchAtLogin, isOn: Binding(
                get: { settings.launchAtLogin },
                set: { settings.setLaunchAtLogin($0) }
            ))

            Toggle(.generalShowMainWindowOnLaunch, isOn: Binding(
                get: { settings.showMainWindowOnLaunch },
                set: { settings.setShowMainWindowOnLaunch($0) }
            ))

            Toggle(.generalShowInDock, isOn: $settings.showInDock)

            Toggle(.generalClickOutsideDismiss, isOn: $settings.clickOutsideDismiss)

            Picker(.generalQuitAction, selection: $settings.quitActionPreference) {
                ForEach(QuitActionPreference.allCases) { action in
                    Text(action.localizedTitle).tag(action)
                }
            }
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
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Label("Quyền Trợ năng (Accessibility)", systemImage: "figure.roll")
                        .font(.system(size: 13, weight: .medium))
                    Text("Cần thiết để tự động trích xuất văn bản đang chọn khi bấm phím tắt dịch.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isAccessibilityGranted {
                    Label("Đã cấp", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                } else {
                    Button("Cấp quyền") {
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
                    Label("Quyền Ghi màn hình (Screen Recording)", systemImage: "viewfinder")
                        .font(.system(size: 13, weight: .medium))
                    Text("Cần thiết để chụp vùng màn hình khi dịch OCR (Option + S).")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isScreenCaptureGranted {
                    Label("Đã cấp", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                } else {
                    Button("Cấp quyền") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        } header: {
            Text("QUYỀN HỆ THỐNG (PRIVACY & PERMISSIONS)")
        }
    }

    // MARK: - Translation & Engine

    private var translationSection: some View {
        Section {
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

            Picker(.generalTargetLanguage, selection: $settings.targetLanguage) {
                ForEach(TargetLanguage.allCases) { lang in
                    Text(lang.displayName).tag(lang.rawValue)
                }
            }

            Picker(.generalDisplayMode, selection: $settings.translationDisplayMode) {
                ForEach(TranslationDisplayMode.allCases) { mode in
                    Text(mode.localizedTitle).tag(mode)
                }
            }

            Picker("Chế độ tra từ đơn (HUD):", selection: $settings.wordLookupMode) {
                ForEach(WordLookupMode.allCases) { mode in
                    Label(LocalizedStringKey(mode.title), systemImage: mode.icon)
                        .tag(mode)
                }
            }
        } header: {
            Text(.sectionTranslation)
        }
    }

    // MARK: - Interaction & Quick Trigger

    private var interactionSection: some View {
        Section {
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
        } header: {
            Text(.sectionInteraction)
        }
    }

    // MARK: - Cache
    private var cacheSection: some View {
        Section {
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
        } header: {
            Text(.sectionCache)
        }
    }
}

#Preview {
    LocalizedRootView {
        GeneralSettingsSection()
    }
    .frame(width: 600, height: 700)
}
