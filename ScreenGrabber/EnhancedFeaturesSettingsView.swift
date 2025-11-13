//
//  EnhancedFeaturesSettingsView.swift
//  ScreenGrabber
//
//  Comprehensive settings view for all new features
//

import SwiftUI

struct EnhancedFeaturesSettingsView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            QuickDrawSettingsTab()
                .tabItem {
                    Label("Quick Draw", systemImage: "pencil.tip.crop.circle")
                }
                .tag(0)

            SmartTagsSettingsTab()
                .tabItem {
                    Label("Smart Tags", systemImage: "tag")
                }
                .tag(1)

            ProjectWorkspaceSettingsTab()
                .tabItem {
                    Label("Projects", systemImage: "folder")
                }
                .tag(2)

            MultiMonitorSettingsTab()
                .tabItem {
                    Label("Displays", systemImage: "display")
                }
                .tag(3)

            AutoTrimSettingsTab()
                .tabItem {
                    Label("Auto-Trim", systemImage: "crop")
                }
                .tag(4)
        }
        .frame(minWidth: 600, minHeight: 500)
    }
}

// MARK: - Quick Draw Settings

struct QuickDrawSettingsTab: View {
    @ObservedObject var manager = QuickDrawManager.shared

    var body: some View {
        Form {
            Section("Quick Draw on Capture") {
                Toggle("Enable Quick Draw overlay", isOn: $manager.isQuickDrawEnabled)
                    .onChange(of: manager.isQuickDrawEnabled) { oldValue, newValue in
                        manager.saveSettings()
                    }

                Toggle("Automatically show after capture", isOn: Binding(
                    get: { NewFeaturesSettings.quickDrawAutoShow },
                    set: { NewFeaturesSettings.quickDrawAutoShow = $0 }
                ))

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Default Color")
                    ColorPicker("Stroke Color", selection: Binding(
                        get: { Color(manager.strokeColor) },
                        set: { manager.strokeColor = NSColor($0); manager.saveSettings() }
                    ))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Default Stroke Width: \(Int(manager.strokeWidth))px")
                    Slider(value: $manager.strokeWidth, in: 1...10, step: 1)
                        .onChange(of: manager.strokeWidth) { oldValue, newValue in
                            manager.saveSettings()
                        }
                }
            }

            Section("Available Tools") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(QuickDrawManager.DrawingTool.allCases, id: \.self) { tool in
                        HStack {
                            Image(systemName: tool.icon)
                                .frame(width: 24)
                            Text(tool.rawValue)
                            Spacer()
                        }
                    }
                }
            }

            Section("Keyboard Shortcuts") {
                VStack(alignment: .leading, spacing: 8) {
                    ShortcutRow(key: "⌘K", description: "Clear all annotations")
                    ShortcutRow(key: "ESC", description: "Cancel without saving")
                    ShortcutRow(key: "⏎", description: "Save annotated screenshot")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Smart Tags Settings

struct SmartTagsSettingsTab: View {
    @ObservedObject var manager = SmartTagsManager.shared

    var body: some View {
        Form {
            Section("Auto-Tagging") {
                Toggle("Enable automatic tagging", isOn: $manager.autoTaggingEnabled)
                    .onChange(of: manager.autoTaggingEnabled) { oldValue, newValue in
                        manager.saveSettings()
                    }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Auto-tagging uses:")
                        .font(.caption)

                    VStack(alignment: .leading, spacing: 4) {
                        BulletPoint(text: "OCR text recognition")
                        BulletPoint(text: "Image dimensions and aspect ratio")
                        BulletPoint(text: "Capture method")
                        BulletPoint(text: "Time of day")
                        BulletPoint(text: "Content analysis (code, UI, errors, etc.)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }

            Section("Known Tags") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("You have \(manager.allTags.count) known tags")
                        .font(.headline)

                    if !manager.allTags.isEmpty {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                                ForEach(manager.allTags, id: \.self) { tag in
                                    TagChip(tag: tag, isAutoTag: false, onRemove: {
                                        manager.removeTag(tag)
                                    })
                                }
                            }
                        }
                        .frame(maxHeight: 200)

                        Button("Clear All Tags") {
                            manager.allTags.removeAll()
                            manager.saveAllTags()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            Section("Common Tags") {
                Text("Pre-defined tags for quick access")
                    .font(.caption)
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                    ForEach(SmartTagsManager.commonTags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Project Workspace Settings

struct ProjectWorkspaceSettingsTab: View {
    @ObservedObject var manager = ProjectWorkspaceManager.shared

    var body: some View {
        Form {
            Section("Project Settings") {
                Toggle("Auto-detect project from content", isOn: $manager.autoDetectProject)

                VStack(alignment: .leading, spacing: 8) {
                    Text("When enabled, ScreenGrabber will automatically assign screenshots to projects based on:")
                        .font(.caption)

                    VStack(alignment: .leading, spacing: 4) {
                        BulletPoint(text: "Active window or application")
                        BulletPoint(text: "Screenshot content (via OCR)")
                        BulletPoint(text: "Currently active project")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }

            Section("Statistics") {
                HStack {
                    Text("Total Screenshots:")
                    Spacer()
                    Text("\(manager.getTotalScreenshots())")
                        .fontWeight(.semibold)
                }

                HStack {
                    Text("Active Projects:")
                    Spacer()
                    Text("\(manager.projects.count)")
                        .fontWeight(.semibold)
                }

                if let mostUsed = manager.getMostUsedProject() {
                    HStack {
                        Text("Most Used Project:")
                        Spacer()
                        Text(mostUsed.name)
                            .fontWeight(.semibold)
                    }
                }
            }

            Section("Recent Projects") {
                if manager.projects.isEmpty {
                    Text("No projects yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(manager.getRecentProjects(limit: 5)) { project in
                        HStack {
                            Image(systemName: project.icon)
                                .foregroundColor(Color(project.nsColor))
                            Text(project.name)
                            Spacer()
                            Text("\(project.screenshotCount)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Multi-Monitor Settings

struct MultiMonitorSettingsTab: View {
    @ObservedObject var manager = MultiMonitorManager.shared

    var body: some View {
        Form {
            Section("Display Selection") {
                Toggle("Remember display preference", isOn: $manager.rememberDisplayPreference)

                VStack(alignment: .leading, spacing: 8) {
                    Text("When enabled, ScreenGrabber will remember your preferred display for screenshots.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Detected Displays") {
                if manager.availableDisplays.isEmpty {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Detecting displays...")
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(manager.availableDisplays.count) display(s) detected")
                            .font(.headline)

                        ForEach(manager.availableDisplays) { display in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "display")
                                    Text(display.name)
                                        .fontWeight(.medium)

                                    if display.isPrimary {
                                        Text("(Primary)")
                                            .font(.caption)
                                            .foregroundColor(.yellow)
                                    }

                                    if manager.selectedDisplay?.id == display.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.accentColor)
                                    }
                                }

                                HStack(spacing: 16) {
                                    Text("Resolution: \(display.resolution)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Text("Aspect: \(display.aspectRatio)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Button("Refresh Displays") {
                    manager.refreshDisplays()
                }
                .buttonStyle(.bordered)
            }

            Section("Keyboard Shortcuts") {
                VStack(alignment: .leading, spacing: 8) {
                    ShortcutRow(key: "⌘]", description: "Next display")
                    ShortcutRow(key: "⌘[", description: "Previous display")
                }
            }

            if manager.availableDisplays.count > 1 {
                Section("Display Arrangement") {
                    Text(manager.getDisplayArrangement())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            manager.refreshDisplays()
        }
    }
}

// MARK: - Auto-Trim Settings

struct AutoTrimSettingsTab: View {
    @ObservedObject var manager = AutoTrimManager.shared

    var body: some View {
        Form {
            Section("Auto-Trim Settings") {
                Toggle("Enable auto-trim on capture", isOn: $manager.autoTrimEnabled)
                    .onChange(of: manager.autoTrimEnabled) { oldValue, newValue in
                        manager.saveSettings()
                    }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Auto-trim automatically removes uniform colored borders from screenshots.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Sensitivity") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Trim Threshold: \(Int(manager.trimThreshold))")
                        .font(.headline)

                    Slider(value: $manager.trimThreshold, in: 1...50, step: 1)
                        .onChange(of: manager.trimThreshold) { oldValue, newValue in
                            manager.saveSettings()
                        }

                    Text("Lower values detect more subtle borders. Higher values only trim very obvious borders.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Minimum Border Size: \(Int(manager.minBorderSize))px")
                        .font(.headline)

                    Slider(value: $manager.minBorderSize, in: 1...20, step: 1)
                        .onChange(of: manager.minBorderSize) { oldValue, newValue in
                            manager.saveSettings()
                        }

                    Text("Minimum number of pixels to trim from each edge.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("How It Works") {
                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(
                        icon: "viewfinder.circle",
                        title: "Border Detection",
                        description: "Samples edge colors to detect uniform borders"
                    )

                    FeatureRow(
                        icon: "crop",
                        title: "Smart Cropping",
                        description: "Removes detected borders while preserving content"
                    )

                    FeatureRow(
                        icon: "arrow.up.backward.and.arrow.down.forward",
                        title: "Dimension Tracking",
                        description: "Saves original dimensions for reference"
                    )
                }
            }

            Section("Additional Features") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Smart Crop (content-aware)", isOn: .constant(true))
                        .disabled(true)

                    Text("Smart crop uses AI to detect important content and crop around it.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Helper Views

struct ShortcutRow: View {
    let key: String
    let description: String

    var body: some View {
        HStack {
            Text(key)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(4)

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct BulletPoint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
            Text(text)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    EnhancedFeaturesSettingsView()
}
