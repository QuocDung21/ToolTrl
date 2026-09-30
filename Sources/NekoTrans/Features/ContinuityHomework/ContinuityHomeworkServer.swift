import Foundation
import Network
import AppKit
import Vision
import PDFKit

public final class ContinuityHomeworkServer: ObservableObject {
    public static let shared = ContinuityHomeworkServer()

    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var serverPort: UInt16 = 8099
    @Published public private(set) var currentTaskId: String = UUID().uuidString
    @Published public private(set) var currentTaskText: String = ""
    @Published public private(set) var currentTaskImageData: Data? = nil
    @Published public private(set) var currentTaskPDFData: Data? = nil
    @Published public private(set) var currentTaskPDFFileName: String? = nil
    @Published public private(set) var currentTaskPDFPageCount: Int = 0
    
    @Published public private(set) var lastSubmittedImages: [NSImage] = []
    @Published public private(set) var lastSubmittedImage: NSImage? = nil
    @Published public private(set) var lastSubmittedText: String? = nil
    @Published public private(set) var submissionCount: Int = 0

    private var currentPDFDocument: PDFDocument? = nil
    private let pageCache = NSCache<NSNumber, NSData>()
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.nekotrans.mac.continuity.server", qos: .userInitiated)

    private init() {
        pageCache.countLimit = 6 // Cache max 6 pages in memory to keep RAM usage ultra-low (< 20MB)
    }

    public func startServer(port: UInt16 = 8099) {
        guard !isRunning else { return }
        self.serverPort = port

        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            let newListener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)

            // Broadcast Bonjour Service across Apple Local Ecosystem
            let hostName = Host.current().localizedName ?? "Mac"
            // The service *type* is frozen: it is the discovery protocol shared with the
            // iPad app, so changing it here alone would break pairing with any build
            // already installed on the tablet. Only the display name is rebranded.
            newListener.service = NWListener.Service(name: "NekoTrans-\(hostName)", type: "_tooltrl._tcp")

