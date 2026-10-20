import SwiftUI

/// Nút phát âm tích hợp sóng âm Equalizer động dùng chung cho NekoTrans.
public struct NekoAudioButton: View {
    public let label: String
    public var flag: String? = nil
    public let isPlaying: Bool
    public var activeColor: Color = .blue
    public var inactiveColor: Color = .secondary
    public var height: CGFloat = 20
    public var cornerRadius: CGFloat = 4.5
    public let action: () -> Void

    public init(
        label: String,
        flag: String? = nil,
        isPlaying: Bool,
        activeColor: Color = .blue,
        inactiveColor: Color = .secondary,
        height: CGFloat = 20,
        cornerRadius: CGFloat = 4.5,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.flag = flag
        self.isPlaying = isPlaying
        self.activeColor = activeColor
        self.inactiveColor = inactiveColor
        self.height = height
        self.cornerRadius = cornerRadius
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let flag = flag, !flag.isEmpty {
                    Text(flag)
                        .font(.system(size: 10.5))
                }

                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))

                if isPlaying {
                    EqualizerWaveView(
                        isActive: true,
                        barColor: activeColor,
                        barCount: 3,
                        height: 9
                    )
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                isPlaying
                    ? activeColor.opacity(0.18)
                    : activeColor.opacity(0.08)
            )
            .foregroundColor(isPlaying ? activeColor : activeColor.opacity(0.9))
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        isPlaying ? activeColor.opacity(0.3) : activeColor.opacity(0.1),
                        lineWidth: 0.6
                    )
            )
        }
        .buttonStyle(.plain)
        .frame(height: height)
    }
}
