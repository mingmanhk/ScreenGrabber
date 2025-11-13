//
//  GlobalHotkeyManager.swift
//  ScreenGrabber
//
//  Created by Victor Lam on 10/23/25.
//

import Cocoa
import Carbon

class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var onHotkeyPressed: (() -> Void)?
    
    private init() {}
    
    /// Registers a global hotkey.
    /// - Returns: `true` if the hotkey was registered successfully, `false` otherwise (e.g., due to a conflict).
    func registerHotkey(_ hotkey: String, action: @escaping () -> Void) -> Bool {
        // Unregister existing hotkey first
        unregisterHotkey()
        
        guard let (keyCode, modifiers) = parseHotkey(hotkey) else {
            print("Invalid hotkey format: \(hotkey)")
            return false
        }
        
        self.onHotkeyPressed = action
        
        // Install event handler
        var eventTypeSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        let eventHandlerUPP: EventHandlerUPP = { (nextHandler, theEvent, userData) -> OSStatus in
            GlobalHotkeyManager.shared.handleHotkeyEvent(theEvent)
            return noErr
        }
        
        let result = InstallEventHandler(
            GetApplicationEventTarget(),
            eventHandlerUPP,
            1,
            &eventTypeSpec,
            nil,
            &eventHandler
        )
        
        if result != noErr {
            print("Failed to install event handler: \(result)")
            unregisterHotkey() // Clean up partially installed handler
            return false
        }
        
        // Register the hotkey
        let hotkeyID = EventHotKeyID(signature: OSType(1234), id: UInt32(1))
        let registerResult = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(modifiers),
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if registerResult != noErr {
            print("Failed to register hotkey: \(registerResult)")
            if registerResult == eventHotKeyExistsErr {
                print("Hotkey conflict: The hotkey '\(hotkey)' is already in use by another application.")
            }
            unregisterHotkey() // Clean up
            return false
        }
        
        print("Successfully registered hotkey: \(hotkey)")
        return true
    }
    
    func unregisterHotkey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        
        onHotkeyPressed = nil
    }
    
    private func handleHotkeyEvent(_ event: EventRef?) {
        DispatchQueue.main.async {
            self.onHotkeyPressed?()
        }
    }
    
    private func parseHotkey(_ hotkey: String) -> (keyCode: Int, modifiers: Int)? {
        let components = hotkey.components(separatedBy: CharacterSet.whitespacesAndNewlines)
        let cleanHotkey = components.joined()
        
        var modifiers = 0
        var keyChar = ""
        
        // Parse modifiers
        if cleanHotkey.contains("⌘") {
            modifiers |= cmdKey
        }
        if cleanHotkey.contains("⇧") {
            modifiers |= shiftKey
        }
        if cleanHotkey.contains("⌥") {
            modifiers |= optionKey
        }
        if cleanHotkey.contains("⌃") {
            modifiers |= controlKey
        }
        
        // Extract the key character (last character)
        if let lastChar = cleanHotkey.last, !["⌘", "⇧", "⌥", "⌃"].contains(String(lastChar)) {
            keyChar = String(lastChar).uppercased()
        } else {
            return nil
        }
        
        // Convert key character to virtual key code
        guard let keyCode = virtualKeyCodeForCharacter(keyChar) else {
            print("Unknown key character: \(keyChar)")
            return nil
        }
        
        return (keyCode: keyCode, modifiers: modifiers)
    }
    
    private func virtualKeyCodeForCharacter(_ char: String) -> Int? {
        let keyMap: [String: Int] = [
            "A": kVK_ANSI_A, "B": kVK_ANSI_B, "C": kVK_ANSI_C, "D": kVK_ANSI_D,
            "E": kVK_ANSI_E, "F": kVK_ANSI_F, "G": kVK_ANSI_G, "H": kVK_ANSI_H,
            "I": kVK_ANSI_I, "J": kVK_ANSI_J, "K": kVK_ANSI_K, "L": kVK_ANSI_L,
            "M": kVK_ANSI_M, "N": kVK_ANSI_N, "O": kVK_ANSI_O, "P": kVK_ANSI_P,
            "Q": kVK_ANSI_Q, "R": kVK_ANSI_R, "S": kVK_ANSI_S, "T": kVK_ANSI_T,
            "U": kVK_ANSI_U, "V": kVK_ANSI_V, "W": kVK_ANSI_W, "X": kVK_ANSI_X,
            "Y": kVK_ANSI_Y, "Z": kVK_ANSI_Z,
            "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3,
            "4": kVK_ANSI_4, "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7,
            "8": kVK_ANSI_8, "9": kVK_ANSI_9
        ]
        
        return keyMap[char.uppercased()]
    }
}
