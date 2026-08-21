import Foundation
import AppKit
import UniformTypeIdentifiers

public struct LocalModelInfo: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID = UUID()
    public let name: String
    public let filename: String
    public let fileSizeFormatted: String
    public let dateAdded: Date
    public var isSelected: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        filename: String,
        fileSizeFormatted: String,
        dateAdded: Date = Date(),
        isSelected: Bool = false
    ) {
        self.id = id
        self.name = name
        self.filename = filename
        self.fileSizeFormatted = fileSizeFormatted
        self.dateAdded = dateAdded
        self.isSelected = isSelected
    }
}

public struct HuggingFaceModelPreset: Identifiable {
    public let id: String
    public let title: String
    public let description: String
    public let size: String
    public let downloadURL: String
    
    public init(id: String, title: String, description: String, size: String, downloadURL: String) {
        self.id = id
        self.title = title
        self.description = description
        self.size = size
        self.downloadURL = downloadURL
    }
}

public enum AITranslationEngine: String, CaseIterable, Identifiable, Sendable {
    case appleNeural = "Apple Neural AI (Mặc định macOS)"
    case huggingFaceLocal = "Hugging Face Model (.gguf Cục bộ)"
    case ollamaLocal = "Ollama / LM Studio (Localhost)"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .appleNeural: return "apple.logo"
        case .huggingFaceLocal: return "shippingbox.fill"
        case .ollamaLocal: return "server.rack"
        }
    }
}

@MainActor
public final class LocalModelService: NSObject, ObservableObject {
    public static let shared = LocalModelService()
    
    @Published public var installedModels: [LocalModelInfo] = []
    @Published public var isDownloading: Bool = false
    @Published public var downloadProgress: Double = 0.0
    @Published public var downloadStatusText: String = ""
    @Published public var currentDownloadTitle: String = ""
    @Published public var ollamaEndpoint: String = "http://localhost:11434"
    @Published public var ollamaModelName: String = "qwen2.5:0.5b"
    @Published public var isOllamaAvailable: Bool = false
    
    public let presets: [HuggingFaceModelPreset] = [
        HuggingFaceModelPreset(
            id: "qwen-0.5b",
            title: "Qwen2.5-0.5B-Instruct (GGUF)",
            description: "Model siêu nhẹ ~390MB, tốc độ cực nhanh, dịch tiếng Việt trôi chảy trên mọi máy Mac.",
            size: "398 MB",
            downloadURL: "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf"
        ),
        HuggingFaceModelPreset(
            id: "llama-1b",
            title: "Llama-3.2-1B-Instruct (GGUF)",
            description: "Model 1B tối ưu bởi Meta, dịch đa ngôn ngữ sắc nét và văn phong tự nhiên.",
            size: "770 MB",
            downloadURL: "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf"
        ),
        HuggingFaceModelPreset(
            id: "qwen-1.5b",
            title: "Qwen2.5-1.5B-Instruct (GGUF)",
            description: "Model 1.5B chất lượng dịch văn bản kỹ thuật và ngữ cảnh chuyên sâu cao.",
            size: "1.1 GB",
            downloadURL: "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf"
        )
    ]
    
    private var downloadTask: URLSessionDownloadTask?
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()
    
    private var modelsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ToolTrL/Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    private override init() {
        super.init()
        scanInstalledModels()
        checkOllamaConnection()
    }
    
    public func scanInstalledModels() {
        let dir = modelsDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) else {
            self.installedModels = []
            return
        }
        
        var list: [LocalModelInfo] = []
        let selectedFilename = UserDefaults.standard.string(forKey: "selected_local_model_filename")
        
