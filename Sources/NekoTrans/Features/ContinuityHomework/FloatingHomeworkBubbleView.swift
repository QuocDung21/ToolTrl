import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct FloatingHomeworkBubbleView: View {
    @ObservedObject var server = ContinuityHomeworkServer.shared
    @State private var isTargetedForDrop: Bool = false
    @State private var isHovered: Bool = false
    @State private var flashSuccess: Bool = false
    @State private var pulseAnimation: Bool = false
    
    public var onExpand: () -> Void
    public var onClose: () -> Void
    
    public init(onExpand: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.onExpand = onExpand
        self.onClose = onClose
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // Main Interactive Bubble
            ZStack {
                // Outer Glow / Drop Ripple
                Circle()
                    .stroke(
                        flashSuccess ? Color.green : (isTargetedForDrop ? AppColors.accent : Color.blue.opacity(0.3)),
                        lineWidth: isTargetedForDrop ? 3.5 : (flashSuccess ? 3 : 1.5)
                    )
                    .scaleEffect(isTargetedForDrop ? 1.25 : (flashSuccess ? 1.2 : 1.0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isTargetedForDrop)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: flashSuccess)
                
                // Background Gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: flashSuccess ? [Color.green, Color.mint] : (isTargetedForDrop ? [Color.blue, Color.cyan] : [Color(red: 0.12, green: 0.15, blue: 0.24), Color(red: 0.08, green: 0.1, blue: 0.18)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 4)
                
                // Content Icon & Badges
                VStack(spacing: 0) {
                    if flashSuccess {
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    } else if isTargetedForDrop {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "ipad.and.arrow.forward")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                
                // Online status dot
                Circle()
                    .fill(server.isRunning ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                    .offset(x: 16, y: -16)
                
                // New Submission Notification Badge
                if !server.lastSubmittedImages.isEmpty {
                    ZStack {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 16, height: 16)
                        Text("\(server.lastSubmittedImages.count)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .offset(x: -16, y: -16)
                }
            }
            .frame(width: 52, height: 52)
            
            // Expanded Pill info when hovered or dragging over
            if isHovered || isTargetedForDrop {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isTargetedForDrop ? "Thả để bắn sang iPad!" : "Bắn Bài Tập iPad")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(server.currentTaskPDFData != nil ? "📄 Có PDF" : (server.currentTaskImageData != nil ? "🖼️ Có Ảnh" : "Kéo thả PDF / Ảnh"))
                        .font(.system(size: 9.5))
                        .foregroundColor(Color.white.opacity(0.8))
                        .lineLimit(1)
                }
                .padding(.trailing, 8)
                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .leading)), removal: .opacity))
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color.black.opacity(isHovered || isTargetedForDrop ? 0.65 : 0.001))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(isHovered || isTargetedForDrop ? 0.2 : 0.0), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onExpand()
        }
        .onDrop(of: [.fileURL, .plainText, .utf8PlainText, .text, .image, .pdf], isTargeted: $isTargetedForDrop) { providers in
            handleDrop(providers: providers)
        }
        .contextMenu {
            Button(action: onExpand) {
                Label("Mở Studio Đầy Đủ", systemImage: "arrow.up.left.and.arrow.down.right")
            }
            Divider()
            Button(action: { choosePDF() }) {
                Label("Chọn File PDF...", systemImage: "doc.richtext")
            }
            Button(action: { chooseImage() }) {
                Label("Chọn File Ảnh...", systemImage: "photo")
            }
            Button(action: { pasteClipboard() }) {
                Label("Dán Từ Clipboard", systemImage: "doc.on.clipboard")
            }
            Button(action: { ScreenOCRService.shared.captureAndSendToIPad() }) {
                Label("Khoanh Màn Hình (OCR)", systemImage: "viewfinder")
            }
            Divider()
            Button(action: onClose) {
                Label("Ẩn Icon Nổi", systemImage: "xmark.circle")
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    
                    DispatchQueue.main.async {
                        let ext = url.pathExtension.lowercased()
                        if ext == "pdf", let pdfData = try? Data(contentsOf: url) {
                            self.server.setTaskPDF(data: pdfData, fileName: url.lastPathComponent)
                            self.triggerFlash()
                        } else if ["png", "jpg", "jpeg", "webp", "heic", "tiff"].contains(ext),
                                  let img = NSImage(contentsOf: url) {
                            self.server.setTask(text: "Ảnh: \(url.lastPathComponent)", image: img, pdfData: nil, pdfFileName: nil)
                            self.triggerFlash()
                        }
                    }
                }
                return true
            }
            
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                    if let text = item as? String {
                        DispatchQueue.main.async {
                            self.server.setTask(text: text, image: nil, pdfData: nil, pdfFileName: nil)
                            self.triggerFlash()
                        }
                    } else if let data = item as? Data, let text = String(data: data, encoding: .utf8) {
                        DispatchQueue.main.async {
                            self.server.setTask(text: text, image: nil, pdfData: nil, pdfFileName: nil)
                            self.triggerFlash()
                        }
                    }
                }
                return true
            }
        }
        return false
    }
    
    private func triggerFlash() {
        flashSuccess = true
        NSSound(named: "Glass")?.play()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            flashSuccess = false
        }
    }
    
    private func choosePDF() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Gửi sang iPad"
        if panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) {
            server.setTaskPDF(data: data, fileName: url.lastPathComponent)
            triggerFlash()
        }
    }
    
    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Gửi sang iPad"
        if panel.runModal() == .OK, let url = panel.url, let img = NSImage(contentsOf: url) {
            server.setTask(text: "Ảnh: \(url.lastPathComponent)", image: img, pdfData: nil, pdfFileName: nil)
            triggerFlash()
        }
    }
    
    private func pasteClipboard() {
        let pb = NSPasteboard.general
        if let pdfData = pb.data(forType: .pdf) {
            server.setTaskPDF(data: pdfData, fileName: "Clipboard_Document.pdf")
            triggerFlash()
        } else if let img = NSImage(pasteboard: pb) {
            server.setTask(text: "Ảnh từ Clipboard", image: img, pdfData: nil, pdfFileName: nil)
            triggerFlash()
        } else if let text = pb.string(forType: .string), !text.isEmpty {
            server.setTask(text: text, image: nil, pdfData: nil, pdfFileName: nil)
            triggerFlash()
        }
    }
}
