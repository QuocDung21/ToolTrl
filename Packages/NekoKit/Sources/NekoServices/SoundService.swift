import AppKit

public enum SoundEffect: String, Sendable {
    case pop = "Pop"
    case tink = "Tink"
    case blow = "Blow"
    case ping = "Ping"
}

public struct SoundService: Sendable {
    public static func play(_ effect: SoundEffect) {
        if let sound = NSSound(named: NSSound.Name(effect.rawValue)) {
            sound.stop()
            sound.play()
        }
    }
    
    public static func playPopSound() {
        play(.pop)
    }
}
