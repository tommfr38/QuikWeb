import AppKit

/// Loads PNGs generated from Icons/*.svg out of the app bundle's Resources
/// folder (hand-copied there by Scripts/build_app.sh — see plan notes on why
/// this skips SPM's Bundle.module). Always returns a visible image: if a
/// resource is somehow missing, a placeholder dot is drawn instead so no
/// icon slot in the UI is ever literally blank.
enum IconLoader {
    static func image(named name: String, template: Bool = false, pointSize: CGFloat? = nil) -> NSImage {
        let image: NSImage
        if let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let loaded = NSImage(contentsOf: url) {
            image = loaded
        } else {
            image = fallbackImage()
        }
        image.isTemplate = template
        if let pointSize {
            image.size = NSSize(width: pointSize, height: pointSize)
        }
        return image
    }

    private static func fallbackImage() -> NSImage {
        let fallback = NSImage(size: NSSize(width: 24, height: 24))
        fallback.lockFocus()
        NSColor.systemGray.setFill()
        NSBezierPath(ovalIn: NSRect(x: 2, y: 2, width: 20, height: 20)).fill()
        fallback.unlockFocus()
        return fallback
    }
}
