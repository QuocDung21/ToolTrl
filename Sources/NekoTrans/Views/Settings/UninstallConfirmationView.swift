import SwiftUI

public struct UninstallConfirmationView: View {
    @ObservedObject private var uninstaller = AppUninstaller.shared
    @EnvironmentObject private var l10n: Localization
    @State private var deleteJournal: Bool = true

    public init() {}

    private var isEn: Bool {
        l10n.resolvedLanguage == .english
    }

    public var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                .padding(.top, 8)

            VStack(spacing: 6) {
                Text(isEn ? "Uninstall NekoTrans?" : "Gỡ cài đặt NekoTrans?")
                    .font(.system(size: 16, weight: .bold))

                Text(isEn
                    ? "NekoTrans and all its associated data (vocabulary, settings, API keys in Keychain, and caches) will be permanently deleted from this Mac."
                    : "Ứng dụng NekoTrans cùng toàn bộ dữ liệu (sổ từ vựng, cấu hình, API key trong Keychain và bộ nhớ đệm) sẽ bị xóa vĩnh viễn khỏi máy Mac này."
                )
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
            }

            Toggle(isOn: $deleteJournal) {
                Text(isEn
                    ? "Delete vocabulary journal (words.jsonl in Documents)"
                    : "Xóa cả file nhật ký từ vựng (words.jsonl trong Documents)"
                )
                .font(.system(size: 12))
            }
            .toggleStyle(.checkbox)
            .padding(.top, 4)

            Spacer(minLength: 0)

            HStack {
                if uninstaller.isUninstalling {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text(uninstaller.currentOperation)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button(isEn ? "Cancel" : "Hủy") {
                    UninstallWindowController.shared.close()
                }
                .keyboardShortcut(.cancelAction)
                .disabled(uninstaller.isUninstalling)

                Button(role: .destructive) {
                    Task {
                        await uninstaller.performCleanUninstall(deleteJournal: deleteJournal)
                    }
                } label: {
                    Text(isEn ? "Uninstall" : "Gỡ cài đặt")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(uninstaller.isUninstalling)
            }
            .padding(.top, 6)
        }
        .padding(24)
        .frame(width: 440, height: 260)
    }
}

#Preview {
    UninstallConfirmationView()
        
}
