import AppKit
import SwiftUI
import Defaults
import Observation

// MARK: - Reactive State for Floating Selection Popup
@Observable
@MainActor
public final class SelectionPopupState {
    public var selectedText: String = ""
    public var translatedText: String = ""
    public var phonetic: String? = nil
    public var isLoading: Bool = false
    public var isSaved: Bool = false
    public var detectedLanguage: String = "en"
    public var effectiveTarget: TargetLanguage = .vietnamese
    public var style: SelectionPopupStyle = .instantTranslation

    public init() {}
}

// MARK: - 3-Mode Floating Selection Popup View (Instant Pill / Action Bar / Minimal Bubble)
public struct SelectionBubbleView: View {
    var state: SelectionPopupState
    let onExpandHUD: () -> Void
    let onSpeak: () -> Void
    let onToggleSave: () -> Void
    let onAskAI: () -> Void
    let onHoverChanged: (Bool) -> Void

    @ObservedObject private var speechService = SpeechService.shared
    private var settings = AppSettings.shared
    @State private var isHovered: Bool = false

    public init(
        state: SelectionPopupState,
        onExpandHUD: @escaping () -> Void,
        onSpeak: @escaping () -> Void,
        onToggleSave: @escaping () -> Void,
        onAskAI: @escaping () -> Void,
        onHoverChanged: @escaping (Bool) -> Void
    ) {
        self.state = state
        self.onExpandHUD = onExpandHUD
        self.onSpeak = onSpeak
        self.onToggleSave = onToggleSave
        self.onAskAI = onAskAI
        self.onHoverChanged = onHoverChanged
    }

    public var body: some View {
        Group {
            switch state.style {
            case .instantTranslation:
                if state.selectedText.count <= 140 {
                    instantTranslationPill
                } else {
                    compactActionBar
                }
            case .actionBar:
                compactActionBar
            case .iconBubble:
                minimalIconBubble
            }
        }
        .onHover { hovering in
            isHovered = hovering
            onHoverChanged(hovering)
        }
    }

