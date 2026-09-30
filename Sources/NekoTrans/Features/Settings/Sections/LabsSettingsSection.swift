import SwiftUI

public struct LabsSettingsSection: View {
    @ObservedObject var flags = FeatureFlagService.shared
    @State private var showLockConfirmation: Bool = false
    
    public init() {}
    
    public var body: some View {
        Form {
            // MARK: - Banner cảnh báo
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Image(systemName: "flask.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Phòng Thí Nghiệm Neko Labs")
                                .font(.system(size: 15, weight: .bold))
                            Text("Khu vực thử nghiệm các công nghệ mới chưa công bố")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text("⚠️ Các tính năng dưới đây đang trong giai đoạn phát triển (Beta). Một số tính năng có thể gây hao pin, mở cổng mạng nội bộ hoặc can thiệp sự kiện chuột/bàn phím toàn hệ thống. Hãy cân nhắc trước khi bật.")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                        .padding(10)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    
                    Toggle(isOn: $flags.isBetaLabsEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Kích hoạt Neko Labs (Master Switch)")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Bật công tắc này để mở khóa các tính năng thử nghiệm bên dưới.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .padding(.top, 4)
                }
                .padding(.vertical, 4)
            } header: {
                Text("TRẠNG THÁI THỬ NGHIỆM")
            }
            
            // MARK: - Danh sách các tính năng
            Section {
                Toggle(isOn: $flags.continuityStudio) {
                    FeatureRow(flag: .continuityStudio)
                }
                .disabled(!flags.isBetaLabsEnabled)
                
                Toggle(isOn: $flags.selectionBubble) {
                    FeatureRow(flag: .selectionBubble)
                }
                .disabled(!flags.isBetaLabsEnabled)
                
                Toggle(isOn: $flags.doubleCmdCTrigger) {
                    FeatureRow(flag: .doubleCmdCTrigger)
                }
                .disabled(!flags.isBetaLabsEnabled)
                
                Toggle(isOn: $flags.localLLM) {
                    FeatureRow(flag: .localLLM)
                }
                .disabled(!flags.isBetaLabsEnabled)
            } header: {
                Text("TÍNH NĂNG ĐANG THỬ NGHIỆM")
            } footer: {
                Text("Các tính năng bị tắt sẽ tự động giải phóng toàn bộ tài nguyên nền (dừng web server, hủy timer, ngắt theo dõi chuột).")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            // MARK: - Khóa lại chế độ Developer
            Section {
                Button(role: .destructive, action: {
                    showLockConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "lock.fill")
                        Text("Khóa & Ẩn Neko Labs khỏi Cài đặt")
                    }
                }
                .confirmationDialog(
                    "Khóa lại chế độ Nhà phát triển?",
                    isPresented: $showLockConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Khóa & Ẩn ngay", role: .destructive) {
                        flags.lockDeveloperMode()
                    }
                    Button("Hủy", role: .cancel) {}
                } message: {
                    Text("Sau khi khóa, tab Neko Labs sẽ biến mất khỏi thanh bên Cài đặt. Bạn có thể mở lại bằng cách chạm 7 lần vào phiên bản trong phần Giới thiệu.")
                }
            } header: {
                Text("BẢO MẬT & QUẢN TRỊ")
            }
        }
        .formStyle(.grouped)
    }
}

private struct FeatureRow: View {
    let flag: FeatureFlag
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: flag.icon)
                .font(.system(size: 15))
                .foregroundColor(.accentColor)
                .frame(width: 22, height: 22)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(flag.title)
                    .font(.system(size: 13, weight: .medium))
                Text(flag.subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }
}
