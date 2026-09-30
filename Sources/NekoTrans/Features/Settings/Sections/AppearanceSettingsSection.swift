import SwiftUI

public struct AppearanceSettingsSection: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var iconService = AppIconService.shared
    
    public init() {}
    
    public var body: some View {
        Form {
            fontSizeSection
            iconPickerSection
        }
        .formStyle(.grouped)
    }
    
    private var fontSizeSection: some View {
        Section(header: Text("KÍCH THƯỚC CHỮ ĐỒNG BỘ TOÀN ỨNG DỤNG")) {
            Picker("Cỡ chữ hiển thị:", selection: $settings.appFontSize) {
                ForEach(AppFontSize.allCases) { size in
                    Text(size.rawValue).tag(size)
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
                        
                        Text("/ˌser.ənˈdɪp.ə.ti/")
                            .font(.appPhonetic)
                            .foregroundColor(AppColors.phonetic)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(AppColors.phoneticSubtle)
                            .cornerRadius(4)
                    }
                    
                    Text("Sự may mắn bất ngờ, tình cờ phát hiện điều thú vị")
                        .font(.appHeadlineBold)
                        .foregroundColor(AppColors.accent)
                    
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
                        .stroke(AppColors.cardBorder, lineWidth: 0.8)
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
