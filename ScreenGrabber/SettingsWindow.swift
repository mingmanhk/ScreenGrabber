//
//  SettingsWindow.swift
//  ScreenGrabber
//
//  Canonical Settings window. NavigationSplitView with sidebar sections.
//  All settings modifications go through SettingsModel.shared.
//

import SwiftUI

struct SettingsWindow: View {
    @State private var selection: Section? = .general
    @ObservedObject private var settings = SettingsModel.shared

    enum Section: String, CaseIterable, Identifiable {
        case general, capture, ocr, aiPro, editor, videoAudio, about
        var id: String { rawValue }

        var title: String {
            switch self {
            case .general:   return "General"
            case .capture:   return "Capture"
            case .ocr:       return "OCR"
            case .aiPro:     return "AI Pro"
            case .editor:    return "Editor"
            case .videoAudio: return "Video & Audio"
            case .about:     return "About"
            }
        }

        var icon: String {
            switch self {
            case .general:   return "gearshape"
            case .capture:   return "camera.viewfinder"
            case .ocr:       return "doc.text.viewfinder"
            case .aiPro:     return "sparkles"
            case .editor:    return "pencil.tip.crop.circle"
            case .videoAudio: return "video"
            case .about:     return "info.circle"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(Section.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.icon).tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 240)
        } detail: {
            Group {
                switch selection ?? .general {
                case .general:   GeneralSettingsPane()
                case .capture:   CaptureSettingsPane()
                case .ocr:       OCRSettingsPane()
                case .aiPro:     AIProSettingsPane()
                case .editor:    EditorSettingsPane()
                case .videoAudio: VideoAudioSettingsPane()
                case .about:     AboutPane()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Settings")
        .frame(minWidth: 720, idealWidth: 820, minHeight: 520, idealHeight: 620)
    }
}

// MARK: - General

private struct GeneralSettingsPane: View {
    @ObservedObject private var settings = SettingsModel.shared
    @State private var showHotkeySheet = false
    @State private var currentHotkey = UserDefaults.standard.string(forKey: "grabScreenHotkey") ?? "⌘⇧C"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Hotkey
                SettingsPaneSection(icon: "keyboard", title: "Global Hotkey", subtitle: "Trigger a capture from anywhere on your Mac") {
                    HStack {
                        Text("Current shortcut:")
                        Text(currentHotkey)
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.1)))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor.opacity(0.3), lineWidth: 1))
                        Spacer()
                        Button("Change…") { showHotkeySheet = true }.buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                }

                // Behavior
                SettingsPaneSection(icon: "gearshape.fill", title: "Behavior", subtitle: "Configure app behavior and preferences") {
                    SettingsToggle(title: "Keep Screen Grabber running in menu bar",
                                   subtitle: "App stays accessible from the menu bar",
                                   isOn: $settings.keepInMenuBar)

                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Automatically check for updates").fontWeight(.medium)
                            Text("Choose how often to check for new versions").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Picker("", selection: $settings.autoUpdateFrequency) {
                            ForEach(SettingsModel.AutoUpdateFrequency.allCases) { Text($0.displayName).tag($0) }
                        }
                        .labelsHidden().frame(width: 150)
                    }
                    .padding(.vertical, 6)

                    SettingsToggle(title: "Send anonymous crash reports",
                                   subtitle: "Helps improve app stability",
                                   isOn: $settings.sendCrashReports)
                    SettingsToggle(title: "Show tips and notifications",
                                   subtitle: "Receive helpful tips about Screen Grabber features",
                                   isOn: $settings.showTips)
                }

                // Save location (shortcut row; full config is in Capture pane)
                SettingsPaneSection(icon: "folder.fill", title: "Screenshots Folder", subtitle: "Where captures are saved by default") {
                    FolderPermissionsManager.shared.showFolderSettingsRow()
                    Text("For full folder options, see the Capture pane.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
        .navigationTitle("General")
        .sheet(isPresented: $showHotkeySheet) {
            HotkeyConfigSheet(currentHotkey: $currentHotkey)
        }
    }
}

// MARK: - Capture

