import SwiftUI

#if canImport(UIKit)
@main
public struct NekoTransiPadApp: App {
    public init() {}
    
    public var body: some Scene {
        WindowGroup {
            iPadStudioMainView()
        }
    }
}
#endif
