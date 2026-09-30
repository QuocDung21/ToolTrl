import SwiftUI
import Vision
import UniformTypeIdentifiers
import PDFKit

public struct ContinuityHomeworkView: View {
    @ObservedObject var server = ContinuityHomeworkServer.shared
    @ObservedObject var hwStats = HomeworkStatsService.shared
    @ObservedObject var winCtrl = ContinuityHomeworkWindowController.shared
    
    @State private var selectedTab: Int = 0 // 0: Gửi Đề, 1: Bài Nộp, 2: Thống Kê
    @State private var selectedImageIndex: Int = 0
    @State private var previewPdfPageIndex: Int = 0
    @State private var isProcessingAI: Bool = false
    @State private var isTargetedForDrop: Bool = false
    @State private var dropSuccessFlash: Bool = false
    @State private var dropSuccessMessage: String = ""
    @State private var isCopiedUrl: Bool = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Native macOS Window Header & Toolbar
            windowHeader
            
            Divider()
            
            // Content
            ScrollView {
                VStack(spacing: 16) {
                    if selectedTab == 0 {
                        taskSenderView
                    } else if selectedTab == 1 {
                        submissionsView
                    } else {
                        statsView
                    }
                }
                .padding(18)
            }
        }
        .frame(minWidth: 580, maxWidth: 800, minHeight: 560, maxHeight: 780)
        .background(VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow))
        .onAppear {
            server.startServer()
            if !server.lastSubmittedImages.isEmpty {
                selectedTab = 1
            }
        }
        .onReceive(server.$submissionCount) { _ in
            if !server.lastSubmittedImages.isEmpty {
                selectedTab = 1
            }
        }
    }
    
    // MARK: - Native Window Header
    private var windowHeader: some View {
        HStack(spacing: 12) {
            // Left: Title and Status
            HStack(spacing: 8) {
                Image(systemName: "ipad.and.arrow.forward")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                
                Text("Bài Tập iPad")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                
                // Status indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(server.isRunning ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                    Text(server.isRunning ? "Sẵn sàng" : "Đang bật")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(4)
            }
            
            Spacer()
            
            // Center: Native Segmented Picker
            Picker("", selection: $selectedTab) {
                Text("Gửi đề").tag(0)
                Text(server.lastSubmittedImages.isEmpty ? "Bài nộp" : "Bài nộp (\(server.lastSubmittedImages.count))").tag(1)
                Text("Thống kê").tag(2)
            }
            .pickerStyle(.segmented)
            .frame(width: 250)
            
            Spacer()
            
            // Right: Actions
            HStack(spacing: 6) {
                // Streak badge
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text("\(hwStats.completedToday)/\(hwStats.dailyGoal)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(5)
                
                // Minimize to Floating Bubble
                Button(action: { winCtrl.minimizeToBubble() }) {
                    Image(systemName: "pip.enter")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Thu nhỏ thành Icon nổi (Kéo thả nhanh)")
                
                // Pin
                Button(action: { winCtrl.togglePin() }) {
                    Image(systemName: winCtrl.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 12))
                        .foregroundColor(winCtrl.isPinned ? AppColors.accent : .secondary)
                }
                .buttonStyle(.plain)
                .help(winCtrl.isPinned ? "Bỏ ghim" : "Ghim cửa sổ trên cùng")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.4))
    }
    
    // MARK: - TAB 1: GỬI ĐỀ BÀI (TASK SENDER)
    private var taskSenderView: some View {
        VStack(spacing: 14) {
            // 1. Native Drop Zone
            nativeDropZoneCard
            
            // 2. Current Task Preview
            if server.currentTaskPDFData != nil || server.currentTaskImageData != nil || !server.currentTaskText.isEmpty {
                currentTaskPreviewCard
            }
            
            // 3. iPad Connection Info Card
            ipadConnectionCard
        }
    }
    
    // MARK: - Native Drop Zone Card
    private var nativeDropZoneCard: some View {
        GroupBox {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            isTargetedForDrop ? AppColors.accent : (dropSuccessFlash ? Color.green : Color(nsColor: .separatorColor)),
                            style: StrokeStyle(lineWidth: isTargetedForDrop ? 2 : 1, dash: isTargetedForDrop ? [6, 3] : [4, 4])
                        )
                        .background(
                            isTargetedForDrop ? AppColors.accent.opacity(0.06) : (dropSuccessFlash ? Color.green.opacity(0.06) : Color(nsColor: .controlBackgroundColor).opacity(0.5))
                        )
                    
                    VStack(spacing: 6) {
                        Image(systemName: dropSuccessFlash ? "checkmark.circle.fill" : (isTargetedForDrop ? "arrow.down.doc.fill" : "doc.badge.plus"))
                            .font(.system(size: 24))
                            .foregroundColor(dropSuccessFlash ? Color.green : (isTargetedForDrop ? AppColors.accent : .secondary))
                        
                        if dropSuccessFlash {
                            Text(dropSuccessMessage)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.green)
                        } else {
                            Text(isTargetedForDrop ? "Thả vào đây để gửi sang iPad" : "Kéo thả file PDF, Ảnh hoặc Chữ vào đây")
                                .font(.system(size: 12.5, weight: isTargetedForDrop ? .bold : .medium))
                                .foregroundColor(isTargetedForDrop ? AppColors.accent : .primary)
                        }
                    }
                    .padding(.vertical, 16)
                }
                .frame(height: 85)
                .onDrop(of: [.fileURL, .plainText, .utf8PlainText, .text, .image, .pdf], isTargeted: $isTargetedForDrop) { providers in
                    handleDrop(providers: providers)
                }
                
                // Action Buttons Row
                HStack(spacing: 8) {
                    Button(action: { choosePDF() }) {
                        Label("Chọn PDF...", systemImage: "doc.richtext")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button(action: { chooseImage() }) {
                        Label("Chọn Ảnh...", systemImage: "photo")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button(action: { pasteClipboard() }) {
                        Label("Dán Clipboard", systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button(action: { ScreenOCRService.shared.captureAndSendToIPad() }) {
                        Label("Khoanh Màn Hình", systemImage: "viewfinder")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(4)
        } label: {
            Label("Nạp Đề Bài Tập", systemImage: "arrow.up.doc")
                .font(.system(size: 12, weight: .semibold))
        }
    }
    
    // MARK: - Current Task Preview Card
    private var currentTaskPreviewCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    if server.currentTaskPDFData != nil {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(.red)
                        Text(server.currentTaskPDFFileName ?? "Tài liệu PDF")
                            .font(.system(size: 12, weight: .bold))
                        
                        Spacer()
                        
                        if server.currentTaskPDFPageCount > 0 {
                            Text("Trang \(previewPdfPageIndex + 1)/\(server.currentTaskPDFPageCount)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                if previewPdfPageIndex > 0 { previewPdfPageIndex -= 1 }
                            }) {
                                Image(systemName: "chevron.left")
                            }
                            .controlSize(.mini)
                            .disabled(previewPdfPageIndex == 0)
                            
                            Button(action: {
                                if previewPdfPageIndex < server.currentTaskPDFPageCount - 1 { previewPdfPageIndex += 1 }
                            }) {
                                Image(systemName: "chevron.right")
                            }
                            .controlSize(.mini)
                            .disabled(previewPdfPageIndex >= server.currentTaskPDFPageCount - 1)
                        }
                    } else if server.currentTaskImageData != nil {
                        Image(systemName: "photo.fill")
                            .foregroundColor(.blue)
                        Text("Ảnh đề bài")
                            .font(.system(size: 12, weight: .bold))
                        Spacer()
                    } else {
                        Image(systemName: "text.alignleft")
                            .foregroundColor(.secondary)
                        Text("Văn bản đề bài")
                            .font(.system(size: 12, weight: .bold))
                        Spacer()
                    }
                    
                    Button(action: {
                        server.clearTask()
                        previewPdfPageIndex = 0
                    }) {
                        Label("Dọn dẹp", systemImage: "trash")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red.opacity(0.85))
                    .padding(.leading, 6)
                    .help("Xoá đề và giải phóng toàn bộ bộ nhớ đệm")
                }
                
                // Content Display
                if server.currentTaskPDFData != nil, server.currentTaskPDFPageCount > 0 {
                    if let pageData = server.renderPDFPage(at: previewPdfPageIndex),
                       let pageImg = NSImage(data: pageData) {
                        Image(nsImage: pageImg)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 180)
                            .cornerRadius(4)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(nsColor: .separatorColor), lineWidth: 0.8))
                    }
                } else if let imgData = server.currentTaskImageData, let nsImg = NSImage(data: imgData) {
                    Image(nsImage: nsImg)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 180)
                        .cornerRadius(4)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(nsColor: .separatorColor), lineWidth: 0.8))
                } else if !server.currentTaskText.isEmpty {
                    Text(server.currentTaskText)
                        .font(.system(size: 12.5))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(6)
                }
            }
            .padding(4)
        } label: {
            Label("Đề Bài Đang Đồng Bộ", systemImage: "ipad.and.arrow.forward")
                .font(.system(size: 12, weight: .semibold))
        }
    }
    
    // MARK: - iPad Connection Info Card
    private var ipadConnectionCard: some View {
        GroupBox {
            HStack(spacing: 16) {
                // QR Code
                let qrPayload = "http://\(server.getLocalIPAddress()):\(server.serverPort)"
                if let qrImage = generateQRCode(from: qrPayload) {
                    Image(nsImage: qrImage)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 88, height: 88)
                        .padding(4)
                        .background(Color.white)
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Kết nối Safari hoặc App trên iPad")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Mở **Camera** hoặc trình duyệt **Safari** trên iPad quét mã QR bên cạnh để giải bài bằng Apple Pencil.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineSpacing(1.5)
                    
                    HStack(spacing: 6) {
                        Text(qrPayload)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(AppColors.accent)
                            .textSelection(.enabled)
                        
                        Button(action: {
                            let pb = NSPasteboard.general
                            pb.clearContents()
                            pb.setString(qrPayload, forType: .string)
                            isCopiedUrl = true
                            NSSound(named: "Glass")?.play()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { isCopiedUrl = false }
                        }) {
                            Label(isCopiedUrl ? "Đã copy" : "Sao chép", systemImage: isCopiedUrl ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(4)
        } label: {
            Label("Kết Nối iPad", systemImage: "qrcode")
                .font(.system(size: 12, weight: .semibold))
        }
    }
    
    // MARK: - TAB 2: BÀI NỘP (SUBMISSIONS GALLERY)
    private var submissionsView: some View {
        VStack(spacing: 14) {
            let images = server.lastSubmittedImages
            
            if images.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Chưa có bài nộp từ iPad")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)
                    Text("Làm bài trên iPad và bấm 'Nộp Bài Sang Mac' để nhận bài giải tại đây.")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
            } else {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Đã nhận \(images.count) trang bài giải", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.green)
                            
                            Spacer()
                            
                            Button("Làm bài mới") {
                                server.setTask(text: "", image: nil, pdfData: nil, pdfFileName: nil)
                                selectedTab = 0
                            }
                            .font(.system(size: 11))
                            .buttonStyle(.plain)
                            .foregroundColor(AppColors.accent)
                        }
                        
                        // Thumbnail Strip if multiple images
                        if images.count > 1 {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(0..<images.count, id: \.self) { idx in
                                        VStack(spacing: 2) {
                                            Image(nsImage: images[idx])
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 60, height: 60)
                                                .cornerRadius(4)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .stroke(selectedImageIndex == idx ? AppColors.accent : Color(nsColor: .separatorColor), lineWidth: selectedImageIndex == idx ? 2 : 0.8)
                                                )
                                            
                                            Text("Trang \(idx + 1)")
                                                .font(.system(size: 9.5, weight: selectedImageIndex == idx ? .bold : .regular))
                                                .foregroundColor(selectedImageIndex == idx ? AppColors.accent : .secondary)
                                        }
                                        .onTapGesture {
                                            selectedImageIndex = idx
                                        }
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        
                        // Active Image Preview
                        if selectedImageIndex < images.count {
                            Image(nsImage: images[selectedImageIndex])
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 260)
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor), lineWidth: 0.8))
                        }
                        
                        // Action Toolbar
                        HStack(spacing: 8) {
                            Button(action: { copySingle(index: selectedImageIndex) }) {
                                Label("Copy Trang Này", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            if images.count > 1 {
                                Button(action: { copyAll() }) {
                                    Label("Copy Tất Cả (\(images.count))", systemImage: "square.on.square")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            
                            Button(action: { saveAll() }) {
                                Label("Lưu Thư Mục...", systemImage: "arrow.down.to.line")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            Spacer()
                            
                            Button(action: { performAIGrading() }) {
                                Label(isProcessingAI ? "Đang Phân Tích..." : "Chấm Điểm AI", systemImage: "sparkles")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(isProcessingAI)
                        }
                    }
                    .padding(4)
                } label: {
                    Label("Bài Giải Hoàn Thành", systemImage: "doc.text.image")
                        .font(.system(size: 12, weight: .semibold))
                }
            }
        }
    }
    
    // MARK: - TAB 3: THỐNG KÊ (STATS)
    private var statsView: some View {
        VStack(spacing: 14) {
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 14) {
                        statTile(title: "Bài Tập Hôm Nay", value: "\(hwStats.completedToday) / \(hwStats.dailyGoal)", icon: "pencil", color: .blue)
                        statTile(title: "Chuỗi Ngày Liên Tục", value: "\(hwStats.homeworkStreak) ngày", icon: "flame.fill", color: .orange)
                        statTile(title: "Tổng Bài Đã Nộp", value: "\(hwStats.totalCompleted)", icon: "checkmark.seal.fill", color: .green)
                    }
                }
                .padding(4)
            } label: {
                Label("Tiến Trình Học Tập", systemImage: "chart.bar.fill")
                    .font(.system(size: 12, weight: .semibold))
            }
        }
    }
    
    private func statTile(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }
    
    // MARK: - Drop & File Helpers
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    
                    DispatchQueue.main.async {
                        let ext = url.pathExtension.lowercased()
                        if ext == "pdf", let pdfData = try? Data(contentsOf: url) {
                            self.previewPdfPageIndex = 0
                            self.server.setTaskPDF(data: pdfData, fileName: url.lastPathComponent)
                            self.flashSuccess(msg: "Đã nạp file PDF: \(url.lastPathComponent)")
                        } else if ["png", "jpg", "jpeg", "webp", "heic", "tiff"].contains(ext),
                                  let img = NSImage(contentsOf: url) {
                            self.server.setTask(text: "Ảnh: \(url.lastPathComponent)", image: img, pdfData: nil, pdfFileName: nil)
                            self.flashSuccess(msg: "Đã nạp file Ảnh: \(url.lastPathComponent)")
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
                            self.flashSuccess(msg: "Đã nạp đề bài văn bản!")
                        }
                    } else if let data = item as? Data, let text = String(data: data, encoding: .utf8) {
                        DispatchQueue.main.async {
                            self.server.setTask(text: text, image: nil, pdfData: nil, pdfFileName: nil)
                            self.flashSuccess(msg: "Đã nạp đề bài văn bản!")
                        }
                    }
                }
                return true
            }
        }
        return false
    }
    
    private func flashSuccess(msg: String) {
        dropSuccessMessage = msg
        dropSuccessFlash = true
        NSSound(named: "Glass")?.play()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            dropSuccessFlash = false
        }
    }
    
    private func choosePDF() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Gửi sang iPad"
        if panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) {
            previewPdfPageIndex = 0
            server.setTaskPDF(data: data, fileName: url.lastPathComponent)
            flashSuccess(msg: "Đã nạp file PDF: \(url.lastPathComponent)")
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
            flashSuccess(msg: "Đã nạp file Ảnh: \(url.lastPathComponent)")
        }
    }
    
    private func pasteClipboard() {
        let pb = NSPasteboard.general
        if let pdfData = pb.data(forType: .pdf) {
            previewPdfPageIndex = 0
            server.setTaskPDF(data: pdfData, fileName: "Clipboard_Document.pdf")
            flashSuccess(msg: "Đã dán tài liệu PDF!")
        } else if let img = NSImage(pasteboard: pb) {
            server.setTask(text: "Ảnh từ Clipboard", image: img, pdfData: nil, pdfFileName: nil)
            flashSuccess(msg: "Đã dán Ảnh từ Clipboard!")
        } else if let text = pb.string(forType: .string), !text.isEmpty {
            server.setTask(text: text, image: nil, pdfData: nil, pdfFileName: nil)
            flashSuccess(msg: "Đã dán đề bài từ Clipboard!")
        }
    }
    
    private func copySingle(index: Int) {
        guard index < server.lastSubmittedImages.count else { return }
        let img = server.lastSubmittedImages[index]
        if let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            let pb = NSPasteboard.general
            pb.clearContents()
            let item = NSPasteboardItem()
            item.setData(png, forType: .png)
            item.setData(tiff, forType: .tiff)
            pb.writeObjects([item])
            NSSound(named: "Glass")?.play()
        }
    }
    
    private func copyAll() {
        let pb = NSPasteboard.general
        pb.clearContents()
        var items: [NSPasteboardItem] = []
        for img in server.lastSubmittedImages {
            if let tiff = img.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                let item = NSPasteboardItem()
                item.setData(png, forType: .png)
                item.setData(tiff, forType: .tiff)
                items.append(item)
            }
        }
        if !items.isEmpty {
            pb.writeObjects(items)
            NSSound(named: "Glass")?.play()
        }
    }
    
    private func saveAll() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Lưu ảnh vào thư mục này"
        
        if panel.runModal() == .OK, let folderURL = panel.url {
            let timestamp = Int(Date().timeIntervalSince1970)
            for (idx, img) in server.lastSubmittedImages.enumerated() {
                if let tiff = img.tiffRepresentation,
                   let rep = NSBitmapImageRep(data: tiff),
                   let png = rep.representation(using: .png, properties: [:]) {
                    let fileURL = folderURL.appendingPathComponent("NekoTrans_Homework_\(timestamp)_Page\(idx + 1).png")
                    try? png.write(to: fileURL)
                }
            }
            NSWorkspace.shared.activateFileViewerSelecting([folderURL])
        }
    }
    
    private func generateQRCode(from string: String) -> NSImage? {
        guard let data = string.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        
        guard let outputImage = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 5, y: 5)
        let scaledImage = outputImage.transformed(by: transform)
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: scaledImage.extent.width, height: scaledImage.extent.height))
    }
    
    private func performAIGrading() {
        isProcessingAI = true
        let allExtractedText = server.lastSubmittedText ?? ""
        let taskContext = server.currentTaskText
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isProcessingAI = false
            let gradingPrompt = """
            Bạn là một giáo viên chuyên nghiệp. Dưới đây là nội dung toàn bộ bài làm được học sinh hoàn thành trên iPad (Apple Pencil đa trang):
            
            [NỘI DUNG ĐỀ BÀI]:
            \(taskContext.isEmpty ? "Bài tập giải trên iPad" : taskContext)
            
            [BÀI LÀM CỦA HỌC SINH TỪ TẤT CẢ CÁC TRANG]:
            \(allExtractedText.isEmpty ? taskContext : allExtractedText)
            
            [YÊU CẦU CHẤM ĐIỂM & ĐÁNH GIÁ CHI TIẾT]:
            1. Chấm điểm toàn bài trên thang điểm 10.
            2. Phân tích chi tiết từng câu / từng trang: Chỉ rõ câu nào ĐÚNG, câu nào SAI.
            3. Giải thích cặn kẽ lỗi sai và đưa ra lời giải chuẩn xác, tối ưu nhất.
            4. Nhận xét tổng kết và lời khuyên để học sinh cải thiện.
            """
            QuickAIWindowController.shared.showAI(prompt: gradingPrompt)
        }
    }
}

// MARK: - Backward Compatibility Bridge
public typealias ContinuityHomeworkController = ContinuityHomeworkWindowController