private struct CaptureSettingsPane: View {
    @ObservedObject private var settings = SettingsModel.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Save Location
                SettingsPaneSection(icon: "folder.fill", title: "Save Location", subtitle: "Choose where captures are saved") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "folder.fill").foregroundStyle(Color.accentColor)
                            Text(currentFolderDisplay)
                                .font(.caption).lineLimit(2).truncationMode(.middle).textSelection(.enabled)
                            Spacer()
                            Button(action: copyPathToClipboard) {
                                Image(systemName: "doc.on.doc")
                            }.buttonStyle(.borderless).help("Copy path to clipboard")
                        }
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(6)

                        SaveFolderStatusView()

                        HStack(spacing: 8) {
                            Button("Choose Different Folder…") { chooseFolder() }.buttonStyle(.bordered)
                            Button("Reset to Default") { resetToDefault() }.buttonStyle(.bordered)
                            Button("Open in Finder") { openCurrentFolder() }.buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Capture Options
                SettingsPaneSection(icon: "camera.viewfinder", title: "Capture Options", subtitle: "Format, quality, and timing") {
                    Picker("Image format:", selection: $settings.captureFormat) {
                        ForEach(ImageFormat.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    HStack {
                        Text("Quality:")
                        Slider(value: $settings.captureQuality, in: 0.1...1.0)
                        Text("\(Int(settings.captureQuality * 100))%").frame(width: 46)
                    }
                    HStack {
                        Text("Capture delay:")
                        Slider(value: $settings.captureDelay, in: 0...10, step: 0.5)
                        Text("\(settings.captureDelay, specifier: "%.1f")s").frame(width: 46)
                    }
                    SettingsToggle(title: "Include cursor in capture",
                                   subtitle: "Shows the mouse cursor in screenshots",
                                   isOn: $settings.includeCursor)
                    SettingsToggle(title: "Play sound on capture",
                                   subtitle: "Plays the camera shutter sound",
                                   isOn: $settings.captureSound)
                }

                // Clipboard
                SettingsPaneSection(icon: "doc.on.clipboard", title: "Clipboard", subtitle: "Automatic clipboard behavior after capture") {
                    SettingsToggle(title: "Copy to clipboard after capture",
                                   subtitle: "Automatically copies the screenshot to clipboard",
                                   isOn: $settings.copyToClipboardEnabled)
                }

                // Floating Thumbnail
                SettingsPaneSection(icon: "photo.badge.clock", title: "Floating Thumbnail", subtitle: "Show a preview thumbnail after capture") {
                    SettingsToggle(title: "Show floating thumbnail",
                                   subtitle: "Appears briefly after each capture",
                                   isOn: $settings.floatingThumbnailSettings.enabled)

                    if settings.floatingThumbnailSettings.enabled {
                        HStack {
                            Text("Duration:")
                            Slider(value: $settings.floatingThumbnailSettings.duration, in: 1...10, step: 0.5)
                            Text("\(settings.floatingThumbnailSettings.duration, specifier: "%.1f")s").frame(width: 46)
                        }
                        Picker("Position:", selection: $settings.floatingThumbnailSettings.position) {
                            ForEach(FloatingThumbnailSettings.ThumbnailPosition.allCases, id: \.self) {
                                Text($0.displayName).tag($0)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Capture")
    }

    private var currentFolderDisplay: String {
        SettingsModel.shared.effectiveSaveURL.path
            .replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    private func copyPathToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(SettingsModel.shared.effectiveSaveURL.path, forType: .string)
    }

    private func openCurrentFolder() {
        let url = SettingsModel.shared.effectiveSaveURL
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            let result = await CapturePermissionsManager.shared.ensureCaptureFolderExists(at: url)
            switch result {
            case .success: SettingsModel.shared.saveFolderPath = url.path
            case .failure(let error): await presentFolderError(error)
            }
        }
    }

    private func resetToDefault() {
        SettingsModel.shared.saveFolderPath = ""
        Task {
            _ = await CapturePermissionsManager.shared.ensureCaptureFolderExists()
        }
    }

    @MainActor
    private func presentFolderError(_ error: ScreenGrabberTypes.CaptureError) async {
        let alert = NSAlert()
        alert.messageText = "Cannot Use Selected Folder"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        if case .permissionDenied(let type) = error, type == .fileSystem {
            alert.addButton(withTitle: "Open System Settings")
        }
        if alert.runModal() == .alertSecondButtonReturn {
            CapturePermissionsManager.openSystemSettings(for: .fileSystem)
        }
    }
}

// MARK: - OCR

private struct OCRSettingsPane: View {
    @ObservedObject private var settings = SettingsModel.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsPaneSection(icon: "doc.text.viewfinder", title: "OCR", subtitle: "Extract text from screenshots automatically") {
                    SettingsToggle(title: "Enable OCR",
                                   subtitle: "Automatically recognise text in every screenshot",
                                   isOn: $settings.ocrEnabled)
                    SettingsToggle(title: "Auto-copy text to clipboard",
                                   subtitle: "Copies extracted text immediately after capture",
                                   isOn: $settings.autoCopyOCRText)
                }

                SettingsPaneSection(icon: "lock.shield", title: "Privacy", subtitle: "Protect sensitive information in captures") {
                    SettingsToggle(title: "Auto-redact sensitive info",
                                   subtitle: "Blurs passwords, credit card numbers, and similar text",
                                   isOn: $settings.autoRedactSensitiveInfo)
                }
            }
            .padding(24)
        }
        .navigationTitle("OCR")
    }
}

// MARK: - Editor

private struct EditorSettingsPane: View {
    @ObservedObject private var settings = SettingsModel.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsPaneSection(icon: "pencil.tip", title: "Default Annotation Style", subtitle: "Starting values for new annotations") {
                    ColorPicker("Color:", selection: Binding(
                        get: { Color(hex: settings.defaultAnnotationColor) ?? .red },
                        set: { settings.defaultAnnotationColor = $0.toHex() ?? "FF0000" }
                    ))
                    HStack {
                        Text("Line width:")
                        Slider(value: $settings.defaultLineWidth, in: 1...10, step: 0.5)
                        Text("\(settings.defaultLineWidth, specifier: "%.1f") pt").frame(width: 52)
                    }
                    HStack {
                        Text("Font size:")
                        Slider(value: $settings.defaultFontSize, in: 8...48, step: 1)
                        Text("\(Int(settings.defaultFontSize)) pt").frame(width: 52)
                    }
                }

                SettingsPaneSection(icon: "grid", title: "Canvas Grid", subtitle: "Alignment guide overlay on the editing canvas") {
                    SettingsToggle(title: "Show grid",
                                   subtitle: "Displays a grid overlay while editing",
                                   isOn: $settings.showGrid)
                    if settings.showGrid {
                        HStack {
                            Text("Grid size:")
                            Slider(value: $settings.gridSize, in: 10...50, step: 5)
                            Text("\(Int(settings.gridSize)) px").frame(width: 52)
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Editor")
    }
}

// MARK: - Video & Audio

private struct VideoAudioSettingsPane: View {
    @ObservedObject private var settings = SettingsModel.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                SettingsPaneSection(icon: "video.fill", title: "Video", subtitle: "Configure video capture settings") {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Frame rate").fontWeight(.medium)
                            Text("Higher frame rates produce smoother video").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Picker("", selection: $settings.frameRate) {
                            ForEach(SettingsModel.FrameRate.allCases) { Text($0.displayName).tag($0) }
                        }.labelsHidden().frame(width: 120)
                    }.padding(.vertical, 6)

                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Encoding").fontWeight(.medium)
                            Text("Video compression format").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Picker("", selection: $settings.encoding) {
                            ForEach(SettingsModel.Encoding.allCases) { Text($0.rawValue).tag($0) }
                        }.labelsHidden().frame(width: 120)
                    }.padding(.vertical, 6)

                    SettingsToggle(title: "Downsample Retina recordings",
                                   subtitle: "Reduces file size for high-resolution displays",
                                   isOn: $settings.downsampleRetina)
                    SettingsToggle(title: "Show countdown before recording",
                                   subtitle: "Displays 3-2-1 before recording starts",
                                   isOn: $settings.showVideoCountdown)
                }

                SettingsPaneSection(icon: "waveform", title: "Audio", subtitle: "Configure audio recording settings") {
                    SettingsToggle(title: "Combine audio tracks",
                                   subtitle: "Merges system and microphone audio into one track",
                                   isOn: $settings.combineAudioTracks)

                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("System audio").fontWeight(.medium)
                            Text("Choose system audio recording method").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Picker("", selection: $settings.systemAudio) {
                            ForEach(SettingsModel.SystemAudioSource.allCases) { Text($0.rawValue).tag($0) }
                        }.labelsHidden().frame(width: 150)
                    }.padding(.vertical, 6)
                }
            }
            .padding(24)
        }
        .navigationTitle("Video & Audio")
    }
}

