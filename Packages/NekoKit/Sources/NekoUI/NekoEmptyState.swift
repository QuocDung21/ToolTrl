import SwiftUI

/// Giao diện màn hình trống (Empty State) chuẩn macOS dùng chung cho NekoTrans.
public struct NekoEmptyState: View {
    public let icon: String
    public let title: String
    public var subtitle: String? = nil
    public var actionTitle: String? = nil
    public var actionIcon: String? = nil
    public var action: (() -> Void)? = nil

    public init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        actionTitle: String? = nil,
        actionIcon: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.actionIcon = actionIcon
        self.action = action
    }

    public var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.secondary.opacity(0.45))
                .padding(.bottom, 2)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary.opacity(0.85))

            if let subtitle = subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    HStack(spacing: 4) {
                        if let actionIcon = actionIcon {
                            Image(systemName: actionIcon)
                                .font(.system(size: 10))
                        }
                        Text(actionTitle)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundColor(.accentColor)
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }
}
