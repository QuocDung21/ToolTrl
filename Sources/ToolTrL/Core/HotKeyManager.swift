import Foundation
import Carbon
import AppKit

public extension Notification.Name {
    static let hotKeysDidChange = Notification.Name("ToolTrLHotKeysDidChangeNotification")
}

@MainActor
public final class HotKeyManager: ObservableObject {
    public static let shared = HotKeyManager()
    
    @Published public var translateShortcut: KeyShortcut {
        didSet {
            saveShortcut(translateShortcut, key: "hotkey_translate")
            reRegister()
        }
    }
    
    @Published public var aiShortcut: KeyShortcut {
        didSet {
            saveShortcut(aiShortcut, key: "hotkey_ai")
            reRegister()
        }
    }
    
    @Published public var notebookShortcut: KeyShortcut {
        didSet {
            saveShortcut(notebookShortcut, key: "hotkey_notebook")
            reRegister()
        }
    }
    
    private var hotKeyRefTranslate: EventHotKeyRef?
    private var hotKeyRefAI: EventHotKeyRef?
    private var hotKeyRefNotebook: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    
    private var translateAction: (() -> Void)?
    private var aiAction: (() -> Void)?
    private var notebookAction: (() -> Void)?
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    private init() {
        self.translateShortcut = Self.loadShortcut(key: "hotkey_translate") ?? KeyShortcut.defaultTranslate
        self.aiShortcut = Self.loadShortcut(key: "hotkey_ai") ?? KeyShortcut.defaultAI
        self.notebookShortcut = Self.loadShortcut(key: "hotkey_notebook") ?? KeyShortcut.defaultNotebook
        
        setupCarbonEventHandler()
        setupNSEventMonitor()
    }
    
    // MARK: - Carbon Global Event Handler
    private func setupCarbonEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        let handlerCallback: EventHandlerUPP = { _, inEvent, _ -> OSStatus in
            guard let inEvent = inEvent else { return noErr }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                inEvent,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            
            if status == noErr {
                DispatchQueue.main.async {
                    if hotKeyID.id == 1 {
                        HotKeyManager.shared.triggerTranslate()
                    } else if hotKeyID.id == 2 {
                        HotKeyManager.shared.triggerAI()
                    } else if hotKeyID.id == 3 {
                        HotKeyManager.shared.triggerNotebook()
                    }
                }
            }
            return noErr
        }
        
        InstallEventHandler(
            GetEventDispatcherTarget(),
            handlerCallback,
            1,
            &eventType,
            nil,
            &eventHandler
        )
    }
    
    // MARK: - NSEvent Fallback Monitors
    private func setupNSEventMonitor() {
        stopNSEventMonitor()
        
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            self.handleKeyDown(event)
        }
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            if self.handleKeyDown(event) {
                return nil
            }
            return event
        }
    }
    
    private func stopNSEventMonitor() {
        if let g = globalMonitor {
            NSEvent.removeMonitor(g)
            globalMonitor = nil
        }
        if let l = localMonitor {
            NSEvent.removeMonitor(l)
            localMonitor = nil
        }
    }
    
    @discardableResult
    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .option, .shift, .control])
        let code = UInt32(event.keyCode)
        
        // 1. Translate
        if code == translateShortcut.keyCode && flags.rawValue == translateShortcut.cocoaModifiers {
            DispatchQueue.main.async { self.triggerTranslate() }
            return true
        }
        
        // 2. AI Assistant
        if code == aiShortcut.keyCode && flags.rawValue == aiShortcut.cocoaModifiers {
            DispatchQueue.main.async { self.triggerAI() }
            return true
        }
        
        // 3. Notebook
        if code == notebookShortcut.keyCode && flags.rawValue == notebookShortcut.cocoaModifiers {
            DispatchQueue.main.async { self.triggerNotebook() }
            return true
        }
        
        return false
    }
    
    // MARK: - Register Carbon HotKeys
    public func registerHotKeys(
        onTranslate: @escaping () -> Void,
        onAI: @escaping () -> Void,
        onNotebook: @escaping () -> Void
    ) {
        self.translateAction = onTranslate
        self.aiAction = onAI
        self.notebookAction = onNotebook
        reRegister()
    }
    
    public func reRegister() {
        unregisterHotKeys()
        
        // 1. Translate HotKey (ID 1)
        let id1 = EventHotKeyID(signature: OSType(0x5452414E), id: 1)
        _ = RegisterEventHotKey(
            translateShortcut.keyCode,
            translateShortcut.carbonModifiers,
            id1,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRefTranslate
        )
        
        // 2. AI HotKey (ID 2)
        let id2 = EventHotKeyID(signature: OSType(0x5452414E), id: 2)
        _ = RegisterEventHotKey(
            aiShortcut.keyCode,
            aiShortcut.carbonModifiers,
            id2,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRefAI
        )
        
        // 3. Notebook HotKey (ID 3)
        let id3 = EventHotKeyID(signature: OSType(0x5452414E), id: 3)
        _ = RegisterEventHotKey(
            notebookShortcut.keyCode,
            notebookShortcut.carbonModifiers,
            id3,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRefNotebook
        )
        
        setupNSEventMonitor()
        NotificationCenter.default.post(name: .hotKeysDidChange, object: nil)
    }
    
    public func unregisterHotKeys() {
        if let ref = hotKeyRefTranslate {
            UnregisterEventHotKey(ref)
            hotKeyRefTranslate = nil
        }
        if let ref = hotKeyRefAI {
            UnregisterEventHotKey(ref)
            hotKeyRefAI = nil
        }
        if let ref = hotKeyRefNotebook {
            UnregisterEventHotKey(ref)
            hotKeyRefNotebook = nil
        }
    }
    
    public func resetDefaults() {
        self.translateShortcut = KeyShortcut.defaultTranslate
        self.aiShortcut = KeyShortcut.defaultAI
        self.notebookShortcut = KeyShortcut.defaultNotebook
    }
    
    private func triggerTranslate() {
        translateAction?()
    }
    
    private func triggerAI() {
        aiAction?()
    }
    
    private func triggerNotebook() {
        notebookAction?()
    }
    
    // MARK: - Persistence Helper
    private static func loadShortcut(key: String) -> KeyShortcut? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(KeyShortcut.self, from: data) else {
            return nil
        }
        return decoded
    }
    
    private func saveShortcut(_ shortcut: KeyShortcut, key: String) {
        if let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
