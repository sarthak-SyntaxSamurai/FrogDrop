import Carbon
import Cocoa

@MainActor
class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()
    
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var isHandlerInstalled = false
    
    private init() {}
    
    func setup() {
        registerHotkeys()
    }
    
    func registerHotkeys() {
        unregisterHotkeys()
        
        let keyMappings: [Int: Int32] = [
            0: 29, // 0 -> kVK_ANSI_0
            1: 18, // 1 -> kVK_ANSI_1
            2: 19, // 2 -> kVK_ANSI_2
            3: 20, // 3 -> kVK_ANSI_3
            4: 21, // 4 -> kVK_ANSI_4
            5: 23, // 5 -> kVK_ANSI_5
            6: 22, // 6 -> kVK_ANSI_6
            7: 26, // 7 -> kVK_ANSI_7
            8: 28, // 8 -> kVK_ANSI_8
            9: 25  // 9 -> kVK_ANSI_9
        ]
        
        // Carbon modifier key for Command key is cmdKey (0x0100)
        let modifiers = UInt32(cmdKey)
        
        if !isHandlerInstalled {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            
            let status = InstallEventHandler(
                GetApplicationEventTarget(),
                hotKeyHandler,
                1,
                &eventType,
                nil,
                nil
            )
            if status == noErr {
                isHandlerInstalled = true
            }
        }
        
        for (index, keyCode) in keyMappings {
            var hotKeyRef: EventHotKeyRef?
            var hotKeyID = EventHotKeyID()
            // Signature "FRGD" -> 1179815492
            hotKeyID.signature = OSType(1179815492)
            hotKeyID.id = UInt32(index)
            
            let result = RegisterEventHotKey(
                UInt32(keyCode),
                modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )
            
            if result == noErr, let ref = hotKeyRef {
                hotKeyRefs.append(ref)
            }
        }
    }
    
    func unregisterHotkeys() {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
    }
}

// C-compatible event handler callback
private func hotKeyHandler(
    nextHandler: EventHandlerCallRef?,
    theEvent: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        theEvent,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    
    if status == noErr {
        let index = Int(hotKeyID.id)
        DispatchQueue.main.async {
            let sorted = ClipboardManager.shared.items.sorted { a, b in
                if a.isPinned != b.isPinned {
                    return a.isPinned && !b.isPinned
                }
                return a.timestamp > b.timestamp
            }
            if index < sorted.count {
                let item = sorted[index]
                ClipboardManager.shared.copyToPasteboard(item)
                HapticManager.shared.success()
            }
        }
    }
    
    return noErr
}
