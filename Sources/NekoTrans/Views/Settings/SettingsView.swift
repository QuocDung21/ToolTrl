import SwiftUI

// MARK: - Sidebar Section

public enum SettingsSidebarSection: String, CaseIterable, Identifiable, Sendable {
    case general    = "general"
    case advanced   = "advanced"
    case shortcuts  = "shortcuts"
    case speech     = "speech"
    case appearance = "appearance"
    case prompts    = "prompts"
    case github     = "github"
    case labs       = "labs"
    case about      = "about"

    public var id: String { rawValue }

    public var localizedTitle: LocalizedStringResource {
        switch self {
        case .general:    return .sidebarGeneral
        case .advanced:   return .sidebarAdvanced
        case .shortcuts:  return .sidebarShortcuts
        case .speech:     return .sidebarSpeech
        case .appearance: return .sidebarAppearance
        case .prompts:    return .sidebarPrompts
        case .github:     return .sidebarGithub
        case .labs:       return .sidebarLabs
        case .about:      return .sidebarAbout
        }
    }

    public var icon: String {
        switch self {
        case .general:    return "gearshape.fill"
        case .advanced:   return "sparkles.rectangle.stack.fill"
        case .shortcuts:  return "command"
        case .speech:     return "speaker.wave.2.fill"
        case .appearance: return "textformat.size"
        case .prompts:    return "sparkles"
        case .github:     return "arrow.triangle.2.circlepath.icloud.fill"
        case .labs:       return "flask.fill"
        case .about:      return "info.circle.fill"
        }
    }

    public var iconBgColor: Color {
        switch self {
        case .general:    return .gray
        case .advanced:   return .indigo
        case .shortcuts:  return .orange
        case .speech:     return .blue
        case .appearance: return .purple
        case .prompts:    return .teal
        case .github:     return .indigo
        case .labs:       return .orange
        case .about:      return .gray
        }
    }
}

// MARK: - Settings View

public struct SettingsView: View {
    @EnvironmentObject private var l10n: Localization
    @EnvironmentObject private var flags: FeatureFlagService

    @State private var selectedSection: SettingsSidebarSection? = .general
    @State private var showPromptManagerSheet: Bool = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    public init() {}

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            detail
        }
        .toolbar(removing: .sidebarToggle)
        .frame(minWidth: 720, minHeight: 490)
        .sheet(isPresented: $showPromptManagerSheet) {
            QuickPromptManagerSheet()
        }
    }

    // MARK: - Sidebar

    private var visibleSections: [SettingsSidebarSection] {
        SettingsSidebarSection.allCases.filter { sec in
            if sec == .labs {
                return flags.isDeveloperModeUnlocked
            }
            return true
        }
    }

    private var sidebar: some View {
        List(selection: $selectedSection) {
            ForEach(visibleSections) { sec in
                NavigationLink(value: sec) {
                    SidebarRow(section: sec)
                }
            }
        }
        .toolbar(removing: .sidebarToggle)
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 220, ideal: 235, max: 280)
    }

    // MARK: - Detail

    private var detail: some View {
        Group {
            switch selectedSection {
            case .general:    GeneralSettingsSection()
            case .advanced:   AdvancedFeaturesSettingsSection()
            case .shortcuts:  ShortcutsSettingsSection()
            case .speech:     SpeechSettingsSection()
            case .appearance: AppearanceSettingsSection()
            case .prompts:    PromptsSettingsSection(showPromptManagerSheet: $showPromptManagerSheet)
            case .github:     GitHubSyncSettingsSection()
            case .labs:       LabsSettingsSection()
            case .about:      AboutSettingsSection()
            case .none:       GeneralSettingsSection()
            }
        }
        .navigationTitle(navigationTitle)
        .toolbar(removing: .sidebarToggle)
        .onChange(of: flags.isDeveloperModeUnlocked) { _, unlocked in
            if !unlocked && selectedSection == .labs {
                selectedSection = .general
            }
        }
        .onChange(of: selectedSection) { _, _ in
            updateWindowTitle()
        }
        .onChange(of: l10n.resolvedLanguage) { _, _ in
            updateWindowTitle()
        }
        .onAppear {
            updateWindowTitle()
        }
    }

    // MARK: - Title helpers

    private var navigationTitle: String {
        guard let sec = selectedSection else {
            return l10n[.settingsTitle]
        }
        return l10n[sec.localizedTitle]
    }

    /// Cập nhật `NSWindow.title` — giao cho controller sở hữu window,
    private func updateWindowTitle() {
        let sectionTitle = navigationTitle
        let newTitle = l10n[.settingsWindowTitle(sectionTitle)]
        SettingsWindowController.shared.updateTitle(newTitle)
    }
}

// MARK: - Sidebar Row
private struct SidebarRow: View {
    let section: SettingsSidebarSection

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(section.iconBgColor)
                    .frame(width: 26, height: 26)

                Image(systemName: section.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }

            Text(section.localizedTitle)
                .font(.system(size: 13, weight: .light))
                .lineLimit(1)
        }
        .padding(.vertical, 1)
    }
}

// MARK: - Preview

#Preview("Cửa Sổ Cài Đặt (Light)") {
    LocalizedRootView {
        SettingsView()
    }
    .frame(width: 750, height: 520)
}

#Preview("Cửa Sổ Cài Đặt (Dark)") {
    LocalizedRootView {
        SettingsView()
    }
    .preferredColorScheme(.dark)
    .frame(width: 750, height: 520)
}
