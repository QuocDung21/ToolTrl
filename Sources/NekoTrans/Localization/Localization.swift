import Combine
import Foundation
import Defaults

// MARK: - Language Preference

public enum LanguagePreference: Hashable, Identifiable, Sendable, CaseIterable {
    case system
    case language(AppLanguage)

    public static var allCases: [LanguagePreference] {
        [.system] + AppLanguage.allCases.map { .language($0) }
    }

    public var id: String {
        switch self {
        case .system:
            return "system"
        case .language(let language):
            return language.rawValue
        }
    }

    public var localizedTitle: LocalizedStringResource {
        switch self {
        case .system:
            return .languageSystem
        case .language(let language):
            return LocalizedStringResource(stringLiteral: language.nativeName)
        }
    }

    func resolvedLanguage(preferredLanguages: [String]) -> AppLanguage {
        switch self {
        case .system:
            return AppLanguage.resolved(preferredLanguages: preferredLanguages)
        case .language(let language):
            return language
        }
    }
}

// MARK: - Localization

@MainActor  
public final class Localization: ObservableObject {
    public static let shared = Localization()

    @Published public private(set) var preference: LanguagePreference
    @Published public private(set) var resolvedLanguage: AppLanguage

    private var preferredLanguages: [String]
    nonisolated(unsafe) private var localeObserver: NSObjectProtocol?

    public init(preferredLanguages: [String] = Locale.preferredLanguages) {
        self.preferredLanguages = preferredLanguages

        let initialPreference: LanguagePreference
        if let stored = Defaults[.appLanguage] {
            initialPreference = .language(stored)
        } else {
            initialPreference = .system
        }

        self.preference = initialPreference
        self.resolvedLanguage = initialPreference.resolvedLanguage(
            preferredLanguages: preferredLanguages
        )

        localeObserver = NotificationCenter.default.addObserver(
            forName: NSLocale.currentLocaleDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshSystemLanguage()
            }
        }
    }

    deinit {
        if let localeObserver {
            NotificationCenter.default.removeObserver(localeObserver)
        }
    }

    // MARK: - Preference

    public func setPreference(_ newPreference: LanguagePreference) {
        guard newPreference != preference else { return }
        preference = newPreference

        let language: AppLanguage?
        switch newPreference {
        case .system:
            language = nil
            Defaults[.appLanguage] = nil
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        case .language(let lang):
            language = lang
            Defaults[.appLanguage] = lang
            UserDefaults.standard.set([lang.rawValue], forKey: "AppleLanguages")
        }

        if AppSettings.shared.appLanguage != language {
            AppSettings.shared.appLanguage = language
        }

        resolvedLanguage = newPreference.resolvedLanguage(
            preferredLanguages: preferredLanguages
        )

        NotificationCenter.default.post(name: .appLanguageDidChange, object: nil)
    }

    // MARK: - String Resolution (for AppKit / Window Titles / Tooltips)

    public func string(_ resource: LocalizedStringResource) -> String {
        var localizedResource = resource
        localizedResource.locale = resolvedLanguage.locale
        return String(localized: localizedResource)
    }

    public subscript(resource: LocalizedStringResource) -> String {
        string(resource)
    }

    private func refreshSystemLanguage() {
        preferredLanguages = Locale.preferredLanguages
        guard preference == .system else { return }
        let resolved = AppLanguage.resolved(preferredLanguages: preferredLanguages)
        if resolved != resolvedLanguage {
            resolvedLanguage = resolved
            NotificationCenter.default.post(name: .appLanguageDidChange, object: nil)
        }
    }
}

// MARK: - Notification
public extension Notification.Name {
    static let appLanguageDidChange = Notification.Name("NekoTrans.appLanguageDidChange")
}
