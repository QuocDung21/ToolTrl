import Foundation
import llama
import Defaults
import NekoCore

public struct LocalGGUFModelItem: Identifiable, Hashable, Sendable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let fileSize: Int64
    
    public var formattedSize: String {
        let gb = Double(fileSize) / 1_073_741_824.0
        if gb >= 1.0 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(fileSize) / 1_048_576.0
        return String(format: "%.0f MB", mb)
    }
    
    public init(name: String, path: String, fileSize: Int64) {
        self.name = name
        self.path = path
        self.fileSize = fileSize
    }
}

/// Native in-process GGUF LLM inference engine using llama.cpp and Apple Metal
public final class LocalGGUFService: @unchecked Sendable {
    public static let shared = LocalGGUFService()
    
    private let queue = DispatchQueue(label: "com.nekotrans.gguf.inference", qos: .userInitiated)
    
    private var model: OpaquePointer?
    private var context: OpaquePointer?
    public private(set) var loadedModelPath: String?
    public private(set) var loadedModelName: String?
    
    public var isLoaded: Bool {
        model != nil && context != nil
    }
    
    private init() {
        llama_backend_init()
    }
    
    deinit {
        unloadModel()
        llama_backend_free()
    }
    
    // MARK: - Model Management
    
    public func loadModel(at path: String, contextSize: UInt32 = 2048, nGpuLayers: Int32 = 99) throws {
        try queue.sync {
            unloadModelInternal()
            
            guard FileManager.default.fileExists(atPath: path) else {
                throw NSError(domain: "GGUF", code: 404, userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy file model GGUF tại: \(path)"])
            }
            
            AppLog.ai.info("Nạp mô hình GGUF In-Process từ: \(path, privacy: .public)")
            
            var modelParams = llama_model_default_params()
            modelParams.n_gpu_layers = nGpuLayers // Offload to Apple Metal GPU
            
            guard let loadedModel = llama_model_load_from_file(path, modelParams) else {
                throw NSError(domain: "GGUF", code: 500, userInfo: [NSLocalizedDescriptionKey: "Không thể nạp model GGUF. Vui lòng kiểm tra định dạng file."])
            }
            
            var ctxParams = llama_context_default_params()
            ctxParams.n_ctx = contextSize
            ctxParams.n_batch = 512
            
            guard let loadedContext = llama_init_from_model(loadedModel, ctxParams) else {
                llama_model_free(loadedModel)
                throw NSError(domain: "GGUF", code: 500, userInfo: [NSLocalizedDescriptionKey: "Không thể khởi tạo context cho model GGUF."])
            }
            
            self.model = loadedModel
            self.context = loadedContext
            self.loadedModelPath = path
            self.loadedModelName = Self.friendlyModelName(from: path)
            
            AppLog.ai.info("Nạp mô hình GGUF thành công: \(self.loadedModelName ?? "", privacy: .public)")
        }
    }
    
    public func unloadModel() {
        queue.sync {
            unloadModelInternal()
        }
    }
    
    private func unloadModelInternal() {
        if let ctx = context {
            llama_free(ctx)
            context = nil
        }
        if let m = model {
            llama_model_free(m)
            model = nil
        }
        loadedModelPath = nil
        loadedModelName = nil
    }
    
    // MARK: - Prompt Formatting
    
    public func formatPrompt(system: String, user: String) -> String {
        if let model = self.model {
            let tmpl = llama_model_chat_template(model, nil)
            let sysRole = "system"
            let userRole = "user"
            
            var formatted: String?
            sysRole.withCString { sysRolePtr in
                system.withCString { sysPtr in
                    userRole.withCString { userRolePtr in
                        user.withCString { userPtr in
                            var msgs = [
                                llama_chat_message(role: sysRolePtr, content: sysPtr),
                                llama_chat_message(role: userRolePtr, content: userPtr)
                            ]
                            let neededLen = llama_chat_apply_template(tmpl, &msgs, msgs.count, true, nil, 0)
                            if neededLen > 0 {
                                var buffer = [CChar](repeating: 0, count: Int(neededLen) + 32)
                                let res = llama_chat_apply_template(tmpl, &msgs, msgs.count, true, &buffer, Int32(buffer.count))
                                if res > 0 {
                                    formatted = String(cString: buffer)
                                }
                            }
                        }
                    }
                }
            }
            if let f = formatted, !f.isEmpty {
                return f
            }
        }
        
        // Universal ChatML fallback (Qwen, Llama, Yi, etc.)
        return "<|im_start|>system\n\(system)<|im_end|>\n<|im_start|>user\n\(user)<|im_end|>\n<|im_start|>assistant\n"
    }
    
    // MARK: - Inference & Streaming
    
    public func streamInference(
        prompt: String,
        maxTokens: Int = 1024,
        onToken: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    guard let model = self.model, let ctx = self.context else {
                        throw NSError(domain: "GGUF", code: 400, userInfo: [NSLocalizedDescriptionKey: "Chưa nạp mô hình GGUF nào vào bộ nhớ."])
                    }
                    
                    guard let vocab = llama_model_get_vocab(model) else {
                        throw NSError(domain: "GGUF", code: 500, userInfo: [NSLocalizedDescriptionKey: "Không thể truy xuất từ điển (vocab) của model."])
                    }
                    
                    // 1. Tokenize prompt
                    let promptUtf8 = prompt.utf8CString
                    let promptLen = Int32(promptUtf8.count - 1)
                    var tokens = [llama_token](repeating: 0, count: max(Int(promptLen) + 16, 512))
                    let nTokens = llama_tokenize(vocab, prompt, promptLen, &tokens, Int32(tokens.count), true, true)
                    
                    guard nTokens > 0 else {
                        throw NSError(domain: "GGUF", code: 400, userInfo: [NSLocalizedDescriptionKey: "Lỗi mã hoá chuỗi prompt sang tokens."])
                    }
                    
                    tokens.removeSubrange(Int(nTokens)..<tokens.count)
                    
                    // 2. Setup Batch
                    var batch = llama_batch_init(512, 0, 1)
                    defer { llama_batch_free(batch) }
                    
                    // 3. Setup Sampler Chain (Temperature + Greedy for deterministic accurate translation)
                    let sparams = llama_sampler_chain_default_params()
                    guard let smpl = llama_sampler_chain_init(sparams) else {
                        throw NSError(domain: "GGUF", code: 500, userInfo: [NSLocalizedDescriptionKey: "Không thể tạo sampler chain."])
                    }
                    defer { llama_sampler_free(smpl) }
                    
                    llama_sampler_chain_add(smpl, llama_sampler_init_temp(0.3))
                    llama_sampler_chain_add(smpl, llama_sampler_init_greedy())
                    
                    // 4. Ingest Prompt Tokens
                    for (i, token) in tokens.enumerated() {
                        let isLast = (i == tokens.count - 1)
                        self.addToken(to: &batch, token: token, pos: llama_pos(i), seqId: 0, logits: isLast)
                        if batch.n_tokens == 512 || isLast {
                            let decodeRes = llama_decode(ctx, batch)
                            if decodeRes != 0 {
                                throw NSError(domain: "GGUF", code: 500, userInfo: [NSLocalizedDescriptionKey: "Lỗi giải mã prompt (mã: \(decodeRes))."])
                            }
                            batch.n_tokens = 0
                        }
                    }
                    
                    // 5. Generation Loop
                    var generatedText = ""
                    var curPos = llama_pos(tokens.count)
                    var tokenBuffer = [CChar](repeating: 0, count: 256)
                    
                    for _ in 0..<maxTokens {
                        let nextToken = llama_sampler_sample(smpl, ctx, -1)
                        
                        // Check End-of-Generation
                        if llama_vocab_is_eog(vocab, nextToken) {
                            break
                        }
                        
                        // Convert token to string piece
                        let pieceLen = llama_token_to_piece(vocab, nextToken, &tokenBuffer, Int32(tokenBuffer.count), 0, false)
                        if pieceLen > 0 {
                            let pieceData = Data(bytes: tokenBuffer, count: Int(pieceLen))
                            if let pieceStr = String(data: pieceData, encoding: .utf8) {
                                if !pieceStr.contains("<|") {
                                    generatedText += pieceStr
                                    onToken(pieceStr)
                                }
                            }
                        }
                        
                        // Feed generated token back for next step
                        self.addToken(to: &batch, token: nextToken, pos: curPos, seqId: 0, logits: true)
                        curPos += 1
                        
                        let decodeRes = llama_decode(ctx, batch)
                        if decodeRes != 0 {
                            break
                        }
                        batch.n_tokens = 0
                    }
                    
                    let cleaned = generatedText
                        .replacingOccurrences(of: "<|im_end|>", with: "")
                        .replacingOccurrences(of: "<|endoftext|>", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(returning: cleaned)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func addToken(to batch: inout llama_batch, token: llama_token, pos: llama_pos, seqId: llama_seq_id, logits: Bool) {
        let idx = Int(batch.n_tokens)
        batch.token[idx] = token
        batch.pos[idx] = pos
        batch.n_seq_id[idx] = 1
        batch.seq_id[idx]?[0] = seqId
        batch.logits[idx] = logits ? 1 : 0
        batch.n_tokens += 1
    }
    
    // MARK: - Friendly Model Name Resolver
    
    public static func friendlyModelName(from path: String) -> String {
        guard !path.isEmpty else { return "GGUF Metal" }
        let url = URL(fileURLWithPath: path)
        let filename = url.deletingPathExtension().lastPathComponent
        
        let isHex = filename.count >= 32 && filename.allSatisfy { $0.isHexDigit }
        if isHex || url.pathComponents.contains("blobs") {
            // Check snapshots folder in HuggingFace cache
            let parentDir = url.deletingLastPathComponent().deletingLastPathComponent()
            let snapshotsDir = parentDir.appendingPathComponent("snapshots")
            if let subdirs = try? FileManager.default.contentsOfDirectory(at: snapshotsDir, includingPropertiesForKeys: nil) {
                for snap in subdirs {
                    if let files = try? FileManager.default.contentsOfDirectory(at: snap, includingPropertiesForKeys: nil) {
                        for file in files where file.pathExtension.lowercased() == "gguf" {
                            let cleanName = file.deletingPathExtension().lastPathComponent
                            if !cleanName.allSatisfy({ $0.isHexDigit }) {
                                return cleanName
                            }
                        }
                    }
                }
            }
            
            // Check repo directory in huggingface cache (e.g. models--Qwen--Qwen2.5-0.5B-Instruct-GGUF)
            for comp in url.pathComponents {
                if comp.hasPrefix("models--") {
                    let cleaned = comp.replacingOccurrences(of: "models--", with: "")
                    let parts = cleaned.components(separatedBy: "--")
                    if parts.count >= 2 {
                        return parts[1]
                    }
                    return cleaned
                }
            }
        }
        
        return filename.isEmpty ? "GGUF Model" : filename
    }
    
    // MARK: - Scanning Local GGUF Files
    
    public func scanLocalGGUFModels() -> [LocalGGUFModelItem] {
        var results: [LocalGGUFModelItem] = []
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        
        var searchDirs: [URL] = [
            home.appendingPathComponent("Downloads"),
            home.appendingPathComponent(".cache/huggingface/hub"),
            home.appendingPathComponent("Library/Application Support/NekoTrans/models")
        ]
        
        // Also check custom saved model path in Defaults if set
        let savedCustomPath = Defaults[.customGGUFModelPath]
        if !savedCustomPath.isEmpty {
            let customURL = URL(fileURLWithPath: savedCustomPath)
            if fileManager.fileExists(atPath: savedCustomPath) {
                if customURL.pathExtension.lowercased() == "gguf" || fileManager.fileExists(atPath: savedCustomPath) {
                    if let attrs = try? fileManager.attributesOfItem(atPath: savedCustomPath),
                       let size = attrs[.size] as? Int64 {
                        results.append(LocalGGUFModelItem(
                            name: Self.friendlyModelName(from: savedCustomPath),
                            path: savedCustomPath,
                            fileSize: size
                        ))
                    }
                } else {
                    searchDirs.append(customURL)
                }
            }
        }
        
        for dir in searchDirs {
            guard fileManager.fileExists(atPath: dir.path) else { continue }
            guard let enumerator = fileManager.enumerator(
                at: dir,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }
            
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension.lowercased() == "gguf" {
                    let resolved = fileURL.resolvingSymlinksInPath()
                    if let attrs = try? fileManager.attributesOfItem(atPath: resolved.path),
                       let size = attrs[.size] as? Int64 {
                        let name = Self.friendlyModelName(from: fileURL.path)
                        let pathToStore = fileURL.path
                        if !results.contains(where: { $0.path == pathToStore || $0.path == resolved.path }) {
                            results.append(LocalGGUFModelItem(name: name, path: pathToStore, fileSize: size))
                        }
                    }
                }
            }
        }
        
        return results.sorted(by: { $0.fileSize < $1.fileSize })
    }
}
