import SwiftUI
import AppKit

public final class FloatingPanel: NSPanel, NSWindowDelegate {
    private var outsideClickMonitor: Any?
    private var localKeyMonitor: Any?
    private var selectionMonitor: Any?
    private var previousApp: NSRunningApplication?

    public var isPinned: Bool = false

    public var onCopyRequested: (() -> Void)?
    public var onSpeakRequested: (() -> Void)?
    public var onBookmarkRequested: (() -> Void)?
    public var onOpenNotebookRequested: (() -> Void)?
    public var onOpenSettingsRequested: (() -> Void)?
    public var onBackRequested: (() -> Void)?
    public var onSelectionTranslated: ((String) -> Void)?
    public var onPinChanged: ((Bool) -> Void)?

    public init(contentRect: NSRect, backing: NSPanel.BackingStoreType, defer flag: Bool) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: backing,
            defer: flag
        )

        self.delegate = self
        self.isFloatingPanel = true
        self.level = .popUpMenu
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = true
        self.isReleasedWhenClosed = false
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
    }

    public override var canBecomeKey: Bool {
        return true
    }

    public override var canBecomeMain: Bool {
        return false
    }

    public override func cancelOperation(_ sender: Any?) {
        hidePanel()
    }

    public func hidePanel() {
        stopOutsideClickMonitor()
        stopLocalKeyMonitor()
        stopSelectionMonitor()
        SpeechService.shared.stop()

        let appToRestore = self.previousApp
        self.previousApp = nil

        // Zero-latency focus restore: user can immediately continue typing in previous application
        DispatchQueue.main.async {
            if let app = appToRestore, !app.isTerminated {
                app.activate()
            } else if NSApp.isActive && MainWindowController.shared.window?.isVisible != true {
                NSApp.deactivate()
            }
        }

        // Native snappy exit: 0.08s fade + subtle shrink (1.0 -> 0.975)
        if let layer = self.contentView?.layer {
            let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
            scaleAnim.fromValue = 1.0
            scaleAnim.toValue = 0.975
            scaleAnim.duration = 0.08
            scaleAnim.timingFunction = CAMediaTimingFunction(name: .easeIn)
            layer.add(scaleAnim, forKey: "shrinkOut")
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.08
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0.0
        }, completionHandler: {
            self.orderOut(nil)
            self.alphaValue = 1.0
            self.contentView?.layer?.removeAnimation(forKey: "shrinkOut")
        })
    }

    public func windowDidResignKey(_ notification: Notification) {
        if !isPinned {
            hidePanel()
        }
    }

    public func windowDidMove(_ notification: Notification) {
        // When user manually moves the panel, anchor to top edge so future height updates expand downwards smoothly
        currentAnchor = .top
    }

    public func togglePin() {
        isPinned.toggle()
        self.level = isPinned ? .statusBar : .popUpMenu
        onPinChanged?(isPinned)

        if isPinned {
            stopOutsideClickMonitor()
            startSelectionMonitor()
        } else {
            stopSelectionMonitor()
            startOutsideClickMonitor()
        }
    }

    public enum WindowAnchor {
        case top
        case bottom
    }

    public static func predictInitialHeight(for text: String) -> CGFloat {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return 160
        }
        let count = trimmed.count
        let hasSpaces = trimmed.contains(" ") || trimmed.contains("\n")

        // Single word or very short idiom -> Dictionary Mode
        if !hasSpaces && count < 35 {
            return 280
        }

        // Sentence or Paragraph Translation Mode
        if count < 60 {
            return 210
        } else if count < 150 {
            return 270
        } else if count < 300 {
            return 340
        } else {
            return 400
        }
    }

    public private(set) var currentAnchor: WindowAnchor = .top
    private var lastMeasuredHeight: CGFloat = 160

    public func showNearRect(_ rect: NSRect, initialHeight: CGFloat? = nil) {
        let windowWidth: CGFloat = 515
        let windowHeight: CGFloat = initialHeight ?? lastMeasuredHeight
        lastMeasuredHeight = windowHeight

        let centerPoint = NSPoint(x: rect.midX, y: rect.midY)
        let screen = NSScreen.screens.first(where: { NSMouseInRect(centerPoint, $0.frame, false) })
            ?? NSScreen.screens.first(where: { NSIntersectsRect(rect, $0.frame) })
            ?? NSScreen.main
            ?? NSScreen.screens[0]

        let visibleFrame = screen.visibleFrame

        // 1. Horizontal positioning: Align with left edge of rect
        var x = rect.minX
        if x + windowWidth > visibleFrame.maxX - 16 {
            x = visibleFrame.maxX - windowWidth - 16
        }
        if x < visibleFrame.minX + 16 {
            x = visibleFrame.minX + 16
        }

        // 2. Vertical positioning: Default below rect, flip above if overflowing bottom
        var y = rect.minY - windowHeight - 8
        var anchor: WindowAnchor = .top

        if y < visibleFrame.minY + 16 {
            y = rect.maxY + 8
            anchor = .bottom
            if y + windowHeight > visibleFrame.maxY - 16 {
                y = visibleFrame.maxY - windowHeight - 16
                anchor = .top
            }
        }

        currentAnchor = anchor
        self.setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
        presentPanel()
    }

    public func showNearCursorOrCenter(initialHeight: CGFloat? = nil) {
        let mouseLoc = NSEvent.mouseLocation
        let windowWidth: CGFloat = 515
        let windowHeight: CGFloat = initialHeight ?? lastMeasuredHeight
        lastMeasuredHeight = windowHeight

        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main {
            var x = mouseLoc.x + 8
            var y = mouseLoc.y - windowHeight - 12
            var anchor: WindowAnchor = .top

            let visibleFrame = screen.visibleFrame

            // Smart clamping so popup never clips out of screen bounds
            if x + windowWidth > visibleFrame.maxX - 16 {
                x = visibleFrame.maxX - windowWidth - 16
            }
            if x < visibleFrame.minX + 16 {
                x = visibleFrame.minX + 16
            }

            if y < visibleFrame.minY + 16 {
                // If bottom overflow, flip to above the cursor
                y = mouseLoc.y + 24
                anchor = .bottom
                if y + windowHeight > visibleFrame.maxY - 16 {
                    y = visibleFrame.maxY - windowHeight - 16
                    anchor = .top
                }
            }
            if y + windowHeight > visibleFrame.maxY - 16 {
                y = visibleFrame.maxY - windowHeight - 16
            }

            currentAnchor = anchor
            self.setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
        } else {
            currentAnchor = .top
            self.center()
        }

        presentPanel()
    }

    private func presentPanel() {
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           frontApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            self.previousApp = frontApp
        }

        if !self.isVisible || self.alphaValue < 0.8 {
            self.alphaValue = 0.0
            self.contentView?.wantsLayer = true

            // Native macOS micro-scale spring pop-in (0.965 -> 1.008 -> 1.0)
            if let layer = self.contentView?.layer {
                let scaleAnim = CAKeyframeAnimation(keyPath: "transform.scale")
                scaleAnim.values = [0.965, 1.008, 1.0]
                scaleAnim.keyTimes = [0.0, 0.65, 1.0]
                scaleAnim.duration = 0.16
                scaleAnim.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
                layer.add(scaleAnim, forKey: "popIn")
            }

            self.invalidateShadow()
            self.orderFrontRegardless()
            self.makeKeyAndOrderFront(nil)
            NSApp.activate()

            // Smooth fade-in animation
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
                self.animator().alphaValue = 1.0
            }
        } else {
            self.orderFrontRegardless()
            self.makeKeyAndOrderFront(nil)
            NSApp.activate()
        }

        startOutsideClickMonitor()
        startLocalKeyMonitor()
        if isPinned {
            startSelectionMonitor()
        }
    }

    public func updateDimensions(width: CGFloat? = nil, targetHeight: CGFloat, animate: Bool = true) {
        let clampedHeight = min(max(targetHeight.rounded(), 120), 540)
        lastMeasuredHeight = clampedHeight
        let currentFrame = self.frame
        let targetWidth = width ?? currentFrame.width
        let clampedWidth = min(max(targetWidth.rounded(), 480), 750)

        let heightDiff = abs(currentFrame.height - clampedHeight)
        let widthDiff = abs(currentFrame.width - clampedWidth)
        let threshold: CGFloat = animate ? 1.0 : 8.0
        guard heightDiff >= threshold || widthDiff >= threshold else { return }

        var newX = currentFrame.origin.x
        if let screen = self.screen ?? NSScreen.main {
            let visibleFrame = screen.visibleFrame
            if newX + clampedWidth > visibleFrame.maxX - 16 {
                newX = visibleFrame.maxX - clampedWidth - 16
            }
            if newX < visibleFrame.minX + 16 {
                newX = visibleFrame.minX + 16
            }
        }

        var newY: CGFloat
        if currentAnchor == .bottom {
            // Bottom edge is anchored, expand upwards
            newY = currentFrame.origin.y
            if let screen = self.screen ?? NSScreen.main {
                let visibleFrame = screen.visibleFrame
                if newY + clampedHeight > visibleFrame.maxY - 16 {
                    newY = visibleFrame.maxY - clampedHeight - 16
                }
            }
        } else {
            // Top edge is anchored, expand downwards
            let top = currentFrame.origin.y + currentFrame.size.height
            newY = top - clampedHeight
            if let screen = self.screen ?? NSScreen.main {
                let visibleFrame = screen.visibleFrame
                if newY < visibleFrame.minY + 16 {
                    newY = visibleFrame.minY + 16
                }
            }
        }

        let newFrame = NSRect(
            x: newX,
            y: newY,
            width: clampedWidth,
            height: clampedHeight
        )

        if animate && self.isVisible {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.36, 1.0)
                self.animator().setFrame(newFrame, display: true)
            }, completionHandler: {
                self.invalidateShadow()
            })
        } else {
            self.setFrame(newFrame, display: true)
        }
    }

    public func updateHeight(_ targetHeight: CGFloat, animate: Bool = true) {
        updateDimensions(width: nil, targetHeight: targetHeight, animate: animate)
    }

    private func startOutsideClickMonitor() {
        stopOutsideClickMonitor()
        guard AppSettings.shared.clickOutsideDismiss && !isPinned else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            guard let self = self, self.isVisible else { return }
            guard AppSettings.shared.clickOutsideDismiss && !self.isPinned else { return }
            let clickLocation = NSEvent.mouseLocation
            if !NSMouseInRect(clickLocation, self.frame, false) {
                DispatchQueue.main.async {
                    self.hidePanel()
                }
            }
        }
    }

    private func stopOutsideClickMonitor() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }

    // MARK: - Auto Translate on Text Selection (When Pinned)
    private func startSelectionMonitor() {
        stopSelectionMonitor()
        guard isPinned && AppSettings.shared.autoTranslateOnSelectionWhenPinned else { return }

        selectionMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            guard let self = self, self.isPinned, self.isVisible else { return }
            guard AppSettings.shared.autoTranslateOnSelectionWhenPinned else { return }

            // Ignore mouse releases that occur inside our own HUD window
            let clickLocation = NSEvent.mouseLocation
            if NSMouseInRect(clickLocation, self.frame, false) {
                return
            }

            // Small delay to allow host app (browser/editor) to finalize selection range
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                guard let self = self, self.isPinned, self.isVisible else { return }
                Task { @MainActor in
                    if let text = await TextGrabber.shared.getSelectedText() {
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            self.onSelectionTranslated?(trimmed)
                        }
                    }
                }
            }
        }
    }

    private func stopSelectionMonitor() {
        if let monitor = selectionMonitor {
            NSEvent.removeMonitor(monitor)
            selectionMonitor = nil
        }
    }

    private func startLocalKeyMonitor() {
        stopLocalKeyMonitor()
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            // ESC key -> Dismiss
            if event.keyCode == 53 {
                self.hidePanel()
                return nil
            }

            // Command key combinations
            if event.modifierFlags.contains(.command) {
                // Allow standard text editing commands to reach focused editable text fields (Cmd+C, Cmd+V, Cmd+A, Cmd+X, Cmd+Z)
                if let textEditor = self.firstResponder as? NSTextView, textEditor.isEditable {
                    let char = event.charactersIgnoringModifiers?.lowercased()
                    if char == "v" || char == "c" || char == "a" || char == "x" || char == "z" {
                        return event
                    }
                }

                switch event.charactersIgnoringModifiers?.lowercased() {
                case "c":
                    self.onCopyRequested?()
                    return nil
                case "s", "b":
                    self.onBookmarkRequested?()
                    return nil
                case "r", "p":
                    self.onSpeakRequested?()
                    return nil
                case "[":
                    self.onBackRequested?()
                    return nil
                case ",":
                    self.onOpenSettingsRequested?()
                    return nil
                default:
                    break
                }
            }
            return event
        }
    }

    private func stopLocalKeyMonitor() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
    }

    deinit {
        stopOutsideClickMonitor()
        stopLocalKeyMonitor()
        stopSelectionMonitor()
    }
}

private struct HUDPreviewMock: View {
    let originalText: String
    let translatedText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "text.magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("NekoTrans")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Image(systemName: "pin")
                    .foregroundStyle(.secondary)
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            // Original text
            VStack(alignment: .leading, spacing: 6) {
                Text("EN")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                Text(originalText)
                    .font(.system(size: 15))
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 16)

            Divider()

            // Translated text
            VStack(alignment: .leading, spacing: 6) {
                Text("VI")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                Text(translatedText)
                    .font(.system(size: 15))
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 16)

            Spacer()

            // Bottom bar
            HStack(spacing: 16) {
                Image(systemName: "doc.on.doc")
                Image(systemName: "speaker.wave.2")
                Image(systemName: "bookmark")
                Spacer()
                Image(systemName: "brain.head.profile")
            }
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
    }
}

#Preview("HUD — Light") {
    LocalizedRootView {
        HUDPreviewMock(
            originalText: "Hello, how are you?",
            translatedText: "Xin chào, bạn khỏe không?"
        )
    }
    .frame(width: 515, height: 600)
    .background(Color(nsColor: .windowBackgroundColor))
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
}
