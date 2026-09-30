import SwiftUI

public struct AboutSettingsSection: View {
    @ObservedObject var iconService = AppIconService.shared
    @ObservedObject var flags = FeatureFlagService.shared
    @State private var tapCount: Int = 0
    @State private var showUnlockedAlert: Bool = false
    
    public init() {}
    
    public var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    iconService.currentImage
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                        .foregroundColor(iconService.selectedType.accentColor)
                    
                    VStack(spacing: 4) {
                        Text("NekoTrans")
                            .font(.system(size: 20, weight: .bold))
                        
                        Text("Phiên bản 1.0.0 (Native macOS)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                tapCount += 1
                                if tapCount >= 7 {
                                    tapCount = 0
                                    flags.unlockDeveloperMode()
                                    showUnlockedAlert = true
                                }
                            }
                        
                        if flags.isDeveloperModeUnlocked {
                            HStack(spacing: 4) {
                                Image(systemName: "flask.fill")
                                    .font(.system(size: 10))
                                Text("Đã mở khóa Neko Labs")
                                    .font(.system(size: 10.5, weight: .semibold))
                            }
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.12))
                            .cornerRadius(6)
                            .padding(.top, 2)
                        }
                    }
                    
                    Text("Ứng dụng tra từ điển, dịch thuật AI đa tầng, bóc tách ngữ pháp và ôn tập thẻ ghi nhớ tối ưu cho hệ điều hành macOS.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            
            Section(header: Text("THÔNG TIN MÃ NGUỒN & TÁC GIẢ")) {
                LabeledContent("Tác giả", value: "Dũng Nguyễn Quốc (QuocDung21)")
                LabeledContent("Bản quyền", value: "Giấy phép mã nguồn mở MIT")
                
                Link(destination: URL(string: "https://github.com/QuocDung21/ToolTrl.git")!) {
                    HStack {
                        Text("Kho mã nguồn GitHub")
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .alert("🧪 Neko Labs Đã Mở Khóa!", isPresented: $showUnlockedAlert) {
            Button("Đã hiểu", role: .cancel) {}
        } message: {
            Text("Bạn vừa kích hoạt Chế độ Nhà phát triển. Tab 'Neko Labs' đã xuất hiện trên thanh bên Cài đặt để bạn thử nghiệm các công nghệ mới.")
        }
    }
}
