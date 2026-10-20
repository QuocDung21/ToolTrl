import SwiftUI

/// Thanh tìm kiếm / Tra cứu nhanh chuẩn Spotlight/Raycast dùng chung cho NekoTrans.
public struct NekoSearchBar: View {
    @Binding public var text: String
    public var placeholder: String = "Tìm kiếm..."
    public var height: CGFloat = 28
    public var cornerRadius: CGFloat = 6
    public var shortcutHint: String? = nil
    public var onSubmit: (() -> Void)? = nil

    @FocusState private var isFocused: Bool

    public init(
        text: Binding<String>,
        placeholder: String = "Tìm kiếm...",
        height: CGFloat = 28,
        cornerRadius: CGFloat = 6,
        shortcutHint: String? = nil,
        onSubmit: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.height = height
        self.cornerRadius = cornerRadius
        self.shortcutHint = shortcutHint
        self.onSubmit = onSubmit
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.8))

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 11.5))
                .focused($isFocused)
                .onSubmit {
                    onSubmit?()
                }

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
            }

            if let hint = shortcutHint, text.isEmpty {
                Text(hint)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(3)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: height)
        .background(Color.primary.opacity(0.035))
        .cornerRadius(cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    isFocused ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.08),
                    lineWidth: 0.8
                )
        )
    }
}
