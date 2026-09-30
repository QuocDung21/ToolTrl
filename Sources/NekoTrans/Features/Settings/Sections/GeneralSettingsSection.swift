import SwiftUI

public struct GeneralSettingsSection: View {
    @ObservedObject var settings = AppSettings.shared
    
    public init() {}
    
    public var body: some View {
        Form {
            Section(header: Text("KHỞI ĐỘNG & HỆ THỐNG")) {
                Toggle("Tự động khởi chạy cùng macOS khi đăng nhập", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                ))
                
                Toggle("Hiển thị cửa sổ chính khi khởi chạy", isOn: Binding(
                    get: { settings.showMainWindowOnLaunch },
                    set: { settings.setShowMainWindowOnLaunch($0) 
                    }
                ))
                
                
                
                Toggle("Show icon in dock (Hiển thị trên thanh Dock)", isOn: $settings.showInDock)
                
                Toggle("Tự động ẩn cửa sổ dịch khi bấm chuột ra ngoài", isOn: $settings.clickOutsideDismiss)
                
                Picker("Khi thoát ứng dụng (⌘Q):", selection: $settings.quitActionPreference) {
                    ForEach(QuitActionPreference.allCases) { action in
                        Text(action.title).tag(action)
                    }
                }
            }
            
            Section(header: Text("DỊCH THUẬT & ĐỘNG CƠ")) {
                Picker("Động cơ dịch mặc định:", selection: $settings.translationEngine) {
                    ForEach(TranslationEngine.allCases) { eng in
                        HStack {
                            Image(systemName: eng.icon)
                            Text(eng.rawValue)
                        }.tag(eng)
                    }
                }
                
                Picker("Văn phong dịch thuật:", selection: $settings.translationTone) {
                    ForEach(TranslationTone.allCases) { tone in
                        HStack {
                            Image(systemName: tone.icon)
                            Text(tone.rawValue)
                        }.tag(tone)
                    }
                }
                
                Picker("Ngôn ngữ đích mặc định:", selection: $settings.targetLanguage) {
                    ForEach(TargetLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang.rawValue)
                    }
                }
                
                Picker("Chế độ hiển thị bản dịch:", selection: $settings.translationDisplayMode) {
                    ForEach(TranslationDisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
            }
            
            Section(header: Text("TƯƠNG TÁC & KÍCH HOẠT NHANH")) {
                Toggle("Tự động dịch trực tiếp khi bôi đen từ (khi ghim cửa sổ)", isOn: $settings.autoTranslateOnSelectionWhenPinned)
                
                if FeatureFlagService.shared.isFeatureEnabled(.doubleCmdCTrigger) {
                    Toggle("Dịch nhanh khi nhấn phím Sao chép hai lần (Double ⌘+C)", isOn: $settings.enableDoubleCmdCTrigger)
                }
                if FeatureFlagService.shared.isFeatureEnabled(.selectionBubble) {
                    Toggle("Hiển thị bong bóng mini (Popover) bên cạnh con trỏ khi bôi đen", isOn: $settings.enableSelectionBubble)
                }
            }
            
            Section(header: Text("BỘ NHỚ TẠM (CACHE)")) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Xóa bộ nhớ đệm dịch thuật")
                            .font(.system(size: 13, weight: .medium))
                        Text("Làm sạch các bản dịch đã lưu trong RAM và Disk để giải phóng dung lượng.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Xóa Cache") {
                        Task {
                            await TranslationCache.shared.clearAll()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .formStyle(.grouped)
    }
}


#Preview {
    GeneralSettingsSection()
}
