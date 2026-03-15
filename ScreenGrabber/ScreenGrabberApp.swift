//
//  ScreenGrabberApp.swift
//  ScreenGrabber
//
//  App entry point. Manages the MenuBarExtra, Library window, and Settings window.
//

import SwiftUI
import SwiftData

// MARK: - Notification Names

extension Notification.Name {
    static let requestSettingsOpen = Notification.Name("requestSettingsOpen")
    static let openScreenshotInEditor = Notification.Name("openScreenshotInEditor")
}

// MARK: - App

@main
struct ScreenGrabberApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow

    /// Persistent SwiftData store. Falls back to an in-memory store if the on-disk
    /// store is corrupted, then shows an alert so the user knows data was reset.
    static var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Screenshot.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // If the on-disk store is corrupted, fall back to in-memory and show an alert
            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                let fallback = try ModelContainer(for: schema, configurations: [fallbackConfig])
                Task { @MainActor in
                    Self.showDataResetAlert(persistent: false)
                }
                return fallback
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup("Library", id: "library") {
            ContentView()
        }
        .modelContainer(Self.sharedModelContainer)
        .defaultPosition(.center)
        .commands {
            CommandGroup(replacing: .appSettings) {
                SettingsLink { Text("Settings…") }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }

        Window("Settings", id: "settings") {
            SettingsWindow()
        }
        .modelContainer(Self.sharedModelContainer)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .keyboardShortcut(",", modifiers: .command)

        MenuBarExtra("Screen Grabber", systemImage: "camera.fill") {
            MenuBarContentView()
                .modelContainer(Self.sharedModelContainer)
        }
        .menuBarExtraStyle(.window)
    }

    // MARK: - Helpers

    private static func showDataResetAlert(persistent: Bool = true) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = persistent
            ? "Screenshot History Was Reset"
            : "Running in Temporary Mode"
        alert.informativeText = persistent
            ? "ScreenGrabber encountered a problem with its database and created a fresh one. Previous captures saved in ~/Pictures/Screen Grabber are still on disk."
            : "ScreenGrabber could not open its database. Your captures are safe on disk, but history won't be saved until you restart the app."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    @Environment(\.openWindow) private var openWindow
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        DotEnvLoader.load()
        SubscriptionManager.shared.start()
        setupGlobalHotkey()
        setupEditorNotificationObserver()

        NotificationCenter.default.addObserver(
            forName: .requestSettingsOpen,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.openSettingsWindow() }

        checkAccessibilityPermissionsIfNeeded()
        promptForSaveLocationOnFirstLaunch()
    }

    // MARK: - Editor Notification

    private func setupEditorNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: .openScreenshotInEditor,
            object: nil,
            queue: .main
        ) { notification in
            guard let screenshot = notification.object as? Screenshot else {
                CaptureLogger.log(.error, "openScreenshotInEditor notification missing screenshot object", level: .error)
                return
            }
            
            let fileURL = URL(fileURLWithPath: screenshot.filePath)
            EditorWindowOpener.open(fileURL: fileURL)
            
            CaptureLogger.log(.debug, "Editor window opened for: \(screenshot.filename)", level: .info)
        }
        
        CaptureLogger.log(.debug, "Editor notification observer registered", level: .info)
    }

    // MARK: - Accessibility

    private func checkAccessibilityPermissionsIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        guard !AXIsProcessTrustedWithOptions(options as CFDictionary) else {
            CaptureLogger.log(.debug, "Accessibility: trusted — full functionality available")
            return
        }

        CaptureLogger.log(.debug, "Accessibility: not trusted — system prompt shown")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Recommended"
            alert.informativeText = """
                ScreenGrabber works best with Accessibility enabled.

                Required for:
                  • Automatic Scrolling Capture
                  • Global hotkey support

                To enable: System Settings → Privacy & Security → Accessibility → ScreenGrabber
                """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Open System Settings")

            if alert.runModal() == .alertSecondButtonReturn {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                )
            }
        }
    }

    // MARK: - Save Location Setup

    private func promptForSaveLocationOnFirstLaunch() {
        let key = "hasRunInitialSaveLocationSetup"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        Task { @MainActor in
            let result = await FolderPermissionsManager.shared.promptForInitialSaveLocation()
            switch result {
            case .success:
                UserDefaults.standard.set(true, forKey: key)
            case .failure(let error):
                CaptureLogger.log(.error, "Initial save location setup skipped: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Global Hotkey

    private func setupGlobalHotkey() {
        let hotkey = UserDefaults.standard.string(forKey: "grabScreenHotkey") ?? "⌘⇧C"

        let registered = GlobalHotkeyManager.shared.registerHotkey(hotkey) { [weak self] in
            self?.triggerScreenCapture()
        }

        if registered {
            CaptureLogger.log(.debug, "Global hotkey registered: \(hotkey)")
            return
        }

        CaptureLogger.log(.error, "Failed to register hotkey \(hotkey) — trying fallback ⌘⇧C")
        guard hotkey != "⌘⇧C" else { return }

        let fallbackRegistered = GlobalHotkeyManager.shared.registerHotkey("⌘⇧C") { [weak self] in
            self?.triggerScreenCapture()
        }
        if fallbackRegistered {
            UserDefaults.standard.set("⌘⇧C", forKey: "grabScreenHotkey")
            CaptureLogger.log(.debug, "Fallback hotkey ⌘⇧C registered")
        }
    }

    private func triggerScreenCapture() {
        let settings = SettingsManager.shared
        let ctx = ModelContext(ScreenGrabberApp.sharedModelContainer)
        DispatchQueue.main.async {
            ScreenCaptureManager.shared.captureScreen(
                method: settings.selectedScreenOption,
                openOption: settings.selectedOpenOption,
                modelContext: ctx
            )
        }
    }

    // MARK: - Settings Window

    func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        // Use SwiftUI's openWindow environment action instead of synthetic key event
        if let window = NSApp.windows.first(where: {
            $0.title == "Settings" || $0.identifier?.rawValue == "settings"
        }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // Post notification that the main app will handle
            NotificationCenter.default.post(
                name: NSApplication.didBecomeActiveNotification,
                object: NSApp
            )
            // Use the SwiftUI openWindow action directly
            DispatchQueue.main.async {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }
    }
}
