import Foundation
import Vision
import AppKit

@MainActor
public final class ScreenOCRService: ObservableObject {
    public static let shared = ScreenOCRService()
    
    @Published public var isCapturing: Bool = false
    @Published public var isRecognizing: Bool = false
    
    private init() {}
    
    /// Trigger interactive area screen capture and recognize text
    public func captureAndRecognize(completion: @escaping (String?) -> Void) {
        guard !isCapturing else { return }
        isCapturing = true
        
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tooltrl_ocr_\(UUID().uuidString).png")
        
        // Use macOS native interactive screencapture CLI (-i interactive, -s selection only, -x no sound)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-s", "-x", tempURL.path]
        
        process.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                self?.isCapturing = false
                
                guard proc.terminationStatus == 0,
                      FileManager.default.fileExists(atPath: tempURL.path),
                      let image = NSImage(contentsOf: tempURL),
                      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                    // User canceled via ESC or no file was created
                    try? FileManager.default.removeItem(at: tempURL)
                    completion(nil)
                    return
                }
                
                self?.isRecognizing = true
                let text = await self?.recognizeText(from: cgImage)
                self?.isRecognizing = false
                
                // Cleanup temp file
                try? FileManager.default.removeItem(at: tempURL)
                completion(text)
            }
        }
        
        do {
            try process.run()
        } catch {
            isCapturing = false
            completion(nil)
        }
    }
    
    /// Perform OCR on CGImage using Apple Vision framework
    public func recognizeText(from cgImage: CGImage) async -> String? {
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let lines = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                
                let recognizedText = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: recognizedText.isEmpty ? nil : recognizedText)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            // Support multiple languages
            if #available(macOS 13.0, *) {
                request.recognitionLanguages = ["en-US", "vi-VN", "ja-JP", "zh-Hans", "ko-KR", "fr-FR", "de-DE", "es-ES"]
            } else {
                request.recognitionLanguages = ["en-US", "fr-FR", "de-DE", "es-ES", "zh-Hans"]
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
