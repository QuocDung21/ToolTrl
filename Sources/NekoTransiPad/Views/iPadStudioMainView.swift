import SwiftUI
#if canImport(PencilKit) && canImport(UIKit)
import PencilKit
import UIKit
import AudioToolbox

public struct iPadStudioMainView: View {
    @ObservedObject var client = iPadSyncClient.shared
    @State private var canvasView = PKCanvasView()
    @State private var toolPicker = PKToolPicker()
    @State private var isToolPickerVisible: Bool = true
    @State private var allowFingerDrawing: Bool = false
    @State private var isHeaderHidden: Bool = false
    @State private var showConnectionSheet: Bool = false
    @State private var showSentBanner: Bool = false
    @State private var showNewTaskToast: Bool = false
    @State private var isWorksheetGlowFlashing: Bool = false
    @State private var connectionTab: Int = 0 // 0: Radar, 1: QR Scan, 2: Manual IP
    @State private var inputHost: String = ""
    @State private var inputPort: String = "8099"
    @State private var isDrawingEmpty: Bool = true
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Dynamic Island Alert Banner for Incoming New Task
                if showNewTaskToast {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 38, height: 38)
                                .shadow(color: Color.blue.opacity(0.4), radius: 4, x: 0, y: 2)
                            
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("📥 ĐÃ NHẬN ĐỀ BÀI MỚI TỪ MAC!")
                                .font(.system(size: 13, weight: .black))
                                .foregroundColor(.primary)
                            
