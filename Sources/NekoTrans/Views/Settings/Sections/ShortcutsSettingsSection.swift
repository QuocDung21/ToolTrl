import SwiftUI
import KeyboardShortcuts

public struct ShortcutsSettingsSection: View {
    @ObservedObject var hotKeyManager = HotKeyManager.shared

    public init() {}

    public var body: some View {
        Form {
            Section {
                shortcutRow(
                    title: "Dịch văn bản bôi đen",
                    subtitle: "Mở popup dịch ngay tại vị trí con trỏ chuột.",
                    name: .translate
                )

                shortcutRow(
                    title: "Quét chữ trên màn hình (OCR)",
                    subtitle: "Khoanh vùng ảnh màn hình để bóc tách chữ & dịch tức thì.",
                    name: .ocr
                )

                shortcutRow(
                    title: "Chụp chữ im lặng (Silent OCR)",
                    subtitle: "Khoanh vùng chữ trên màn hình và tự động sao chép vào bộ nhớ đệm.",
                    name: .silentOCR
                )

                shortcutRow(
                    title: "Dịch & Thay thế tại chỗ (In-Place)",
                    subtitle: "Dịch văn bản bôi đen và dán đè thay thế trực tiếp vào vị trí con trỏ.",
                    name: .translateAndReplace
                )

                shortcutRow(
                    title: "Sửa lỗi & Trau chuốt tại chỗ (AI Polish)",
                    subtitle: "Dùng AI sửa lỗi ngữ pháp, chính tả và trau chuốt văn bản trực tiếp.",
                    name: .polishAndReplace
                )

                shortcutRow(
                    title: "Mở nhanh Trợ lý AI",
                    subtitle: "Mở cửa sổ trò chuyện với ChatGPT, Gemini, Claude.",
                    name: .ai
                )

                shortcutRow(
                    title: "Mở Sổ tay từ vựng & Flashcards",
                    subtitle: "Xem lại từ vựng đã lưu và ôn tập thẻ ghi nhớ.",
                    name: .notebook
                )
            } header: {
                Text("PHÍM TẮT TOÀN CẦU (GLOBAL SHORTCUTS)")
            } footer: {
                Text("Bấm vào ô phím tắt để ghi nhận tổ hợp phím mới trên bàn phím của bạn.")
            }

            Section {
                Button("Khôi phục toàn bộ phím tắt mặc định") {
                    hotKeyManager.resetDefaults()
                }
                .foregroundColor(.orange)
            }
        }
        .formStyle(.grouped)
    }

    private func shortcutRow(
        title: String,
        subtitle: String,
        name: KeyboardShortcuts.Name
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            ShortcutRecorderView(name: name)
        }
    }
}