// MARK: - About

private struct AboutPane: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 20)

                // App icon
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 96, height: 96)
                        .shadow(color: .accentColor.opacity(0.4), radius: 20, x: 0, y: 8)
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 6) {
                    Text("Screen Grabber")
                        .font(.system(size: 28, weight: .bold))
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                        Text("Version \(version)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Text("A powerful screenshot tool for macOS with advanced editing capabilities, OCR text recognition, and automatic file organisation.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: 500)
                    .fixedSize(horizontal: false, vertical: true)

                // Feature badges
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                          alignment: .center, spacing: 10) {
                    FeatureBadge(icon: "keyboard",            text: "Global Hotkeys")
                    FeatureBadge(icon: "menubar.rectangle",   text: "Menu Bar")
                    FeatureBadge(icon: "folder",              text: "Auto-Save")
                    FeatureBadge(icon: "pencil.circle",       text: "Image Editor")
                    FeatureBadge(icon: "doc.text.viewfinder", text: "OCR")
                    FeatureBadge(icon: "doc.on.clipboard",    text: "Clipboard")
                }
                .frame(maxWidth: 500)

                Spacer(minLength: 8)

                Text("© 2025 Screen Grabber")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(32)
        }
        .navigationTitle("About")
    }
}

// MARK: - AI Pro

