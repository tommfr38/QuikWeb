import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    /// Exactly one settings window exists for the app's lifetime; AppSettings
    /// uses this to push live theme changes onto its NSWindow.appearance
    /// synchronously, the same way it pushes them onto SearchPanel.shared.
    static private(set) var shared: SettingsWindowController?

    convenience init() {
        let hosting = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "QuikWeb"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 480, height: 420))
        window.center()
        window.isReleasedWhenClosed = false
        self.init(window: window)
        SettingsWindowController.shared = self
        applyAppearance()
    }

    /// Pins the whole settings window to the chosen theme via AppKit's real
    /// appearance chain. This is what makes every surface — the SwiftUI form
    /// chrome, the segmented control, AND the bridged NSVisualEffectView
    /// preview — flip together on a single click. We deliberately do NOT use
    /// SwiftUI's `.preferredColorScheme` for this: that routes through
    /// SwiftUI's preference system, which resolves a render pass later and so
    /// lags one click behind the views that set their appearance directly.
    func applyAppearance() {
        window?.appearance = AppSettings.shared.theme.nsAppearance
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
