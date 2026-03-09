//
//  CapturePanel.swift
//  ScreenGrabber
//
//  Left panel with capture configuration options
//

import SwiftUI

struct CapturePanel: View {
    @ObservedObject var settingsManager: SettingsManager
    let onCapture: () -> Void
    let onOpenEditor: () -> Void

    @ObservedObject var settingsModel = SettingsModel.shared
    @ObservedObject private var presetManager = CapturePresetManager.shared

    @State private var selectedEffect: CaptureEffect = .none
    @State private var selectedShare: ShareOption = .none
    @State private var showingNewPresetSheet = false
    @State private var newPresetName = ""
    
    // Explicit init to resolve ambiguity if multiple exist
    init(settingsManager: SettingsManager, onCapture: @escaping () -> Void, onOpenEditor: @escaping () -> Void) {
        self.settingsManager = settingsManager
        self.onCapture = onCapture
        self.onOpenEditor = onOpenEditor
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Capture")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Configure your screenshot")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 20)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Picker("Selection Type", selection: $settingsManager.selectedScreenOption) {
                        ForEach(ScreenOption.allCases) { option in
                            HStack {
                                Image(systemName: option.icon)
                                Text(option.displayName)
                            }.tag(option)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Picker("Effects", selection: $selectedEffect) {
                        ForEach(CaptureEffect.allCases) { effect in
                            HStack {
                                Image(systemName: effect.icon)
                                Text(effect.rawValue)
                            }.tag(effect)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Picker("Share Options", selection: $selectedShare) {
                        ForEach(ShareOption.allCases) { option in
                            HStack {
                                Image(systemName: option.icon)
                                Text(option.rawValue)
                            }.tag(option)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Toggles
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Options")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 20)
                        
                        ToggleOption(
                            title: "Preview in Editor",
                            icon: "pencil.tip.crop.circle",
                            isOn: $settingsModel.previewInEditorEnabled
                        )
                        
                        ToggleOption(
                            title: "Copy to Clipboard",
                            icon: "doc.on.clipboard",
                            isOn: $settingsModel.copyToClipboardEnabled
                        )
                        
                        ToggleOption(
                            title: "Include Cursor",
                            icon: "cursorarrow.rays",
                            isOn: $settingsModel.includeCursor
                        )
                        
                        ToggleOption(
                            title: "Time Delay",
                            icon: "timer",
                            isOn: $settingsModel.timeDelayEnabled
                        )
                        
                        if settingsModel.timeDelayEnabled {
                            HStack {
                                Text("Delay:")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                
                                Stepper("\(Int(settingsModel.timeDelaySeconds))s", value: $settingsModel.timeDelaySeconds, in: 1...10, step: 1)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .padding(.horizontal, 20)
                            .padding(.leading, 32)
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Presets
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Presets")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)

                            Spacer()

                            Button(action: { showingNewPresetSheet = true }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                            .help("Save current settings as preset")
                        }
                        .padding(.horizontal, 20)

                        Menu {
                            ForEach(presetManager.presets) { preset in
                                Button(preset.name) {
                                    presetManager.apply(preset, settings: settingsManager, model: settingsModel)
                                }
                            }
                            if !presetManager.presets.isEmpty {
                                Divider()
                            }
                            ForEach(presetManager.presets) { preset in
                                Button("Delete \"\(preset.name)\"", role: .destructive) {
                                    presetManager.delete(preset)
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.orange)
                                Text("Apply Preset")
                                    .font(.system(size: 13, weight: .medium))
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.gray.opacity(0.2), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                    }
                    .sheet(isPresented: $showingNewPresetSheet) {
                        SavePresetSheet(
                            settingsManager: settingsManager,
                            settingsModel: settingsModel,
                            isPresented: $showingNewPresetSheet
                        )
                    }
                }
                .padding(.vertical, 20)
            }
            
            Divider()
            
            // Bottom Actions
            VStack(spacing: 12) {
                // Large Capture Button
                Button(action: onCapture) {
                    HStack {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Capture")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color.red, Color.red.opacity(0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(8)
                    .shadow(color: Color.red.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                
                HStack(spacing: 8) {
                    // Open in Editor
                    Button(action: onOpenEditor) {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil.tip.crop.circle")
                                .font(.system(size: 13))
                            Text("Open in Editor")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    // Settings
                    Button(action: {
                        if let url = URL(string: "screengrabber://settings") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Image(systemName: "gear")
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                            .frame(width: 36, height: 36)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Settings")
                }
            }
            .padding(20)
        }
        .frame(width: 280)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Save Preset Sheet
struct SavePresetSheet: View {
    let settingsManager: SettingsManager
    let settingsModel: SettingsModel
    @Binding var isPresented: Bool

    @State private var name = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Save as Preset")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 6) {
                Text("Preset Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("e.g. Quick Share", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            // Summary of what will be saved
            VStack(alignment: .leading, spacing: 4) {
                Text("Capture type: \(settingsManager.selectedScreenOption.displayName)")
                Text("Copy to clipboard: \(settingsModel.copyToClipboardEnabled ? "Yes" : "No")")
                Text("Open in editor: \(settingsModel.previewInEditorEnabled ? "Yes" : "No")")
                Text("Include cursor: \(settingsModel.includeCursor ? "Yes" : "No")")
                if settingsModel.timeDelayEnabled {
                    Text("Delay: \(Int(settingsModel.timeDelaySeconds))s")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            HStack(spacing: 12) {
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)

                Button("Save") {
                    let preset = CapturePreset(
                        name: name.isEmpty ? "My Preset" : name,
                        captureType: settingsManager.selectedScreenOption.rawValue,
                        copyToClipboard: settingsModel.copyToClipboardEnabled,
                        previewInEditor: settingsModel.previewInEditorEnabled,
                        includeCursor: settingsModel.includeCursor,
                        timeDelayEnabled: settingsModel.timeDelayEnabled,
                        timeDelaySeconds: settingsModel.timeDelaySeconds
                    )
                    CapturePresetManager.shared.add(preset)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}

