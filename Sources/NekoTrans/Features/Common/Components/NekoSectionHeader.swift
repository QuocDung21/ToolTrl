import SwiftUI

/// Tiêu đề phân đoạn chuẩn macOS dùng chung cho NekoTrans.
public struct NekoSectionHeader<TrailingContent: View>: View {
    public let title: String
    public var icon: String? = nil
    public var iconColor: Color = .secondary
    public var hasDivider: Bool = false
    public let trailingContent: TrailingContent

    public init(
        title: String,
        icon: String? = nil,
        iconColor: Color = .secondary,
        hasDivider: Bool = false,
        @ViewBuilder trailingContent: () -> TrailingContent
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.hasDivider = hasDivider
        self.trailingContent = trailingContent()
    }

    public var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .center) {
                HStack(spacing: 4.5) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 9.5))
                            .foregroundColor(iconColor)
                    }
                    Text(title.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                trailingContent
            }

            if hasDivider {
                Divider()
                    .opacity(0.3)
            }
        }
    }
}

public extension NekoSectionHeader where TrailingContent == EmptyView {
    init(title: String, icon: String? = nil, iconColor: Color = .secondary, hasDivider: Bool = false) {
        self.init(title: title, icon: icon, iconColor: iconColor, hasDivider: hasDivider, trailingContent: { EmptyView() })
    }
}
