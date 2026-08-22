import Foundation
import Carbon
import AppKit

@MainActor
public final class HotKeyManager {
    public static let shared = HotKeyManager()
    
    private var hotKeyRefD: EventHotKeyRef?
    private var hotKeyRefA: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var translateAction: (() -> Void)?
    private var aiAction: (() -> Void)?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    private init() {
        setupCarbonEventHandler()
        setupNSEventMonitor()
    }
    
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
                if hotKeyID.id == 1 {
                    DispatchQueue.main.async {
                        HotKeyManager.shared.triggerTranslate()
                    }
                } else if hotKeyID.id == 2 {
                    DispatchQueue.main.async {
                        HotKeyManager.shared.triggerAI()
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
    
    private func setupNSEventMonitor() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains(.option) && !event.modifierFlags.contains(.command) else { return }
            
            // Option + D (Key code 2)
            if event.keyCode == 2 {
                DispatchQueue.main.async {
                    self?.triggerTranslate()
                }
            }
            // Option + A (Key code 0)
            else if event.keyCode == 0 {
                DispatchQueue.main.async {
                    self?.triggerAI()
                }
            }
        }
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains(.option) && !event.modifierFlags.contains(.command) else { return event }
            
            if event.keyCode == 2 {
                DispatchQueue.main.async {
                    self?.triggerTranslate()
                }
                return nil
            } else if event.keyCode == 0 {
                DispatchQueue.main.async {
                    self?.triggerAI()
                }
                return nil
            }
            return event
        }
    }
    
    /// Register global hotkeys (Option + D for Translate, Option + A for AI Assistant)
    public func registerHotKeys(
        onTranslate: @escaping () -> Void,
        onAI: @escaping () -> Void
    ) {
        unregisterHotKeys()
        self.translateAction = onTranslate
        self.aiAction = onAI
        
        // 1. Register Option + D (ID 1)
        let id1 = EventHotKeyID(signature: OSType(0x5452414E), id: 1) // "TRAN"
        _ = RegisterEventHotKey(
            UInt32(kVK_ANSI_D),
            UInt32(optionKey),
            id1,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRefD
        )
        
        // 2. Register Option + A (ID 2)
        let id2 = EventHotKeyID(signature: OSType(0x5452414E), id: 2)
        _ = RegisterEventHotKey(
            UInt32(kVK_ANSI_A),
            UInt32(optionKey),
            id2,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRefA
        )
    }
    
    public func unregisterHotKeys() {
        if let ref = hotKeyRefD {
            UnregisterEventHotKey(ref)
            hotKeyRefD = nil
        }
        if let ref = hotKeyRefA {
            UnregisterEventHotKey(ref)
            hotKeyRefA = nil
        }
    }
    
    private func triggerTranslate() {
        translateAction?()
    }
    
    private func triggerAI() {
        aiAction?()
    }
}
