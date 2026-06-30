import Foundation
import Combine

/// UserDefaults-backed settings store. Changing `hotKey` here is the single
/// source of truth for rebinding: it persists the new combo AND re-registers
/// HotKeyManager.shared live, so call sites never have to remember to do both.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var hotKey: KeyCombo {
        didSet {
            persistHotKey()
            HotKeyManager.shared?.updateBinding(keyCode: hotKey.keyCode, modifierFlags: hotKey.carbonModifiers)
        }
    }
    @Published var searchEngine: SearchEngine {
        didSet { defaults.set(searchEngine.rawValue, forKey: Keys.searchEngine) }
    }
    @Published var customSearchTemplate: String {
        didSet { defaults.set(customSearchTemplate, forKey: Keys.customSearchTemplate) }
    }
    @Published var theme: AppTheme {
        didSet {
            defaults.set(theme.rawValue, forKey: Keys.theme)
            // Applied synchronously, in this same click's call stack, to BOTH
            // windows. Every theme-sensitive surface is driven directly off
            // NSWindow.appearance here — no surface relies on SwiftUI's
            // `.preferredColorScheme` (which resolves a pass later and would
            // make some elements flip a click behind the rest).
            SearchPanel.shared?.applyAppearance()
            SettingsWindowController.shared?.applyAppearance()
        }
    }
    @Published var accentColor: AccentColor {
        didSet { defaults.set(accentColor.rawValue, forKey: Keys.accentColor) }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let hotKey = "hotKey"
        static let searchEngine = "searchEngine"
        static let customSearchTemplate = "customSearchTemplate"
        static let theme = "theme"
        static let accentColor = "accentColor"
    }

    private init() {
        if let data = defaults.data(forKey: Keys.hotKey),
           let decoded = try? JSONDecoder().decode(KeyCombo.self, from: data) {
            hotKey = decoded
        } else {
            hotKey = .default
        }
        searchEngine = SearchEngine(rawValue: defaults.string(forKey: Keys.searchEngine) ?? "") ?? .google
        customSearchTemplate = defaults.string(forKey: Keys.customSearchTemplate)
            ?? "https://www.google.com/search?q={query}"
        theme = AppTheme(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .dark
        accentColor = AccentColor(rawValue: defaults.string(forKey: Keys.accentColor) ?? "") ?? .indigo
    }

    private func persistHotKey() {
        if let data = try? JSONEncoder().encode(hotKey) {
            defaults.set(data, forKey: Keys.hotKey)
        }
    }
}
