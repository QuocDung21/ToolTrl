import AppKit
import Foundation
import Defaults

/// Service for managing application exclusions and silent mode.
/// Suppresses selection bubbles, in-place replacements, and popups when focus is in blacklisted apps.
/// Inherited from Easydict's `EZAppExclusion` architecture.
@MainActor
public final class AppExclusionService: ObservableObject {
    public static let shared = AppExclusionService()

    @Published public var excludedBundleIDs: [String] = Defaults[.excludedAppBundleIdentifiers]

    public struct AppInfo: Identifiable, Hashable {
        public let id: String // bundleIdentifier
        public let name: String
        public let bundleIdentifier: String
        public let icon: NSImage?

        public init(name: String, bundleIdentifier: String, icon: NSImage? = nil) {
            self.id = bundleIdentifier
            self.name = name
            self.bundleIdentifier = bundleIdentifier
            self.icon = icon
        }

        public static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
            lhs.bundleIdentifier == rhs.bundleIdentifier
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(bundleIdentifier)
        }
    }

    private init() {
        self.excludedBundleIDs = Defaults[.excludedAppBundleIdentifiers]
    }

    /// Determines if the current frontmost application is on the exclusion list.
    public func isCurrentAppExcluded() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return false }
        guard let bundleID = frontApp.bundleIdentifier else { return false }

        // Never exclude NekoTrans itself
        if bundleID == Bundle.main.bundleIdentifier {
            return false
        }

        return isAppExcluded(bundleIdentifier: bundleID)
    }

    /// Checks if a specific bundle identifier is excluded.
    public func isAppExcluded(bundleIdentifier: String?) -> Bool {
        guard let bundleID = bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines), !bundleID.isEmpty else {
            return false
        }
        return Defaults[.excludedAppBundleIdentifiers].contains { $0.caseInsensitiveCompare(bundleID) == .orderedSame }
    }

    /// Adds an application bundle ID to the exclusion list.
    public func addExcludedApp(bundleIdentifier: String) {
        let cleanID = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanID.isEmpty else { return }

        var list = Defaults[.excludedAppBundleIdentifiers]
        if !list.contains(where: { $0.caseInsensitiveCompare(cleanID) == .orderedSame }) {
            list.append(cleanID)
            Defaults[.excludedAppBundleIdentifiers] = list
            self.excludedBundleIDs = list
            AppLog.app.info("Added app to exclusion list: \(cleanID, privacy: .public)")
        }
    }

    /// Removes an application bundle ID from the exclusion list.
    public func removeExcludedApp(bundleIdentifier: String) {
        var list = Defaults[.excludedAppBundleIdentifiers]
        list.removeAll(where: { $0.caseInsensitiveCompare(bundleIdentifier) == .orderedSame })
        Defaults[.excludedAppBundleIdentifiers] = list
        self.excludedBundleIDs = list
        AppLog.app.info("Removed app from exclusion list: \(bundleIdentifier, privacy: .public)")
    }

    /// Retrieves running regular user-facing applications with their icons.
    public func getRunningApplications() -> [AppInfo] {
        let apps = NSWorkspace.shared.runningApplications
        var results: [AppInfo] = []

        for app in apps where app.activationPolicy == .regular {
            guard let bundleID = app.bundleIdentifier, bundleID != Bundle.main.bundleIdentifier else { continue }
            let name = app.localizedName ?? bundleID
            let icon = app.icon
            results.append(AppInfo(name: name, bundleIdentifier: bundleID, icon: icon))
        }

        return results.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    /// Resolves display name and icon for a bundle identifier.
    public func resolveAppInfo(for bundleIdentifier: String) -> AppInfo {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            let name = FileManager.default.displayName(atPath: url.path)
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            return AppInfo(name: name, bundleIdentifier: bundleIdentifier, icon: icon)
        }

        // Fallback: derive name from last component of bundleID
        let fallbackName = bundleIdentifier.components(separatedBy: ".").last?.capitalized ?? bundleIdentifier
        return AppInfo(name: fallbackName, bundleIdentifier: bundleIdentifier, icon: nil)
    }
}
