//
//  EnhancedCaptureSettingsView.swift
//  ScreenGrabber
//
//  Enhanced settings panel with new features
//

import SwiftUI

// MARK: - Capture Delay Picker
struct CaptureDelayPickerView: View {
    @State private var selectedDelay: Int = CaptureDelaySettings.current
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderView(title: "Capture Delay", icon: "timer")
            
            HStack(spacing: 8) {
                ForEach(CaptureDelaySettings.delays, id: \.self) { delay in
                    Button(action: {
                        selectedDelay = delay
                        CaptureDelaySettings.current = delay
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: delay == 0 ? "bolt.fill" : "timer")
                                .font(.title3)
                            
                            Text(delay == 0 ? "Instant" : "\(delay)s")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selectedDelay == delay ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                        )
                        .foregroundColor(selectedDelay == delay ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Compression Profile Picker
struct CompressionProfilePickerView: View {
    @State private var selectedProfile: CompressionProfile = CompressionProfile.current
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderView(title: "Image Format", icon: "photo.stack")
            
            VStack(spacing: 8) {
                ForEach(CompressionProfile.allCases, id: \.self) { profile in
                    Button(action: {
                        selectedProfile = profile
                        CompressionProfile.current = profile
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: profile.icon)
                                .font(.body)
                                .foregroundColor(selectedProfile == profile ? .white : .accentColor)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text(".\(profile.fileExtension)")
                                    .font(.caption)
                                    .opacity(0.8)
                            }
                            .foregroundColor(selectedProfile == profile ? .white : .primary)
                            
                            Spacer()
                            
                            if selectedProfile == profile {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    selectedProfile == profile ?
                                    LinearGradient(
                                        colors: [Color.accentColor, Color.accentColor.opacity(0.85)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ) :
                                    LinearGradient(
                                        colors: [Color(NSColor.controlBackgroundColor), Color(NSColor.controlBackgroundColor)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Auto-Copy Settings
struct AutoCopySettingsView: View {
    @State private var selectedOption: AutoCopyOption = AutoCopyOption.current
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderView(title: "Auto-Copy After Capture", icon: "doc.on.clipboard")
            
            VStack(spacing: 8) {
                ForEach(AutoCopyOption.allCases, id: \.self) { option in
                    Button(action: {
                        selectedOption = option
                        AutoCopyOption.current = option
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: option == .none ? "slash.circle" : "doc.on.clipboard")
                                .font(.body)
                                .foregroundColor(selectedOption == option ? .white : .accentColor)
                                .frame(width: 24)
                            
                            Text(option.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(selectedOption == option ? .white : .primary)
                            
                            Spacer()
                            
                            if selectedOption == option {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selectedOption == option ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Region Presets Manager View
struct RegionPresetsView: View {
    @StateObject private var presetsManager = RegionPresetsManager.shared
    @State private var showingAddPreset = false
    @State private var newPresetName = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeaderView(title: "Region Presets", icon: "rectangle.dashed")
                
                Spacer()
                
                Button(action: { showingAddPreset = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            
            if presetsManager.presets.isEmpty {
                Text("No presets saved. Capture a region and save it as a preset.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
            } else {
                VStack(spacing: 8) {
                    ForEach(presetsManager.presets) { preset in
                        PresetRowView(preset: preset) {
                            // Use preset action
                            captureWithPreset(preset)
                        } onDelete: {
                            presetsManager.deletePreset(preset)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddPreset) {
            AddPresetSheet(presetsManager: presetsManager)
        }
    }
    
    private func captureWithPreset(_ preset: RegionPreset) {
        print("Capturing with preset: \(preset.name)")
        // This would integrate with ScreenCaptureManager
    }
}

struct PresetRowView: View {
    let preset: RegionPreset
    let onUse: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.dashed.badge.record")
                .font(.body)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(preset.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(Int(preset.width)) × \(Int(preset.height))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onUse) {
                Image(systemName: "play.circle")
                    .font(.title3)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
}

struct AddPresetSheet: View {
    @ObservedObject var presetsManager: RegionPresetsManager
    @State private var presetName = ""
    @State private var width: String = "800"
    @State private var height: String = "600"
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Region Preset")
                .font(.title2)
                .fontWeight(.bold)
            
            Form {
                TextField("Preset Name", text: $presetName)
                TextField("Width", text: $width)
                TextField("Height", text: $height)
            }
            .padding()
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Save") {
                    if let w = Double(width), let h = Double(height), !presetName.isEmpty {
                        let preset = RegionPreset(name: presetName, x: 0, y: 0, width: w, height: h)
                        presetsManager.addPreset(preset)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(presetName.isEmpty || width.isEmpty || height.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}

// MARK: - Floating Thumbnail Settings
struct FloatingThumbnailSettingsView: View {
    @State private var enabled: Bool = FloatingThumbnailSettings.enabled
    @State private var autoDismissDelay: Double = FloatingThumbnailSettings.autoDismissDelay
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderView(title: "Floating Thumbnail", icon: "photo.on.rectangle.angled")
            
            Toggle("Show floating preview after capture", isOn: $enabled)
                .onChange(of: enabled) { newValue in
                    FloatingThumbnailSettings.enabled = newValue
                }
            
            if enabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Auto-dismiss after:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(value: $autoDismissDelay, in: 3...30, step: 1) {
                        Text("Delay")
                    } minimumValueLabel: {
                        Text("3s")
                            .font(.caption)
                    } maximumValueLabel: {
                        Text("30s")
                            .font(.caption)
                    }
                    .onChange(of: autoDismissDelay) { newValue in
                        FloatingThumbnailSettings.autoDismissDelay = newValue
                    }
                    
                    Text("\(Int(autoDismissDelay)) seconds")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - Quick Actions Configuration
struct QuickActionsConfigView: View {
    @StateObject private var actionsManager = QuickActionsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderView(title: "Quick Actions Bar", icon: "square.grid.3x2")
            
            Text("Customize actions shown after capture")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                ForEach($actionsManager.actions) { $action in
                    HStack(spacing: 12) {
                        Image(systemName: action.icon)
                            .font(.body)
                            .foregroundColor(.accentColor)
                            .frame(width: 24)
                        
                        Text(action.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Toggle("", isOn: $action.enabled)
                            .labelsHidden()
                            .onChange(of: action.enabled) { _ in
                                actionsManager.saveActions()
                            }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Color(NSColor.controlBackgroundColor)
                            .opacity(action.enabled ? 1.0 : 0.5)
                    )
                    .cornerRadius(10)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        CaptureDelayPickerView()
        CompressionProfilePickerView()
        AutoCopySettingsView()
    }
    .padding()
    .frame(width: 400)
}
