import Foundation
import AVFoundation

@MainActor
public final class AudioPlayerService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    public static let shared = AudioPlayerService()
    
    private var audioPlayer: AVAudioPlayer?
    private var downloadTask: Task<Void, Never>?
    private var audioCache: [String: Data] = [:]
    
    @Published public var isPlaying: Bool = false
    @Published public var currentPlayingURL: String? = nil
    @Published public var currentSpeakerID: String? = nil
    
    private override init() {
        super.init()
    }
    
    /// Tải trước file audio vào bộ nhớ đệm (Prefetch) để khi bấm phát là 0ms delay
    public func prefetchAudio(from urlString: String?) {
        guard let urlString = urlString, !urlString.isEmpty else { return }
        var normalizedURLString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedURLString.hasPrefix("//") {
            normalizedURLString = "https:" + normalizedURLString
        } else if normalizedURLString.hasPrefix("http://") {
            normalizedURLString = "https://" + normalizedURLString.dropFirst(7)
        } else if !normalizedURLString.hasPrefix("https://") {
            normalizedURLString = "https://" + normalizedURLString
        }
        
        if audioCache[normalizedURLString] != nil { return }
        guard let url = URL(string: normalizedURLString) else { return }
        
        Task(priority: .background) { [weak self] in
            guard let self = self else { return }
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 3.0
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, data.count > 100 {
                    await MainActor.run {
                        self.audioCache[normalizedURLString] = data
                    }
                }
            } catch {
                // Ignore prefetch network errors
            }
        }
    }
    
    /// Play native human pronunciation from web URL (e.g. Oxford / Cambridge / Google dictionary audio) with instant fallback to TTS
    public func playAudio(
        from urlString: String,
        fallbackText: String? = nil,
        fallbackVoiceCode: String = "en-US",
        speakerID: String = "audio_player"
    ) {
        // If already playing the same speaker or URL -> toggle stop
        if isPlaying && (currentSpeakerID == speakerID || currentPlayingURL == urlString) {
            stop()
            return
        }
        
        // Stop any running speech or previous audio
        SpeechService.shared.stop()
        stop()
        
        var normalizedURLString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedURLString.hasPrefix("//") {
            normalizedURLString = "https:" + normalizedURLString
        } else if normalizedURLString.hasPrefix("http://") {
            normalizedURLString = "https://" + normalizedURLString.dropFirst(7)
        } else if !normalizedURLString.hasPrefix("https://") {
            normalizedURLString = "https://" + normalizedURLString
        }
        
        guard let url = URL(string: normalizedURLString) else {
            fallbackSpeak(text: fallbackText, voiceCode: fallbackVoiceCode, speakerID: speakerID)
            return
        }
        
        self.isPlaying = true
        self.currentPlayingURL = normalizedURLString
        self.currentSpeakerID = speakerID
        
        // Check in-memory cache first for instant human audio playback
        if let cachedData = audioCache[normalizedURLString] {
            playAudioData(cachedData, fallbackText: fallbackText, fallbackVoiceCode: fallbackVoiceCode, speakerID: speakerID)
            return
        }
        
        // If not in cache, immediately speak via native Apple TTS (0ms latency!)
        // while simultaneously caching the MP3 in background for future plays
        fallbackSpeak(text: fallbackText, voiceCode: fallbackVoiceCode, speakerID: speakerID)
        
        downloadTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 5.0
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, data.count > 100 {
                    self.audioCache[normalizedURLString] = data
                }
            } catch {
                // Ignore background download failure
            }
        }
    }
    
    private func playAudioData(_ data: Data, fallbackText: String?, fallbackVoiceCode: String, speakerID: String) {
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.volume = min(max(Float(AppSettings.shared.speechVolume), 0.0), 1.0)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            if audioPlayer?.play() == true {
                self.isPlaying = true
                self.currentSpeakerID = speakerID
            } else {
                fallbackSpeak(text: fallbackText, voiceCode: fallbackVoiceCode, speakerID: speakerID)
            }
        } catch {
            fallbackSpeak(text: fallbackText, voiceCode: fallbackVoiceCode, speakerID: speakerID)
        }
    }
    
    public func stop() {
        downloadTask?.cancel()
        downloadTask = nil
        if let player = audioPlayer, player.isPlaying {
            player.stop()
        }
        audioPlayer = nil
        isPlaying = false
        currentPlayingURL = nil
        currentSpeakerID = nil
    }
    
    private func fallbackSpeak(text: String?, voiceCode: String, speakerID: String) {
        stop()
        guard let text = text, !text.isEmpty else { return }
        SpeechService.shared.speak(text: text, languageCode: voiceCode, speakerID: speakerID)
    }
    
    // MARK: - AVAudioPlayerDelegate
    public nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stop()
        }
    }
    
    public nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        Task { @MainActor in
            self.stop()
        }
    }
}
