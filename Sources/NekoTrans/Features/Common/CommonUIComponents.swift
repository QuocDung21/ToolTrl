import SwiftUI
import AppKit

// MARK: - AppKit Visual Effect Background
public struct VisualEffectBackground: NSViewRepresentable {
    public let material: NSVisualEffectView.Material
    public let blendingMode: NSVisualEffectView.BlendingMode
    public let cornerRadius: CGFloat

    public init(
        material: NSVisualEffectView.Material = .popover,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        cornerRadius: CGFloat = 0
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.cornerRadius = cornerRadius
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        if cornerRadius > 0 {
            view.layer?.cornerRadius = cornerRadius
            view.layer?.masksToBounds = true
        }
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        if cornerRadius > 0 {
            nsView.wantsLayer = true
            nsView.layer?.cornerRadius = cornerRadius
            nsView.layer?.masksToBounds = true
        }
    }
}

// MARK: - Live Spoken Text View with Real-time Word Highlight
public struct LiveSpokenTextView: View {
    public let text: String
    public let speakerID: String
    @ObservedObject var speechService = SpeechService.shared
    public var font: Font = .system(size: 12)
    public var defaultColor: Color = .primary
    public var lineSpacing: CGFloat = 3.5

    public init(
        text: String,
        speakerID: String,
        font: Font = .system(size: 12),
        defaultColor: Color = .primary,
        lineSpacing: CGFloat = 3.5
    ) {
        self.text = text
        self.speakerID = speakerID
        self.font = font
        self.defaultColor = defaultColor
        self.lineSpacing = lineSpacing
    }

    public var body: some View {
        Text(attributedText)
            .font(font)
            .lineSpacing(lineSpacing)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .animation(.easeInOut(duration: 0.08), value: speechService.spokenRange)
    }

    private var attributedText: AttributedString {
        var attr = AttributedString(text)
        attr.foregroundColor = defaultColor

        if speechService.isSpeaking && speechService.currentSpeakerID == speakerID,
           let nsRange = speechService.spokenRange,
           let swiftRange = Range(nsRange, in: text) {

            if let lower = AttributedString.Index(swiftRange.lowerBound, within: attr),
               let upper = AttributedString.Index(swiftRange.upperBound, within: attr) {
                attr[lower..<upper].backgroundColor = Color.blue.opacity(0.3)
                attr[lower..<upper].foregroundColor = Color.blue
                attr[lower..<upper].inlinePresentationIntent = .stronglyEmphasized
            }
        }
        return attr
    }
}

// MARK: - Wrapping HStack for Tags
public struct WrappingHStack<Model: Hashable, V: View>: View {
    public let models: [Model]
    public let viewGenerator: (Model) -> V

    @State private var totalHeight: CGFloat = .zero

    public init(models: [Model], @ViewBuilder viewGenerator: @escaping (Model) -> V) {
        self.models = models
        self.viewGenerator = viewGenerator
    }

    public var body: some View {
        VStack {
            GeometryReader { geometry in
                self.generateContent(in: geometry)
            }
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in g: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach(self.models, id: \.self) { model in
                self.viewGenerator(model)
                    .padding([.horizontal, .vertical], 2)
                    .alignmentGuide(.leading, computeValue: { d in
                        if (abs(width - d.width) > g.size.width) {
                            width = 0
                            height -= d.height
                        }
                        let result = width
                        if model == self.models.last! {
                            width = 0
                        } else {
                            width -= d.width
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { _ in
                        let result = height
                        if model == self.models.last! {
                            height = 0
                        }
                        return result
                    })
            }
        }
        .background(viewHeightReader($totalHeight))
    }

    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        return GeometryReader { geometry -> Color in
            let rect = geometry.frame(in: .local)
            DispatchQueue.main.async {
                binding.wrappedValue = rect.size.height
            }
            return .clear
        }
    }
}

// MARK: - Modern macOS 15 Smooth Scroll Transition Modifier
public extension View {
    func smoothScrollTransition() -> some View {
        if #available(macOS 14.0, *) {
            return self.scrollTransition { content, phase in
                content
                    .opacity(phase.isIdentity ? 1 : 0.82)
                    .scaleEffect(phase.isIdentity ? 1 : 0.98)
                    .blur(radius: phase.isIdentity ? 0 : 0.3)
            }
        } else {
            return self
        }
    }
}

// MARK: - 🎵 Live Audio Equalizer Wave Animation
public struct EqualizerWaveView: View {
    public let isActive: Bool
    public var barColor: Color = .blue
    public var barCount: Int = 3
    public var height: CGFloat = 10

    @State private var phase: CGFloat = 0

    public init(isActive: Bool, barColor: Color = .blue, barCount: Int = 3, height: CGFloat = 10) {
        self.isActive = isActive
        self.barColor = barColor
        self.barCount = barCount
        self.height = height
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 1.8) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(barColor)
                    .frame(
                        width: 2.2,
                        height: isActive ? barHeight(for: i) : 2.5
                    )
            }
        }
        .frame(height: height, alignment: .bottom)
        .onAppear {
            if isActive { startAnim() }
        }
        .onChange(of: isActive) { _, active in
            if active { startAnim() }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let factors: [CGFloat] = [0.95, 0.45, 0.8, 0.6, 1.0]
        let baseFactor = factors[index % factors.count]
        let wave = (sin(phase + CGFloat(index) * 1.3) + 1.0) / 2.0
        return max(2.5, height * (0.3 + 0.7 * baseFactor * wave))
    }

    private func startAnim() {
        withAnimation(.easeInOut(duration: 0.28).repeatForever(autoreverses: true)) {
            phase = .pi * 2
        }
    }
}

// MARK: - 🌊 Shimmer Wave Loading Modifier
public struct ShimmerModifier: ViewModifier {
    public let isActive: Bool
    @State private var phase: CGFloat = -1.0

    public func body(content: Content) -> some View {
        if isActive {
            content
                .overlay(
                    GeometryReader { geo in
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.clear,
                                Color.white.opacity(0.35),
                                Color.clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .rotationEffect(.degrees(25))
                        .offset(x: phase * geo.size.width * 2)
                    }
                    .mask(content)
                )
                .onAppear {
                    withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                        phase = 1.5
                    }
                }
        } else {
            content
        }
    }
}

public extension View {
    func shimmering(active: Bool = true) -> some View {
        self.modifier(ShimmerModifier(isActive: active))
    }
}

// MARK: - 🌟 Bookmark / Star Bounce Button with Glow
public struct BookmarkBounceButton: View {
    public let isBookmarked: Bool
    public let onToggle: () -> Void

    @State private var isBouncing: Bool = false
    @State private var burstGlow: Bool = false

    public init(isBookmarked: Bool, onToggle: @escaping () -> Void) {
        self.isBookmarked = isBookmarked
        self.onToggle = onToggle
    }

    public var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.45)) {
                isBouncing = true
                burstGlow = true
            }
            onToggle()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isBouncing = false
                burstGlow = false
            }
        }) {
            ZStack {
                if burstGlow && isBookmarked {
                    Circle()
                        .fill(Color.orange.opacity(0.3))
                        .frame(width: 22, height: 22)
                        .scaleEffect(isBouncing ? 1.6 : 0.8)
                        .opacity(isBouncing ? 0 : 0.8)
                }

                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 12.5))
                    .foregroundColor(isBookmarked ? .orange : .secondary.opacity(0.75))
                    .scaleEffect(isBouncing ? 1.35 : 1.0)
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: isBookmarked)
    }
}