        for file in files where file.pathExtension.lowercased() == "gguf" || file.pathExtension.lowercased() == "bin" {
            let name = file.deletingPathExtension().lastPathComponent
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
            
            let isSel = (file.lastPathComponent == selectedFilename) || (list.isEmpty && selectedFilename == nil)
            
            let item = LocalModelInfo(
                name: name,
                filename: file.lastPathComponent,
                fileSizeFormatted: ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file),
                dateAdded: date,
                isSelected: isSel
            )
            list.append(item)
        }
        self.installedModels = list
    }
    
    public func importModelFile() {
        let panel = NSOpenPanel()
        panel.title = "Chọn Model GGUF từ Hugging Face"
        panel.allowsOtherFileTypes = true
        panel.allowedContentTypes = [UTType(filenameExtension: "gguf"), UTType(filenameExtension: "bin")].compactMap { $0 }
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let selectedURL = panel.url {
            let destURL = modelsDirectory.appendingPathComponent(selectedURL.lastPathComponent)
            try? FileManager.default.removeItem(at: destURL)
            try? FileManager.default.copyItem(at: selectedURL, to: destURL)
            
            UserDefaults.standard.set(selectedURL.lastPathComponent, forKey: "selected_local_model_filename")
            scanInstalledModels()
        }
    }
    
    public func selectModel(id: UUID) {
        if let item = installedModels.first(where: { $0.id == id }) {
            UserDefaults.standard.set(item.filename, forKey: "selected_local_model_filename")
            for i in 0..<installedModels.count {
                installedModels[i].isSelected = (installedModels[i].id == id)
            }
        }
    }
    
    public func deleteModel(id: UUID) {
        if let item = installedModels.first(where: { $0.id == id }) {
            let fileURL = modelsDirectory.appendingPathComponent(item.filename)
            try? FileManager.default.removeItem(at: fileURL)
            scanInstalledModels()
        }
    }
    
    public func startDownload(preset: HuggingFaceModelPreset) {
        guard let url = URL(string: preset.downloadURL) else { return }
        self.currentDownloadTitle = preset.title
        self.isDownloading = true
        self.downloadProgress = 0.0
        self.downloadStatusText = "Đang kết nối tới Hugging Face..."
        
        let task = urlSession.downloadTask(with: url)
        self.downloadTask = task
        task.resume()
    }
    
    public func startDownloadFromURLString(_ urlString: String) {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        self.currentDownloadTitle = url.lastPathComponent
        self.isDownloading = true
        self.downloadProgress = 0.0
        self.downloadStatusText = "Đang kết nối tới Hugging Face..."
        
        let task = urlSession.downloadTask(with: url)
        self.downloadTask = task
        task.resume()
    }
    
    public func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        downloadStatusText = ""
    }
    
    public func checkOllamaConnection() {
        guard let url = URL(string: "\(ollamaEndpoint)/api/tags") else {
            self.isOllamaAvailable = false
            return
        }
        
        var req = URLRequest(url: url)
        req.timeoutInterval = 2.0
        Task {
            if let (_, res) = try? await URLSession.shared.data(for: req),
               (res as? HTTPURLResponse)?.statusCode == 200 {
                self.isOllamaAvailable = true
            } else {
                self.isOllamaAvailable = false
            }
        }
    }
    
    // MARK: - Translate via Local Ollama / Local AI Endpoint
    public func translateViaOllama(text: String, to targetLang: String) async -> String? {
        guard let url = URL(string: "\(ollamaEndpoint)/api/generate") else { return nil }
        
        let prompt = "You are a professional translator. Translate the following text into natural, fluent \(targetLang == "vi" ? "Vietnamese" : targetLang). Output ONLY the translated text without explanations or quotes:\n\n\(text)"
        
        let body: [String: Any] = [
            "model": ollamaModelName,
            "prompt": prompt,
            "stream": false
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = httpBody
        req.timeoutInterval = 10.0
        
        guard let (data, res) = try? await URLSession.shared.data(for: req),
              (res as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let responseText = json["response"] as? String else {
            return nil
        }
        
        return responseText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - URLSessionDownloadDelegate
extension LocalModelService: @preconcurrency URLSessionDownloadDelegate {
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            let downloadedMB = ByteCountFormatter.string(fromByteCount: totalBytesWritten, countStyle: .file)
            let totalMB = ByteCountFormatter.string(fromByteCount: totalBytesExpectedToWrite, countStyle: .file)
            
            self.downloadProgress = progress
            self.downloadStatusText = "Đang tải: \(downloadedMB) / \(totalMB) (\(Int(progress * 100))%)"
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let filename = downloadTask.originalRequest?.url?.lastPathComponent ?? "model.gguf"
        let dest = modelsDirectory.appendingPathComponent(filename)
        
        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.moveItem(at: location, to: dest)
        
        UserDefaults.standard.set(filename, forKey: "selected_local_model_filename")
        
        self.isDownloading = false
        self.downloadStatusText = "Đã tải xong model \(filename)!"
        scanInstalledModels()
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let err = error as NSError?, err.code != NSURLErrorCancelled {
            self.isDownloading = false
            self.downloadStatusText = "Lỗi khi tải model: \(err.localizedDescription)"
        }
    }
}
