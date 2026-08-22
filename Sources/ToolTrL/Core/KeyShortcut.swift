import Foundation
import Carbon
import AppKit
import SwiftUI

public struct KeyShortcut: Codable, Equatable, Sendable {
    public var keyCode: UInt32
    public var carbonModifiers: UInt32
    public var cocoaModifiers: UInt
    public var keyChar: String
    
    public init(keyCode: UInt32, carbonModifiers: UInt32, cocoaModifiers: UInt, keyChar: String) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.cocoaModifiers = cocoaModifiers
        self.keyChar = keyChar
    }
    
    public static let defaultTranslate = KeyShortcut(
        keyCode: UInt32(kVK_ANSI_D),
        carbonModifiers: UInt32(optionKey),
        cocoaModifiers: NSEvent.ModifierFlags.option.rawValue,
        keyChar: "D"
    )
    
    public static let defaultAI = KeyShortcut(
        keyCode: UInt32(kVK_ANSI_A),
        carbonModifiers: UInt32(optionKey),
        cocoaModifiers: NSEvent.ModifierFlags.option.rawValue,
        keyChar: "A"
    )
    
    public static let defaultNotebook = KeyShortcut(
        keyCode: UInt32(kVK_ANSI_V),
        carbonModifiers: UInt32(optionKey),
        cocoaModifiers: NSEvent.ModifierFlags.option.rawValue,
        keyChar: "V"
    )
    
    public static let defaultOCR = KeyShortcut(
        keyCode: UInt32(kVK_ANSI_S),
        carbonModifiers: UInt32(optionKey),
        cocoaModifiers: NSEvent.ModifierFlags.option.rawValue,
        keyChar: "S"
    )
    
    public var displayString: String {
        var str = ""
        let flags = NSEvent.ModifierFlags(rawValue: cocoaModifiers)
        if flags.contains(.control) { str += "⌃ " }
        if flags.contains(.option) { str += "⌥ " }
        if flags.contains(.shift) { str += "⇧ " }
        if flags.contains(.command) { str += "⌘ " }
        
        let charStr: String
        switch Int(keyCode) {
        case kVK_Space: charStr = "Space"
        case kVK_Return: charStr = "↩"
        case kVK_Tab: charStr = "⇥"
        case kVK_Escape: charStr = "ESC"
        case kVK_LeftArrow: charStr = "←"
        case kVK_RightArrow: charStr = "→"
        case kVK_UpArrow: charStr = "↑"
        case kVK_DownArrow: charStr = "↓"
        case kVK_Delete: charStr = "⌫"
        default:
            charStr = keyChar.uppercased()
        }
        
        return str + charStr
    }
    
    public static func from(event: NSEvent) -> KeyShortcut? {
        let flags = event.modifierFlags.intersection([.command, .option, .shift, .control])
        // Require at least one modifier
        guard !flags.isEmpty else { return nil }
        
        var carbonMods: UInt32 = 0
        if flags.contains(.command) { carbonMods |= UInt32(cmdKey) }
        if flags.contains(.option) { carbonMods |= UInt32(optionKey) }
        if flags.contains(.shift) { carbonMods |= UInt32(shiftKey) }
        if flags.contains(.control) { carbonMods |= UInt32(controlKey) }
        
        let keyCode = UInt32(event.keyCode)
        let keyChar = event.charactersIgnoringModifiers?.uppercased() ?? ""
        
        return KeyShortcut(
            keyCode: keyCode,
            carbonModifiers: carbonMods,
            cocoaModifiers: flags.rawValue,
            keyChar: keyChar.isEmpty ? "?" : keyChar
        )
    }
}
