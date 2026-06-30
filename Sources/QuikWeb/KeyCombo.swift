import Carbon

/// A global-hotkey binding. Stores Carbon-native keyCode/modifier values
/// (not NSEvent.ModifierFlags) since that's what RegisterEventHotKey needs —
/// translation from NSEvent happens once, at KeyRecorderView's capture point.
struct KeyCombo: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32

    static let `default` = KeyCombo(keyCode: UInt32(kVK_Space), carbonModifiers: UInt32(optionKey))

    var displayString: String {
        var result = ""
        if carbonModifiers & UInt32(controlKey) != 0 { result += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { result += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { result += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { result += "⌘" }
        result += KeyCombo.name(forKeyCode: keyCode)
        return result
    }

    private static let specialKeyNames: [Int: String] = [
        kVK_Space: "Space",
        kVK_Return: "Return",
        kVK_Tab: "Tab",
        kVK_Escape: "Escape",
        kVK_Delete: "Delete",
        kVK_ForwardDelete: "Forward Delete",
        kVK_LeftArrow: "Left",
        kVK_RightArrow: "Right",
        kVK_UpArrow: "Up",
        kVK_DownArrow: "Down",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4",
        kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8",
        kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]

    static func name(forKeyCode keyCode: UInt32) -> String {
        if let special = specialKeyNames[Int(keyCode)] {
            return special
        }
        if let layoutChar = characterFromCurrentLayout(keyCode: keyCode), !layoutChar.isEmpty {
            return layoutChar.uppercased()
        }
        return "Key \(keyCode)"
    }

    /// Translates a virtual key code to a displayable character using the
    /// user's actual current keyboard layout (rather than assuming ANSI/US),
    /// via the same Carbon TIS/UCKeyTranslate APIs AppKit itself uses.
    private static func characterFromCurrentLayout(keyCode: UInt32) -> String? {
        guard let sourceUnmanaged = TISCopyCurrentKeyboardLayoutInputSource() else { return nil }
        let source = sourceUnmanaged.takeRetainedValue()
        guard let layoutDataPointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(layoutDataPointer).takeUnretainedValue() as Data

        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0

        let status = layoutData.withUnsafeBytes { rawBuffer -> OSStatus in
            guard let keyboardLayoutPtr = rawBuffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else {
                return OSStatus(eventNotHandledErr)
            }
            return UCKeyTranslate(
                keyboardLayoutPtr,
                UInt16(keyCode),
                UInt16(kUCKeyActionDown),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &length,
                &chars
            )
        }

        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }
}
