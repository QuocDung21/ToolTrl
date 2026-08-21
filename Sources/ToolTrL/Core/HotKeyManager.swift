import Foundation
import Carbon
import AppKit

@MainActor
public final class HotKeyManager {
    public static let shared = HotKeyManager()
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var actionHandler: (() -> Void)?
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
            
            if status == noErr, hotKeyID.id == 1 {
                DispatchQueue.main.async {
                    HotKeyManager.shared.triggerAction()
                }
            }
            return noErr
        }
        
        // CRITICAL: Must use GetEventDispatcherTarget() for system-wide global hotkeys in background apps
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
        // Dual fallback: NSEvent Global Monitor for Option + D (Key code 2)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.option) && !event.modifierFlags.contains(.command) && event.keyCode == 2 {
                DispatchQueue.main.async {
                    self?.triggerAction()
                }
            }
        }
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.option) && !event.modifierFlags.contains(.command) && event.keyCode == 2 {
                DispatchQueue.main.async {
                    self?.triggerAction()
                }
                return nil
            }
            return event
        }
    }
    
    /// Register global hotkey (default: Option + D)
    public func registerHotKey(
        keyCode: UInt32 = UInt32(kVK_ANSI_D),
        modifiers: UInt32 = UInt32(optionKey),
        action: @escaping () -> Void
    ) {
        unregisterHotKey()
        self.actionHandler = action
        
        let hotKeyID = EventHotKeyID(signature: OSType(0x5452414E), id: 1) // "TRAN"
        
        // Register with GetEventDispatcherTarget so it receives events system-wide
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr {
            print("✅ Global HotKey registered successfully with GetEventDispatcherTarget (Option + D)")
        } else {
            print("❌ Failed to register Global HotKey, status: \(status)")
        }
    }
    
    public func unregisterHotKey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }
    
    private func triggerAction() {
        actionHandler?()
    }
}
