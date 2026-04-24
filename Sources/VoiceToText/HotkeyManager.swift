import Cocoa
import Carbon

private func log(_ msg: String) {
    #if DEBUG
    fputs("[Hotkey] \(msg)\n", stderr)
    #endif
}

final class HotkeyManager {
    private var hotkeyRef: EventHotKeyRef?
    private let onToggle: () -> Void
    var onKeyUp: (() -> Void)?
    var keyCode: UInt16 = 1
    var modifiers: NSEvent.ModifierFlags = [.command, .shift]
    var isEnabled = true

    private static weak var current: HotkeyManager?
    private static var handlerInstalled = false

    init(onToggle: @escaping () -> Void) {
        self.onToggle = onToggle
    }

    func register() {
        unregister()
        HotkeyManager.current = self

        if !HotkeyManager.handlerInstalled {
            installCarbonHandler()
            HotkeyManager.handlerInstalled = true
        }

        let carbonMods = carbonModifiers(from: modifiers)
        var hotkeyID = EventHotKeyID(signature: OSType(0x4543_4857), id: 1) // "ECHW"

        let status = RegisterEventHotKey(
            UInt32(keyCode),
            carbonMods,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        if status == noErr {
            log("Registered — keyCode=\(keyCode) modifiers=\(modifiers.rawValue)")
        } else {
            log("ERROR: RegisterEventHotKey failed with status \(status)")
        }
    }

    func unregister() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
        if HotkeyManager.current === self {
            HotkeyManager.current = nil
        }
    }

    private func installCarbonHandler() {
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                guard let mgr = HotkeyManager.current, mgr.isEnabled else {
                    return OSStatus(eventNotHandledErr)
                }
                if GetEventKind(event) == UInt32(kEventHotKeyPressed) {
                    log("MATCH pressed")
                    mgr.onToggle()
                } else {
                    log("MATCH released")
                    mgr.onKeyUp?()
                }
                return noErr
            },
            2,
            &eventTypes,
            nil,
            nil
        )
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        // Note: .function (fn) is not supported by Carbon hotkeys.
        // If the user has fn in their modifiers, we register without it.
        return carbon
    }

    deinit {
        unregister()
    }
}