    // MARK: 1. Instant Mini-Translation Pill (Zero-Click Meaning + Phonetic/Pinyin + Quick Actions)
    private var instantTranslationPill: some View {
        let hudStyle = settings.hudMaterialStyle
        let isSpeaking = speechService.isSpeaking && speechService.currentSpeakerID == "selection_pill"

        return HStack(alignment: .center, spacing: 8) {
            Button(action: onExpandHUD) {
                VStack(alignment: .leading, spacing: 2) {
                    if let ph = state.phonetic, !ph.isEmpty, settings.showPhonetics {
                        Text(ph)
                            .font(.system(size: 10.5, weight: .medium, design: .serif))
                            .foregroundColor(AppColors.phonetic)
                            .lineLimit(1)
                    }

                    if state.isLoading && state.translatedText.isEmpty {
                        HStack(spacing: 5) {
                            ProgressView()
                                .controlSize(.mini)
                                .scaleEffect(0.65)
                            Text("...")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text(state.translatedText.isEmpty ? state.selectedText : state.translatedText)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .buttonStyle(.plain)
            .help("Nhấn để mở cửa sổ từ điển HUD chi tiết")

            Divider()
                .frame(height: 18)
                .opacity(0.35)

            HStack(spacing: 3) {
                pillIconButton(
                    symbol: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2",
                    tint: isSpeaking ? AppColors.accent : .secondary,
                    tooltip: "Nghe phát âm",
                    action: onSpeak
                )

                pillIconButton(
                    symbol: state.isSaved ? "bookmark.fill" : "bookmark",
                    tint: state.isSaved ? .orange : .secondary,
                    tooltip: state.isSaved ? "Bỏ lưu khỏi Sổ tay" : "Lưu nhanh vào Sổ tay",
                    action: onToggleSave
                )

                pillIconButton(
                    symbol: "arrow.up.left.and.arrow.down.right",
                    tint: AppColors.accent,
                    tooltip: "Mở rộng HUD chi tiết",
                    action: onExpandHUD
                )
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .frame(minWidth: 120, maxWidth: 340)
        .fixedSize(horizontal: true, vertical: true)
        .background(pillGlassBackground(hudStyle: hudStyle, cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isHovered ? AppColors.accent.opacity(0.55) : Color.primary.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 8, x: 0, y: 3)
    }

    // MARK: 2. Compact Action Bar (PopClip Style)
    private var compactActionBar: some View {
        let hudStyle = settings.hudMaterialStyle
        let isSpeaking = speechService.isSpeaking && speechService.currentSpeakerID == "selection_pill"

        return HStack(spacing: 4) {
            actionBarButton(
                title: "Dịch",
                symbol: "character.book.closed.fill",
                tint: AppColors.accent,
                action: onExpandHUD
            )

            Divider().frame(height: 14).opacity(0.3)

            pillIconButton(
                symbol: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2",
                tint: isSpeaking ? AppColors.accent : .primary.opacity(0.85),
                tooltip: "Nghe đọc",
                action: onSpeak
            )

            pillIconButton(
                symbol: state.isSaved ? "bookmark.fill" : "bookmark",
                tint: state.isSaved ? .orange : .primary.opacity(0.85),
                tooltip: "Lưu vào Sổ tay",
                action: onToggleSave
            )

            pillIconButton(
                symbol: "sparkles",
                tint: .purple,
                tooltip: "Hỏi Trợ lý AI",
                action: onAskAI
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .fixedSize()
        .background(pillGlassBackground(hudStyle: hudStyle, cornerRadius: 10))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isHovered ? AppColors.accent.opacity(0.55) : Color.primary.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 7, x: 0, y: 3)
    }

    // MARK: 3. Minimal Icon Bubble (32pt Floating Dot)
    private var minimalIconBubble: some View {
        let hudStyle = settings.hudMaterialStyle
        return Button(action: onExpandHUD) {
            ZStack {
                VisualEffectBackground(material: hudStyle.nsMaterial, blendingMode: .behindWindow, cornerRadius: 18)

                Circle()
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.88))

                Image(systemName: "character.bubble.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isHovered ? AppColors.accent : Color.primary.opacity(0.85))
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(isHovered ? AppColors.accent.opacity(0.7) : Color.primary.opacity(0.18), lineWidth: 1.2)
            )
            .shadow(color: Color.black.opacity(isHovered ? 0.35 : 0.2), radius: isHovered ? 6 : 4, x: 0, y: 2)
            .scaleEffect(isHovered ? 1.12 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Reusable Subcomponents
    private func pillGlassBackground(hudStyle: HUDMaterialStyle, cornerRadius: CGFloat) -> some View {
        ZStack {
            VisualEffectBackground(material: hudStyle.nsMaterial, blendingMode: .behindWindow, cornerRadius: cornerRadius)
            Color(nsColor: .windowBackgroundColor).opacity(hudStyle.tintOverlayOpacity)
        }
    }

    private func pillIconButton(symbol: String, tint: Color, tooltip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 22, height: 22)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    private func actionBarButton(title: LocalizedStringKey, symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 10.5, weight: .bold))
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
            }
            .foregroundColor(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(tint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Optimized Selection Bubble & Instant Floating Translation Controller
@MainActor
public final class SelectionBubbleController: NSObject, ObservableObject, NSWindowDelegate {
    public static let shared = SelectionBubbleController()

    public private(set) var bubblePanel: NSPanel?
    private let popupState = SelectionPopupState()
    private var hostingView: NSHostingView<LocalizedRootView<SelectionBubbleView>>?

    private var globalMouseUpMonitor: Any?
    private var globalMouseDownMonitor: Any?
    private var globalScrollMonitor: Any?
    private var globalKeyDownMonitor: Any?

    private var mouseDownLocation: NSPoint = .zero
    private var anchorMouseLocation: NSPoint = .zero

    private var currentSelectedText: String = ""
    private var autoDismissTimer: Timer?
    private var mouseUpWorkItem: DispatchWorkItem?
    private var instantTranslationTask: Task<Void, Never>?
    private var isPointerHoveringPopup: Bool = false

    public var onBubbleClicked: ((String, NSRect?) -> Void)?

    private override init() {
        super.init()
    }

    public func startMonitoring() {
        stopMonitoring()
        guard AppSettings.shared.isSelectionBubbleActive else { return }

        // 1. Mouse Down: Track start location & dismiss active popup on click outside
        globalMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor in
                self?.handleMouseDown(event: event)
            }
        }

        // 2. Mouse Up: Evaluate drag distance or multi-click intent
        globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
            Task { @MainActor in
                self?.handleMouseUp(event: event)
            }
        }

        // 3. Scroll Wheel: Auto-dismiss when user scrolls the page
        globalScrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel]) { [weak self] _ in
            Task { @MainActor in
                self?.hideBubble()
            }
        }

        // 4. Key Down: Auto-dismiss immediately when user starts typing
        globalKeyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            // Ignore pure modifier presses or Cmd+C copying
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers?.lowercased() == "c" {
                return
            }
            Task { @MainActor in
                if self?.bubblePanel?.isVisible == true {
                    self?.hideBubble()
                }
            }
        }
    }

    public func stopMonitoring() {
        mouseUpWorkItem?.cancel()
        mouseUpWorkItem = nil
        instantTranslationTask?.cancel()
        instantTranslationTask = nil

        if let gDown = globalMouseDownMonitor {
            NSEvent.removeMonitor(gDown)
            globalMouseDownMonitor = nil
        }
        if let gUp = globalMouseUpMonitor {
            NSEvent.removeMonitor(gUp)
            globalMouseUpMonitor = nil
        }
        if let gScroll = globalScrollMonitor {
            NSEvent.removeMonitor(gScroll)
            globalScrollMonitor = nil
        }
        if let gKey = globalKeyDownMonitor {
            NSEvent.removeMonitor(gKey)
            globalKeyDownMonitor = nil
        }
        hideBubble()
    }

    // MARK: - Mouse Event Handlers
    private func handleMouseDown(event: NSEvent) {
        mouseDownLocation = NSEvent.mouseLocation

        if let panel = bubblePanel, panel.isVisible {
            if !panel.frame.contains(mouseDownLocation) {
                hideBubble()
            }
        }
    }

    private func handleMouseUp(event: NSEvent) {
        guard AppSettings.shared.isSelectionBubbleActive else { return }

        let mouseUpLocation = NSEvent.mouseLocation

        // 1. ⚡ ANTI-SPAM & INTENT FILTER: Check drag distance or multi-click FIRST
        let dragDistance = hypot(mouseUpLocation.x - mouseDownLocation.x, mouseUpLocation.y - mouseDownLocation.y)
        let clickCount = event.clickCount
        let isIntentionalSelection = (clickCount >= 2) || (dragDistance >= 10.0)

        guard isIntentionalSelection else {
            if let panel = bubblePanel, panel.isVisible, !panel.frame.contains(mouseUpLocation) {
                hideBubble()
            }
            return
        }

        // 2. Ignore if click is inside any NekoTrans window
        for window in NSApp.windows where window.isVisible {
            if window.frame.contains(mouseUpLocation) {
                return
            }
        }

        // 3. Excluded App check
        if AppExclusionService.shared.isCurrentAppExcluded() {
            hideBubble()
            return
        }

        // 4. Cancel any pending check (trailing debounce)
        mouseUpWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                guard AppSettings.shared.isSelectionBubbleActive else { return }

                if AppDelegate.shared?.floatingPanel?.isVisible == true {
                    return
                }

                // Pure non-invasive extraction (Browser JS + macOS Accessibility API — zero clipboard, zero background OCR)
                let text = await TextGrabber.shared.getSelectedTextNonInvasive()

                guard let selected = text?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !selected.isEmpty,
                      selected.count <= 1500 else {
                    self.hideBubble()
                    return
                }

                guard selected.contains(where: { $0.isLetter || $0.isNumber }) else {
                    self.hideBubble()
                    return
                }

                if selected.count == 1 && (selected.first?.isWhitespace == true || selected.first?.isPunctuation == true) {
                    self.hideBubble()
                    return
                }

                if self.bubblePanel?.isVisible == true && self.currentSelectedText == selected {
                    return
                }

                self.showBubble(for: selected, at: mouseUpLocation)
            }
        }

        self.mouseUpWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16, execute: workItem)
    }

    // MARK: - Show, Instant Translate & Hide
    public func showBubble(for text: String, at location: NSPoint? = nil) {
        instantTranslationTask?.cancel()
        self.currentSelectedText = text
        let mouseLoc = location ?? NSEvent.mouseLocation
        self.anchorMouseLocation = mouseLoc

        if bubblePanel == nil {
            setupPanel()
        }

        let style = AppSettings.shared.selectionPopupStyle
        let detected = TranslationService.shared.detectLanguage(for: text)
        let configuredTarget = TargetLanguage(rawValue: Defaults[.targetLanguage]) ?? .vietnamese
        let target = InputTextNormalizer.resolveTargetLanguage(sourceLanguageCode: detected, configuredTarget: configuredTarget)

        popupState.style = style
        popupState.selectedText = text
        popupState.detectedLanguage = detected
        popupState.effectiveTarget = target
        popupState.isSaved = VocabularyService.shared.isWordSaved(text)

        let wordCount = text.split(separator: " ").count
        if wordCount <= 3 {
            popupState.phonetic = IPANormalizer.normalize(DictionaryService.shared.extractPhonetic(for: text))
                ?? PinyinConverter.toPinyin(text)
        } else {
            popupState.phonetic = PinyinConverter.toPinyin(text)
        }
        popupState.translatedText = ""
        popupState.isLoading = (style == .instantTranslation && text.count <= 140)

        repositionPanel(near: mouseLoc, animatePop: bubblePanel?.isVisible != true)
        scheduleAutoDismiss(seconds: style == .instantTranslation ? 6.0 : 4.0)

        if style == .instantTranslation && text.count <= 140 {
            instantTranslationTask = Task { @MainActor [weak self] in
                guard let self = self else { return }
                let result = await TranslationService.shared.translate(
                    text: text,
                    from: detected,
                    to: target.rawValue
                )
                guard !Task.isCancelled, self.currentSelectedText == text else { return }
                self.popupState.translatedText = result ?? ""
                self.popupState.isLoading = false
                if self.popupState.phonetic == nil, let res = result {
                    self.popupState.phonetic = PinyinConverter.toPinyin(res)
                }
                self.repositionPanel(near: self.anchorMouseLocation, animatePop: false)
            }
        }
    }

    private func repositionPanel(near mouseLoc: NSPoint, animatePop: Bool) {
        guard let panel = bubblePanel, let hosting = hostingView else { return }
        panel.appearance = AppSettings.shared.appAppearanceMode.nsAppearance

        hosting.layoutSubtreeIfNeeded()
        let fitting = hosting.fittingSize
        let width = max(36, min(fitting.width, 350))
        let height = max(36, min(fitting.height, 110))

        var targetX = mouseLoc.x - (width * 0.25)
        var targetY = mouseLoc.y + 14

        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLoc) }) ?? NSScreen.main {
            let screenFrame = screen.visibleFrame
            if targetX + width > screenFrame.maxX - 10 {
                targetX = screenFrame.maxX - width - 10
            }
            if targetY + height > screenFrame.maxY - 10 {
                targetY = mouseLoc.y - height - 14
            }
            if targetX < screenFrame.minX + 10 { targetX = screenFrame.minX + 10 }
            if targetY < screenFrame.minY + 10 { targetY = screenFrame.minY + 10 }
        }

