import Carbon
import Foundation

final class HotkeyMonitor {
    static let shared = HotkeyMonitor()

    var onToggleShow: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    func register() {
        let hotKeyID = EventHotKeyID(signature: OSType(bitPattern: 0x4E44534B), id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_N),
            UInt32(controlKey | optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, _, _ in
            DispatchQueue.main.async {
                HotkeyMonitor.shared.onToggleShow?()
            }
            return noErr
        }
        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &spec, nil, &handlerRef)
    }
}