private struct AIProSettingsPane: View {
    @ObservedObject private var entitlement = AIEntitlementManager.shared
    @ObservedObject private var subscription = SubscriptionManager.shared
    @ObservedObject private var keyManager = APIKeyManager.shared

    @State private var showPaywall = false
    @State private var showBYOK = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Status card
                SettingsPaneSection(icon: "sparkles", title: "AI Pro Status", subtitle: "Your current AI entitlement") {
                    HStack(spacing: 14) {
                        AIEntitlementBadge()
                        VStack(alignment: .leading, spacing: 3) {
                            Text(statusTitle).fontWeight(.semibold)
                            Text(statusSubtitle).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if !entitlement.entitlementResult.isAllowed {
                            Button("Upgrade") { showPaywall = true }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                        }
                    }
                    .padding(.vertical, 4)

                    if subscription.isSubscribed, let expires = subscription.expiresDate {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar").font(.caption).foregroundStyle(.secondary)
                            Text("Renews \(expires, style: .date)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                // Subscription management
                SettingsPaneSection(icon: "creditcard", title: "Subscription", subtitle: "Manage your AI Pro subscription") {
                    if subscription.isSubscribed {
                        Button("Manage Subscription in App Store") {
                            NSWorkspace.shared.open(URL(string: "itms-apps://apps.apple.com/account/subscriptions")!)
                        }
                        .buttonStyle(.bordered)
                        Button("Restore Purchases") {
                            Task { await subscription.restorePurchases() }
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    } else {
                        HStack {
                            Text("No active subscription").foregroundStyle(.secondary)
                            Spacer()
                            Button("View Plans") { showPaywall = true }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                        }
                        Button("Restore Purchases") {
                            Task { await subscription.restorePurchases() }
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                // BYOK key management
                SettingsPaneSection(icon: "key.fill", title: "API Keys (BYOK)", subtitle: "Use your own AI provider keys as an alternative") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(AIProvider.allCases) { provider in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(provider.displayName).font(.system(size: 12, weight: .medium))
                                    let state = keyManager.validationStates[provider] ?? .unknown
                                    Text(state.statusText)
                                        .font(.caption)
                                        .foregroundStyle(state.isValid ? Color.green : Color.secondary)
                                }
                                Spacer()
                                if keyManager.hasKey(for: provider) {
                                    Image(systemName: "key.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color(NSColor.windowBackgroundColor)))
                        }

                        Button("Manage API Keys…") { showBYOK = true }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }

                // AI features quick reference
                SettingsPaneSection(icon: "info.circle", title: "AI Features", subtitle: "Features included in AI Pro or with BYOK keys") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(AIFeature.allCases, id: \.rawValue) { feature in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(entitlement.entitlementResult.isAllowed ? Color.green : Color.secondary)
                                Text(feature.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.system(size: 12))
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("AI Pro")
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showBYOK) { BYOKSetupView() }
    }

    private var statusTitle: String {
        switch entitlement.checkEntitlement() {
        case .allowed(let source):
            switch source {
            case .subscription:     return "AI Pro — Active"
            case .byok(let p):      return "BYOK — \(p.displayName)"
            case .local:            return "Local AI Features"
            }
        case .denied: return "No AI Access"
        }
    }

    private var statusSubtitle: String {
        switch entitlement.checkEntitlement() {
        case .allowed(let source):
            switch source {
            case .subscription: return "All AI features unlocked via subscription"
            case .byok:         return "Using your own API key"
            case .local:       return "Basic features using device processing"
            }
        case .denied: return "Subscribe to AI Pro or add a BYOK key to enable AI features"
        }
    }
}

// MARK: - Shared Components

/// Titled card section used across all settings panes.
private struct SettingsPaneSection<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).fontWeight(.semibold)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
    }
}

private struct SettingsToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).fontWeight(.medium)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 5)
    }
}

private struct SaveFolderStatusView: View {
    @State private var ok = false
    @State private var message = ""

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(ok ? .green : .orange)
            Text(message).font(.caption).foregroundStyle(.secondary)
        }
        .task { await validate() }
    }

    private func validate() async {
        switch await CapturePermissionsManager.shared.ensureCaptureFolderExists() {
        case .success: ok = true; message = "Ready"
        case .failure: ok = false; message = "Check permissions"
        }
    }
}

#Preview {
    SettingsWindow()
        .frame(width: 820, height: 620)
}
