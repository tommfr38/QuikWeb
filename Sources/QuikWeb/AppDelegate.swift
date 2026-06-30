import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var searchPanel: SearchPanel?
    private var hotKeyManager: HotKeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panel = SearchPanel()
        searchPanel = panel

        let settings = AppSettings.shared
        hotKeyManager = HotKeyManager(
            keyCode: settings.hotKey.keyCode,
            modifierFlags: settings.hotKey.carbonModifiers
        ) { [weak panel] in
            panel?.toggle()
        }

        statusBarController = StatusBarController()
    }

    /// QuikWeb is a menu-bar-resident app: closing the Settings window (its
    /// only ordinary window) must not quit the app.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
