import SwiftUI
import ServiceManagement

public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    
    @Published public var speechRate: Double {
        didSet {
            UserDefaults.standard.set(speechRate, forKey: "speech_rate")
        }
    }
    
    @Published public var speechPitch: Double {
        didSet {
            UserDefaults.standard.set(speechPitch, forKey: "speech_pitch")
        }
    }
    
    @Published public var autoSpeakWord: Bool {
        didSet {
            UserDefaults.standard.set(autoSpeakWord, forKey: "auto_speak_word")
        }
    }
    
    @Published public var clickOutsideDismiss: Bool {
        didSet {
            UserDefaults.standard.set(clickOutsideDismiss, forKey: "click_outside_dismiss")
        }
    }
    
    @Published public var targetLanguage: String {
        didSet {
            UserDefaults.standard.set(targetLanguage, forKey: "target_language")
        }
    }
    
    // Tùy chọn hiển thị từ điển
    @Published public var showPhonetics: Bool {
        didSet {
            UserDefaults.standard.set(showPhonetics, forKey: "show_phonetics")
        }
    }
    
    @Published public var showExamples: Bool {
        didSet {
            UserDefaults.standard.set(showExamples, forKey: "show_examples")
        }
    }
    
    @Published public var showSynonyms: Bool {
        didSet {
            UserDefaults.standard.set(showSynonyms, forKey: "show_synonyms")
        }
    }
    
    @Published public var showOfflineDictionary: Bool {
        didSet {
            UserDefaults.standard.set(showOfflineDictionary, forKey: "show_offline_dict")
        }
    }
    
    @Published public var launchAtLogin: Bool = false
    
    private init() {
        let savedRate = UserDefaults.standard.double(forKey: "speech_rate")
        self.speechRate = savedRate > 0.05 ? savedRate : 0.42
        
        let savedPitch = UserDefaults.standard.double(forKey: "speech_pitch")
        self.speechPitch = savedPitch > 0.05 ? savedPitch : 1.0
        
        self.autoSpeakWord = UserDefaults.standard.bool(forKey: "auto_speak_word")
        
        if UserDefaults.standard.object(forKey: "click_outside_dismiss") == nil {
            self.clickOutsideDismiss = true
        } else {
            self.clickOutsideDismiss = UserDefaults.standard.bool(forKey: "click_outside_dismiss")
        }
        
        self.targetLanguage = UserDefaults.standard.string(forKey: "target_language") ?? TargetLanguage.vietnamese.rawValue
        
        // Default display settings
        self.showPhonetics = UserDefaults.standard.object(forKey: "show_phonetics") == nil ? true : UserDefaults.standard.bool(forKey: "show_phonetics")
        self.showExamples = UserDefaults.standard.object(forKey: "show_examples") == nil ? true : UserDefaults.standard.bool(forKey: "show_examples")
        self.showSynonyms = UserDefaults.standard.object(forKey: "show_synonyms") == nil ? true : UserDefaults.standard.bool(forKey: "show_synonyms")
        self.showOfflineDictionary = UserDefaults.standard.object(forKey: "show_offline_dict") == nil ? true : UserDefaults.standard.bool(forKey: "show_offline_dict")
        
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
