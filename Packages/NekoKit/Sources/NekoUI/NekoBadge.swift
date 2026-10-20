import SwiftUI

/// Các kiểu dáng màu ngữ nghĩa cho NekoBadge
public enum NekoBadgeVariant {
    case accent
    case purple
    case orange
    case green
    case secondary
    case custom(fg: Color, bg: Color, border: Color)

    public var foregroundColor: Color {
        switch self {
        case .accent: return .blue
        case .purple: return .purple
        case .orange: return .orange
        case .green: return .green
        case .secondary: return .secondary
        case .custom(let fg, _, _): return fg
        }
    }

    public var backgroundColor: Color {
        switch self {
        case .accent: return Color.blue.opacity(0.1)
        case .purple: return Color.purple.opacity(0.12)
        case .orange: return Color.orange.opacity(0.1)
        case .green: return Color.green.opacity(0.12)
        case .secondary: return Color.primary.opacity(0.05)
        case .custom(_, let bg, _): return bg
        }
    }

    public var borderColor: Color {
        switch self {
        case .accent: return Color.blue.opacity(0.2)
        case .purple: return Color.purple.opacity(0.25)
        case .orange: return Color.orange.opacity(0.2)
        case .green: return Color.green.opacity(0.25)
        case .secondary: return Color.primary.opacity(0.08)
        case .custom(_, _, let border): return border
        }
    }
}

/// Huy hiệu hiển thị thông tin phân loại, từ loại, cấp độ, nhãn dùng chung cho NekoTrans.
public struct NekoBadge: View {
    public let text: String
    public var systemImage: String? = nil
    public var variant: NekoBadgeVariant = .accent
    public var font: Font = .system(size: 10, weight: .semibold)
    public var isCapsule: Bool = false
    public var cornerRadius: CGFloat = 4
    public var horizontalPadding: CGFloat = 6
    public var verticalPadding: CGFloat = 2.5
    public var action: (() -> Void)? = nil

    public init(
        text: String,
        systemImage: String? = nil,
        variant: NekoBadgeVariant = .accent,
        font: Font = .system(size: 10, weight: .semibold),
        isCapsule: Bool = false,
        cornerRadius: CGFloat = 4,
        horizontalPadding: CGFloat = 6,
        verticalPadding: CGFloat = 2.5,
        action: (() -> Void)? = nil
    ) {
        self.text = text
        self.systemImage = systemImage
        self.variant = variant
        self.font = font
        self.isCapsule = isCapsule
        self.cornerRadius = cornerRadius
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.action = action
    }

    public var body: some View {
        if let action = action {
            Button(action: action) {
                badgeContent
            }
            .buttonStyle(.plain)
        } else {
            badgeContent
        }
    }

    private var badgeContent: some View {
        HStack(spacing: 3) {
            if let image = systemImage, !image.isEmpty {
                Image(systemName: image)
                    .font(.system(size: 8.5))
            }
            Text(text)
                .font(font)
                .lineLimit(1)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .foregroundColor(variant.foregroundColor)
        .background(
            Group {
                if isCapsule {
                    Capsule().fill(variant.backgroundColor)
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius).fill(variant.backgroundColor)
                }
            }
        )
        .overlay(
            Group {
                if isCapsule {
                    Capsule().stroke(variant.borderColor, lineWidth: 0.6)
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius).stroke(variant.borderColor, lineWidth: 0.6)
                }
            }
        )
    }
}
