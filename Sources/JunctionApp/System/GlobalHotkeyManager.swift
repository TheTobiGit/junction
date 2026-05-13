import AppKit
import Carbon

struct HotkeyDescriptor: Hashable {
    let id: UInt32
    let keyCode: UInt32
    let modifiers: UInt32
}

enum HotkeyAction: UInt32 {
    case summonPicker = 1
    case rerouteLast = 2
    case pasteAndOpen = 3
}

final class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()

    var onAction: ((HotkeyAction) -> Void)?

    private var registered: [HotkeyAction: EventHotKeyRef] = [:]
    private var handlerRef: EventHandlerRef?
    private let signature: OSType = 0x4A6E6374 // 'Jnct'

    private init() {
        installHandler()
    }

    func reload(from settings: HotkeySettings) {
        clearAll()
        register(binding: settings.summonPicker, action: .summonPicker)
        register(binding: settings.rerouteLast, action: .rerouteLast)
        register(binding: settings.pasteAndOpen, action: .pasteAndOpen)
    }

    private func installHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let event, let userData else { return noErr }
                var hkID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout.size(ofValue: hkID),
                    nil,
                    &hkID
                )
                let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                if let action = HotkeyAction(rawValue: hkID.id) {
                    DispatchQueue.main.async { manager.onAction?(action) }
                }
                return noErr
            },
            1,
            &spec,
            userData,
            &handlerRef
        )
    }

    private func register(binding: HotkeyBinding, action: HotkeyAction) {
        guard binding.enabled, binding.keyCode != 0 else { return }

        let hotKeyID = EventHotKeyID(signature: signature, id: action.rawValue)
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            binding.keyCode,
            binding.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status == noErr, let ref = hotKeyRef {
            registered[action] = ref
        } else {
            NSLog("Junction: failed to register hotkey \(action) status=\(status)")
        }
        _ = hotKeyID
    }

    private func clearAll() {
        for (_, ref) in registered {
            UnregisterEventHotKey(ref)
        }
        registered.removeAll()
    }
}

enum HotkeyFormatting {
    static func modifierString(_ carbonFlags: UInt32) -> String {
        var parts: [String] = []
        if (carbonFlags & UInt32(controlKey)) != 0 { parts.append("⌃") }
        if (carbonFlags & UInt32(optionKey)) != 0 { parts.append("⌥") }
        if (carbonFlags & UInt32(shiftKey)) != 0 { parts.append("⇧") }
        if (carbonFlags & UInt32(cmdKey)) != 0 { parts.append("⌘") }
        return parts.joined()
    }

    static func keyString(_ keyCode: UInt32) -> String {
        if let special = specialKeyNames[Int(keyCode)] { return special }
        let inputSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        if let layoutDataPtr = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) {
            let layoutData = Unmanaged<CFData>.fromOpaque(layoutDataPtr).takeUnretainedValue() as Data
            var deadKeyState: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var length = 0
            let result = layoutData.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> OSStatus in
                guard let base = bytes.baseAddress else { return -1 }
                let layoutPtr = base.assumingMemoryBound(to: UCKeyboardLayout.self)
                return UCKeyTranslate(
                    layoutPtr,
                    UInt16(keyCode),
                    UInt16(kUCKeyActionDisplay),
                    0,
                    UInt32(LMGetKbdType()),
                    OptionBits(kUCKeyTranslateNoDeadKeysBit),
                    &deadKeyState,
                    chars.count,
                    &length,
                    &chars
                )
            }
            if result == noErr, length > 0 {
                return String(utf16CodeUnits: chars, count: length).uppercased()
            }
        }
        return "Key-\(keyCode)"
    }

    static func cocoaModifiersToCarbon(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        return carbon
    }

    private static let specialKeyNames: [Int: String] = [
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋",
        76: "⌤", 117: "⌦",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5",
        97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10",
        103: "F11", 111: "F12",
    ]
}
