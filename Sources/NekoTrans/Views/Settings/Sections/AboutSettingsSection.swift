import Defaults
import Sparkle
import SwiftUI

public struct AboutSettingsSection: View {
    private var iconService = AppIconService.shared
    @ObservedObject private var flags = FeatureFlagService.shared
    @ObservedObject private var updaterService = UpdaterService.shared

    @Default(.updateChannel) private var updateChannel
    @State private var automaticallyChecksForUpdates: Bool = UpdaterService.shared.automaticallyChecksForUpdates
    @State private var automaticallyDownloadsUpdates: Bool = UpdaterService.shared.automaticallyDownloadsUpdates

    @State private var tapCount: Int = 0
    @State private var showUnlockedAlert: Bool = false

    public init() {}

    public var body: some View {
        Form {
            appInfoSection
            softwareUpdatesSection
            updateChannelSection
            sourceSection
        }
        .formStyle(.grouped)
        .onAppear {
            automaticallyChecksForUpdates = updaterService.automaticallyChecksForUpdates
            automaticallyDownloadsUpdates = updaterService.automaticallyDownloadsUpdates
        }
        .alert(.aboutAlertTitle, isPresented: $showUnlockedAlert) {
            Button(.aboutAlertDismiss, role: .cancel) {}
        } message: {
            Text(.aboutAlertMessage)
        }
    }

    // MARK: - App Info

    private var appInfoSection: some View {
        Section {
            VStack(spacing: 12) {
                iconService.currentImage
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .foregroundColor(iconService.selectedType.accentColor)

                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Text("NekoTrans")
                            .font(.system(size: 20, weight: .bold))

                        Text(UpdateChannel.buildChannel.localizedTitle)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(UpdateChannel.buildChannel.badgeColor).opacity(0.2))
                            .foregroundStyle(Color(UpdateChannel.buildChannel.badgeColor))
                            .clipShape(Capsule())
                    }

                    Text(.aboutVersion)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            tapCount += 1
                            if tapCount >= 7 {
                                tapCount = 0
                                flags.unlockDeveloperMode()
                                showUnlockedAlert = true
                            }
                        }

                    if flags.isDeveloperModeUnlocked {
                        HStack(spacing: 4) {
                            Image(systemName: "flask.fill")
                                .font(.system(size: 10))
                            Text(.aboutDevModeUnlocked)
                                .font(.system(size: 10.5, weight: .semibold))
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(6)
                        .padding(.top, 2)
                    }
                }

                Text(.aboutDescription)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                Button {
                    updaterService.checkForUpdates()
                } label: {
                    Label(.updaterCheckForUpdates, systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(!updaterService.canCheckForUpdates)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Sparkle Software Updates

    private var softwareUpdatesSection: some View {
        Section {
            Toggle(isOn: $automaticallyChecksForUpdates) {
                Text(.updaterAutoCheck)
            }
            .onChange(of: automaticallyChecksForUpdates) { _, newValue in
                updaterService.automaticallyChecksForUpdates = newValue
            }

            Toggle(isOn: $automaticallyDownloadsUpdates) {
                Text(.updaterAutoDownload)
            }
            .disabled(!automaticallyChecksForUpdates)
            .onChange(of: automaticallyDownloadsUpdates) { _, newValue in
                updaterService.automaticallyDownloadsUpdates = newValue
            }
        } header: {
            Text(.sectionSoftwareUpdates)
        }
    }

    // MARK: - Update Channel Selector

    private var updateChannelSection: some View {
        Section {
            ForEach(UpdateChannel.availableChannels) { channel in
                Button {
                    updateChannel = channel
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: channel.badgeIcon)
                            .font(.system(size: 13))
                            .foregroundStyle(Color(channel.badgeColor))
                            .frame(width: 20, alignment: .center)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(channel.localizedTitle)
                                .foregroundStyle(.primary)
                            Text(channel.localizedDescription)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if updateChannel == channel {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color(channel.badgeColor))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(.sectionUpdateChannel)
        }
    }

    // MARK: - Source & Author

    private var sourceSection: some View {
        Section {
            LabeledContent {
                Text("Dũng Nguyễn Quốc (QuocDung21)")
            } label: {
                Text(.aboutAuthor)
            }

            LabeledContent {
                Text(.aboutLicenseValue)
            } label: {
                Text(.aboutLicense)
            }

            Link(destination: URL(string: "https://github.com/QuocDung21/ToolTrl.git")!) {
                HStack {
                    Text(.aboutGithubLink)
                    Spacer()
                    Image(systemName: "arrow.up.forward.app")
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text(.sectionAboutSource)
        }
    }
}

// MARK: - Preview

#Preview("About — Vietnamese") {
    let englishLocalization: Localization = {
        let l = Localization()
        l.setPreference(.language(.vietnamese))
        return l
    }()

    LocalizedRootView(localization: englishLocalization) {
        AboutSettingsSection()
    }
    .frame(width: 600, height: 600)
}
#Preview("About — English") {
    let englishLocalization: Localization = {
        let l = Localization()
        l.setPreference(.language(.english))
        return l
    }()
    LocalizedRootView(localization: englishLocalization) {
        AboutSettingsSection()
    }
    .frame(width: 600, height: 600)
}