        panel.setFrame(NSRect(x: targetX, y: targetY, width: width, height: height), display: true)

        if animatePop {
            panel.alphaValue = 0.0
            panel.contentView?.wantsLayer = true

            if let layer = panel.contentView?.layer {
                let scaleAnim = CAKeyframeAnimation(keyPath: "transform.scale")
                scaleAnim.values = [0.88, 1.03, 1.0]
                scaleAnim.keyTimes = [0.0, 0.65, 1.0]
                scaleAnim.duration = 0.15
                scaleAnim.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
                layer.add(scaleAnim, forKey: "bubblePop")
            }

            panel.orderFrontRegardless()

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.13
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
                panel.animator().alphaValue = 1.0
            }
        } else if !panel.isVisible {
            panel.alphaValue = 1.0
            panel.orderFrontRegardless()
        }
    }

    private func scheduleAutoDismiss(seconds: TimeInterval) {
        autoDismissTimer?.invalidate()
        autoDismissTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.isPointerHoveringPopup {
                    self.scheduleAutoDismiss(seconds: 3.0)
                } else {
                    self.hideBubble()
                }
            }
        }
    }

    public func hideBubble() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
        mouseUpWorkItem?.cancel()
        instantTranslationTask?.cancel()
        instantTranslationTask = nil
        currentSelectedText = ""
        isPointerHoveringPopup = false

        guard let panel = bubblePanel, panel.isVisible else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.08
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0.0
        }, completionHandler: {
            panel.orderOut(nil)
            panel.alphaValue = 1.0
            panel.contentView?.layer?.removeAllAnimations()
        })
    }

    // MARK: - Panel Setup & Micro-Actions
    private func setupPanel() {
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 160, height: 42),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = .popUpMenu
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isReleasedWhenClosed = false
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.delegate = self

        let rootView = LocalizedRootView {
            SelectionBubbleView(
                state: self.popupState,
                onExpandHUD: { [weak self] in
                    self?.expandToFullHUD()
                },
                onSpeak: { [weak self] in
                    self?.speakSelected()
                },
                onToggleSave: { [weak self] in
                    self?.toggleSaveSelected()
                },
                onAskAI: { [weak self] in
                    self?.askAISelected()
                },
                onHoverChanged: { [weak self] hovering in
                    self?.isPointerHoveringPopup = hovering
                    if hovering {
                        self?.autoDismissTimer?.invalidate()
                    } else {
                        self?.scheduleAutoDismiss(seconds: 2.5)
                    }
                }
            )
        }

        let hv = NSHostingView(rootView: rootView)
        hv.sizingOptions = [.intrinsicContentSize]
        p.contentView = hv
        self.hostingView = hv
        self.bubblePanel = p
    }

    private func expandToFullHUD() {
        mouseUpWorkItem?.cancel()
        let textToTranslate = currentSelectedText
        let frame = bubblePanel?.frame
        hideBubble()

        guard !textToTranslate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if let callback = onBubbleClicked {
            callback(textToTranslate, frame)
        } else {
            AppDelegate.shared?.triggerTranslationWithText(textToTranslate, nearRect: frame)
        }
    }

    private func speakSelected() {
        let text = currentSelectedText
        guard !text.isEmpty else { return }
        let lower = popupState.detectedLanguage.lowercased()
        let voiceCode: String
        if lower == "vi" {
            voiceCode = "vi-VN"
        } else if lower == "ja" {
            voiceCode = "ja-JP"
        } else if lower.hasPrefix("zh") || PinyinConverter.containsChineseCharacters(text) {
            voiceCode = "zh-CN"
        } else if lower == "ko" {
            voiceCode = "ko-KR"
        } else {
            voiceCode = "en-US"
        }
        SpeechService.shared.speak(text: text, languageCode: voiceCode, speakerID: "selection_pill")
        scheduleAutoDismiss(seconds: 5.0)
    }

    private func toggleSaveSelected() {
        let text = currentSelectedText
        guard !text.isEmpty else { return }
        let meaning = popupState.translatedText
        let ph = popupState.phonetic ?? PinyinConverter.toPinyin(text)
        VocabularyService.shared.toggleSaveWord(
            word: text,
            phonetic: ph,
            translation: meaning
        )
        popupState.isSaved = VocabularyService.shared.isWordSaved(text)
        SoundService.play(.pop)
        scheduleAutoDismiss(seconds: 4.0)
    }

    private func askAISelected() {
        let text = currentSelectedText
        hideBubble()
        guard !text.isEmpty else { return }
        QuickAIWindowController.shared.showAI(prompt: text)
    }
}
