import SwiftUI
import AppKit
import NekoCore
import NekoServices
import NekoUI

public struct OnboardingLandingView: View {
    public var onComplete: ((_ openWorkspace: Bool) -> Void)?

    @State private var currentStep: Int = 0
    @State private var isMovingForward: Bool = true
    @State private var isAccessibilityGranted: Bool = TextGrabber.isAccessibilityTrusted(prompt: false)
    @State private var openWorkspaceOnComplete: Bool = false

    // Animation & Interaction States
    @State private var hoveredCard: Int? = nil
    @State private var hoveredShortcut: String? = nil
    @State private var isFloatingHero: Bool = false
    @State private var pulseRing: Bool = false
    @State private var showSettingsMockupToggle: Bool = false
    @State private var clickedShortcutKey: String? = nil
    @State private var pointerBounce: Bool = false

    @Namespace private var animationNamespace

    private let totalSteps = 4

    public init(onComplete: ((_ openWorkspace: Bool) -> Void)? = nil) {
        self.onComplete = onComplete
    }

    // Smooth macOS Depth & Slide Transition
    private var macOSStepTransition: AnyTransition {
        .asymmetric(
            insertion: .offset(x: isMovingForward ? 32 : -32)
                .combined(with: .scale(scale: 0.97))
                .combined(with: .opacity),
            removal: .offset(x: isMovingForward ? -32 : 32)
                .combined(with: .scale(scale: 0.97))
                .combined(with: .opacity)
        )
    }

