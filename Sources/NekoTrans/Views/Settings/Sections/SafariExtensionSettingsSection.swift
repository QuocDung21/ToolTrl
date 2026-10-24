import SwiftUI
import SafariServices
import NekoCore

public struct SafariExtensionSettingsSection: View {
    @State private var isCheckingStatus = false
    @State private var extensionStatusMessage: String?

    public init() {}

    public var body: some View {
        Form {
            heroSection
            activationStepsSection
            featuresSection
            troubleshootingSection
        }
        .formStyle(.grouped)
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    ZStack(alignment: .bottomTrailing) {
                        AppIconService.shared.currentImage
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)

                        ZStack {
                            Circle()
                                .fill(Color(nsColor: .windowBackgroundColor))
                                .frame(width: 22, height: 22)
                            Image(systemName: "safari.fill")
                                .font(.system(size: 15))
                                .foregroundColor(.blue)
                        }
                        .offset(x: 4, y: 4)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text("NekoTrans cho Safari")
                                .font(.system(size: 16, weight: .bold))

                            Text("BẢN CHÍNH THỨC")
                                .font(.system(size: 9.5, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .foregroundColor(.green)
                                .clipShape(Capsule())
                        }

                        Text("Dịch song ngữ trang web, tra từ vựng và bôi đen dịch mượt mà trực tiếp trên Safari macOS.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                HStack(spacing: 12) {
                    Button(action: openSafariExtensionPreferences) {
                        Label("Mở Cài đặt Tiện ích Safari...", systemImage: "arrow.up.forward.app")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)

                    Button(action: openTestWebPage) {
                        Label("Mở trang web thử nghiệm", systemImage: "globe")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }

                if let message = extensionStatusMessage {
                    Text(message)
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("TIỆN ÍCH MỞ RỘNG (SAFARI WEB EXTENSION)")
        }
    }

    // MARK: - Activation Steps Section

    private var activationStepsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                stepRow(
                    stepNumber: 1,
                    title: "Kích hoạt tiện ích trong Cài đặt Safari",
                    detail: "Nhấn nút 'Mở Cài đặt Tiện ích Safari' ở trên (hoặc mở Safari > Cài đặt (⌘,) > chọn thẻ Tiện ích)."
                )

                stepRow(
                    stepNumber: 2,
                    title: "Bật NekoTrans",
                    detail: "Tìm 'NekoTrans - Trình dịch Web Safari' trong danh sách bên trái và đánh dấu tích chọn."
                )

                stepRow(
                    stepNumber: 3,
                    title: "Cấp quyền truy cập trang web",
                    detail: "Tại mục Quyền (Permissions), bấm 'Luôn cho phép trên mọi trang web' (Always Allow on Every Website) để tiện ích tự động hỗ trợ dịch mà không cần hỏi lại."
                )
            }
            .padding(.vertical, 2)
        } header: {
            Text("HƯỚNG DẪN 3 BƯỚC KÍCH HOẠT")
        }
    }

    private func stepRow(stepNumber: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 24, height: 24)

                Text("\(stepNumber)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        Section {
            featureRow(
                icon: "character.book.closed.fill",
                iconColor: .purple,
                title: "Dịch song ngữ trang web (Bilingual Translation)",
                description: "Giữ nguyên bài viết gốc và hiển thị bản dịch tiếng Việt ngay dưới từng đoạn văn bản, giúp bạn đọc báo tiếng Anh/Nhật/Trung cực kỳ tiện lợi."
            )

            featureRow(
                icon: "hand.point.up.left.fill",
                iconColor: .blue,
                title: "Nút dịch nổi 🐱 khi bôi đen văn bản",
                description: "Chỉ cần chọn bất kỳ từ hoặc câu trên trang web, nút mèo sẽ xuất hiện để dịch nhanh, phát âm chuẩn và hiển thị phiên âm IPA."
            )

            featureRow(
                icon: "bookmark.fill",
                iconColor: .orange,
                title: "Lưu từ vựng trực tiếp vào NekoTrans",
                description: "Bấm biểu tượng 🔖 trên bảng dịch nổi để lưu từ mới kèm nghĩa vào Sổ tay từ vựng của ứng dụng NekoTrans."
            )

            featureRow(
                icon: "command",
                iconColor: .green,
                title: "Phím tắt Option + T",
                description: "Nhấn Option + T trên Safari để bật/tắt dịch song ngữ toàn bộ trang web ngay tức thì."
            )
        } header: {
            Text("CÁC TÍNH NĂNG NỔI BẬT TRÊN SAFARI")
        }
    }

    private func featureRow(icon: String, iconColor: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                Text(description)
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Troubleshooting Section

    private var troubleshootingSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Mẹo dành cho bản thử nghiệm phát triển (Developer Build):")
                    .font(.system(size: 12, weight: .medium))

                Text("Nếu tiện ích chưa xuất hiện trong danh sách Tiện ích của Safari:")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("1. Mở Safari > Cài đặt (⌘,) > thẻ Nâng cao (Advanced) > tích chọn 'Hiển thị tính năng cho nhà phát triển web' (Show features for web developers).")
                    Text("2. Trên thanh menu Safari, bấm vào mục 'Phát triển' (Develop) > tích chọn 'Cho phép tiện ích mở rộng chưa ký' (Allow Unsigned Extensions).")
                    Text("3. Khởi động lại Safari và quay lại thẻ Tiện ích để kích hoạt.")
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.leading, 8)
            }
            .padding(.vertical, 2)
        } header: {
            Text("HỖ TRỢ & KHẮC PHỤC SỰ CỐ")
        }
    }

    // MARK: - Actions

    private func openSafariExtensionPreferences() {
        SFSafariApplication.showPreferencesForExtension(withIdentifier: "com.nekotrans.mac.SafariExtension") { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.extensionStatusMessage = "Vui lòng mở Safari > Cài đặt > Tiện ích để bật NekoTrans (\(error.localizedDescription))."
                } else {
                    self.extensionStatusMessage = "Đã mở Cài đặt Tiện ích Safari thành công!"
                }
            }
        }
    }

    private func openTestWebPage() {
        if let url = URL(string: "https://en.wikipedia.org/wiki/Cat") {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    SafariExtensionSettingsSection()
        .frame(width: 600, height: 650)
}
