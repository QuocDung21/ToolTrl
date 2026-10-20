import AppKit
import Combine
import Defaults
import Sparkle
import SwiftUI

/// Custom Sparkle updater delegate that dynamically returns the feed URL
/// based on the user's selected update channel preference.
public final class NekoUpdaterDelegate: NSObject, SPUUpdaterDelegate {
    public func feedURLString(for updater: SPUUpdater) -> String? {
        Defaults[.updateChannel].feedURL.absoluteString
    }
}

/// Centralized Sparkle 2 Auto-Updater service using standard Sparkle UI.
@MainActor
public final class UpdaterService: ObservableObject {
    public static let shared = UpdaterService()

    private let updaterController: SPUStandardUpdaterController
    public var updater: SPUUpdater { updaterController.updater }
    private let updaterDelegate = NekoUpdaterDelegate()
    private var cancellables = Set<AnyCancellable>()

    @Published public private(set) var canCheckForUpdates: Bool = false

    public var automaticallyChecksForUpdates: Bool {
        get { updater.automaticallyChecksForUpdates }
        set {
            objectWillChange.send()
            updater.automaticallyChecksForUpdates = newValue
        }
    }

    public var automaticallyDownloadsUpdates: Bool {
        get { updater.automaticallyDownloadsUpdates }
        set {
            objectWillChange.send()
            updater.automaticallyDownloadsUpdates = newValue
        }
    }

    public var lastUpdateCheckDate: Date? {
        updater.lastUpdateCheckDate
    }

    private init() {
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        updaterController = SPUStandardUpdaterController(
            startingUpdater: !isRunningTests,
            updaterDelegate: updaterDelegate,
            userDriverDelegate: nil
        )

        updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$canCheckForUpdates)
    }

    public func checkForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        updaterController.checkForUpdates(nil)
    }
}
