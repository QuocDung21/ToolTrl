import SwiftUI

public enum SettingsSidebarSection: String, CaseIterable, Identifiable {
    case general = "Chung"
    case advanced = "Tính năng nâng cao"
    case shortcuts = "Phím tắt"
    case speech = "Giọng đọc"
    case appearance = "Giao diện & Cỡ chữ"
    case prompts = "Mẫu câu hỏi AI"
    case github = "Đồng bộ GitHub"
    case labs = "Neko Labs (Thử nghiệm)"
    case about = "Giới thiệu"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .advanced: return "sparkles.rectangle.stack.fill"
        case .shortcuts: return "command"
        case .speech: return "speaker.wave.2.fill"
        case .appearance: return "textformat.size"
        case .prompts: return "sparkles"
        case .github: return "arrow.triangle.2.circlepath.icloud.fill"
        case .labs: return "flask.fill"
        case .about: return "info.circle.fill"
        }
    }
    
    public var iconBgColor: Color {
        switch self {
        case .general: return .gray
        case .advanced: return .indigo
        case .shortcuts: return .orange
        case .speech: return .blue
        case .appearance: return .purple
        case .prompts: return .teal
        case .github: return .indigo
        case .labs: return .orange
        case .about: return .gray
        }
    }
}

public struct SettingsView: View {
    @ObservedObject var flags = FeatureFlagService.shared
    @State private var selectedSection: SettingsSidebarSection? = .general
    @State private var showPromptManagerSheet: Bool = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar Navigation (Standard macOS System Settings)
            List(selection: $selectedSection) {
                ForEach(SettingsSidebarSection.allCases.filter { $0 != .labs || flags.isDeveloperModeUnlocked }) { sec in
                    NavigationLink(value: sec) {
                        HStack(spacing: 9) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(sec.iconBgColor)
                                    .frame(width: 22, height: 22)
                                
                                Image(systemName: sec.icon)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            Text(sec.rawValue)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                        }
                        .padding(.vertical, 1)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 220, ideal: 235, max: 280)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            Group {
                switch selectedSection {
                case .general:
                    GeneralSettingsSection()
                case .advanced:
                    AdvancedFeaturesSettingsSection()
                case .shortcuts:
                    ShortcutsSettingsSection()
                case .speech:
                    SpeechSettingsSection()
                case .appearance:
                    AppearanceSettingsSection()
                case .prompts:
                    PromptsSettingsSection(showPromptManagerSheet: $showPromptManagerSheet)
                case .github:
                    GitHubSyncSettingsSection()
                case .labs:
                    LabsSettingsSection()
                case .about:
                    AboutSettingsSection()
                case .none:
                    GeneralSettingsSection()
                }
            }
            .navigationTitle(selectedSection?.rawValue ?? "Cài đặt")
            .toolbar(removing: .sidebarToggle)
            .onChange(of: flags.isDeveloperModeUnlocked) { _, unlocked in
                if !unlocked && selectedSection == .labs {
                    selectedSection = .general
                }
            }
            .onChange(of: selectedSection) { _, newSec in
                if let title = newSec?.rawValue {
                    for window in NSApp.windows where window.isVisible && window.title.contains("Cài đặt") {
                        window.title = "Cài đặt - \(title)"
                    }
                }
            }
        }
        .toolbar(removing: .sidebarToggle)
        .frame(minWidth: 720, minHeight: 490)
        .sheet(isPresented: $showPromptManagerSheet) {
            QuickPromptManagerSheet()
        }
    }
}

#Preview("Cửa Sổ Cài Đặt (Light)") {
    SettingsView()
        .frame(width: 750, height: 520)
}

#Preview("Cửa Sổ Cài Đặt (Dark)") {
    SettingsView()
        .preferredColorScheme(.dark)
        .frame(width: 750, height: 520)
}
