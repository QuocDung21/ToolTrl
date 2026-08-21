import Foundation
import AVFoundation

@MainActor
public final class SpeechService: NSObject, AVSpeechSynthesizerDelegate {
    public static let shared = SpeechService()
    
    private let synthesizer = AVSpeechSynthesizer()
    private var isSpeaking = false
    
    private override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    public func speak(text: String, languageCode: String? = nil) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        utterance.pitchMultiplier = 1.0
        
        if let lang = languageCode {
            utterance.voice = AVSpeechSynthesisVoice(language: lang)
        } else {
            // Default to system or en-US
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        
        synthesizer.speak(utterance)
    }
    
    public func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}
