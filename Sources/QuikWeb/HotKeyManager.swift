import AppKit
@preconcurrency import Carbon.HIToolbox

/// Manages a single global hotkey via Carbon's RegisterEventHotKey /
/// InstallEventHandler. This is used instead of NSEvent.addGlobalMonitorForEvents
/// specifically because it needs no Accessibility/Input Monitoring permission —
/// it's the standard mechanism for exactly this "summon a panel from anywhere"
/// use case.
///
/// kEventHotKeyPressed callbacks are routed back to Swift via a static
/// registry keyed by EventHotKeyID, looked up from a file-scope, non-capturing
/// callback (rather than userData/Unmanaged pointer-passing — InstallEventHandler's
/// userData belongs to the one shared event handler, not to a specific hotkey,
/// so the registry is the natural shape of this problem).
final class HotKeyManager {
    private static var registry: [UInt32: HotKeyManager] = [:]
    private static var nextID: UInt32 = 1
    private static var eventHandlerInstalled = false

    /// The app has exactly one logical hotkey manager for its lifetime;
    /// AppSettings uses this to live-update the binding when it changes.
    static private(set) var shared: HotKeyManager?

    private let hotKeyID: UInt32
    private var hotKeyRef: EventHotKeyRef?
    private let onPress: () -> Void

    init(keyCode: UInt32, modifierFlags: UInt32, onPress: @escaping () -> Void) {
        self.hotKeyID = HotKeyManager.nextID
        HotKeyManager.nextID += 1
        self.onPress = onPress

        HotKeyManager.installEventHandlerIfNeeded()
        register(keyCode: keyCode, modifierFlags: modifierFlags)
        HotKeyManager.shared = self
    }

    deinit {
        unregister()
    }

    /// Tears down the current binding and re-registers with a new combo.
    /// Safe to call repeatedly when the user picks a new shortcut in Settings.
    func updateBinding(keyCode: UInt32, modifierFlags: UInt32) {
        unregister()
        register(keyCode: keyCode, modifierFlags: modifierFlags)
    }

    private func register(keyCode: UInt32, modifierFlags: UInt32) {
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: HotKeyManager.fourCharCode("QkWb"), id: hotKeyID)

        let status = RegisterEventHotKey(
            keyCode,
            modifierFlags,
            id,
            GetEventDispatcherTarget(),
            0,
            &ref
        )

        guard status == noErr, let registeredRef = ref else {
            NSLog("QuikWeb: RegisterEventHotKey failed with status \(status)")
            return
        }

        hotKeyRef = registeredRef
        HotKeyManager.registry[hotKeyID] = self
    }

    private func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        HotKeyManager.registry.removeValue(forKey: hotKeyID)
    }

    fileprivate func handlePress() {
        onPress()
    }

    private static func installEventHandlerIfNeeded() {
        guard !eventHandlerInstalled else { return }
        eventHandlerInstalled = true

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // `hotKeyEventHandler` is a non-capturing global function, which Swift
        // converts implicitly to the C function pointer InstallEventHandler
        // expects. No explicit @convention(c) is needed (or legal) on a func
        // declaration.
        InstallEventHandler(
            GetEventDispatcherTarget(),
            hotKeyEventHandler,
            1,
            &eventType,
            nil,
            nil
        )
    }

    fileprivate static func manager(for id: UInt32) -> HotKeyManager? {
        registry[id]
    }

    private static func fourCharCode(_ string: String) -> OSType {
        var result: OSType = 0
        for byte in string.utf8.prefix(4) {
            result = (result << 8) + OSType(byte)
        }
        return result
    }
}

private func hotKeyEventHandler(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event = event else { return OSStatus(eventNotHandledErr) }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )

    guard status == noErr else { return status }

    HotKeyManager.manager(for: hotKeyID.id)?.handlePress()

    return noErr
}