                            Text(client.currentTaskText.isEmpty ? "Đã xóa nét cũ & chuẩn bị trang làm bài" : String(client.currentTaskText.prefix(60)) + "...")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "pencil.tip")
                            Text("Làm ngay")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.12))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color.blue.opacity(0.4), lineWidth: 1.5)
                            )
                            .shadow(color: Color.blue.opacity(0.25), radius: 14, x: 0, y: 6)
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Floating AirDrop Sent Notification Banner
                if showSentBanner {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Đã gửi bài sang máy Mac thành công!")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                        Spacer()
                        Text("📋 Đã copy vào Clipboard Mac")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Unified Worksheet with Paper, Question Text/Image, and Top-Layer PencilKit
                ZStack(alignment: .top) {
                    ScrollView {
                        ZStack(alignment: .topLeading) {
                            // 1. UNDERLYING WORKSHEET LAYER (Question text, OCR image, notebook lines)
                            worksheetBackgroundView
                            
                            // 2. NATIVE APPLE PENCILKIT CANVAS LAYER (Directly over the entire worksheet)
                            PencilKitCanvasView(
                                canvasView: $canvasView,
                                toolPicker: toolPicker,
                                isToolPickerVisible: isToolPickerVisible,
                                allowFingerDrawing: allowFingerDrawing
                            ) {
                                isDrawingEmpty = canvasView.drawing.bounds.isEmpty
                            }
                            .id(client.currentTaskId.isEmpty ? "default_canvas" : client.currentTaskId)
                            .frame(minHeight: 1800)
                        }
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.blue.opacity(isWorksheetGlowFlashing ? 0.85 : 0.0), lineWidth: 3.5)
                        )
                        .shadow(color: isWorksheetGlowFlashing ? Color.blue.opacity(0.3) : Color.black.opacity(0.08), radius: isWorksheetGlowFlashing ? 16 : 10, x: 0, y: 4)
                        .padding(16)
                    }
                    .background(Color(uiColor: .secondarySystemBackground))
                    
                    // 3. Floating Quick Header Bar (Visible when main header is collapsed)
                    if isHeaderHidden {
                        floatingCollapsedTopBar
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // 4. Floating Quick Pen Toolbar (Bottom Right Dock)
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            floatingPenQuickBar
                                .padding(24)
                        }
                    }
                }
            }
            .navigationTitle(isHeaderHidden ? "" : "NekoTrans • iPad Apple Pencil Studio")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(isHeaderHidden)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if client.isConnected {
                        Button(action: { showConnectionSheet = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "macbook.and.ipad")
                                    .font(.system(size: 13, weight: .bold))
                                Text(client.discoveredMacName.isEmpty ? "Đã nối: \(client.serverHost)" : "Đã nối: \(client.discoveredMacName)")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(.green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.green.opacity(0.12))
                            .cornerRadius(16)
                        }
                    } else if client.isSearchingBonjour {
                        Button(action: {
                            connectionTab = 0
                            showConnectionSheet = true
                        }) {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Đang tìm Mac...")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.gray.opacity(0.12))
                            .cornerRadius(16)
                        }
                    } else {
                        Button(action: {
                            connectionTab = 0
                            showConnectionSheet = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Kết Nối Mac")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .cornerRadius(16)
                        }
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Hide Header Icon Button (Toàn màn hình)
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            isHeaderHidden = true
                        }
                    }) {
                        Label("Ẩn Header", systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                    .help("Ẩn thanh tiêu đề trên cùng để tối đa diện tích viết bài")

                    // Apple Pencil Floating ToolPicker Toggle
                    Button(action: {
                        isToolPickerVisible.toggle()
                        toolPicker.setVisible(isToolPickerVisible, forFirstResponder: canvasView)
                        if isToolPickerVisible {
                            canvasView.becomeFirstResponder()
                        }
                    }) {
                        Label(
                            isToolPickerVisible ? "Ẩn Hộp Bút" : "Hiện Hộp Bút",
                            systemImage: isToolPickerVisible ? "pencil.tip.crop.circle.fill" : "pencil.tip.crop.circle"
                        )
                    }
                    .help("Bật/Tắt thanh công cụ Apple Pencil chuẩn iPadOS")
                    
                    // Finger Drawing Toggle (Palm Rejection Mode)
                    Button(action: {
                        allowFingerDrawing.toggle()
                        canvasView.drawingPolicy = allowFingerDrawing ? .anyInput : .pencilOnly
                    }) {
                        Label(
                            allowFingerDrawing ? "Chế độ: Bút & Tay" : "Chế độ: Chỉ Apple Pencil",
                            systemImage: allowFingerDrawing ? "hand.draw.fill" : "hand.raised.fill"
                        )
                    }
                    .tint(allowFingerDrawing ? .orange : .blue)
                    .help(allowFingerDrawing ? "Đang cho phép vẽ bằng tay & bút" : "Đang bật chống chạm tay (chỉ nhận Apple Pencil)")
                    
                    Button(action: {
                        Task { await client.fetchTaskFromMac() }
                    }) {
                        Label("Tải Đề Mới", systemImage: "arrow.triangle.2.circlepath")
                    }
                    
                    Button(role: .destructive, action: {
                        clearDrawing()
                    }) {
                        Label("Xóa Nét", systemImage: "trash")
                    }
                    
                    Button(action: {
                        submitDrawing()
                    }) {
                        HStack(spacing: 5) {
                            if client.isSubmitting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                                    Text("Đang gửi...")
                                        .font(.system(size: 14, weight: .bold))
                            } else {
                                Image(systemName: "paperplane.fill")
                                Text("Gửi Sang Mac")
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(client.isSubmitting)
                }
            }
            .sheet(isPresented: $showConnectionSheet) {
                connectionModalSheet
            }
            .onChange(of: client.currentTaskId) { _ in
                notifyNewTaskReceived()
            }
            .onChange(of: client.currentTaskText) { _ in
                notifyNewTaskReceived()
            }
            .task {
                // 1. Hook up Real-Time New Task Detection
                client.onNewTaskReceived = {
                    notifyNewTaskReceived()
                }
                
                // 2. Start Apple Continuity Zero-Config Bonjour Auto-Discovery & Real-Time Sync Loop
                client.startAutoDiscovery()
                
                // 3. If previously paired, fetch task immediately
                if !client.serverHost.isEmpty {
                    await client.fetchTaskFromMac()
                }
            }
        }
    }
    
    // MARK: - Incoming New Task Alert & Canvas Reset Helper
    @MainActor
    private func notifyNewTaskReceived() {
        // 1. Clean previous strokes
        clearDrawing()
        
        // 2. Play Apple System Chime / Incoming Sound
        AudioServicesPlaySystemSound(1007)
        
        // 3. Dual Haptic Pulses
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        
        // 4. Trigger Dynamic Toast & Glowing Halo Border
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            showNewTaskToast = true
            isWorksheetGlowFlashing = true
        }
        
        // 5. Fade Halo Glow after 1.5s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.5)) {
                isWorksheetGlowFlashing = false
            }
        }
        
        // 6. Dismiss Toast Banner after 4.0s
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showNewTaskToast = false
            }
        }
    }
    
    @MainActor
    private func clearDrawing() {
        canvasView.drawing = PKDrawing()
        canvasView.undoManager?.removeAllActions()
        canvasView.setNeedsDisplay()
        isDrawingEmpty = true
        
        DispatchQueue.main.async {
            self.canvasView.drawing = PKDrawing()
            self.canvasView.undoManager?.removeAllActions()
            self.canvasView.setNeedsDisplay()
            self.isDrawingEmpty = true
        }
    }
    
    // MARK: - Worksheet Background Content
    private var worksheetBackgroundView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Task Header & Content (Directly writable underneath PencilKit)
            taskHeaderAndContentView
                .padding(24)
            
            Divider()
                .opacity(0.3)
                .padding(.horizontal, 16)
            
            // Ruled Paper Area for Scratch / Calculations
            RuledPaperBackground()
                .frame(minHeight: 1200)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Task Header & Content (Underneath Drawing Layer)
    private var taskHeaderAndContentView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "pencil.and.scribble")
                        .font(.system(size: 11, weight: .bold))
                    Text("ĐỀ BÀI TẬP TỪ MAC")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.12))
                .cornerRadius(5)
                
                Text("• Dùng bút khoanh trực tiếp đáp án A, B, C, D hoặc viết lên đề")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            if !client.currentTaskText.isEmpty {
                Text(client.currentTaskText)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(.primary)
                    .lineSpacing(6)
            } else {
                Text("Chưa có đề bài. Hãy quét bài tập trên máy Mac và bấm 'Gửi sang iPad'.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            
            if let taskImg = client.currentTaskImage {
                Image(uiImage: taskImg)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
        }
    }
    
    // MARK: - Connection Modal Sheet (Radar Map + QR Scanner + Manual IP)
    private var connectionModalSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented Switcher
                Picker("Chế độ kết nối", selection: $connectionTab) {
                    Text("📡 Bản Đồ Radar").tag(0)
                    Text("📷 Quét Mã QR").tag(1)
                    Text("⌨️ Nhập IP").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 14)
                
                if connectionTab == 0 {
                    // Radar Circular Map View
                    RadarDeviceDiscoveryView { device in
                        client.selectDevice(device)
                        showConnectionSheet = false
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if connectionTab == 1 {
                    // QR Scanner View
                    ZStack {
                        QRCodeScannerView(onScanResult: { scannedCode in
                            handleScannedQRCode(scannedCode)
                        }, onDismiss: {
                            showConnectionSheet = false
                        })
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Manual IP Entry Form
                    Form {
                        Section(header: Text("ĐỊA CHỈ MÁY MAC TRONG MẠNG WI-FI")) {
                            TextField("VD: 192.168.1.15 hoặc macbook.local", text: $inputHost)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            
                            TextField("Port (mặc định 8099)", text: $inputPort)
                                .keyboardType(.numberPad)
                            
                            Button("Kết Nối Ngay") {
                                connectManually()
                            }
                            .disabled(inputHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        
                        Section(header: Text("TRẠNG THÁI HIỆN TẠI")) {
                            Text(client.statusMessage)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Kết Nối NekoTrans Mac")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { showConnectionSheet = false }
                }
            }
            .onAppear {
                inputHost = client.serverHost
                inputPort = String(client.serverPort)
            }
        }
    }
    
    private func handleScannedQRCode(_ code: String) {
        client.setHost(code)
        showConnectionSheet = false
        Task {
            await client.fetchTaskFromMac()
        }
    }
    
    private func connectManually() {
        if let p = Int(inputPort.trimmingCharacters(in: .whitespacesAndNewlines)) {
            client.serverPort = p
        }
        client.setHost(inputHost)
        showConnectionSheet = false
        Task {
            await client.fetchTaskFromMac()
        }
    }
    
    // MARK: - Submit Full Composite Image (Task Background + Pencil Strokes)
    @MainActor
    private func submitDrawing() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        
        let finalComposite = generateFullCompositeWorksheetImage()
        
        Task {
            let success = await client.submitDrawingToMac(image: finalComposite)
            if success {
                generator.impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    self.showSentBanner = true
                }
                
                // Auto hide banner after 3 seconds
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.showSentBanner = false
                }
            }
        }
    }
    
    @MainActor
    private func generateFullCompositeWorksheetImage() -> UIImage {
        return autoreleasepool {
            let canvasWidth = max(canvasView.bounds.width, 768)
            let drawingBounds = canvasView.drawing.bounds
            let padding: CGFloat = 24
            let contentWidth = canvasWidth - (padding * 2)
            
            var currentY: CGFloat = padding
            
            // 1. Measure Question Text
            let textFont = UIFont.systemFont(ofSize: 19, weight: .medium)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 6
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: textFont,
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraphStyle
            ]
            
            let questionText = client.currentTaskText.isEmpty ? "Đề bài tập từ Mac" : client.currentTaskText
            let attributedText = NSAttributedString(string: questionText, attributes: textAttributes)
            let textRect = attributedText.boundingRect(
                with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            
            // 2. Measure OCR Image if present
            var imageDrawRect: CGRect = .zero
            if let taskImg = client.currentTaskImage {
                let imgAspect = taskImg.size.height / max(taskImg.size.width, 1)
                let imgHeight = min(contentWidth * imgAspect, 600)
                imageDrawRect = CGRect(x: padding, y: 0, width: contentWidth, height: imgHeight)
            }
            
            // Total calculated content height
            var totalNeededHeight = padding + 32 + 12 + ceil(textRect.height) + 20
            if imageDrawRect.height > 0 {
                totalNeededHeight += imageDrawRect.height + 20
            }
            totalNeededHeight += 40
            
            let finalHeight = max(max(totalNeededHeight + 150, drawingBounds.maxY + 120), 750)
            let renderSize = CGSize(width: canvasWidth, height: min(finalHeight, 3000))
            let targetRect = CGRect(origin: .zero, size: renderSize)
            
            let format = UIGraphicsImageRendererFormat()
            format.scale = 2.0
            format.opaque = true
            let renderer = UIGraphicsImageRenderer(size: renderSize, format: format)
            
            return renderer.image { ctx in
                let cgCtx = ctx.cgContext
                
                // 1. White Paper Base
                UIColor.systemBackground.setFill()
                ctx.fill(targetRect)
                
                // 2. Subtle Ruled Notebook Lines
                UIColor.systemGray5.setStroke()
                cgCtx.setLineWidth(1.0)
                let lineSpacing: CGFloat = 28.0
                var yLine: CGFloat = 80.0
                while yLine < renderSize.height - 20 {
                    cgCtx.move(to: CGPoint(x: 20, y: yLine))
                    cgCtx.addLine(to: CGPoint(x: renderSize.width - 20, y: yLine))
                    cgCtx.strokePath()
                    yLine += lineSpacing
                }
            
            // 3. Draw Header Badge: "✍️ ĐỀ BÀI TẬP TỪ MAC"
            let badgeRect = CGRect(x: padding, y: currentY, width: 175, height: 26)
            let badgePath = UIBezierPath(roundedRect: badgeRect, cornerRadius: 6)
            UIColor.systemBlue.withAlphaComponent(0.12).setFill()
            badgePath.fill()
            
            let badgeAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .bold),
                .foregroundColor: UIColor.systemBlue
            ]
            let badgeString = NSAttributedString(string: "✍️ ĐỀ BÀI TẬP TỪ MAC", attributes: badgeAttributes)
            badgeString.draw(at: CGPoint(x: padding + 8, y: currentY + 5))
            currentY += 36
            
            // 4. Draw Question Text
            let textDrawRect = CGRect(x: padding, y: currentY, width: contentWidth, height: ceil(textRect.height))
            attributedText.draw(in: textDrawRect)
            currentY += ceil(textRect.height) + 16
            
            // 5. Draw Question Image if available
            if let taskImg = client.currentTaskImage, imageDrawRect.height > 0 {
                imageDrawRect.origin.y = currentY
                taskImg.draw(in: imageDrawRect)
                currentY += imageDrawRect.height + 16
            }
            
            // 6. Draw Divider
            UIColor.separator.setStroke()
            cgCtx.setLineWidth(0.5)
            cgCtx.move(to: CGPoint(x: padding, y: currentY))
            cgCtx.addLine(to: CGPoint(x: renderSize.width - padding, y: currentY))
            cgCtx.strokePath()
            
            // 7. Draw Student's Apple Pencil Handwriting Strokes on top
            let drawingImage = canvasView.drawing.image(from: targetRect, scale: 2.0)
            drawingImage.draw(in: targetRect)
        }
    }
}
    
    // MARK: - Floating Quick Pen Palette (iPad Bottom Dock)
    private var floatingPenQuickBar: some View {
        HStack(spacing: 10) {
            // Blue Pen
            Button(action: {
                canvasView.tool = PKInkingTool(.pen, color: .systemBlue, width: 2.5)
                canvasView.becomeFirstResponder()
            }) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
            }
            .help("Bút bi xanh")
            
            // Red Pen
            Button(action: {
                canvasView.tool = PKInkingTool(.pen, color: .systemRed, width: 2.5)
                canvasView.becomeFirstResponder()
            }) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
            }
            .help("Bút đỏ chấm bài")
            
            // Yellow Highlighter
            Button(action: {
                canvasView.tool = PKInkingTool(.marker, color: .systemYellow, width: 12.0)
                canvasView.becomeFirstResponder()
            }) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.yellow)
                    .frame(width: 22, height: 22)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white, lineWidth: 1.5))
            }
            .help("Bút dạ quang vàng")
            
            // Eraser
            Button(action: {
                canvasView.tool = PKEraserTool(.vector)
                canvasView.becomeFirstResponder()
            }) {
                Image(systemName: "eraser.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 28, height: 28)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(6)
            }
            .help("Tẩy nét vẽ")
            
            Divider()
                .frame(height: 18)
                .padding(.horizontal, 2)
            
            // Undo
            Button(action: {
                canvasView.undoManager?.undo()
            }) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 28, height: 28)
                    .background(Color.gray.opacity(0.12))
                    .cornerRadius(6)
            }
            .help("Hoàn tác (Undo)")
            
            // Redo
            Button(action: {
                canvasView.undoManager?.redo()
            }) {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 28, height: 28)
                    .background(Color.gray.opacity(0.12))
                    .cornerRadius(6)
            }
            .help("Làm lại (Redo)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: Color.black.opacity(0.14), radius: 10, x: 0, y: 3)
        )
    }
    
    // MARK: - Floating Header Action Bar (Visible when Header is Collapsed)
    private var floatingCollapsedTopBar: some View {
        HStack(spacing: 10) {
            // Restore Header Button
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    isHeaderHidden = false
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                    Text("Hiện Header")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        .shadow(color: Color.black.opacity(0.14), radius: 8, x: 0, y: 3)
                )
            }
            
            Spacer()
            
            // Quick Refresh Task
            Button(action: {
                Task { await client.fetchTaskFromMac() }
            }) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
                    )
            }
            .help("Tải đề bài mới từ Mac")
            
            // Quick Clear Drawing
            Button(action: {
                clearDrawing()
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.red)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
                    )
            }
            .help("Xóa nét vẽ")
            
            // PROMINENT FLOATING SEND BUTTON (Chừa lại nút Send nổi)
            Button(action: {
                submitDrawing()
            }) {
                HStack(spacing: 6) {
                    if client.isSubmitting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                        Text("Đang gửi...")
                            .font(.system(size: 13.5, weight: .bold))
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("Gửi Sang Mac")
                            .font(.system(size: 13.5, weight: .bold))
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.blue)
                        .shadow(color: Color.blue.opacity(0.38), radius: 8, x: 0, y: 3)
                )
            }
            .disabled(client.isSubmitting)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
}

// MARK: - Ruled Paper Background View
struct RuledPaperBackground: View {
    var body: some View {
        Canvas { context, size in
            let lineHeight: CGFloat = 34
            var y: CGFloat = lineHeight
            
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(Color.gray.opacity(0.15)), lineWidth: 1)
                y += lineHeight
            }
        }
    }
}

#if DEBUG
#Preview("iPad Apple Pencil Studio") {
    iPadStudioMainView()
        .preferredColorScheme(.light)
}
#endif
#endif

