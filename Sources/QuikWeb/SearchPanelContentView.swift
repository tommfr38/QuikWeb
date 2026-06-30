import SwiftUI
import AppKit

/// Holds the live query text. A plain ObservableObject (rather than SwiftUI
/// @State) so SearchPanel can reset it directly from show()/hide() without
/// reaching into the view hierarchy's private state.
final class SearchPanelState: ObservableObject {
    @Published var query: String = ""
}

/// SwiftUI's TextField does not reliably win first responder inside a
/// borderless .nonactivatingPanel (see SearchPanel.show()) — the panel
/// becoming key and SwiftUI's focus engine catching up can race. Routing
/// focus through a plain NSTextField reference removes that race entirely.
final class SearchFieldFocusCoordinator {
    weak var textField: NSTextField?

    func focus() {
        DispatchQueue.main.async { [weak self] in
            guard let field = self?.textField, let window = field.window else { return }
            window.makeFirstResponder(field)
        }
    }
}

struct SearchPanelContentView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var state: SearchPanelState
    let focusCoordinator: SearchFieldFocusCoordinator
    var onSubmit: (String) -> Void
    var onCancel: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(nsImage: IconLoader.image(named: "glyph-search", template: true, pointSize: 22))
                .resizable()
                .renderingMode(.template)
                .foregroundColor(settings.accentColor.color)
                .frame(width: 22, height: 22)

            SearchTextField(
                text: $state.query,
                focusCoordinator: focusCoordinator,
                onSubmit: { onSubmit(state.query) },
                onCancel: onCancel
            )
            .frame(height: 34)
        }
        .padding(.horizontal, 20)
        .frame(width: 600, height: 64)
        .background(VisualEffectBackground(material: .hudWindow, appearance: settings.theme.nsAppearance))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        // No .preferredColorScheme: the panel's own NSWindow.appearance
        // (set in SearchPanel.applyAppearance) drives the SwiftUI colorScheme
        // here, which keeps every surface flipping together on one click.
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var appearance: NSAppearance?

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = appearance
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.appearance = appearance
    }
}

private struct SearchTextField: NSViewRepresentable {
    @Binding var text: String
    let focusCoordinator: SearchFieldFocusCoordinator
    var onSubmit: () -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = NSFont.systemFont(ofSize: 24, weight: .regular)
        field.placeholderString = "Search the web…"
        field.lineBreakMode = .byTruncatingTail
        field.delegate = context.coordinator
        focusCoordinator.textField = field
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: SearchTextField
        init(_ parent: SearchTextField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onCancel()
                return true
            }
            return false
        }
    }
}
