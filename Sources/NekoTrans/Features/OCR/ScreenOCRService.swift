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
        isCapturing = true
        ScreenSnipController.shared.startSnip { [weak self] recognizedText in
            self?.isCapturing = false
            completion(recognizedText)
        }
    }

    /// Trigger screen snip and directly send image + OCR to iPad Pencil Studio
    public func captureAndSendToIPad() {
        isCapturing = true
        ScreenSnipController.shared.startSnipWithImage { [weak self] text, image in
            self?.isCapturing = false
            guard image != nil || text != nil else { return }
            ContinuityHomeworkController.shared.showStudio(taskText: text ?? "", taskImage: image)
        }
    }

    /// Perform OCR on CGImage using Apple Vision framework with smart reading order & paragraph assembly
    public func recognizeText(from cgImage: CGImage) async -> String? {
        isRecognizing = true
        defer { isRecognizing = false }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation],
                      !observations.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                // 1. Sort observations in natural reading order: Top-to-Bottom, then Left-to-Right
                let sortedObservations = observations.sorted { a, b in
                    let yDiff = abs(a.boundingBox.midY - b.boundingBox.midY)
                    if yDiff < 0.015 {
                        return a.boundingBox.minX < b.boundingBox.minX
                    }
                    return a.boundingBox.midY > b.boundingBox.midY
                }

                // 2. Extract top text candidates
                let rawLines = sortedObservations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }

                // 3. Smart paragraph reassembly & de-hyphenation
                let processedText = Self.assembleSmartText(from: rawLines)
                continuation.resume(returning: processedText.isEmpty ? nil : processedText)
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

    /// Tự động ghép nối các câu bị ngắt dòng vô cớ và khử dấu gạch nối cuối dòng
    public static func assembleSmartText(from rawLines: [String]) -> String {
        guard !rawLines.isEmpty else { return "" }
        var paragraphs: [String] = []
        var currentParagraph = ""

        for line in rawLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else {
                if !currentParagraph.isEmpty {
                    paragraphs.append(currentParagraph)
                    currentParagraph = ""
                }
                continue
            }

            if currentParagraph.isEmpty {
                currentParagraph = trimmed
            } else if currentParagraph.hasSuffix("-") {
                // De-hyphenate: "imple-" + "mentation" -> "implementation"
                currentParagraph.removeLast()
                currentParagraph += trimmed
            } else {
                let lastChar = currentParagraph.last ?? " "
                let isSentenceEnd = [".", "!", "?", ":", "…", "\"", "”"].contains(String(lastChar))
                let isListItem = trimmed.hasPrefix("•") || trimmed.hasPrefix("-") || (trimmed.first?.isNumber == true && trimmed.contains("."))

                if isSentenceEnd || isListItem {
                    paragraphs.append(currentParagraph)
                    currentParagraph = trimmed
                } else {
                    currentParagraph += " " + trimmed
                }
            }
        }

        if !currentParagraph.isEmpty {
            paragraphs.append(currentParagraph)
        }

        return paragraphs.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
