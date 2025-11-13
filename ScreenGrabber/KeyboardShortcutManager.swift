//
//  KeyboardShortcutManager.swift
//  ScreenGrabber
//
//  Enhanced keyboard shortcut manager with multi-hotkey support
//

import Cocoa
import Carbon
import SwiftUI

// MARK: - Shortcut Action Types
enum ShortcutAction: String, CaseIterable {
    case captureSelectedArea = "capture_selected_area"
    case captureWindow = "capture_window"
    case captureFullScreen = "capture_full_screen"
    case captureScrolling = "capture_scrolling"
    case openEditor = "open_editor"
    case openLibrary = "open_library"
    case quickShare = "quick_share"
    case ocrExtract = "ocr_extract"
    case toggleAnnotation = "toggle_annotation"
    case undo = "undo"
    case redo = "redo"
    case save = "save"
    case copy = "copy"
    case delete = "delete"

    var displayName: String {
        switch self {
        case .captureSelectedArea: return "Capture Selected Area"
        case .captureWindow: return "Capture Window"
        case .captureFullScreen: return "Capture Full Screen"
        case .captureScrolling: return "Capture Scrolling Window"
        case .openEditor: return "Open Editor"
        case .openLibrary: return "Open Library"
        case .quickShare: return "Quick Share"
        case .ocrExtract: return "Extract Text (OCR)"
        case .toggleAnnotation: return "Toggle Annotation Mode"
        case .undo: return "Undo"
        case .redo: return "Redo"
        case .save: return "Save"
        case .copy: return "Copy"
        case .delete: return "Delete"
        }
    }

    var defaultShortcut: String {
        switch self {
        case .captureSelectedArea: return "⌘⇧C"
        case .captureWindow: return "⌘⇧W"
        case .captureFullScreen: return "⌘⇧F"
        case .captureScrolling: return "⌘⇧S"
        case .openEditor: return "⌘⇧E"
        case .openLibrary: return "⌘⇧L"
        case .quickShare: return "⌘⇧Q"
        case .ocrExtract: return "⌘⇧T"
        case .toggleAnnotation: return "⌘⇧A"
        case .undo: return "⌘Z"
        case .redo: return "⌘⇧Z"
        case .save: return "⌘S"
        case .copy: return "⌘C"
        case .delete: return "⌫"
        }
    }

    var icon: String {
        switch self {
        case .captureSelectedArea: return "rectangle.dashed"
        case .captureWindow: return "macwindow"
        case .captureFullScreen: return "rectangle"
        case .captureScrolling: return "scroll"
        case .openEditor: return "pencil"
        case .openLibrary: return "photo.on.rectangle"
        case .quickShare: return "square.and.arrow.up"
        case .ocrExtract: return "doc.text.viewfinder"
        case .toggleAnnotation: return "pencil.tip"
        case .undo: return "arrow.uturn.backward"
        case .redo: return "arrow.uturn.forward"
        case .save: return "square.and.arrow.down"
        case .copy: return "doc.on.doc"
        case .delete: return "trash"
        }
    }
}

// MARK: - Keyboard Shortcut
struct KeyboardShortcut: Identifiable, Codable, Equatable {
    let id: UUID
    let action: ShortcutAction
    var hotkey: String
    var isEnabled: Bool
    var isGlobal: Bool

    init(id: UUID = UUID(), action: ShortcutAction, hotkey: String? = nil, isEnabled: Bool = true, isGlobal: Bool = true) {
        self.id = id
        self.action = action
        self.hotkey = hotkey ?? action.defaultShortcut
        self.isEnabled = isEnabled
        self.isGlobal = isGlobal
    }
}

// MARK: - Enhanced Keyboard Shortcut Manager
class KeyboardShortcutManager: ObservableObject {
    static let shared = KeyboardShortcutManager()

    @Published var shortcuts: [KeyboardShortcut] = []
    @Published var isRecording: Bool = false
    @Published var recordingAction: ShortcutAction?
    @Published var conflicts: [ShortcutConflict] = []

    private var registeredHotkeys: [UUID: (hotKeyRef: EventHotKeyRef, eventHandler: EventHandlerRef)] = [:]
    private var actionHandlers: [ShortcutAction: () -> Void] = [:]

    private let userDefaultsKey = "com.screengrabber.keyboard_shortcuts"

