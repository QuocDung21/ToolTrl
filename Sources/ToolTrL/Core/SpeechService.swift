import Foundation
import AVFoundation

@MainActor
public final class SpeechService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    public static let shared = SpeechService()
    
    private let synthesizer = AVSpeechSynthesizer()
    
    @Published public var isSpeaking: Bool = false
    @Published public var spokenRange: NSRange? = nil
    @Published public var currentSpeakerID: String? = nil
    
    private override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    public func speak(text: String, languageCode: String? = nil, speakerID: String = "default") {
        if synthesizer.isSpeaking {
            let wasSpeakingSame = (currentSpeakerID == speakerID)
            synthesizer.stopSpeaking(at: .immediate)
            spokenRange = nil
            isSpeaking = false
            currentSpeakerID = nil
            // If user clicked the same speaker button that is currently playing -> Toggle stop!
            if wasSpeakingSame { return }
        }
        
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let utterance = AVSpeechUtterance(string: trimmed)
        let rate = Float(AppSettings.shared.speechRate)
        utterance.rate = min(max(rate, 0.2), 0.8)
        utterance.pitchMultiplier = Float(AppSettings.shared.speechPitch)
        
        if let lang = languageCode {
            utterance.voice = AVSpeechSynthesisVoice(language: lang)
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        
        self.currentSpeakerID = speakerID
        self.isSpeaking = true
        self.spokenRange = nil
        
        synthesizer.speak(utterance)
    }
    
    public func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        spokenRange = nil
        currentSpeakerID = nil
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.spokenRange = characterRange
        }
    }
    
    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = true
        }
    }
    
    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.spokenRange = nil
            self.currentSpeakerID = nil
        }
    }
    
    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.spokenRange = nil
            self.currentSpeakerID = nil
        }
    }
}