    public var body: some View {
        VStack(spacing: 0) {
            topProgressHeader

            Divider()
                .opacity(0.12)

            // Step Content
            ZStack {
                switch currentStep {
                case 0:
                    welcomeStepView
                        .transition(macOSStepTransition)
                case 1:
                    permissionsStepView
                        .transition(macOSStepTransition)
                case 2:
                    shortcutsStepView
                        .transition(macOSStepTransition)
                case 3:
                    completionStepView
                        .transition(macOSStepTransition)
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.spring(response: 0.38, dampingFraction: 0.82), value: currentStep)

            Divider()
                .opacity(0.12)

            bottomNavigationFooter
        }
        .frame(width: 730, height: 580)
        .background(
            ZStack {
                VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow)

                // Dynamic Ambient Multi-Color Glow
                Circle()
                    .fill(ambientColorForStep.opacity(0.10))
                    .frame(width: 420, height: 420)
                    .blur(radius: 80)
                    .offset(x: CGFloat(currentStep - 1) * 85, y: -90)
                    .animation(.easeInOut(duration: 0.75), value: currentStep)
                    .animation(.easeInOut(duration: 0.5), value: isAccessibilityGranted)

                Circle()
                    .fill(secondaryAmbientColor.opacity(0.06))
                    .frame(width: 320, height: 320)
                    .blur(radius: 70)
                    .offset(x: CGFloat(1 - currentStep) * 60, y: 120)
                    .animation(.easeInOut(duration: 0.75), value: currentStep)
            }
        )
        .onAppear {
            checkPermissions()
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                isFloatingHero = true
            }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pointerBounce = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkPermissions()
        }
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            if currentStep == 1 && !isAccessibilityGranted {
                checkPermissions()
            }
        }
    }

    private var ambientColorForStep: Color {
        switch currentStep {
        case 0: return AppColors.accent
        case 1: return isAccessibilityGranted ? .green : .orange
        case 2: return .purple
        case 3: return .green
        default: return AppColors.accent
        }
    }

    private var secondaryAmbientColor: Color {
        switch currentStep {
        case 0: return .purple
        case 1: return .blue
        case 2: return .blue
        case 3: return AppColors.accent
        default: return .clear
        }
    }

    // MARK: - Top Progress Header (Window Traffic Light Safe Inset)

    private var topProgressHeader: some View {
        HStack(spacing: 0) {
            // Reserve space for standard macOS Traffic Light buttons (Close/Minimize/Zoom)
            Spacer()
                .frame(width: 76)

            // Centered Progress Pill Bar
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Button {
                        if index != currentStep {
                            navigate(to: index)
                        }
                    } label: {
                        ZStack {
                            Capsule()
                                .fill(index < currentStep ? AppColors.accent.opacity(0.35) : Color.primary.opacity(0.12))
                                .frame(width: index == currentStep ? 32 : 8, height: 5)

                            if index == currentStep {
                                Capsule()
                                    .fill(AppColors.accent)
                                    .frame(width: 32, height: 5)
                                    .matchedGeometryEffect(id: "ActiveStepIndicator", in: animationNamespace)
                                    .shadow(color: AppColors.accent.opacity(0.55), radius: 5, x: 0, y: 1)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .animation(.spring(response: 0.36, dampingFraction: 0.78), value: currentStep)

            Spacer()

            // Step Counter & Skip Button
            HStack(spacing: 12) {
                Text("Bước \(currentStep + 1) / \(totalSteps)")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.85))
                    .contentTransition(.numericText())

                if currentStep < totalSteps - 1 {
                    Button {
                        finishOnboarding()
                    } label: {
                        Text("Bỏ qua")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3.5)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(TactileMacButtonStyle())
                }
            }
        }
        .padding(.trailing, 24)
        .padding(.vertical, 12)
        .background(WindowDragArea()) // Allows moving the window by dragging the header
    }

    // MARK: - Step 0: Welcome Step View

    private var welcomeStepView: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 2)

            // Floating Hero App Icon with Ambient Glow
            ZStack {
                // Ambient pulsating glow behind icon
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                AppColors.accent.opacity(0.42),
                                .purple.opacity(0.20),
                                .clear
                            ]),
                            center: .center,
                            startRadius: 10,
                            endRadius: 80
                        )
                    )
                    .frame(width: 140, height: 140)
                    .blur(radius: 14)
                    .scaleEffect(isFloatingHero ? 1.08 : 0.94)

                Image(nsImage: AppIconService.shared.currentNSImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Color.black.opacity(0.28), radius: isFloatingHero ? 16 : 10, x: 0, y: isFloatingHero ? 10 : 5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.4), Color.white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .offset(y: isFloatingHero ? -4 : 4)
            }

            VStack(spacing: 4) {
                Text("Chào mừng đến với NekoTrans")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("Trợ lý dịch thuật & tra cứu từ vựng thông minh cho macOS")
                    .font(.system(size: 13.5))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // 3 Elegant Feature Cards
            VStack(spacing: 9) {
                welcomeFeatureCard(
                    id: 0,
                    icon: "menubar.arrow.up.rectangle",
                    color: .blue,
                    badge: "Thường trực",
                    title: "Túc trực trên thanh Menu Bar",
                    desc: "Hoạt động êm ái trên thanh Menu ở góc trên màn hình, luôn sẵn sàng mà không chiếm chỗ trên Dock."
                )

                welcomeFeatureCard(
                    id: 1,
                    icon: "text.viewfinder",
                    color: .purple,
                    badge: "Phím tắt ⌥D",
                    title: "Khung Dịch Nhanh Thông Minh (HUD)",
                    desc: "Bôi đen từ hoặc câu bất kỳ trong Safari, Chrome, Word hay Xcode để tra cứu tức thì kèm phát âm IPA chuẩn."
                )

                welcomeFeatureCard(
                    id: 2,
                    icon: "sparkles.square.filled.on.square",
                    color: .orange,
                    badge: "AI & Sổ tay",
                    title: "Phân Tích Ngữ Pháp & Flashcards",
                    desc: "Giải thích ngữ pháp chuyên sâu, gợi ý collocations tự nhiên và đồng bộ vào sổ tay Spaced Repetition."
                )
            }
            .padding(.horizontal, 34)

            Spacer(minLength: 2)
        }
        .padding(.vertical, 6)
    }

    private func welcomeFeatureCard(
        id: Int,
        icon: String,
        color: Color,
        badge: String,
        title: String,
        desc: String
    ) -> some View {
        let isHovered = (hoveredCard == id)

        return HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(isHovered ? 0.25 : 0.16), color.opacity(isHovered ? 0.15 : 0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(color.opacity(isHovered ? 0.5 : 0.25), lineWidth: 0.8)
                    )

                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(color)
                    .scaleEffect(isHovered ? 1.12 : 1.0)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(badge)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.12))
                        .clipShape(Capsule())
                }

                Text(desc)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(isHovered ? 0.72 : 0.48))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(isHovered ? color.opacity(0.4) : Color.primary.opacity(0.07), lineWidth: 0.8)
        )
        .scaleEffect(isHovered ? 1.012 : 1.0)
        .shadow(color: isHovered ? color.opacity(0.12) : Color.black.opacity(0.02), radius: isHovered ? 8 : 2, x: 0, y: 2)
        .onHover { h in
            withAnimation(.spring(response: 0.26, dampingFraction: 0.8)) {
                hoveredCard = h ? id : nil
            }
        }
    }

    // MARK: - Step 1: Permissions Step View (Accessibility)

    private var permissionsStepView: some View {
        let statusColor: Color = isAccessibilityGranted ? .green : .orange

        return VStack(spacing: 16) {
            Spacer(minLength: 4)

            // Sonar Pulse Shield Icon
            ZStack {
                if !isAccessibilityGranted {
                    Circle()
                        .stroke(statusColor.opacity(0.35), lineWidth: 1.5)
                        .frame(width: 90, height: 90)
                        .scaleEffect(pulseRing ? 1.38 : 0.95)
                        .opacity(pulseRing ? 0.0 : 0.7)
                        .animation(.easeOut(duration: 1.8).repeatForever(autoreverses: false), value: pulseRing)
                }

                Circle()
                    .fill(statusColor.opacity(0.14))
                    .frame(width: 90, height: 90)

                Image(systemName: isAccessibilityGranted ? "checkmark.shield.fill" : "hand.raised.app.fill")
                    .font(.system(size: 46))
                    .foregroundColor(statusColor)
                    .contentTransition(.symbolEffect(.replace))
            }
            .onAppear {
                pulseRing = true
            }

            VStack(spacing: 5) {
                Text("Cấp Quyền Trợ Năng (Accessibility)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text("NekoTrans cần quyền Trợ năng để tự động trích xuất văn bản khi bạn bôi đen và nhấn phím tắt.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 50)
            }

            // Visual Mockup of macOS System Settings
            VStack(spacing: 12) {
                if isAccessibilityGranted {
                    HStack(spacing: 14) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.green)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Quyền Trợ năng đã được kích hoạt!")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.green)

                            Text("NekoTrans đã sẵn sàng nhận diện văn bản trên Safari, Chrome, Word, Xcode, PDF Reader...")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(16)
                    .background(Color.green.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.green.opacity(0.35), lineWidth: 1)
                    )
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                } else {
                    // Interactive Guide Box
                    VStack(spacing: 10) {
                        // Mini macOS Settings Window Preview
                        VStack(spacing: 0) {
                            HStack(spacing: 6) {
                                Circle().fill(Color.red.opacity(0.7)).frame(width: 8, height: 8)
                                Circle().fill(Color.yellow.opacity(0.7)).frame(width: 8, height: 8)
                                Circle().fill(Color.green.opacity(0.7)).frame(width: 8, height: 8)

                                Spacer()

                                Text("Cài đặt hệ thống ▸ Quyền riêng tư & Bảo mật ▸ Trợ năng")
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundColor(.secondary)

                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.primary.opacity(0.04))

                            Divider().opacity(0.1)

                            HStack(spacing: 12) {
                                Image(nsImage: AppIconService.shared.currentNSImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 24, height: 24)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))

                                Text("NekoTrans")
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundColor(.primary)

                                Spacer()

                                // Toggle Switch Simulation
                                ZStack {
                                    Capsule()
                                        .fill(showSettingsMockupToggle ? Color.green : Color.primary.opacity(0.18))
                                        .frame(width: 38, height: 22)

                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 18, height: 18)
                                        .shadow(color: .black.opacity(0.2), radius: 1.5, x: 0, y: 1)
                                        .offset(x: showSettingsMockupToggle ? 8 : -8)
                                }
                                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: showSettingsMockupToggle)
                                .onAppear {
                                    showSettingsMockupToggle = true
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                        }
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
                        )

                        // Action Buttons
                        HStack(spacing: 12) {
                            Button {
                                openSystemSettingsForAccessibility()
                            } label: {
                                Label("Mở Cài đặt hệ thống để bật Trợ năng", systemImage: "gearshape.fill")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)

                            Button {
                                checkPermissions()
                            } label: {
                                Label("Kiểm tra lại", systemImage: "arrow.clockwise")
                                    .font(.system(size: 13))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                    }
                    .padding(14)
                    .background(Color.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(Color.orange.opacity(0.28), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 44)
            .animation(.spring(response: 0.38, dampingFraction: 0.78), value: isAccessibilityGranted)

            // Privacy Guarantee
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
                Text("Cam kết quyền riêng tư: NekoTrans chỉ đọc chữ khi bạn bấm phím tắt, không ghi nhận phím gõ hay gửi dữ liệu ra ngoài.")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary.opacity(0.85))
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 50)

            Spacer(minLength: 4)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Step 2: Shortcuts Step View (2x2 Mechanical Keycap Showcase)

    private var shortcutsStepView: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 4)

            VStack(spacing: 5) {
                Text("Phím Tắt Toàn Cầu Tiện Dụng")
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text("Nhấn các tổ hợp phím này ở bất cứ đâu trên macOS để kích hoạt tính năng ngay:")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            // 2x2 Showcase Grid
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                shortcutGridCard(
                    keys: ["⌥", "D"],
                    title: "Dịch nhanh văn bản (HUD)",
                    desc: "Bôi đen từ hoặc câu rồi bấm ⌥D. Khung dịch xuất hiện tức thì kèm phiên âm IPA.",
                    accentColor: .blue
                )

                shortcutGridCard(
                    keys: ["⌥", "S"],
                    title: "Chụp & Dịch ảnh (OCR)",
                    desc: "Khoanh vùng hình ảnh, video YouTube hoặc file PDF để trích xuất chữ và dịch.",
                    accentColor: .purple
                )

                shortcutGridCard(
                    keys: ["⌥", "A"],
                    title: "Trợ lý AI Thông minh",
                    desc: "Trò chuyện với AI để hỏi đáp ngữ pháp, trau chuốt email hoặc giải thích thành ngữ.",
                    accentColor: .orange
                )

                shortcutGridCard(
                    keys: ["⌥", "V"],
                    title: "Sổ tay & Flashcards",
                    desc: "Mở sổ tay từ vựng để ôn tập thẻ flashcard, nghe phát âm và theo dõi ghi nhớ.",
                    accentColor: .green
                )
            }
            .padding(.horizontal, 34)

            HStack(spacing: 6) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.accent)
                Text("Mẹo: Nhấn thử vào các phím tắt ở trên để cảm nhận • Tùy chỉnh tự do trong Cài đặt (⌘,)")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 4)
        }
        .padding(.vertical, 8)
    }

    private func shortcutGridCard(
        keys: [String],
        title: String,
        desc: String,
        accentColor: Color
    ) -> some View {
        let cardID = keys.joined()
        let isHovered = (hoveredShortcut == cardID)
        let isClicked = (clickedShortcutKey == cardID)

        return Button {
            SoundService.play(.tink)
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                clickedShortcutKey = cardID
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.easeOut(duration: 0.2)) {
                    if clickedShortcutKey == cardID {
                        clickedShortcutKey = nil
                    }
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    // Tactile 3D Mechanical Keycaps
                    HStack(spacing: 5) {
                        ForEach(keys, id: \.self) { key in
                            Text(key)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(isHovered ? accentColor : .primary)
                                .frame(width: 28, height: 26)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(NSColor.controlBackgroundColor),
                                                    Color(NSColor.controlBackgroundColor).opacity(0.85)
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .shadow(
                                            color: Color.black.opacity(isClicked ? 0.05 : (isHovered ? 0.15 : 0.22)),
                                            radius: isClicked ? 0.2 : 0.8,
                                            x: 0,
                                            y: isClicked ? 0.5 : 2.0
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(isHovered ? accentColor.opacity(0.45) : Color.primary.opacity(0.15), lineWidth: 0.8)
                                )
                                .offset(y: isClicked ? 2.0 : (isHovered ? 0.8 : 0))
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(accentColor)
                        .opacity(isHovered ? 0.9 : 0.0)
                        .offset(x: isHovered ? 0 : -4)
                }

                VStack(alignment: .leading, spacing: 2.5) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(desc)
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(13)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(isHovered ? 0.75 : 0.50))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isHovered ? accentColor.opacity(0.4) : Color.primary.opacity(0.08), lineWidth: 0.8)
            )
            .scaleEffect(isClicked ? 0.985 : (isHovered ? 1.015 : 1.0))
            .shadow(color: isHovered ? accentColor.opacity(0.12) : Color.black.opacity(0.02), radius: isHovered ? 7 : 2, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .onHover { h in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.78)) {
                hoveredShortcut = h ? cardID : nil
            }
        }
    }

    // MARK: - Step 3: Completion Step View (Illustrated Menu Bar Showcase)

    private var completionStepView: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 4)

            // Celebration Badge with Radiant Glow
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.14))
                    .frame(width: 88, height: 88)
                    .scaleEffect(1.0)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 54))
                    .foregroundColor(.green)
            }

            VStack(spacing: 4) {
                Text("Cài Đặt Hoàn Tất!")
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                Text("NekoTrans đã sẵn sàng đồng hành cùng bạn trên macOS.")
                    .font(.system(size: 13.5))
                    .foregroundColor(.secondary)
            }

            // Illustrated macOS Menu Bar Card (Solves Menu Bar vs Main Window confusion)
            VStack(spacing: 12) {
                VStack(spacing: 0) {
                    // Simulated Menu Bar Strip
                    HStack(spacing: 12) {
                        Image(systemName: "applelogo")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)

                        Text("Finder")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)

                        Text("Tệp")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.7))

                        Spacer()

                        Image(systemName: "wifi")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)

                        Image(systemName: "battery.100")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)

                        Text("14:30")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(.secondary)

                        // Highlighted NekoTrans Menu Bar Icon
                        HStack(spacing: 4) {
                            Text("🐱")
                                .font(.system(size: 13))
                            Text("NekoTrans")
                                .font(.system(size: 10.5, weight: .bold))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(AppColors.accent.opacity(0.22))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(AppColors.accent.opacity(0.6), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.25))

                    Divider().opacity(0.12)

                    // Explanation Note with Bouncing Pointer
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(AppColors.accent)
                            .offset(y: pointerBounce ? -2 : 2)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ứng dụng luôn túc trực trên thanh Menu (Góc trên bên phải)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)

                            Text("NekoTrans chạy ngầm êm ái trên thanh Menu. Khi đóng cửa sổ, bạn vẫn có thể bấm vào icon 🐱 hoặc nhấn phím tắt ⌥D để tra cứu bất cứ lúc nào.")
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                                .lineSpacing(2)
                        }

                        Spacer()
                    }
                    .padding(13)
                }
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppColors.accent.opacity(0.35), lineWidth: 1)
                )

                // Optional Workspace Launch Checkbox
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        openWorkspaceOnComplete.toggle()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Toggle("", isOn: $openWorkspaceOnComplete)
                            .labelsHidden()
                            .toggleStyle(.checkbox)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mở Không gian làm việc chính (Workspace) ngay sau khi hoàn tất")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundColor(.primary)
                            Text("Khám phá Sổ tay từ vựng, quản lý Flashcards và bảng phân tích chuyên sâu.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(11)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(openWorkspaceOnComplete ? AppColors.accent.opacity(0.06) : Color(nsColor: .controlBackgroundColor).opacity(0.45))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(openWorkspaceOnComplete ? AppColors.accent.opacity(0.4) : Color.primary.opacity(0.07), lineWidth: 0.8)
                    )
                }
                .buttonStyle(TactileMacButtonStyle())
            }
            .padding(.horizontal, 42)

            Spacer(minLength: 4)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Bottom Navigation Footer

    private var bottomNavigationFooter: some View {
        HStack {
            if currentStep > 0 {
                Button {
                    navigate(to: currentStep - 1)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .bold))
                        Text("Quay lại")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7.5)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
                    )
                }
                .buttonStyle(TactileMacButtonStyle())
                .transition(.move(edge: .leading).combined(with: .opacity))
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.accent)
                    Text("Thiết lập nhanh trong 1 phút")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .transition(.opacity)
            }

            Spacer()

            if currentStep < totalSteps - 1 {
                let isSkippingPermission = (currentStep == 1 && !isAccessibilityGranted)

                Button {
                    navigate(to: currentStep + 1)
                } label: {
                    HStack(spacing: 6) {
                        Text(isSkippingPermission ? "Cấp quyền sau" : "Tiếp tục")
                            .font(.system(size: 13.5, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(isSkippingPermission ? .primary : .white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 8.5)
                    .background(
                        ZStack {
                            if isSkippingPermission {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color(NSColor.controlBackgroundColor))
                            } else {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [AppColors.accent, AppColors.accent.opacity(0.85)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .matchedGeometryEffect(id: "PrimaryCTA", in: animationNamespace)
                            }
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.primary.opacity(isSkippingPermission ? 0.15 : 0), lineWidth: 0.8)
                    )
                    .shadow(
                        color: isSkippingPermission ? .clear : AppColors.accent.opacity(0.38),
                        radius: 6, x: 0, y: 2
                    )
                }
                .buttonStyle(TactileMacButtonStyle())
                .keyboardShortcut(.defaultAction)
            } else {
                Button {
                    finishOnboarding()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .bold))
                        Text("Bắt đầu sử dụng NekoTrans")
                            .font(.system(size: 13.5, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 9.5)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.accent, AppColors.accent.opacity(0.85)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .matchedGeometryEffect(id: "PrimaryCTA", in: animationNamespace)
                    )
                    .shadow(color: AppColors.accent.opacity(0.45), radius: 8, x: 0, y: 3)
                }
                .buttonStyle(TactileMacButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 12)
        .padding(.bottom, 22)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentStep)
    }

    // MARK: - Helpers & Actions

    private func navigate(to targetStep: Int) {
        guard targetStep >= 0 && targetStep < totalSteps else { return }
        isMovingForward = targetStep > currentStep

        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            currentStep = targetStep
        }
    }

    private func checkPermissions() {
        let granted = TextGrabber.isAccessibilityTrusted(prompt: false)
        if granted != isAccessibilityGranted {
            if granted {
                SoundService.play(.pop)
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                isAccessibilityGranted = granted
            }
        }
    }

    private func openSystemSettingsForAccessibility() {
        _ = TextGrabber.isAccessibilityTrusted(prompt: true)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func finishOnboarding() {
        SoundService.play(.pop)
        AppSettings.shared.hasCompletedOnboarding = true
        onComplete?(openWorkspaceOnComplete)
    }
}

// MARK: - Tactile Button Style

private struct TactileMacButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

//#Preview {
//    OnboardingLandingView()
//
//}
