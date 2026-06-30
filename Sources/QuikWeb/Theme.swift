import SwiftUI
import AppKit

enum AppTheme: String, CaseIterable, Identifiable, Codable, Hashable {
    case light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// The single source of truth for theming. Everything theme-sensitive is
    /// driven off the real AppKit appearance chain (NSWindow/NSView.appearance)
    /// rather than SwiftUI's `.preferredColorScheme`, because the latter only
    /// reaches SwiftUI-native views — not the bridged NSVisualEffectView blur
    /// or the NSTextField — and resolves a render pass later, which would make
    /// some surfaces flip a click behind the rest. Setting this directly makes
    /// every surface flip together on one click.
    var nsAppearance: NSAppearance {
        switch self {
        case .light: return NSAppearance(named: .aqua)!
        case .dark: return NSAppearance(named: .darkAqua)!
        }
    }
}

enum AccentColor: String, CaseIterable, Identifiable, Codable, Hashable {
    case indigo, cyan, violet, rose, emerald, orange

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .indigo: return Color(red: 0.388, green: 0.400, blue: 0.965)
        case .cyan: return Color(red: 0.133, green: 0.827, blue: 0.933)
        case .violet: return Color(red: 0.545, green: 0.361, blue: 0.965)
        case .rose: return Color(red: 0.957, green: 0.255, blue: 0.475)
        case .emerald: return Color(red: 0.063, green: 0.725, blue: 0.506)
        case .orange: return Color(red: 0.976, green: 0.451, blue: 0.086)
        }
    }

    var label: String { rawValue.capitalized }
}
