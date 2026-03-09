//
//  SettingsView.swift
//  ScreenGrabber
//
//  Shared components used by the canonical SettingsWindow:
//    - HotkeyConfigSheet  — modal for changing the global capture hotkey
//    - FeatureBadge       — pill badge used in the About pane
//
//  The old `SettingsView` struct has been removed; the app uses SettingsWindow instead.
//

import SwiftUI
import SwiftData

// MARK: - Hotkey Config Sheet

/// Presented as a sheet when the user taps "Change…" in General Settings.
struct HotkeyConfigSheet: View {
    @Binding var currentHotkey: String
    @Environment(\.dismiss) private var dismiss

    @State private var newHotkey: String
    @State private var errorMessage: String?

    init(currentHotkey: Binding<String>) {
        self._currentHotkey = currentHotkey
        self._newHotkey = State(initialValue: currentHotkey.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 60, height: 60)
                Image(systemName: "keyboard")
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            VStack(spacing: 6) {
                Text("Set Global Hotkey").font(.title2.bold())
                Text("Press a key combination to trigger a capture from anywhere on your Mac.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TextField("e.g. ⌘⇧C", text: $newHotkey)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .font(.title3)
                .padding(.horizontal)

            if let msg = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                    Text(msg).font(.caption).foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.bordered)

                Button("Save") {
                    if saveHotkey() { dismiss() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newHotkey.trimmingCharacters(in: .whitespaces).isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(30)
        .frame(width: 400)
    }

    private func saveHotkey() -> Bool {
        // Use the shared container — never create a new ModelContainer here
        let ctx = ModelContext(ScreenGrabberApp.sharedModelContainer)
        let success = GlobalHotkeyManager.shared.registerHotkey(newHotkey) {
            let settings = SettingsManager.shared
            DispatchQueue.main.async {
                ScreenCaptureManager.shared.captureScreen(
                    method: settings.selectedScreenOption,
                    openOption: settings.selectedOpenOption,
                    modelContext: ctx
                )
            }
        }

        if success {
            UserDefaults.standard.set(newHotkey, forKey: "grabScreenHotkey")
            currentHotkey = newHotkey
            CaptureLogger.log(.debug, "Hotkey updated: \(newHotkey)")
        } else {
            errorMessage = "This shortcut is already in use. Please try another combination."
            CaptureLogger.log(.error, "Failed to register hotkey: \(newHotkey)")
        }
        return success
    }
}

// MARK: - Feature Badge

/// Small pill badge used in the About pane.
struct FeatureBadge: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.accentColor)
            Text(text).font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.1)))
    }
}
