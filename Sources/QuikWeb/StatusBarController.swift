import AppKit

/// The only UI surface QuikWeb shows outside its search panel and settings
/// window: the menu-bar status item. Its menu is deliberately just the two
/// entries the app is scoped to — "Menu" (settings) and "Exit" (quit).
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let settingsWindowController = SettingsWindowController()

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = IconLoader.image(named: "StatusBarIcon", template: true, pointSize: 18)
        statusItem.menu = StatusBarController.buildMenu(target: self)
    }

    private static func buildMenu(target: StatusBarController) -> NSMenu {
        let menu = NSMenu()

        let header = NSMenuItem(title: "QuikWeb", action: nil, keyEquivalent: "")
        header.image = IconLoader.image(named: "AppIcon256", pointSize: 16)
        header.isEnabled = false
        menu.addItem(header)

        menu.addItem(.separator())

        let menuItem = NSMenuItem(title: "Menu", action: #selector(openSettings), keyEquivalent: "")
        menuItem.image = IconLoader.image(named: "tab-general", template: true, pointSize: 16)
        menuItem.target = target
        menu.addItem(menuItem)

        let exitItem = NSMenuItem(title: "Exit", action: #selector(quit), keyEquivalent: "")
        exitItem.image = IconLoader.image(named: "menu-exit", template: true, pointSize: 16)
        exitItem.target = target
        menu.addItem(exitItem)

        return menu
    }

    @objc private func openSettings() {
        settingsWindowController.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
