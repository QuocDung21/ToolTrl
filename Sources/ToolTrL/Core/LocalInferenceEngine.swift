import Foundation

@MainActor
public final class LocalInferenceEngine {
    public static let shared = LocalInferenceEngine()
    
    private init() {}
    
    private var llamaCliPath: String? {
        // 1. Check in App Bundle Resources
        if let bundleResource = Bundle.main.resourceURL?.appendingPathComponent("llama-runner/llama-cli").path,
           FileManager.default.fileExists(atPath: bundleResource) {
            return bundleResource
        }
        
        // 2. Check in Dev Resources
        let devPath = "/Users/dungnguyenquoc/Dev/ToolTrL/Resources/llama-runner/llama-cli"
        if FileManager.default.fileExists(atPath: devPath) {
            return devPath
        }
        
        // 3. Check system Homebrew
        let brewPath = "/opt/homebrew/bin/llama-cli"
        if FileManager.default.fileExists(atPath: brewPath) {
            return brewPath
        }
        
        return nil
    }
    
    public func translateWithGGUF(
        text: String,
        modelFilename: String,
        targetLang: String
    ) async -> String? {
        let modelsDir = LocalModelService.shared.modelsDirectory
        let modelPath = modelsDir.appendingPathComponent(modelFilename).path
        
        guard FileManager.default.fileExists(atPath: modelPath) else {
            print("⚠️ File model không tồn tại tại: \(modelPath)")
            return nil
        }
        
        guard let cliPath = llamaCliPath else {
            print("⚠️ Không tìm thấy llama-cli binary.")
            return nil
        }
        
        let targetName = targetLang == "vi" ? "tiếng Việt" : (targetLang == "ja" ? "tiếng Nhật" : (targetLang == "zh" ? "tiếng Trung" : targetLang))
        
        let prompt = "<|im_start|>system\nBạn là một chuyên gia dịch thuật AI cao cấp. Hãy dịch đoạn văn bản sau sang \(targetName) một cách tự nhiên, chuẩn ngữ pháp và trôi chảy nhất. Chỉ xuất ra duy nhất câu dịch, không kèm lời giải thích hoặc dấu ngoặc kép thừa.<|im_end|>\n<|im_start|>user\n\(text)<|im_end|>\n<|im_start|>assistant\n"
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: cliPath)
                
                // Set dyld library path to llama-runner directory so it loads libggml-metal.dylib
                let runnerDir = (cliPath as NSString).deletingLastPathComponent
                var env = ProcessInfo.processInfo.environment
                env["DYLD_LIBRARY_PATH"] = runnerDir
                process.environment = env
                
                process.arguments = [
                    "-m", modelPath,
                    "-ngl", "99",              // Offload all layers to Apple Metal GPU
                    "-c", "2048",              // Context size
                    "-n", "512",               // Max tokens
                    "--temp", "0.3",           // Low temperature for accurate translation
                    "-p", prompt,
                    "--no-display-prompt",
                    "-e"
                ]
                
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let rawOutput = String(data: data, encoding: .utf8) {
                        let cleaned = rawOutput
                            .replacingOccurrences(of: "<|im_end|>", with: "")
                            .replacingOccurrences(of: "<|endoftext|>", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        if !cleaned.isEmpty {
                            continuation.resume(returning: cleaned)
                            return
                        }
                    }
                    continuation.resume(returning: nil)
                } catch {
                    print("❌ Lỗi khi chạy llama-cli: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
