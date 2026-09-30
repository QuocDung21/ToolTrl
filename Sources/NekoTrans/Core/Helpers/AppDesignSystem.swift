import SwiftUI

// MARK: - 🎨 App Semantic Color Palette
public enum AppColors {
    public static let accent = Color.blue
    public static let accentSubtle = Color.blue.opacity(0.1)
    
    public static let phonetic = Color.orange
    public static let phoneticSubtle = Color.orange.opacity(0.08)
    
    public static let grammar = Color.blue
    public static let grammarSubtle = Color.blue.opacity(0.08)
    
    public static let success = Color.green
    public static let successSubtle = Color.green.opacity(0.1)
    
    public static let warning = Color.orange
    public static let destructive = Color.red
    
    public static let cardBackground = Color(nsColor: .controlBackgroundColor).opacity(0.85)
    public static let cardBorder = Color.primary.opacity(0.12)
    public static let cardHover = Color(nsColor: .controlBackgroundColor)
    
    public static let tagBackground = Color(nsColor: .controlBackgroundColor).opacity(0.9)
    public static let tagBorder = Color.primary.opacity(0.14)
}

// MARK: - 🔤 App Dynamic Scalable Typography System
public enum AppTypography {
    private static var delta: CGFloat {
        AppSettings.shared.appFontSize.scaleDelta
    }
    
    public static var titleLarge: Font {
        .system(size: 24 + delta, weight: .bold)
    }
    
    public static var titleMedium: Font {
        .system(size: 18 + delta, weight: .bold)
    }
    
    public static var headline: Font {
        .system(size: 15 + delta, weight: .semibold)
    }
    
    public static var headlineBold: Font {
        .system(size: 15 + delta, weight: .bold)
    }
    
    public static var body: Font {
        .system(size: 13 + delta, weight: .regular)
    }
    
    public static var bodyMedium: Font {
        .system(size: 13 + delta, weight: .medium)
    }
    
    public static var bodyBold: Font {
        .system(size: 13 + delta, weight: .bold)
    }
    
    public static var caption: Font {
        .system(size: 11 + delta, weight: .regular)
    }
    
    public static var captionMedium: Font {
        .system(size: 11 + delta, weight: .medium)
    }
    
    public static var captionBold: Font {
        .system(size: 11 + delta, weight: .bold)
    }
    
    public static var subcaption: Font {
        .system(size: 9.5 + delta, weight: .medium)
    }
    
    public static var subcaptionBold: Font {
        .system(size: 9.5 + delta, weight: .bold)
    }
    
    public static var phonetic: Font {
        .system(size: 13.5 + delta, weight: .medium, design: .serif)
    }
    
    public static var example: Font {
        .system(size: 12.5 + delta, weight: .regular, design: .serif)
    }
    
    public static var formula: Font {
        .system(size: 13.5 + delta, weight: .bold, design: .monospaced)
    }
    
    public static var number: Font {
        .system(size: 12 + delta, weight: .bold, design: .rounded)
    }
}

// MARK: - Convenient Extensions
public extension Font {
    static var appTitleLarge: Font { AppTypography.titleLarge }
    static var appTitleMedium: Font { AppTypography.titleMedium }
    static var appHeadline: Font { AppTypography.headline }
    static var appHeadlineBold: Font { AppTypography.headlineBold }
    static var appBody: Font { AppTypography.body }
    static var appBodyMedium: Font { AppTypography.bodyMedium }
    static var appBodyBold: Font { AppTypography.bodyBold }
    static var appCaption: Font { AppTypography.caption }
    static var appCaptionMedium: Font { AppTypography.captionMedium }
    static var appCaptionBold: Font { AppTypography.captionBold }
    static var appSubcaption: Font { AppTypography.subcaption }
    static var appSubcaptionBold: Font { AppTypography.subcaptionBold }
    static var appPhonetic: Font { AppTypography.phonetic }
    static var appExample: Font { AppTypography.example }
    static var appFormula: Font { AppTypography.formula }
    static var appNumber: Font { AppTypography.number }
}
