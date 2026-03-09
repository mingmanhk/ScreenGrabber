//
//  SettingsPanel.swift
//  ScreenGrabber
//
//  Settings view for customizing app appearance and behavior
//  Created on 01/03/26.
//

import SwiftUI

struct SettingsPanel: View {
    @State private var selectedTheme: AppColors.ColorTheme = .classic
    @State private var layoutSize: LayoutSize = .normal
    @State private var showFileNames = true
    @State private var showTimestamps = true
    @State private var autoRefresh = true
    @State private var thumbnailQuality: ThumbnailQuality = .balanced
    
    enum LayoutSize: String, CaseIterable, Identifiable {
        case compact = "Compact"
        case normal = "Normal"
        case spacious = "Spacious"
        
        var id: String { rawValue }
    }
    
    enum ThumbnailQuality: String, CaseIterable, Identifiable {
        case fast = "Fast (Lower Quality)"
        case balanced = "Balanced"
        case best = "Best Quality"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 28))
                            .foregroundColor(AppColors.accent)
                        
                        Text("Settings")
                            .font(AppTypography.panelTitle)
                    }
                    
                    Text("Customize your Screen Grabber experience")
                        .font(AppTypography.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
                
                Divider()
                
                // Appearance Section
                SettingsSection(title: "Appearance", icon: "paintbrush.fill") {
                    VStack(alignment: .leading, spacing: 16) {
                        // Theme selector
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Color Theme")
                                .font(AppTypography.caption)
                                .foregroundColor(.secondary)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                                ThemeButton(
                                    name: "Classic",
                                    color: Color(red: 1.0, green: 0.23, blue: 0.19),
                                    theme: .classic,
                                    isSelected: selectedTheme == .classic
                                ) {
                                    selectTheme(.classic)
                                }
                                
                                ThemeButton(
                                    name: "Blue",
                                    color: Color(red: 0.0, green: 0.48, blue: 1.0),
                                    theme: .blue,
                                    isSelected: selectedTheme == .blue
                                ) {
                                    selectTheme(.blue)
                                }
                                
                                ThemeButton(
                                    name: "Purple",
                                    color: Color(red: 0.69, green: 0.32, blue: 0.87),
                                    theme: .purple,
                                    isSelected: selectedTheme == .purple
                                ) {
                                    selectTheme(.purple)
                                }
                                
                                ThemeButton(
                                    name: "Orange",
                                    color: Color(red: 1.0, green: 0.58, blue: 0.0),
                                    theme: .orange,
                                    isSelected: selectedTheme == .orange
                                ) {
                                    selectTheme(.orange)
                                }
                                
                                ThemeButton(
                                    name: "Green",
                                    color: Color(red: 0.2, green: 0.78, blue: 0.35),
                                    theme: .green,
                                    isSelected: selectedTheme == .green
                                ) {
                                    selectTheme(.green)
                                }
                                
                                ThemeButton(
                                    name: "Pro",
                                    color: Color(red: 0.26, green: 0.46, blue: 0.75),
                                    theme: .professional,
                                    isSelected: selectedTheme == .professional
                                ) {
                                    selectTheme(.professional)
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Layout size
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Layout Size")
                                .font(AppTypography.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("Layout Size", selection: $layoutSize) {
                                ForEach(LayoutSize.allCases) { size in
                                    Text(size.rawValue).tag(size)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: layoutSize) { _, newValue in
                                applyLayoutSize(newValue)
                            }
                            
                            Text(layoutSizeDescription)
                                .font(AppTypography.smallCaption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }
                }
                
                // Display Section
                SettingsSection(title: "Display", icon: "rectangle.grid.3x2.fill") {
                    VStack(alignment: .leading, spacing: 16) {
                        ToggleSetting(
                            title: "Show File Names",
                            description: "Display file names below thumbnails",
                            isOn: $showFileNames
                        )
                        
                        ToggleSetting(
                            title: "Show Timestamps",
                            description: "Display when each screenshot was taken",
                            isOn: $showTimestamps
                        )
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Thumbnail Quality")
                                .font(AppTypography.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("Quality", selection: $thumbnailQuality) {
                                ForEach(ThumbnailQuality.allCases) { quality in
                                    Text(quality.rawValue).tag(quality)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }
                
                // Performance Section
                SettingsSection(title: "Performance", icon: "speedometer") {
                    VStack(alignment: .leading, spacing: 16) {
                        ToggleSetting(
                            title: "Auto-Refresh Gallery",
                            description: "Automatically update when new screenshots are added",
                            isOn: $autoRefresh
                        )
                        
                        Button(action: clearThumbnailCache) {
                            HStack {
                                Image(systemName: "trash")
                                    .foregroundColor(.orange)
                                Text("Clear Thumbnail Cache")
                                    .font(AppTypography.caption)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Storage Section
                SettingsSection(title: "Storage", icon: "externaldrive.fill") {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Screenshots Location")
                                    .font(AppTypography.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("~/Pictures/ScreenGrabber/")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            Button("Open") {
                                openScreenshotsFolder()
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Divider()
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total Screenshots")
                                    .font(AppTypography.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("Loading...")
                                    .font(AppTypography.body)
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Space Used")
                                    .font(AppTypography.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("Loading...")
                                    .font(AppTypography.body)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
                
                // About Section
                SettingsSection(title: "About", icon: "info.circle.fill") {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(label: "Version", value: "2.0.0")
                        InfoRow(label: "Build", value: "2026.01.03")
                        InfoRow(label: "macOS", value: "14.0+")
                        
                        Divider()
                        
                        HStack(spacing: 12) {
                            Button(action: {
                                // Open GitHub
                            }) {
                                HStack {
                                    Image(systemName: "link")
                                    Text("GitHub")
                                }
                                .font(AppTypography.smallCaption)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                // Open documentation
                            }) {
                                HStack {
                                    Image(systemName: "book")
                                    Text("Docs")
                                }
                                .font(AppTypography.smallCaption)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // Reset Button
                Button(action: resetToDefaults) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset All Settings to Defaults")
                            .font(AppTypography.caption)
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Helper Views
    
    private var layoutSizeDescription: String {
        switch layoutSize {
        case .compact:
            return "Smaller panels and thumbnails (240px panels)"
        case .normal:
            return "Default size (280px panels)"
        case .spacious:
            return "Larger panels and thumbnails (320px panels)"
        }
    }
    
    // MARK: - Actions
    
    private func selectTheme(_ theme: AppColors.ColorTheme) {
        selectedTheme = theme
        AppColors.applyTheme(theme)
    }
    
    private func applyLayoutSize(_ size: LayoutSize) {
        switch size {
        case .compact:
            AppLayout.applyCompact()
        case .normal:
            AppLayout.applyNormal()
        case .spacious:
            AppLayout.applySpacious()
        }
    }
    
    private func clearThumbnailCache() {
        // Implementation: Clear thumbnail cache
        print("Clearing thumbnail cache...")
    }
    
    private func openScreenshotsFolder() {
        Task { @MainActor in
            if let folderURL = await UnifiedCaptureManager.shared.getCapturesFolderURL() {
                NSWorkspace.shared.open(folderURL)
            }
        }
    }
    
    private func resetToDefaults() {
        selectedTheme = .classic
        layoutSize = .normal
        showFileNames = true
        showTimestamps = true
        autoRefresh = true
        thumbnailQuality = .balanced
        
        AppColors.applyTheme(.classic)
        AppLayout.applyNormal()
    }
}

// MARK: - Helper Components

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                
                Text(title)
                    .font(AppTypography.sectionTitle)
                    .foregroundColor(.primary)
            }
            
            content()
                .padding(16)
                .background(AppColors.panelBackground)
                .cornerRadius(AppLayout.panelCornerRadius)
        }
    }
}

struct ToggleSetting: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTypography.body)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(AppTypography.smallCaption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

struct ThemeButton: View {
    let name: String
    let color: Color
    let theme: AppColors.ColorTheme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2)
                            .padding(-3)
                    )
                
                Text(name)
                    .font(AppTypography.tinyText)
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.gray.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(AppTypography.caption)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    SettingsPanel()
        .frame(width: 600, height: 800)
}

