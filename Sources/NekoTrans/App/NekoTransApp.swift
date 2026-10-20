import SwiftUI
import SettingsAccess

@main
struct NekoTransApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            LocalizedRootView {
                SettingsView()
            }
        }
    }
}
