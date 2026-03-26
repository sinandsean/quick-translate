import Foundation
import AppKit
import Carbon

final class HotkeyManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var hotKeyRef: EventHotKeyRef?
    private var onHotkey: (() -> Void)?

    private static var sharedInstance: HotkeyManager?

    func register(onHotkey: @escaping () -> Void) {
        self.onHotkey = onHotkey
        HotkeyManager.sharedInstance = self

        registerCarbonHotkey()
        registerNSEventMonitors()

        print("[QuickTranslate] Hotkey registration complete")
    }

    private func registerCarbonHotkey() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                HotkeyManager.sharedInstance?.onHotkey?()
                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )

        if status != noErr {
            print("[QuickTranslate] Failed to install event handler: \(status)")
        }

        let hotkeyID = EventHotKeyID(signature: OSType(0x5154_5243), id: 1) // "QTRC"
        let keyCode = UInt32(kVK_ANSI_T)
        let modifiers = UInt32(controlKey)

        let regStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if regStatus != noErr {
            print("[QuickTranslate] Failed to register hotkey: \(regStatus)")
        } else {
            print("[QuickTranslate] Carbon hotkey registered (Ctrl+T)")
        }
    }

    private func registerNSEventMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.isHotkeyEvent(event) == true {
                print("[QuickTranslate] Global monitor: Ctrl+T detected")
                self?.onHotkey?()
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.isHotkeyEvent(event) == true {
                print("[QuickTranslate] Local monitor: Ctrl+T detected")
                self?.onHotkey?()
                return nil
            }
            return event
        }
    }

    func unregister() {
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
        onHotkey = nil
        HotkeyManager.sharedInstance = nil
    }

    private func isHotkeyEvent(_ event: NSEvent) -> Bool {
        return event.keyCode == UInt16(kVK_ANSI_T)
            && event.modifierFlags.contains(.control)
            && !event.modifierFlags.contains(.command)
            && !event.modifierFlags.contains(.option)
            && !event.modifierFlags.contains(.shift)
    }

    deinit {
        unregister()
    }
}
