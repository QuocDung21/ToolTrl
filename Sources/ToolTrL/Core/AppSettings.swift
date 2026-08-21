import SwiftUI
import ServiceManagement

public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    
    @AppStorage("speech_rate") public var speechRate: Double = 0.45 // Natural relaxed reading pace (default is 0.5)
    @AppStorage("speech_pitch") public var speechPitch: Double = 1.0
    @AppStorage("auto_speak_word") public var autoSpeakWord: Bool = false
    @AppStorage("click_outside_dismiss") public var clickOutsideDismiss: Bool = true
    @AppStorage("target_language") public var targetLanguage: String = TargetLanguage.vietnamese.rawValue
    
    @Published public var launchAtLogin: Bool = false
    
    private init() {
        if #available(macOS 13.0, *) {
            self.launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
    
    public func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                self.launchAtLogin = (SMAppService.mainApp.status == .enabled)
            } catch {
                print("Launch at login error: \(error)")
            }
        }
    }
}
