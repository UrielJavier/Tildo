import Cocoa
import CoreGraphics

/// Holds a reference to the focused UI element at the moment recording started.
struct RecordingTarget {
    let element: AXUIElement
    let pid: pid_t
    let appName: String
}

enum TextSimulator {
    /// Types the given text at the current cursor position using CGEvent.
    /// Requires Accessibility permissions to be granted.
    static func simulateTyping(text: String) {
        let source = CGEventSource(stateID: .hidSystemState)

        for char in text {
            let str = String(char)
            let unichars = Array(str.utf16)

            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)

            keyDown?.keyboardSetUnicodeString(stringLength: unichars.count, unicodeString: unichars)
            keyUp?.keyboardSetUnicodeString(stringLength: unichars.count, unicodeString: unichars)

            keyDown?.post(tap: .cgAnnotatedSessionEventTap)
            keyUp?.post(tap: .cgAnnotatedSessionEventTap)

            // Small delay to ensure events are processed in order
            usleep(5000) // 5ms
        }
    }

    /// Selects `count` characters to the left, then deletes them with a single backspace.
    /// More reliable than repeated backspaces across different apps (editors, terminals, etc).
    static func deleteCharacters(count: Int) {
        guard count > 0 else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        let leftArrow: CGKeyCode = 0x7B
        let backspace: CGKeyCode = 0x33

        // Shift+Left × count to select
        for _ in 0..<count {
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: leftArrow, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: leftArrow, keyDown: false)
            keyDown?.flags = .maskShift
            keyUp?.flags = .maskShift
            keyDown?.post(tap: .cgAnnotatedSessionEventTap)
            keyUp?.post(tap: .cgAnnotatedSessionEventTap)
            usleep(3000)
        }

        usleep(10000) // let selection settle

        // Single backspace to delete selection
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: backspace, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: backspace, keyDown: false)
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
        usleep(5000)
    }

    /// Copies text to the system clipboard and optionally pastes it.
    static func copyToClipboard(text: String, autoPaste: Bool = false) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        if autoPaste {
            let source = CGEventSource(stateID: .hidSystemState)
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)  // V key
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            keyDown?.flags = .maskCommand
            keyUp?.flags = .maskCommand
            keyDown?.post(tap: .cgAnnotatedSessionEventTap)
            keyUp?.post(tap: .cgAnnotatedSessionEventTap)
        }
    }

    /// Captures the currently focused element so text can be routed back to it later,
    /// even after the user switches to another app.
    static func captureCurrentTarget() -> RecordingTarget? {
        guard hasAccessibilityPermission else { return nil }
        let systemWide = AXUIElementCreateSystemWide()
        var focusedApp: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success else { return nil }
        let appElement = focusedApp as! AXUIElement

        var pid: pid_t = 0
        AXUIElementGetPid(appElement, &pid)

        // Don't capture our own process as target
        guard pid != ProcessInfo.processInfo.processIdentifier else { return nil }

        var focusedElement: AnyObject?
        AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        let element: AXUIElement = focusedElement != nil ? (focusedElement as! AXUIElement) : appElement

        let appName = NSRunningApplication(processIdentifier: pid)?.localizedName ?? "App"
        return RecordingTarget(element: element, pid: pid, appName: appName)
    }

    /// Activates the target app and restores focus to the captured element.
    static func focusTarget(_ target: RecordingTarget) {
        guard let app = NSRunningApplication(processIdentifier: target.pid),
              !app.isTerminated else { return }
        app.activate()
        usleep(120_000) // wait for app activation
        AXUIElementSetAttributeValue(target.element, kAXFocusedAttribute as CFString, true as CFTypeRef)
        usleep(50_000) // wait for element focus
    }

    /// Returns the screen-space frame of the currently focused text field, if available.
    static func focusedElementFrame() -> NSRect? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedApp: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success else {
            return nil
        }
        var focusedElement: AnyObject?
        guard AXUIElementCopyAttributeValue(focusedApp as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success else {
            return nil
        }
        let element = focusedElement as! AXUIElement
        var posValue: AnyObject?
        var sizeValue: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success else {
            return nil
        }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(posValue as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else {
            return nil
        }
        return NSRect(origin: position, size: size)
    }

    /// Returns the active tab URL for known browsers using AppleScript.
    /// Returns nil for non-browser apps or if the query fails.
    static func browserURL(for appName: String) -> String? {
        let chromeFamily: Set<String> = [
            "Google Chrome", "Google Chrome Canary", "Chromium",
            "Brave Browser", "Arc", "Microsoft Edge", "Opera", "Vivaldi"
        ]
        let safariFamily: Set<String> = ["Safari", "Safari Technology Preview"]

        let script: String
        if chromeFamily.contains(appName) {
            script = "tell application \"\(appName)\" to get URL of active tab of front window"
        } else if safariFamily.contains(appName) {
            script = "tell application \"\(appName)\" to get URL of current tab of front window"
        } else {
            return nil
        }

        guard let appleScript = NSAppleScript(source: script) else { return nil }
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)
        guard error == nil else { return nil }
        return result.stringValue
    }

    /// Checks if accessibility permissions are granted.
    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the user to grant accessibility permissions.
    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
