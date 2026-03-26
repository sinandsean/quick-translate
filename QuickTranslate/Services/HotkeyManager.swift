import Foundation
import AppKit
import Carbon

struct HotkeyConfig: Equatable {
    let keyCode: UInt32
    let carbonModifiers: UInt32
    let nsModifiers: NSEvent.ModifierFlags
    let displayString: String

    static let defaultConfig = HotkeyConfig(
        keyCode: UInt32(kVK_ANSI_T),
        carbonModifiers: UInt32(controlKey),
        nsModifiers: .control,
        displayString: "⌃T"
    )

    static func load() -> HotkeyConfig {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "hotkeyKeyCode") != nil else {
            return .defaultConfig
        }
        let keyCode = UInt32(defaults.integer(forKey: "hotkeyKeyCode"))
        let modifierRaw = defaults.integer(forKey: "hotkeyModifiers")
        let nsModifiers = NSEvent.ModifierFlags(rawValue: UInt(modifierRaw))
        let carbonMods = nsModifiersToCarbonModifiers(nsModifiers)
        let display = displayString(keyCode: UInt16(keyCode), modifiers: nsModifiers)
        return HotkeyConfig(keyCode: keyCode, carbonModifiers: carbonMods, nsModifiers: nsModifiers, displayString: display)
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(Int(keyCode), forKey: "hotkeyKeyCode")
        defaults.set(Int(nsModifiers.rawValue), forKey: "hotkeyModifiers")
    }

    static func nsModifiersToCarbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        return carbon
    }

    static func displayString(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        parts.append(keyName(for: keyCode))
        return parts.joined()
    }

    static func keyName(for keyCode: UInt16) -> String {
        let keyMap: [UInt16: String] = [
            UInt16(kVK_ANSI_A): "A", UInt16(kVK_ANSI_B): "B", UInt16(kVK_ANSI_C): "C",
            UInt16(kVK_ANSI_D): "D", UInt16(kVK_ANSI_E): "E", UInt16(kVK_ANSI_F): "F",
            UInt16(kVK_ANSI_G): "G", UInt16(kVK_ANSI_H): "H", UInt16(kVK_ANSI_I): "I",
            UInt16(kVK_ANSI_J): "J", UInt16(kVK_ANSI_K): "K", UInt16(kVK_ANSI_L): "L",
            UInt16(kVK_ANSI_M): "M", UInt16(kVK_ANSI_N): "N", UInt16(kVK_ANSI_O): "O",
            UInt16(kVK_ANSI_P): "P", UInt16(kVK_ANSI_Q): "Q", UInt16(kVK_ANSI_R): "R",
            UInt16(kVK_ANSI_S): "S", UInt16(kVK_ANSI_T): "T", UInt16(kVK_ANSI_U): "U",
            UInt16(kVK_ANSI_V): "V", UInt16(kVK_ANSI_W): "W", UInt16(kVK_ANSI_X): "X",
            UInt16(kVK_ANSI_Y): "Y", UInt16(kVK_ANSI_Z): "Z",
            UInt16(kVK_ANSI_0): "0", UInt16(kVK_ANSI_1): "1", UInt16(kVK_ANSI_2): "2",
            UInt16(kVK_ANSI_3): "3", UInt16(kVK_ANSI_4): "4", UInt16(kVK_ANSI_5): "5",
            UInt16(kVK_ANSI_6): "6", UInt16(kVK_ANSI_7): "7", UInt16(kVK_ANSI_8): "8",
            UInt16(kVK_ANSI_9): "9",
            UInt16(kVK_F1): "F1", UInt16(kVK_F2): "F2", UInt16(kVK_F3): "F3",
            UInt16(kVK_F4): "F4", UInt16(kVK_F5): "F5", UInt16(kVK_F6): "F6",
            UInt16(kVK_F7): "F7", UInt16(kVK_F8): "F8", UInt16(kVK_F9): "F9",
            UInt16(kVK_F10): "F10", UInt16(kVK_F11): "F11", UInt16(kVK_F12): "F12",
            UInt16(kVK_Space): "Space", UInt16(kVK_Return): "↩",
            UInt16(kVK_Tab): "⇥", UInt16(kVK_Escape): "⎋",
            UInt16(kVK_Delete): "⌫",
            UInt16(kVK_ANSI_Minus): "-", UInt16(kVK_ANSI_Equal): "=",
            UInt16(kVK_ANSI_LeftBracket): "[", UInt16(kVK_ANSI_RightBracket): "]",
            UInt16(kVK_ANSI_Semicolon): ";", UInt16(kVK_ANSI_Quote): "'",
            UInt16(kVK_ANSI_Comma): ",", UInt16(kVK_ANSI_Period): ".",
            UInt16(kVK_ANSI_Slash): "/", UInt16(kVK_ANSI_Backslash): "\\",
            UInt16(kVK_ANSI_Grave): "`",
        ]
        return keyMap[keyCode] ?? "?"
    }
}

final class HotkeyManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var onHotkey: (() -> Void)?
    private(set) var currentConfig: HotkeyConfig = .defaultConfig

    private static var sharedInstance: HotkeyManager?

    func register(onHotkey: @escaping () -> Void) {
        self.onHotkey = onHotkey
        HotkeyManager.sharedInstance = self
        currentConfig = HotkeyConfig.load()

        registerCarbonHotkey()
        registerNSEventMonitors()

        print("[QuickTranslate] Hotkey registered: \(currentConfig.displayString)")
    }

    func updateHotkey(config: HotkeyConfig) {
        unregisterHotkey()
        currentConfig = config
        config.save()
        registerCarbonHotkey()
        registerNSEventMonitors()
        print("[QuickTranslate] Hotkey updated: \(config.displayString)")
    }

    private func registerCarbonHotkey() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        if eventHandlerRef == nil {
            InstallEventHandler(
                GetApplicationEventTarget(),
                { (_, event, _) -> OSStatus in
                    HotkeyManager.sharedInstance?.onHotkey?()
                    return noErr
                },
                1,
                &eventType,
                nil,
                &eventHandlerRef
            )
        }

        let hotkeyID = EventHotKeyID(signature: OSType(0x5154_5243), id: 1)

        let regStatus = RegisterEventHotKey(
            currentConfig.keyCode,
            currentConfig.carbonModifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if regStatus != noErr {
            print("[QuickTranslate] Failed to register hotkey: \(regStatus)")
        }
    }

    private func registerNSEventMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            if self.isHotkeyEvent(event) {
                self.onHotkey?()
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if self.isHotkeyEvent(event) {
                self.onHotkey?()
                return nil
            }
            return event
        }
    }

    private func unregisterHotkey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    func unregister() {
        unregisterHotkey()
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
        onHotkey = nil
        HotkeyManager.sharedInstance = nil
    }

    private func isHotkeyEvent(_ event: NSEvent) -> Bool {
        let keyMatch = event.keyCode == UInt16(currentConfig.keyCode)
        let modMatch = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])
            == currentConfig.nsModifiers
        return keyMatch && modMatch
    }

    deinit {
        unregister()
    }
}
