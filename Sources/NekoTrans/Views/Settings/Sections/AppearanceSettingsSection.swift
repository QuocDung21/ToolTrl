import SwiftUI

public struct AppearanceSettingsSection: View {
    @Bindable var settings = AppSettings.shared
    @Bindable var iconService = AppIconService.shared
    
    public init() {}
    
    public var body: some View {
        Form {
            themeSection
            fontSizeSection
            iconPickerSection
        }
        .formStyle(.grouped)
    }

    private var themeSection: some View {
        Section {
            Picker("Chế độ hiển thị:", selection: $settings.appAppearanceMode) {
                ForEach(AppAppearanceMode.allCases) { mode in
                    Label {
                        Text(mode.localizedTitle)
                    } icon: {
                        Image(systemName: mode.sfSymbol)
                    }
                    .tag(mode)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                Text("Màu nhấn chủ đạo:")
                    .font(.system(size: 12, weight: .medium))

                HStack(spacing: 10) {
                    ForEach(AppAccentTheme.allCases) { accentTheme in
                        let isSelected = settings.appAccentTheme == accentTheme
                        Button(action: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                settings.appAccentTheme = accentTheme
                            }
                        }) {
                            VStack(spacing: 5) {
                                ZStack {
                                    Circle()
                                        .fill(accentTheme.color)
                                        .frame(width: 24, height: 24)
                                        .shadow(color: accentTheme.color.opacity(0.35), radius: isSelected ? 4 : 1, y: 1)

                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(3)
                                .overlay(
                                    Circle()
                                        .stroke(isSelected ? accentTheme.color : Color.clear, lineWidth: 1.5)
                                )

                                Text(accentTheme.localizedTitle)
                                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                                    .foregroundColor(isSelected ? .primary : .secondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 2)
            }
            .padding(.vertical, 4)

            Picker("Chất liệu kính cửa sổ HUD:", selection: $settings.hudMaterialStyle) {
                ForEach(HUDMaterialStyle.allCases) { style in
                    Text(style.localizedTitle).tag(style)
                }
            }
        } header: {
            Text("CHỦ ĐỀ & MÀU SẮC GIAO DIỆN")
        }
    }
    
    private var fontSizeSection: some View {
        Section(header: Text("KÍCH THƯỚC CHỮ ĐỒNG BỘ TOÀN ỨNG DỤNG")) {
            Picker("Cỡ chữ :", selection: $settings.appFontSize) {
                ForEach(AppFontSize.allCases) { size in
                    Text(size.localizedTitle).tag(size)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 6) {
                Text("Xem trước giao diện với cỡ chữ hiện tại:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 8) {
                        Text("Serendipity")
                            .font(.appTitleLarge)
                            .foregroundColor(.primary)
                        
                        Text(verbatim: "/ˌser.ənˈdɪp.ə.ti/")
                            .font(.appPhonetic)
                            .foregroundColor(AppColors.phonetic)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(AppColors.phoneticSubtle)
                            .cornerRadius(4)
                    }
                    
                    Text("Sự may mắn bất ngờ, tình cờ phát hiện điều thú vị")
                        .font(.appHeadlineBold)
                        .foregroundColor(settings.appAccentTheme.color)
                    
                    Text("• Finding this library was pure serendipity.")
                        .font(.appExample)
                        .foregroundColor(.secondary)
                        .italic()
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.cardBackground)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(settings.appAccentTheme.color.opacity(0.28), lineWidth: 1)
                )
            }
            .padding(.vertical, 4)
        }
    }
    
    private var iconPickerSection: some View {
        Section {
            Toggle("Show icon in dock (Hiển thị biểu tượng trên thanh Dock)", isOn: $settings.showInDock)
            
            Picker("Bộ Icon:", selection: $iconService.selectedType) {
                ForEach(AppIconType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            
            if iconService.selectedType == .custom {
                customIconRow
            }
        } header: {
            Text("BIỂU TƯỢNG MENU BAR & ỨNG DỤNG")
        } footer: {
            Text("Tùy chỉnh hiển thị biểu tượng NekoTrans trên thanh Dock và thanh Menu Bar.")
        }
    }
    
    private var customIconRow: some View {
        HStack {
            iconService.currentImage
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .cornerRadius(4)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(iconService.customImageName ?? "Ảnh tự chọn")
                    .font(.system(size: 12, weight: .medium))
                Text("Nhấn vào để thay đổi logo biểu tượng cá nhân.")
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Chọn ảnh...") {
                iconService.importCustomImage()
            }
            .buttonStyle(.bordered)
            
            Button("Khôi phục") {
                iconService.resetToDefault()
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    AppearanceSettingsSection()
}
