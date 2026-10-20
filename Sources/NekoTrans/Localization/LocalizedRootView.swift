//
//  LocalizedRootView.swift
//  NekoTrans
//
//  Created by Dũng Nguyễn Quốc on 4/10/26.
//

import SwiftUI

/// Root view bọc mọi cây SwiftUI được host bởi AppKit (`NSHostingView` / `NSHostingController`).
///
/// **Vai trò**: Cầu nối giữa AppKit và SwiftUI.
/// - Nhận các service toàn cục qua `init` (dependency injection).
/// - Inject lại vào SwiftUI environment cho toàn bộ cây view con.
///
/// **Pattern** (Composition Root):
/// - **Root view** → `@ObservedObject`, nhận qua `init`.
/// - **View con cháu** → `@EnvironmentObject`, nhận từ environment.
/// - **Chỉ 1 chỗ inject** → dễ kiểm soát, không crash.
///
/// **Cách dùng**:
/// ```swift
/// let rootView = LocalizedRootView {
///     SettingsView()
/// }
/// let hosting = NSHostingView(rootView: rootView)
/// ```
///
/// **Preview/Test**:
/// ```swift
/// #Preview {
///     LocalizedRootView(localization: Localization()) {
///         SettingsView()
///     }
/// }
/// ```
@MainActor
public struct LocalizedRootView<Content: View>: View {

    // MARK: - Dependencies

    @ObservedObject private var localization: Localization
    @ObservedObject private var flags: FeatureFlagService

    // MARK: - Content

    private let content: Content

    // MARK: - Init

    public init(
        localization: Localization? = nil,
        flags: FeatureFlagService? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.localization = localization ?? Localization.shared
        self.flags = flags ?? FeatureFlagService.shared
        self.content = content()
    }

    // MARK: - Body

    public var body: some View {
        content
            .environmentObject(localization)
            .environmentObject(flags)
            .environment(\.locale, localization.resolvedLanguage.locale)
            .environment(\.layoutDirection, localization.resolvedLanguage.layoutDirection)
    }
}
