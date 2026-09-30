import SwiftUI

public struct ShortcutsSettingsSection: View {
    @ObservedObject var hotKeyManager = HotKeyManager.shared
    
    public init() {}
    
    public var body: some View {
        Form {
            Section {
                shortcutRow(
                    title: "Dịch văn bản bôi đen",
                    subtitle: "Mở popup dịch ngay tại vị trí con trỏ chuột.",
                    shortcut: $hotKeyManager.translateShortcut,
                    defaultShortcut: KeyShortcut.defaultTranslate
                )
                
                shortcutRow(
                    title: "Quét chữ trên màn hình (OCR)",
                    subtitle: "Khoanh vùng ảnh màn hình để bóc tách chữ & dịch tức thì.",
                    shortcut: $hotKeyManager.ocrShortcut,
                    defaultShortcut: KeyShortcut.defaultOCR
                )
                
                shortcutRow(
                    title: "Mở nhanh Trợ lý AI",
                    subtitle: "Mở cửa sổ trò chuyện với ChatGPT, Gemini, Claude.",
                    shortcut: $hotKeyManager.aiShortcut,
                    defaultShortcut: KeyShortcut.defaultAI
                )
                
                shortcutRow(
                    title: "Mở Sổ tay từ vựng & Flashcards",
                    subtitle: "Xem lại từ vựng đã lưu và ôn tập thẻ ghi nhớ.",
                    shortcut: $hotKeyManager.notebookShortcut,
                    defaultShortcut: KeyShortcut.defaultNotebook
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
        shortcut: Binding<KeyShortcut>,
        defaultShortcut: KeyShortcut
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
            ShortcutRecorderView(
                shortcut: shortcut,
                defaultShortcut: defaultShortcut
            )
        }
    }
}
