import SwiftUI
import AppKit
import UniformTypeIdentifiers

public enum AppIconType: String, CaseIterable, Identifiable, Codable {
    case defaultCat = "Mèo Cam (Mặc định)"
    case aiSparkle = "✨ AI Sparkle"
    case bolt = "⚡ Tia Chớp"
    case book = "📖 Sách Tri Thức"
    case globe = "🌐 Quả Cầu Dịch"
    case rocket = "🚀 Tên Lửa"
    case diamond = "💎 Kim Cương"
    case custom = "📁 Ảnh Tự Chọn"
    
    public var id: String { rawValue }
    
    public var sfSymbol: String? {
        switch self {
        case .defaultCat: return nil
        case .aiSparkle: return "sparkles"
        case .bolt: return "bolt.fill"
        case .book: return "character.book.closed.fill"
        case .globe: return "globe.americas.fill"
        case .rocket: return "rocket.fill"
        case .diamond: return "diamond.fill"
        case .custom: return nil
        }
    }
    
    public var accentColor: Color {
        switch self {
        case .defaultCat: return .orange
        case .aiSparkle: return .purple
        case .bolt: return .yellow
        case .book: return .blue
        case .globe: return .cyan
        case .rocket: return .red
        case .diamond: return .indigo
        case .custom: return .green
        }
    }
}

@MainActor
public final class AppIconService: ObservableObject {
    public static let shared = AppIconService()
    
    @Published public var selectedType: AppIconType {
        didSet {
            UserDefaults.standard.set(selectedType.rawValue, forKey: "app_icon_type")
            NotificationCenter.default.post(name: .appIconDidChange, object: nil)
        }
    }
    
    @Published public var customImageName: String? = nil
    
    private var customImageFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ToolTrL/CustomIcons", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("custom_logo.png")
    }
    
    private init() {
        let saved = UserDefaults.standard.string(forKey: "app_icon_type") ?? AppIconType.defaultCat.rawValue
        self.selectedType = AppIconType(rawValue: saved) ?? .defaultCat
        
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let customFile = appSupport.appendingPathComponent("ToolTrL/CustomIcons/custom_logo.png")
        if FileManager.default.fileExists(atPath: customFile.path) {
            self.customImageName = "custom_logo.png"
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
    static let appIconDidChange = Notification.Name("ToolTrLAppIconDidChangeNotification")
}
