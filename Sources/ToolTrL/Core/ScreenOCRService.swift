import Foundation
@preconcurrency import Vision
import AppKit

@MainActor
public final class ScreenOCRService: ObservableObject {
    public static let shared = ScreenOCRService()
    
    @Published public var isCapturing: Bool = false
    @Published public var isRecognizing: Bool = false
    
    private init() {}
    
    /// Trigger interactive area screen snip and recognize text
    public func captureAndRecognize(completion: @escaping (String?) -> Void) {
        ScreenSnipController.shared.startSnip { [weak self] recognizedText in
            self?.isCapturing = false
            completion(recognizedText)
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
