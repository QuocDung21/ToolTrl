import SwiftUI
import AppKit

// MARK: - AirDrop Notification Banner View
public struct AirDropNotificationBannerView: View {
    public let images: [NSImage]
    public let text: String
    public var onClose: () -> Void
    
    @State private var isCopiedFlash: Bool = false
    @State private var wavePulse: Bool = false
    
    public init(images: [NSImage], text: String, onClose: @escaping () -> Void) {
        self.images = images
        self.text = text
        self.onClose = onClose
    }
    
    public init(image: NSImage?, text: String, onClose: @escaping () -> Void) {
        if let img = image {
            self.images = [img]
        } else {
            self.images = []
        }
        self.text = text
        self.onClose = onClose
    }
    
    public var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // AirDrop / iPad Icon with pulsing ripple animation
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(wavePulse ? 0.0 : 0.4), lineWidth: 2)
                    .scaleEffect(wavePulse ? 1.4 : 1.0)
                    .frame(width: 44, height: 44)
                
                Circle()
                    .fill(LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                    .shadow(color: Color.blue.opacity(0.35), radius: 6, x: 0, y: 3)
                
                Image(systemName: "airdrop")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    wavePulse = true
                }
            }
            
            // Content Info
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    let titleText = images.count > 1 ? "AirDrop • \(images.count) trang bài giải từ iPad" : "AirDrop • Bài giải từ iPad"
                    Text(titleText)
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        onClose()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                
                let copyNotice = isCopiedFlash ? "✅ Đã copy vào Clipboard (Bấm Cmd+V để dán)" : (images.count > 1 ? "📋 Đã copy \(images.count) trang ảnh vào Clipboard (Cmd + V)" : "📋 Đã copy bài giải vào Clipboard (Cmd + V)")
                Text(copyNotice)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(isCopiedFlash ? .green : .secondary)
                    .animation(.easeInOut(duration: 0.2), value: isCopiedFlash)
                
                // Thumbnail preview of the worksheet if image(s) available
                if !images.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(0..<min(3, images.count), id: \.self) { idx in
                            Image(nsImage: images[idx])
                                .resizable()
                                .scaledToFit()
                                .frame(height: 50)
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                        }
                        
                        if images.count > 3 {
                            Text("+\(images.count - 3)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 4)
                        }
                        
                        if !text.isEmpty {
                            Text(text.prefix(50) + (text.count > 50 ? "..." : ""))
                                .font(.system(size: 10.5))
                                .foregroundColor(.primary.opacity(0.8))
                                .lineLimit(2)
                        }
                    }
                    .padding(.top, 2)
                }
                
                // Action Buttons Row
                HStack(spacing: 8) {
                    // Copy Again button
                    Button(action: {
                        copyToClipboard()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.clipboard")
                            Text("Dán (Cmd+V)")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    // View in Studio button
                    Button(action: {
                        ContinuityHomeworkController.shared.showStudio(taskText: text, taskImage: images.first)
                        onClose()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "eye.fill")
                            Text("Xem Studio")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.12))
                        .foregroundColor(.primary)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    // Ask AI button
                    Button(action: {
                        openQuickAI()
                        onClose()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                            Text("Hỏi AI")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(LinearGradient(colors: [Color.blue, Color.purple], startPoint: .leading, endPoint: .trailing))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .frame(width: 400)
        .background(
            VisualEffectBackground(material: .hudWindow, blendingMode: .withinWindow)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 8)
    }
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        var pbItems: [NSPasteboardItem] = []
        for img in images {
            if let tiffData = img.tiffRepresentation,
               let bitmapRep = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                let item = NSPasteboardItem()
                item.setData(pngData, forType: .png)
                item.setData(tiffData, forType: .tiff)
                pbItems.append(item)
            }
        }
        if !pbItems.isEmpty {
            pasteboard.writeObjects(pbItems)
        }
        
        isCopiedFlash = true
        NSSound(named: "Glass")?.play()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isCopiedFlash = false
        }
    }
    
    private func openQuickAI() {
        let prompt = """
        Bạn là một giáo viên chuyên nghiệp. Dưới đây là đề bài và bài giải được học sinh hoàn thành bằng bút Apple Pencil trên iPad:

        [NỘI DUNG ĐỀ BÀI & BÀI LÀM]:
        \(text)

        [YÊU CẦU]:
        1. Chấm điểm bài làm chi tiết trên thang điểm 10.
        2. Nhận xét đúng/sai cho từng đáp án và giải thích chi tiết.
        3. Cung cấp lời giải mẫu chuẩn xác nhất.
        """
        QuickAIWindowController.shared.showAI(prompt: prompt)
    }
}

// MARK: - AirDrop Banner Controller (Floating Top-Right HUD)
@MainActor
public final class AirDropNotificationBannerController: NSObject, NSWindowDelegate {
    public static let shared = AirDropNotificationBannerController()
    
    private var panel: NSPanel?
    private var dismissTimer: Timer?
    
    private override init() {
        super.init()
    }
    
    public func showBanner(images: [NSImage], text: String) {
        dismissTimer?.invalidate()
        dismissTimer = nil
        
        let screen = NSScreen.main ?? NSScreen.screens.first
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        
        let bannerWidth: CGFloat = 400
        let bannerHeight: CGFloat = 140
        let padding: CGFloat = 20
        
        let targetX = screenFrame.maxX - bannerWidth - padding
        let targetY = screenFrame.maxY - bannerHeight - padding
        
        let initialRect = NSRect(x: targetX, y: targetY + 30, width: bannerWidth, height: bannerHeight)
        let finalRect = NSRect(x: targetX, y: targetY, width: bannerWidth, height: bannerHeight)
        
        if panel == nil {
            let p = NSPanel(
                contentRect: initialRect,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            p.isFloatingPanel = true
            p.level = .statusBar
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.isReleasedWhenClosed = false
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = false
            p.delegate = self
            self.panel = p
        }
        
        guard let p = self.panel else { return }
        
        let bannerView = AirDropNotificationBannerView(images: images, text: text) { [weak self] in
            self?.hideBanner()
        }
        
        p.contentView = NSHostingView(rootView: bannerView)
        p.setFrame(initialRect, display: true)
        p.alphaValue = 0.0
        p.orderFrontRegardless()
        
        // Play AirDrop Chime
        NSSound(named: "Glass")?.play()
        
        // Slide & Fade-in Animation
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            p.animator().setFrame(finalRect, display: true)
            p.animator().alphaValue = 1.0
        }
        
        // Auto dismiss after 10 seconds
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.hideBanner()
            }
        }
    }
    
    public func showBanner(image: NSImage?, text: String) {
        if let img = image {
            showBanner(images: [img], text: text)
        } else {
            showBanner(images: [], text: text)
        }
    }
    
    public func hideBanner() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        
        guard let p = self.panel else { return }
        
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            p.animator().alphaValue = 0.0
        }, completionHandler: {
            p.orderOut(nil)
        })
    }
}
