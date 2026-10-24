import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Defaults
import Observation

@Observable
@MainActor
public final class AppIconService {
    public static let shared = AppIconService()
    
    public var selectedType: AppIconType {
        didSet {
            Defaults[.appIconType] = selectedType
            updateDockIcon()
            NotificationCenter.default.post(name: .appIconDidChange, object: nil)
        }
    }
    
    public var customImageName: String? = nil
    
    /// Directory name is frozen on purpose: it holds the user's custom app icon on
    /// disk, so renaming it would make existing custom icons disappear.
    private static let customIconsDirectory = "ToolTrL/CustomIcons"
    
    private var customImageFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent(AppIconService.customIconsDirectory, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("custom_logo.png")
    }
    
    private init() {
        self.selectedType = Defaults[.appIconType]
        
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let customFile = appSupport
            .appendingPathComponent(AppIconService.customIconsDirectory, isDirectory: true)
            .appendingPathComponent("custom_logo.png")
        if FileManager.default.fileExists(atPath: customFile.path) {
            self.customImageName = "custom_logo.png"
        }
        
        updateDockIcon()
    }
    
    public func updateDockIcon() {
        if selectedType == .defaultCat {
            NSApp.applicationIconImage = nil
        } else if selectedType == .custom, let img = NSImage(contentsOf: customImageFileURL) {
            NSApp.applicationIconImage = img
        } else if let sym = selectedType.sfSymbol, let img = NSImage(systemSymbolName: sym, accessibilityDescription: selectedType.rawValue) {
            NSApp.applicationIconImage = img
        }
    }
    
    // MARK: - Current SwiftUI Image
    public var currentImage: Image {
        switch selectedType {
        case .defaultCat:
            return AppLogo.image
        case .custom:
            if let nsImg = NSImage(contentsOf: customImageFileURL) {
                return Image(nsImage: nsImg)
            }
            return AppLogo.image
        case .aiSparkle, .bolt, .book, .globe, .rocket, .diamond:
            if let symbol = selectedType.sfSymbol {
                return Image(systemName: symbol)
            }
            return AppLogo.image
        }
    }
    
    // MARK: - Current NSImage (for AppKit & Status Item)
    public var currentNSImage: NSImage {
        switch selectedType {
        case .defaultCat:
            return AppLogo.nsImage
        case .custom:
            if let img = NSImage(contentsOf: customImageFileURL) {
                img.size = NSSize(width: 18, height: 18)
                return img
            }
            return AppLogo.nsImage
        case .aiSparkle, .bolt, .book, .globe, .rocket, .diamond:
            if let symbol = selectedType.sfSymbol,
               let img = NSImage(systemSymbolName: symbol, accessibilityDescription: selectedType.rawValue) {
                let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
                let configured = img.withSymbolConfiguration(config) ?? img
                configured.size = NSSize(width: 18, height: 18)
                return configured
            }
            return AppLogo.nsImage
        }
    }
    
    public func selectIcon(_ type: AppIconType) {
        self.selectedType = type
    }
    
    // MARK: - Import Custom Image from Disk
    public func importCustomImage() {
        let panel = NSOpenPanel()
        panel.title = "Chọn Logo / Icon Tùy Ý (PNG, JPG, ICNS)"
        panel.allowsOtherFileTypes = true
        panel.allowedContentTypes = [
            UTType.png,
            UTType.jpeg,
            UTType.icns,
            UTType.image
        ]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let selectedURL = panel.url {
            try? FileManager.default.removeItem(at: customImageFileURL)
            try? FileManager.default.copyItem(at: selectedURL, to: customImageFileURL)
            self.customImageName = selectedURL.lastPathComponent
            self.selectedType = .custom
        }
    }
    
    public func resetToDefault() {
        try? FileManager.default.removeItem(at: customImageFileURL)
        self.customImageName = nil
        self.selectedType = .defaultCat
    }
}

public extension Notification.Name {
    static let appIconDidChange = Notification.Name("NekoTransAppIconDidChangeNotification")
}