            newListener.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.isRunning = true
                    case .failed, .cancelled:
                        self?.isRunning = false
                    default:
                        break
                    }
                }
            }

            newListener.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            self.listener = newListener
            newListener.start(queue: queue)
        } catch {
            AppLog.continuity.error("Server start failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func stopServer() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    /// Set or update the current task (optimized for memory efficiency)
    public func setTask(text: String = "", image: NSImage? = nil, pdfData: Data? = nil, pdfFileName: String? = nil) {
        // Clear previous memory cache
        pageCache.removeAllObjects()
        
        self.currentTaskId = UUID().uuidString
        self.currentTaskText = text
        self.currentTaskPDFData = pdfData
        self.currentTaskPDFFileName = pdfFileName
        
        if let image = image, let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
            self.currentTaskImageData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.82])
        } else {
            self.currentTaskImageData = nil
        }
        
        // Fast PDF metadata parsing without rendering all pages into RAM
        if let pdfData = pdfData, let pdfDoc = PDFDocument(data: pdfData) {
            self.currentPDFDocument = pdfDoc
            self.currentTaskPDFPageCount = pdfDoc.pageCount
        } else {
            self.currentPDFDocument = nil
            self.currentTaskPDFPageCount = 0
        }
    }

    public func setTaskPDF(data: Data, fileName: String) {
        setTask(text: "Tài liệu PDF: \(fileName)", image: nil, pdfData: data, pdfFileName: fileName)
    }

    /// Complete memory cleanup to free all cached resources and prevent leaks
    public func clearTask() {
        pageCache.removeAllObjects()
        self.currentTaskId = UUID().uuidString
        self.currentTaskText = ""
        self.currentTaskImageData = nil
        self.currentTaskPDFData = nil
        self.currentTaskPDFFileName = nil
        self.currentPDFDocument = nil
        self.currentTaskPDFPageCount = 0
        self.lastSubmittedImages.removeAll()
        self.lastSubmittedImage = nil
        self.lastSubmittedText = nil
    }

    /// On-demand lazy render for a single PDF page with memory safety and JPEG compression
    public func renderPDFPage(at index: Int, maxDimension: CGFloat = 1600) -> Data? {
        if let cached = pageCache.object(forKey: NSNumber(value: index)) {
            return cached as Data
        }
        
        guard let doc = currentPDFDocument, index >= 0, index < doc.pageCount,
              let page = doc.page(at: index) else { return nil }
        
        return autoreleasepool {
            let bounds = page.bounds(for: .mediaBox)
            guard bounds.width > 0, bounds.height > 0 else { return nil }
            
            let scale = min(maxDimension / max(bounds.width, bounds.height), 2.0)
            let targetSize = NSSize(width: max(50, bounds.width * scale), height: max(50, bounds.height * scale))
            
            let img = NSImage(size: targetSize)
            img.lockFocus()
            if let ctx = NSGraphicsContext.current?.cgContext {
                ctx.setFillColor(NSColor.white.cgColor)
                ctx.fill(CGRect(origin: .zero, size: targetSize))
                ctx.scaleBy(x: scale, y: scale)
                page.draw(with: .mediaBox, to: ctx)
            }
            img.unlockFocus()
            
            if let tiff = img.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff),
               let jpegData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.82]) {
                pageCache.setObject(jpegData as NSData, forKey: NSNumber(value: index))
                return jpegData
            }
            return nil
        }
    }

    public func getLocalIPAddress() -> String {
        var address: String = "localhost"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return address }
        guard let firstAddr = ifaddr else { return address }

        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            guard let ifaAddr = interface.ifa_addr else { continue }
            let addrFamily = ifaAddr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "en1" || name == "bridge0" || name == "pdp_ip0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(ifaAddr, socklen_t(ifaAddr.pointee.sa_len),
                                   &hostname, socklen_t(hostname.count),
                                   nil, socklen_t(0), NI_NUMERICHOST) == 0 {
                        address = String(cString: hostname)
                        break
                    }
                }
            }
        }
        freeifaddrs(ifaddr)
        return address
    }

    // MARK: - HTTP Server Core
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveHTTPRequest(connection, accumulatedData: Data())
    }

    private func receiveHTTPRequest(_ connection: NWConnection, accumulatedData: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536 * 16) { [weak self] chunk, _, isComplete, error in
            guard let self = self else { return }

            var buffer = accumulatedData
            if let chunk = chunk, !chunk.isEmpty {
                buffer.append(chunk)
            }

            // Check for HTTP Header Delimiter (\r\n\r\n)
            if let headerEnd = buffer.range(of: Data("\r\n\r\n".utf8)) {
                let headerData = buffer.subdata(in: 0..<headerEnd.lowerBound)
                let bodyData = buffer.subdata(in: headerEnd.upperBound..<buffer.count)

                if let headerString = String(data: headerData, encoding: .utf8) {
                    var expectedLength: Int? = nil
                    for line in headerString.components(separatedBy: "\r\n") {
                        let lower = line.lowercased()
                        if lower.hasPrefix("content-length:") {
                            let parts = line.components(separatedBy: ":")
                            if parts.count >= 2 {
                                expectedLength = Int(parts[1].trimmingCharacters(in: .whitespaces))
                            }
                        }
                    }

                    // If Content-Length is specified, wait until all body bytes are received
                    if let expected = expectedLength {
                        if bodyData.count < expected && !isComplete {
                            self.receiveHTTPRequest(connection, accumulatedData: buffer)
                            return
                        }
                    }

                    // Full HTTP message received!
                    let lines = headerString.components(separatedBy: "\r\n")
                    if let firstLine = lines.first {
                        let parts = firstLine.components(separatedBy: " ")
                        if parts.count >= 2 {
                            let method = parts[0]
                            let path = parts[1]
                            self.routeRequest(method: method, path: path, bodyData: bodyData, headerString: headerString, connection: connection)
                            return
                        }
                    }
                }
            }

            // If header not yet complete and connection still open, continue accumulating
            if !isComplete && (error == nil) {
                self.receiveHTTPRequest(connection, accumulatedData: buffer)
            } else {
                connection.cancel()
            }
        }
    }

    private func decodeBase64Image(_ base64String: String) -> NSImage? {
        let clean = base64String
            .replacingOccurrences(of: "data:image/png;base64,", with: "")
            .replacingOccurrences(of: "data:image/jpeg;base64,", with: "")
            .replacingOccurrences(of: "data:image/jpg;base64,", with: "")
        guard let data = Data(base64Encoded: clean, options: .ignoreUnknownCharacters) else { return nil }
        return NSImage(data: data)
    }

    private func routeRequest(method: String, path: String, bodyData: Data, headerString: String, connection: NWConnection) {
        let cleanPath = path.components(separatedBy: "?").first ?? path
        
        if cleanPath == "/" || cleanPath == "/index.html" {
            // Serve iPad Web Studio App
            let htmlContent = IPadStudioWebPage.html()
            let htmlData = htmlContent.data(using: .utf8) ?? Data()
            sendResponse(connection: connection, statusCode: 200, contentType: "text/html; charset=utf-8", body: htmlData)
        } else if cleanPath == "/api/task" {
            // Lightweight Task Metadata (No heavy base64 strings!)
            var taskDict: [String: Any] = [
                "taskId": currentTaskId,
                "text": currentTaskText,
                "hasImage": currentTaskImageData != nil,
                "hasPDF": currentTaskPDFData != nil,
                "pdfFileName": currentTaskPDFFileName ?? "",
                "pdfPagesCount": currentTaskPDFPageCount
            ]
            if let imgData = currentTaskImageData {
                taskDict["imageBase64"] = "data:image/jpeg;base64,\(imgData.base64EncodedString())"
            }
            let jsonData = (try? JSONSerialization.data(withJSONObject: taskDict, options: [])) ?? Data()
            sendResponse(connection: connection, statusCode: 200, contentType: "application/json", body: jsonData)
        } else if cleanPath == "/api/pdf" && currentTaskPDFData != nil {
            let pdfData = currentTaskPDFData ?? Data()
            let fileName = currentTaskPDFFileName ?? "document.pdf"
            sendPDFResponse(connection: connection, pdfData: pdfData, fileName: fileName)
        } else if cleanPath.hasPrefix("/api/pdf/page/") {
            let indexStr = cleanPath.replacingOccurrences(of: "/api/pdf/page/", with: "")
            if let index = Int(indexStr), let pageJpeg = renderPDFPage(at: index) {
                sendResponse(connection: connection, statusCode: 200, contentType: "image/jpeg", body: pageJpeg)
            } else {
                sendResponse(connection: connection, statusCode: 404, contentType: "text/plain", body: "Page not found".data(using: .utf8)!)
            }
        } else if cleanPath == "/api/submit" && method == "POST" {
            var submittedImagesList: [NSImage] = []
            var userNotes: String = ""

            if let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] {
                // Support multiple images array (`images`)
                if let imagesArray = json["images"] as? [String] {
                    for base64Str in imagesArray {
                        if let img = decodeBase64Image(base64Str) {
                            submittedImagesList.append(img)
                        }
                    }
                }
                
                // Fallback to single imageBase64 if images array is empty
                if submittedImagesList.isEmpty, let base64String = json["imageBase64"] as? String {
                    if let img = decodeBase64Image(base64String) {
                        submittedImagesList.append(img)
                    }
                }
                
                if let notes = json["notes"] as? String {
                    userNotes = notes
                }
            }

            let finalImages = submittedImagesList
            let primaryImage = finalImages.first
            let notesText = userNotes

            DispatchQueue.main.async {
                self.lastSubmittedImages = finalImages
                self.lastSubmittedImage = primaryImage
                self.lastSubmittedText = notesText
                self.submissionCount += max(1, finalImages.count)
                
                let noteText = notesText.isEmpty ? self.currentTaskText : notesText
                HomeworkStatsService.shared.recordSubmission(notes: noteText, image: primaryImage)
            }

            // Copy submitted images to macOS Clipboard
            DispatchQueue.main.async {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()

                var items: [NSPasteboardItem] = []
                for img in finalImages {
                    if let tiffData = img.tiffRepresentation,
                       let bitmapRep = NSBitmapImageRep(data: tiffData),
                       let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                        let item = NSPasteboardItem()
                        item.setData(pngData, forType: .png)
                        item.setData(tiffData, forType: .tiff)
                        items.append(item)
                    }
                }
                if !items.isEmpty {
                    pasteboard.writeObjects(items)
                }

                NSSound(named: "Glass")?.play()

                // Display AirDrop Style Floating Banner on macOS
                AirDropNotificationBannerController.shared.showBanner(images: finalImages, text: notesText)
            }

            // Background OCR across all submitted images for AI evaluation
            Task.detached(priority: .userInitiated) { [weak self] in
                guard let self = self else { return }
                var pageTexts: [String] = []

                for (idx, img) in finalImages.enumerated() {
                    autoreleasepool {
                        if let tiff = img.tiffRepresentation,
                           let cgImage = CGImageSourceCreateWithData(tiff as CFData, nil).flatMap({ CGImageSourceCreateImageAtIndex($0, 0, nil) }) {
                            let request = VNRecognizeTextRequest()
                            request.recognitionLevel = .accurate
                            request.usesLanguageCorrection = true
                            request.recognitionLanguages = ["en-US", "vi-VN"]

                            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                            try? handler.perform([request])

                            let recognized = request.results?.compactMap { $0.topCandidates(1).first?.string } ?? []
                            if !recognized.isEmpty {
                                let text = recognized.joined(separator: "\n")
                                pageTexts.append("--- Trang \(idx + 1) ---\n\(text)")
                            }
                        }
                    }
                }

                let combinedExtractedText = pageTexts.isEmpty ? notesText : pageTexts.joined(separator: "\n\n")
                let textToArchive = combinedExtractedText.isEmpty ? self.currentTaskText : combinedExtractedText
                
                await MainActor.run {
                    self.lastSubmittedText = textToArchive
                }
            }

            let successResult: [String: Any] = [
                "status": "ok",
                "count": finalImages.count,
                "message": "Đã nhận thành công \(finalImages.count) trang bài làm trên Mac! Đã copy vào Clipboard (Cmd+V)."
            ]

            let responseData = (try? JSONSerialization.data(withJSONObject: successResult, options: [])) ?? Data()
            self.sendResponse(connection: connection, statusCode: 200, contentType: "application/json", body: responseData)
        } else {
            let infoJSON = "{\"app\":\"NekoTrans iPad Studio API\",\"version\":\"3.0\"}".data(using: .utf8)!
            sendResponse(connection: connection, statusCode: 200, contentType: "application/json", body: infoJSON)
        }
    }

    private func sendResponse(connection: NWConnection, statusCode: Int, contentType: String, body: Data) {
        let statusText = statusCode == 200 ? "OK" : (statusCode == 404 ? "Not Found" : "Error")
        let header = "HTTP/1.1 \(statusCode) \(statusText)\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.count)\r\nAccess-Control-Allow-Origin: *\r\nCache-Control: no-cache\r\nConnection: close\r\n\r\n"

        var responseData = header.data(using: .utf8)!
        responseData.append(body)

        connection.send(content: responseData, completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }

    private func sendPDFResponse(connection: NWConnection, pdfData: Data, fileName: String) {
        let header = "HTTP/1.1 200 OK\r\nContent-Type: application/pdf\r\nContent-Disposition: inline; filename=\"\(fileName)\"\r\nContent-Length: \(pdfData.count)\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n"
        var responseData = header.data(using: .utf8)!
        responseData.append(pdfData)

        connection.send(content: responseData, completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }
}
