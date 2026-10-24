import Foundation
@preconcurrency import Vision
import AppKit

@MainActor
public final class ScreenOCRService: ObservableObject {
    public static let shared = ScreenOCRService()

    @Published public var isCapturing: Bool = false
    @Published public var isRecognizing: Bool = false

    private init() {}

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

    /// Tự động ghép nối các câu bị ngắt dòng, khử dấu gạch nối cuối dòng thông minh
    /// (giữ nguyên từ ghép như state-of-the-art và khử hyphenation như recon-struction)
    /// và chuẩn hóa khoảng trắng/dấu câu theo logic của Easydict.
    nonisolated public static func assembleSmartText(from rawLines: [String]) -> String {
        guard !rawLines.isEmpty else { return "" }
        var paragraphs: [String] = []
        var currentParagraph = ""

        for line in rawLines {
            let trimmed = normalizeOCRLine(line)
            guard !trimmed.isEmpty else {
                if !currentParagraph.isEmpty {
                    paragraphs.append(currentParagraph)
                    currentParagraph = ""
                }
                continue
            }

            if currentParagraph.isEmpty {
                currentParagraph = trimmed
            } else if endsWithDash(currentParagraph) {
                // Smart dash handling (inspired by Easydict OCRDashHandler)
                currentParagraph = handleDashJoin(previous: currentParagraph, next: trimmed)
            } else {
                let lastChar = currentParagraph.last ?? " "
                let isSentenceEnd = [".", "!", "?", ":", "…", "\"", "”"].contains(String(lastChar))
                let isListItem = trimmed.hasPrefix("•") || trimmed.hasPrefix("- ") || (trimmed.first?.isNumber == true && trimmed.contains("."))

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

        let result = paragraphs.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizeFinalPunctuation(result)
    }

    // MARK: - Smart OCR Dash & Text Normalization Helpers

    nonisolated private static func endsWithDash(_ text: String) -> Bool {
        text.hasSuffix("-") || text.hasSuffix("–") || text.hasSuffix("—")
    }

    nonisolated private static func handleDashJoin(previous: String, next: String) -> String {
        // Strip trailing dash
        var prevClean = previous
        if endsWithDash(prevClean) {
            prevClean.removeLast()
        }

        // Extract last word of previous and first word of next
        let prevWords = prevClean.split(separator: " ")
        let nextWords = next.split(separator: " ")
        guard let lastWord = prevWords.last, let firstWord = nextWords.first else {
            return previous + next
        }

        let lastStr = String(lastWord)
        let firstStr = String(firstWord)
        let cleanLast = lastStr.trimmingCharacters(in: .punctuationCharacters)
        let cleanFirst = firstStr.trimmingCharacters(in: .punctuationCharacters)

        // Numbers/Dates: "1990-" + "2020." -> "1990-2020."
        if !cleanLast.isEmpty && !cleanFirst.isEmpty &&
           (cleanLast.allSatisfy(\.isNumber) || cleanLast.allSatisfy { $0.isNumber || $0 == "/" }) &&
           (cleanFirst.allSatisfy(\.isNumber) || cleanFirst.allSatisfy { $0.isNumber || $0 == "/" }) {
            return prevClean + "-" + next
        }

        // Word continuation check
        let joinedWord = cleanLast + cleanFirst
        let isJoinedSpelledCorrectly = isSpelledCorrectly(joinedWord)

        if isJoinedSpelledCorrectly {
            // "recon-" + "struction" -> "reconstruction" (de-hyphenate)
            return prevClean + next
        } else {
            // Compound word: "state-of-" + "the-art" -> "state-of-the-art"
            return prevClean + "-" + next
        }
    }

    nonisolated private static func isSpelledCorrectly(_ word: String) -> Bool {
        guard word.count >= 3 else { return false }
        let checker = NSSpellChecker.shared
        let range = checker.checkSpelling(of: word, startingAt: 0)
        return range.location == NSNotFound
    }

    nonisolated private static func normalizeOCRLine(_ line: String) -> String {
        var str = line.trimmingCharacters(in: .whitespaces)
        // Normalize bullet points
        if str.hasPrefix("•") || str.hasPrefix("●") || str.hasPrefix("▪") || str.hasPrefix("◆") {
            str = "• " + str.dropFirst().trimmingCharacters(in: .whitespaces)
        }
        return str
    }

    nonisolated private static func normalizeFinalPunctuation(_ text: String) -> String {
        var str = text
        // Fix awkward space before commas, periods, colons
        str = str.replacingOccurrences(of: " ,", with: ",")
        str = str.replacingOccurrences(of: " .", with: ".")
        str = str.replacingOccurrences(of: " :", with: ":")
        str = str.replacingOccurrences(of: " ;", with: ";")
        str = str.replacingOccurrences(of: " !", with: "!")
        str = str.replacingOccurrences(of: " ?", with: "?")
        return str
    }

    /// Micro-region OCR for canvas/graphic apps (Figma, Canva, games, etc.)
    /// Captures a tight bounding box between mouseDown and mouseUp,
    /// running Vision OCR with .fast recognition level for near-instant latency (~25-40ms).
    public func recognizeMicroRegion(from startPoint: CGPoint, to endPoint: CGPoint) async -> String? {
        let minX = min(startPoint.x, endPoint.x)
        let maxX = max(startPoint.x, endPoint.x)
        let minY = min(startPoint.y, endPoint.y)
        let maxY = max(startPoint.y, endPoint.y)
        
        let width = Int(max(maxX - minX, 32.0) + 16.0)
        let height = Int(max(maxY - minY, 18.0) + 16.0)
        let originX = Int(minX - 8.0)
        let originY = Int(minY - 8.0)
        
        guard let primaryScreen = NSScreen.screens.first else { return nil }
        let screenHeight = Int(primaryScreen.frame.height)
        let globalY = screenHeight - (originY + height)
        let globalX = originX
        
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("neko_micro_\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", "-R\(globalX),\(globalY),\(width),\(height)", tempURL.path]
        
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0,
                  FileManager.default.fileExists(atPath: tempURL.path),
                  let image = NSImage(contentsOf: tempURL),
                  let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                return nil
            }
            
            return await withCheckedContinuation { continuation in
                let request = VNRecognizeTextRequest { request, error in
                    guard error == nil,
                          let observations = request.results as? [VNRecognizedTextObservation],
                          !observations.isEmpty else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let rawLines = observations.compactMap { $0.topCandidates(1).first?.string }
                    let text = Self.assembleSmartText(from: rawLines)
                    continuation.resume(returning: text.isEmpty ? nil : text)
                }
                request.recognitionLevel = .fast
                request.usesLanguageCorrection = false
                
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        try handler.perform([request])
                    } catch {
                        continuation.resume(returning: nil)
                    }
                }
            }
        } catch {
            return nil
        }
    }
}
