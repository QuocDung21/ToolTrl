import SwiftUI
import AppKit

/// Nút sao chép 1-chạm thông minh cho NekoTrans.
/// Tự động sao chép văn bản vào bộ nhớ tạm (NSPasteboard),
/// hiển thị dấu kiểm tra màu xanh lá khi đã chép và tự động hoàn nguyên sau 1.2s.
public struct NekoCopyButton: View {
    public let textToCopy: String
    public var label: String? = nil
    public var copiedLabel: String? = nil
    public var iconOnly: Bool = false
    public var showIcon: Bool = false
    public var font: Font = .system(size: 9.5, weight: .medium)
    public var iconSize: CGFloat = 9
    public var cornerRadius: CGFloat = 4.5
    public var horizontalPadding: CGFloat = 6
    public var verticalPadding: CGFloat = 2.5
    public var onCopied: (() -> Void)? = nil

    @State private var isCopied: Bool = false

    public init(
        textToCopy: String,
        label: String? = "Sao chép",
        copiedLabel: String? = "Đã chép",
        iconOnly: Bool = false,
        showIcon: Bool = false,
        font: Font = .system(size: 9.5, weight: .medium),
        iconSize: CGFloat = 9,
        cornerRadius: CGFloat = 4.5,
        horizontalPadding: CGFloat = 6,
        verticalPadding: CGFloat = 2.5,
        onCopied: (() -> Void)? = nil
    ) {
        self.textToCopy = textToCopy
        self.label = label
        self.copiedLabel = copiedLabel
        self.iconOnly = iconOnly
        self.showIcon = showIcon
        self.font = font
        self.iconSize = iconSize
        self.cornerRadius = cornerRadius
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.onCopied = onCopied
    }

    public var body: some View {
        Button(action: copyToPasteboard) {
            HStack(spacing: 3.5) {
                if isCopied {
                    Image(systemName: "checkmark")
                        .font(.system(size: iconSize))
                        .foregroundColor(.green)
                } else if iconOnly || showIcon {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: iconSize))
                        .foregroundColor(.secondary)
                }

                if !iconOnly, let text = (isCopied ? (copiedLabel ?? "Đã chép") : label) {
                    Text(text)
                        .font(font)
                        .foregroundColor(isCopied ? .green : .secondary)
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                isCopied
                    ? Color.green.opacity(0.12)
                    : Color.primary.opacity(0.04)
            )
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        isCopied ? Color.green.opacity(0.25) : Color.primary.opacity(0.06),
                        lineWidth: 0.6
                    )
            )
        }
        .buttonStyle(.plain)
        .help(isCopied ? "Đã sao chép vào bộ nhớ tạm" : "Sao chép vào bộ nhớ tạm")
        .sensoryFeedback(.success, trigger: isCopied)
    }

    private func copyToPasteboard() {
        guard !textToCopy.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(textToCopy, forType: .string)

        withAnimation(.easeInOut(duration: 0.15)) {
            isCopied = true
        }
        onCopied?()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.15)) {
                isCopied = false
            }
        }
    }
}