    private init() {
        loadShortcuts()
    }

    // MARK: - Configuration

    /// Register an action handler for a specific shortcut action
    func registerHandler(for action: ShortcutAction, handler: @escaping () -> Void) {
        actionHandlers[action] = handler
    }

    /// Load shortcuts from UserDefaults or create defaults
    private func loadShortcuts() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([KeyboardShortcut].self, from: data) {
            shortcuts = decoded
        } else {
            // Create default shortcuts
            shortcuts = ShortcutAction.allCases.map { action in
                KeyboardShortcut(action: action)
            }
            saveShortcuts()
        }
    }

    /// Save shortcuts to UserDefaults
    private func saveShortcuts() {
        if let encoded = try? JSONEncoder().encode(shortcuts) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    // MARK: - Registration

    /// Register all enabled shortcuts
    func registerAllShortcuts() {
        // Unregister existing shortcuts first
        unregisterAllShortcuts()

        // Detect conflicts before registering
        detectConflicts()

        for shortcut in shortcuts where shortcut.isEnabled && shortcut.isGlobal {
            registerShortcut(shortcut)
        }
    }

    /// Register a single shortcut
    private func registerShortcut(_ shortcut: KeyboardShortcut) {
        guard let (keyCode, modifiers) = parseHotkey(shortcut.hotkey) else {
            print("[Keyboard] Invalid hotkey format: \(shortcut.hotkey)")
            return
        }

        // Create event handler
        var eventTypeSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))

        let eventHandlerUPP: EventHandlerUPP = { (nextHandler, theEvent, userData) -> OSStatus in
            KeyboardShortcutManager.shared.handleHotkeyEvent(theEvent)
            return noErr
        }

        var eventHandler: EventHandlerRef?
        let installResult = InstallEventHandler(
            GetApplicationEventTarget(),
            eventHandlerUPP,
            1,
            &eventTypeSpec,
            nil,
            &eventHandler
        )

        guard installResult == noErr, let handler = eventHandler else {
            print("[Keyboard] Failed to install event handler: \(installResult)")
            return
        }

        // Register the hotkey
        let hotkeyID = EventHotKeyID(signature: OSType(1234), id: UInt32(shortcut.id.hashValue))
        var hotKeyRef: EventHotKeyRef?

        let registerResult = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(modifiers),
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard registerResult == noErr, let hotkey = hotKeyRef else {
            print("[Keyboard] Failed to register hotkey: \(registerResult)")
            RemoveEventHandler(handler)
            return
        }

        // Store references
        registeredHotkeys[shortcut.id] = (hotKeyRef: hotkey, eventHandler: handler)
        print("[Keyboard] Registered shortcut: \(shortcut.action.displayName) - \(shortcut.hotkey)")
    }

    /// Unregister all shortcuts
    func unregisterAllShortcuts() {
        for (_, registration) in registeredHotkeys {
            UnregisterEventHotKey(registration.hotKeyRef)
            RemoveEventHandler(registration.eventHandler)
        }
        registeredHotkeys.removeAll()
    }

    /// Unregister a specific shortcut
    private func unregisterShortcut(_ shortcutId: UUID) {
        guard let registration = registeredHotkeys[shortcutId] else { return }

        UnregisterEventHotKey(registration.hotKeyRef)
        RemoveEventHandler(registration.eventHandler)
        registeredHotkeys.removeValue(forKey: shortcutId)
    }

    // MARK: - Event Handling

    private func handleHotkeyEvent(_ event: EventRef?) {
        guard let event = event else { return }

        var hotkeyID = EventHotKeyID()
        let result = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotkeyID
        )

        guard result == noErr else { return }

        // Find the matching shortcut
        let matchingShortcut = shortcuts.first { shortcut in
            shortcut.id.hashValue == Int(hotkeyID.id)
        }

        if let shortcut = matchingShortcut,
           let handler = actionHandlers[shortcut.action] {
            DispatchQueue.main.async {
                handler()
            }
        }
    }

    // MARK: - Shortcut Management

    /// Update a shortcut's hotkey
    func updateShortcut(id: UUID, newHotkey: String) {
        guard let index = shortcuts.firstIndex(where: { $0.id == id }) else { return }

        // Validate hotkey format
        guard parseHotkey(newHotkey) != nil else {
            print("[Keyboard] Invalid hotkey format: \(newHotkey)")
            return
        }

        shortcuts[index].hotkey = newHotkey
        saveShortcuts()

        // Re-register if it's a global shortcut
        if shortcuts[index].isGlobal && shortcuts[index].isEnabled {
            unregisterShortcut(id)
            registerShortcut(shortcuts[index])
        }

        detectConflicts()
    }

    /// Toggle shortcut enabled state
    func toggleShortcut(id: UUID) {
        guard let index = shortcuts.firstIndex(where: { $0.id == id }) else { return }

        shortcuts[index].isEnabled.toggle()
        saveShortcuts()

        if shortcuts[index].isEnabled {
            registerShortcut(shortcuts[index])
        } else {
            unregisterShortcut(id)
        }
    }

    /// Reset shortcut to default
    func resetShortcut(id: UUID) {
        guard let index = shortcuts.firstIndex(where: { $0.id == id }) else { return }

        let action = shortcuts[index].action
        shortcuts[index].hotkey = action.defaultShortcut
        saveShortcuts()

        if shortcuts[index].isGlobal && shortcuts[index].isEnabled {
            unregisterShortcut(id)
            registerShortcut(shortcuts[index])
        }

        detectConflicts()
    }

    /// Reset all shortcuts to defaults
    func resetAllShortcuts() {
        unregisterAllShortcuts()

        shortcuts = ShortcutAction.allCases.map { action in
            KeyboardShortcut(action: action)
        }

        saveShortcuts()
        registerAllShortcuts()
    }

    // MARK: - Conflict Detection

    func detectConflicts() {
        var foundConflicts: [ShortcutConflict] = []
        var hotkeyMap: [String: [KeyboardShortcut]] = [:]

        // Group shortcuts by hotkey
        for shortcut in shortcuts where shortcut.isEnabled {
            hotkeyMap[shortcut.hotkey, default: []].append(shortcut)
        }

        // Find conflicts
        for (hotkey, shortcuts) in hotkeyMap where shortcuts.count > 1 {
            foundConflicts.append(ShortcutConflict(
                hotkey: hotkey,
                conflictingActions: shortcuts.map { $0.action }
            ))
        }

        conflicts = foundConflicts
    }

    // MARK: - Hotkey Parsing

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

        // Extract the key character (last character that's not a modifier)
        let modifierChars = Set(["⌘", "⇧", "⌥", "⌃"])
        let chars = cleanHotkey.filter { !modifierChars.contains(String($0)) }

        if chars.isEmpty {
            return nil
        }

        keyChar = String(chars.last!).uppercased()

        // Convert key character to virtual key code
        guard let keyCode = virtualKeyCodeForCharacter(keyChar) else {
            print("[Keyboard] Unknown key character: \(keyChar)")
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
            "8": kVK_ANSI_8, "9": kVK_ANSI_9,
            "⌫": kVK_Delete, "⎋": kVK_Escape, "⏎": kVK_Return, "⇥": kVK_Tab,
            "␣": kVK_Space, "←": kVK_LeftArrow, "→": kVK_RightArrow,
            "↑": kVK_UpArrow, "↓": kVK_DownArrow
        ]

        return keyMap[char.uppercased()]
    }

    // MARK: - Recording

    /// Start recording a new hotkey
    func startRecording(for action: ShortcutAction) {
        isRecording = true
        recordingAction = action
    }

    /// Stop recording
    func stopRecording() {
        isRecording = false
        recordingAction = nil
    }

    /// Process recorded hotkey
    func recordHotkey(_ hotkey: String) {
        guard let action = recordingAction,
              let index = shortcuts.firstIndex(where: { $0.action == action }) else {
            stopRecording()
            return
        }

        updateShortcut(id: shortcuts[index].id, newHotkey: hotkey)
        stopRecording()
    }
}

// MARK: - Shortcut Conflict
struct ShortcutConflict: Identifiable {
    let id = UUID()
    let hotkey: String
    let conflictingActions: [ShortcutAction]

    var description: String {
        let actions = conflictingActions.map { $0.displayName }.joined(separator: ", ")
        return "'\(hotkey)' is assigned to: \(actions)"
    }
}

// MARK: - Codable Extensions
extension ShortcutAction: Codable {}
