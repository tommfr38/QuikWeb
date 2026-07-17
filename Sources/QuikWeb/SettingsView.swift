import SwiftUI
import AppKit

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { TabIcon(title: "General", iconName: "tab-general") }
            HotkeySettingsTab()
                .tabItem { TabIcon(title: "Hotkey", iconName: "tab-hotkey") }
            AppearanceSettingsTab()
                .tabItem { TabIcon(title: "Appearance", iconName: "tab-appearance") }
            AboutSettingsTab()
                .tabItem { TabIcon(title: "About", iconName: "tab-about") }
        }
        .frame(width: 480, height: 420)
    }
}

private struct TabIcon: View {
    let title: String
    let iconName: String

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(nsImage: IconLoader.image(named: iconName, template: true, pointSize: 18))
        }
    }
}

struct GeneralSettingsTab: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var loginItemEnabled = LoginItemManager.isEnabled
    @State private var needsApproval = LoginItemManager.requiresApproval

    var body: some View {
        Form {
            Section {
                Picker("Search engine", selection: $settings.searchEngine) {
                    ForEach(SearchEngine.allCases) { engine in
                        Text(engine.label).tag(engine)
                    }
                }
                if settings.searchEngine == .custom {
                    TextField("URL template (use {query})", text: $settings.customSearchTemplate)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Section {
                Toggle("Detect website addresses", isOn: $settings.websiteDetection)
                Text("Typing just an address like \"youtube.com\" opens the website directly instead of searching for it. Queries with other words around it (\"is it safe github.com\") still search normally.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                Toggle("Launch QuikWeb at login", isOn: $loginItemEnabled)
                    .onChange(of: loginItemEnabled) { newValue in
                        let success = LoginItemManager.setEnabled(newValue)
                        if !success {
                            loginItemEnabled = LoginItemManager.isEnabled
                        }
                        needsApproval = LoginItemManager.requiresApproval
                    }
                if needsApproval {
                    HStack {
                        Text("Needs approval in System Settings → Login Items.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Settings") {
                            LoginItemManager.openLoginItemsSettings()
                        }
                    }
                }
            }

            Section {
                LabeledContent("Current shortcut", value: settings.hotKey.displayString)
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
}

struct HotkeySettingsTab: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Global shortcut").font(.headline)
            Text("Click the field, then press a new key combination. At least one modifier key (⌘ ⌥ ⌃ ⇧) is required.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            KeyRecorderView(combo: $settings.hotKey)
                .frame(width: 220, height: 30)

            Button("Reset to Default (⌥Space)") {
                settings.hotKey = .default
            }

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct AppearanceSettingsTab: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Theme").font(.headline)
                Picker("", selection: $settings.theme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.label).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Accent color").font(.headline)
                HStack(spacing: 10) {
                    ForEach(AccentColor.allCases) { accent in
                        Circle()
                            .fill(accent.color)
                            .frame(width: 26, height: 26)
                            .overlay(
                                Circle().strokeBorder(Color.primary, lineWidth: settings.accentColor == accent ? 2 : 0)
                            )
                            .onTapGesture { settings.accentColor = accent }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Preview").font(.headline)
                SearchPanelPreview()
            }

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct SearchPanelPreview: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: IconLoader.image(named: "glyph-search", template: true, pointSize: 16))
                .resizable()
                .renderingMode(.template)
                .foregroundColor(settings.accentColor.color)
                .frame(width: 16, height: 16)
            Text("Search the web…")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(width: 360, height: 44)
        .background(VisualEffectBackground(material: .hudWindow, appearance: settings.theme.nsAppearance))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.08)))
    }
}

struct AboutSettingsTab: View {
    @State private var checking = false
    @State private var statusMessage: String?
    @State private var updateURL: URL?

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: IconLoader.image(named: "AppIcon256", pointSize: 96))
                .resizable()
                .frame(width: 96, height: 96)
            Text("QuikWeb").font(.title2).bold()
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Press your shortcut from anywhere to search the web instantly.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            VStack(spacing: 8) {
                Button(action: checkForUpdates) {
                    HStack(spacing: 6) {
                        if checking {
                            ProgressView().controlSize(.small)
                        }
                        Text(checking ? "Checking…" : "Check for Updates")
                    }
                }
                .disabled(checking)

                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }
                if let updateURL {
                    Button("Download Update") {
                        NSWorkspace.shared.open(updateURL)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.top, 6)

            Spacer()
            Button("Quit QuikWeb") {
                NSApp.terminate(nil)
            }
            .padding(.bottom, 16)
        }
        .padding(.top, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func checkForUpdates() {
        checking = true
        statusMessage = nil
        updateURL = nil
        UpdateChecker.check { result in
            checking = false
            switch result {
            case .upToDate(let version):
                statusMessage = "You're on the latest version (v\(version))."
            case .updateAvailable(let latest, let url):
                statusMessage = "Version \(latest) is available."
                updateURL = url
            case .failed(let reason):
                statusMessage = "Couldn't check for updates: \(reason)"
            }
        }
    }
}
