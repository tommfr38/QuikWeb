import SwiftUI
import AppKit
import Carbon.HIToolbox

/// A click-to-record control for rebinding the global shortcut. Deliberately
/// a plain NSView rather than NSButton: NSButton intercepts Space/Return as
/// its own press triggers, which would swallow exactly the keys someone is
/// likely to want to bind (Space is the default hotkey).
struct KeyRecorderView: NSViewRepresentable {
    @Binding var combo: KeyCombo

    func makeNSView(context: Context) -> KeyRecorderNSView {
        let view = KeyRecorderNSView()
        view.combo = combo
        view.onCapture = { newCombo in
            combo = newCombo
        }
        return view
    }

    func updateNSView(_ nsView: KeyRecorderNSView, context: Context) {
        nsView.combo = combo
    }
}

final class KeyRecorderNSView: NSView {
    var combo: KeyCombo? {
        didSet { needsDisplay = true }
    }
    var onCapture: ((KeyCombo) -> Void)?

    private var isRecording = false {
        didSet { needsDisplay = true }
    }

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 200, height: 28)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == UInt16(kVK_Escape), !event.modifierFlags.contains(.command) {
            isRecording = false
            return
        }

        let carbonModifiers = KeyRecorderNSView.carbonModifiers(from: event.modifierFlags)
        guard carbonModifiers != 0 else {
            // Require at least one modifier so the global hotkey can never
            // swallow ordinary typing in other apps.
            NSSound.beep()
            return
        }

        let newCombo = KeyCombo(keyCode: UInt32(event.keyCode), carbonModifiers: carbonModifiers)
        isRecording = false
        onCapture?(newCombo)
    }

    override func flagsChanged(with event: NSEvent) {
        // No-op: only complete combos are captured, on keyDown.
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
        (isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.15) : NSColor.controlBackgroundColor).setFill()
        path.fill()
        (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = 1
        path.stroke()

        let text = isRecording ? "Press new shortcut…" : (combo?.displayString ?? "Click to record")
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: isRecording ? NSColor.controlAccentColor : NSColor.labelColor,
        ]
        let size = text.size(withAttributes: attrs)
        let point = NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2)
        text.draw(at: point, withAttributes: attrs)
    }
}
