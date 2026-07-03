import AppKit
import SwiftUI

/// Spotlight-style centered floating search bar. Borderless and non-activating
/// but explicitly made key-focusable so the embedded text field receives
/// keystrokes the instant the hotkey fires.
final class SearchPanel: NSPanel {
    /// The app has exactly one search panel for its lifetime; AppSettings
    /// uses this to push live theme changes onto it immediately, the same
    /// way it pushes live hotkey changes onto HotKeyManager.shared.
    static private(set) var shared: SearchPanel?

    private let panelState = SearchPanelState()
    private let focusCoordinator = SearchFieldFocusCoordinator()

    convenience init() {
        self.init(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 600, height: 64)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        configure()
        SearchPanel.shared = self
    }

    private func configure() {
        isFloatingPanel = true
        level = .floating
        // .fullScreenAuxiliary is what lets the bar appear even while a
        // different app is full-screen in another Space — easy to miss but
        // required for a "summon from anywhere" tool to actually work anywhere.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovable = false

        // The panel is ~entirely a text field; it should be ready to type
        // into the instant it's shown, not deferred until a click lands.
        becomesKeyOnlyIfNeeded = false
        hidesOnDeactivate = false

        let content = SearchPanelContentView(
            state: panelState,
            focusCoordinator: focusCoordinator,
            onSubmit: { [weak self] query in self?.handleSubmit(query: query) },
            onCancel: { [weak self] in self?.hide() }
        )
        let hosting = NSHostingView(rootView: content)
        hosting.frame = NSRect(origin: .zero, size: NSSize(width: 600, height: 64))
        contentView = hosting

        applyAppearance()
    }

    /// Sets the panel's own NSAppearance from the current theme setting. This
    /// is what makes the embedded NSTextField (text/cursor/selection color)
    /// consistent with the chosen theme — VisualEffectBackground only covers
    /// the blur material, and SwiftUI's .preferredColorScheme doesn't reach
    /// AppKit-bridged sibling views like the text field at all.
    ///
    /// Assigning `appearance` alone doesn't reliably force AppKit to
    /// re-resolve already-rendered vibrancy immediately, so this also walks
    /// the view tree marking everything dirty for an immediate full redraw.
    func applyAppearance() {
        let newAppearance = AppSettings.shared.theme.nsAppearance
        appearance = newAppearance
        contentView?.appearance = newAppearance
        markSubtreeNeedsDisplay(contentView)
    }

    private func markSubtreeNeedsDisplay(_ view: NSView?) {
        guard let view else { return }
        view.needsDisplay = true
        view.subviews.forEach(markSubtreeNeedsDisplay)
    }

    /// Borderless .nonactivatingPanel windows don't become key by default;
    /// overriding this is required so the text field can receive keystrokes.
    /// canBecomeMain is intentionally left alone — this panel should never
    /// become the app's main window, matching real Spotlight's behavior of
    /// not stealing "main window" status from whatever app was frontmost.
    override var canBecomeKey: Bool { true }

    override func resignKey() {
        super.resignKey()
        hide()
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        panelState.query = ""
        centerOnActiveScreen()
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        focusCoordinator.focus()
    }

    func hide() {
        orderOut(nil)
    }

    private func centerOnActiveScreen() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let screenFrame = screen.visibleFrame
        let size = frame.size
        let originX = screenFrame.midX - size.width / 2
        // Positioned above vertical center, Spotlight-style, not dead center.
        let originY = screenFrame.midY + screenFrame.height * 0.15
        setFrameOrigin(NSPoint(x: originX, y: originY))
    }

    private func handleSubmit(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let settings = AppSettings.shared

        // Website detection: a bare "name.tld" query opens the site directly;
        // anything with surrounding words falls through to a normal search.
        if settings.websiteDetection, let direct = WebsiteDetector.directURL(for: trimmed) {
            NSWorkspace.shared.open(direct)
            hide()
            return
        }

        if let url = settings.searchEngine.url(for: trimmed, customTemplate: settings.customSearchTemplate) {
            NSWorkspace.shared.open(url)
        }
        hide()
    }
}
