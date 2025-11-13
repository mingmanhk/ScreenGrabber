//
//  ScreenshotBrowserView.swift
//  ScreenGrabber
//
//  Created by Victor Lam on 10/23/25.
//

import SwiftUI
import SwiftData
import AppKit

struct ScreenshotBrowserView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedScreenOption: ScreenOption = .selectedArea
    @State private var selectedOpenOption: OpenOption = .clipboard
    @State private var currentHotkey = "⌘⇧C"
    @State private var recentScreenshots: [URL] = []
    @State private var searchText = ""
    @State private var showHotkeySheet = false
    @State private var showingImageEditor = false
    @State private var selectedImageURL: URL?
    @State private var gridColumns = 4
    @State private var sortOption: SortOption = .dateDescending
    
    enum SortOption: String, CaseIterable {
        case dateDescending = "Newest First"
        case dateAscending = "Oldest First"
        case nameAscending = "Name A-Z"
        case nameDescending = "Name Z-A"
    }
    
    var filteredScreenshots: [URL] {
        let filtered = searchText.isEmpty ? recentScreenshots : recentScreenshots.filter { url in
            url.lastPathComponent.localizedCaseInsensitiveContains(searchText)
        }
        
        // Apply sorting
        return filtered.sorted { url1, url2 in
            switch sortOption {
            case .dateDescending:
                let date1 = (try? FileManager.default.attributesOfItem(atPath: url1.path)[.creationDate] as? Date) ?? Date.distantPast
                let date2 = (try? FileManager.default.attributesOfItem(atPath: url2.path)[.creationDate] as? Date) ?? Date.distantPast
                return date1 > date2
            case .dateAscending:
                let date1 = (try? FileManager.default.attributesOfItem(atPath: url1.path)[.creationDate] as? Date) ?? Date.distantPast
                let date2 = (try? FileManager.default.attributesOfItem(atPath: url2.path)[.creationDate] as? Date) ?? Date.distantPast
                return date1 < date2
            case .nameAscending:
                return url1.lastPathComponent < url2.lastPathComponent
            case .nameDescending:
                return url1.lastPathComponent > url2.lastPathComponent
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar with modern grouping
            ScrollView {
                VStack(spacing: 24) {
                    // Header with stats
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.accentColor.opacity(0.2), Color.accentColor.opacity(0.05)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        
                        VStack(spacing: 6) {
                            Text("Screen Grabber")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 12) {
                                Label("\(recentScreenshots.count)", systemImage: "photo.stack")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if !recentScreenshots.isEmpty {
                                    Text("•")
                                        .foregroundColor(.secondary.opacity(0.5))
                                    
                                    Text(formatTotalSize())
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                    
                    // Capture Settings Group
                    SettingsGroupView(
                        title: "Capture",
                        icon: "gearshape.fill",
                        iconColor: .blue
                    ) {
                        VStack(spacing: 16) {
                            // Screen method cards
                            VStack(alignment: .leading, spacing: 10) {
                                SectionHeaderView(title: "Screen Method", icon: "rectangle.dashed")
                                
                                VStack(spacing: 8) {
                                    ForEach(ScreenOption.allCases, id: \.self) { option in
                                        OptionCardButton(
                                            icon: option.icon,
                                            title: option.displayName,
                                            isSelected: selectedScreenOption == option
                                        ) {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                selectedScreenOption = option
                                                UserDefaults.standard.set(option.rawValue, forKey: "selectedScreenOption")
                                            }
                                        }
                                    }
                                }
                            }
                            
                            Divider()
                            
                            // Output method cards
                            VStack(alignment: .leading, spacing: 10) {
                                SectionHeaderView(title: "Output Method", icon: "arrow.up.doc")
                                
                                VStack(spacing: 8) {
                                    ForEach(OpenOption.allCases, id: \.self) { option in
                                        OptionCardButton(
                                            icon: option.icon,
                                            title: option.displayName,
                                            isSelected: selectedOpenOption == option
                                        ) {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                selectedOpenOption = option
                                                UserDefaults.standard.set(option.rawValue, forKey: "selectedOpenOption")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Quick Actions Group
                    SettingsGroupView(
                        title: "Quick Actions",
                        icon: "bolt.fill",
                        iconColor: .orange
                    ) {
                        VStack(spacing: 8) {
                            // Hotkey settings
                            ActionButton(
                                icon: "keyboard",
                                title: "Global Hotkey",
                                subtitle: currentHotkey,
                                badge: nil
                            ) {
                                showHotkeySheet = true
                            }
                            
                            // Folder access
                            ActionButton(
                                icon: "folder",
                                title: "Screenshots Folder",
                                subtitle: "Open in Finder",
                                badge: "arrow.up.forward"
                            ) {
                                openScreenGrabberFolder()
                            }
                        }
                    }
                    
                    // Help & Tips Group
                    SettingsGroupView(
                        title: "Tips & Tricks",
                        icon: "lightbulb.fill",
                        iconColor: .yellow
                    ) {
                        VStack(alignment: .leading, spacing: 10) {
                            TipRow(icon: "menubar.rectangle", text: "Use menu bar for instant access")
                            TipRow(icon: "hand.tap", text: "Double-click to edit screenshots")
                            TipRow(icon: "contextualmenu.and.cursorarrow", text: "Right-click for more options")
                            TipRow(icon: "keyboard", text: "Use hotkey for quick captures")
                        }
                        .font(.caption)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .frame(minWidth: 320, idealWidth: 340)
            .background(Color(NSColor.controlBackgroundColor))
            .sheet(isPresented: $showHotkeySheet) {
                HotkeyConfigView(currentHotkey: $currentHotkey) { newHotkey in
                    setupGlobalHotkey(hotkey: newHotkey)
                }
            }
            
        } detail: {
            // Modern main content area with improved toolbar
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // Enhanced Toolbar
                    VStack(spacing: 0) {
                        HStack(spacing: 16) {
                            // Search with icon
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                    .font(.body)
                                
                                TextField("Search screenshots...", text: $searchText)
                                    .textFieldStyle(.plain)
                                    .font(.body)
                                
                                if !searchText.isEmpty {
                                    Button(action: { searchText = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(NSColor.controlBackgroundColor))
                            )
                            .frame(maxWidth: 400)
                            
                            Spacer()
                            
                            // Toolbar controls group
                            HStack(spacing: 12) {
                                // Sort menu
                                Menu {
                                    ForEach(SortOption.allCases, id: \.self) { option in
                                        Button(action: { sortOption = option }) {
                                            HStack {
                                                Text(option.rawValue)
                                                if sortOption == option {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.up.arrow.down")
                                        Text("Sort")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color(NSColor.controlBackgroundColor))
                                    )
                                }
                                .menuStyle(.borderlessButton)
                                .help("Sort screenshots")
                                
                                // Grid size control
                                Menu {
                                    Button(action: { gridColumns = 3 }) {
                                        HStack {
                                            Text("Large")
                                            if gridColumns == 3 {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                    Button(action: { gridColumns = 4 }) {
                                        HStack {
                                            Text("Medium")
                                            if gridColumns == 4 {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                    Button(action: { gridColumns = 5 }) {
                                        HStack {
                                            Text("Small")
                                            if gridColumns == 5 {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                } label: {
                                    Image(systemName: "square.grid.3x3")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .padding(8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(Color(NSColor.controlBackgroundColor))
                                        )
                                }
                                .menuStyle(.borderlessButton)
                                .help("Grid size")
                                
                                // Refresh button
                                Button(action: loadRecentScreenshots) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .padding(8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(Color(NSColor.controlBackgroundColor))
                                        )
                                }
                                .buttonStyle(.plain)
                                .help("Refresh")
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Color(NSColor.windowBackgroundColor))
                        
                        Divider()
                    }
                    
                    // Screenshots grid or empty state
                    if filteredScreenshots.isEmpty {
                        // Modern empty state
                        VStack(spacing: 24) {
                            Spacer()
                            
                            if recentScreenshots.isEmpty {
                                // No screenshots at all
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.accentColor.opacity(0.15), Color.accentColor.opacity(0.05)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 140, height: 140)
                                    
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.system(size: 60, weight: .thin))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [Color.accentColor.opacity(0.8), Color.accentColor.opacity(0.5)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                                
                                VStack(spacing: 12) {
                                    Text("No Screenshots Yet")
                                        .font(.title)
                                        .fontWeight(.bold)
                                    
                                    Text("Start capturing your first screenshot using the button below or the global hotkey")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: 400)
                                }
                            } else {
                                // Search returned no results
                                ZStack {
                                    Circle()
                                        .fill(Color.secondary.opacity(0.1))
                                        .frame(width: 120, height: 120)
                                    
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 50, weight: .thin))
                                        .foregroundColor(.secondary)
                                }
                                
                                VStack(spacing: 12) {
                                    Text("No Results Found")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                    
                                    Text("Try adjusting your search term")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                                
                                Button(action: { searchText = "" }) {
                                    Text("Clear Search")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.accentColor)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(Color.accentColor.opacity(0.1))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Screenshots grid with modern styling
                        ScrollView {
                            LazyVGrid(
                                columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: gridColumns),
                                spacing: 20
                            ) {
                                ForEach(filteredScreenshots, id: \.self) { fileURL in
                                    ModernScreenshotItem(
                                        fileURL: fileURL,
                                        onEdit: {
                                            selectedImageURL = fileURL
                                            showingImageEditor = true
                                        },
                                        onDeleted: {
                                            withAnimation {
                                                if let idx = recentScreenshots.firstIndex(of: fileURL) {
                                                    recentScreenshots.remove(at: idx)
                                                }
                                            }
                                        }
                                    )
                                    .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding(20)
                            .padding(.bottom, 100) // Space for floating action bar
                        }
                    }
                }
                
                // Floating action bar with modern design
                HStack(spacing: 14) {
                    // Primary capture button
                    Button(action: quickCapture) {
                        HStack(spacing: 12) {
                            ZStack {
                                // High-contrast chip to ensure readability on any backdrop
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.black.opacity(0.35), Color.black.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 38, height: 38)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
                                    )

                                Image(systemName: "camera.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .accessibilityLabel("Take Screenshot")
                            }
                            
                            Text("Capture Screenshot")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(
                            Capsule(style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.accentColor, Color.accentColor.opacity(0.85)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: Color.accentColor.opacity(0.4), radius: 16, x: 0, y: 8)
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)

                    // Secondary actions
                    HStack(spacing: 10) {
                        Button(action: openScreenGrabberFolder) {
                            Image(systemName: "folder")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .fill(Color(NSColor.controlBackgroundColor))
                                        .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 4)
                                )
                        }
                        .buttonStyle(.plain)
                        .help("Open screenshots folder")
                        
                        Button(action: loadRecentScreenshots) {
                            Image(systemName: "arrow.clockwise")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .fill(Color(NSColor.controlBackgroundColor))
                                        .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 4)
                                )
                        }
                        .buttonStyle(.plain)
                        .help("Refresh")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
                        .padding(.horizontal, 16)
                )
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Screen Grabber")
        .onAppear {
            loadSettings()
            loadRecentScreenshots()
        }
        .sheet(isPresented: $showingImageEditor) {
            if let url = selectedImageURL {
                SimpleImageEditorView(imageURL: url)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatTotalSize() -> String {
        let totalBytes = recentScreenshots.compactMap { url -> Int64? in
            (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64)
        }.reduce(0, +)
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalBytes)
    }
    
    private func loadSettings() {
        let savedHotkey = UserDefaults.standard.string(forKey: "grabScreenHotkey") ?? "⌘⇧C"
        currentHotkey = savedHotkey
        
        if let savedScreenOption = UserDefaults.standard.string(forKey: "selectedScreenOption"),
           let screenOption = ScreenOption(rawValue: savedScreenOption) {
            selectedScreenOption = screenOption
        }
        
        if let savedOpenOption = UserDefaults.standard.string(forKey: "selectedOpenOption"),
           let openOption = OpenOption(rawValue: savedOpenOption) {
            selectedOpenOption = openOption
        }
    }
    
    private func loadRecentScreenshots() {
        recentScreenshots = ScreenCaptureManager.shared.loadRecentScreenshots()
    }
    
    private func quickCapture() {
        ScreenCaptureManager.shared.captureScreen(
            method: selectedScreenOption,
            openOption: selectedOpenOption,
            modelContext: modelContext
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            loadRecentScreenshots()
        }
    }
    
    private func setupGlobalHotkey(hotkey: String) -> Bool {
        let success = GlobalHotkeyManager.shared.registerHotkey(hotkey) {
            DispatchQueue.main.async {
                self.quickCapture()
            }
        }
        
        if success {
            UserDefaults.standard.set(hotkey, forKey: "grabScreenHotkey")
            currentHotkey = hotkey
        }
        
        return success
    }
    
    private func openScreenGrabberFolder() {
        let folderURL = ScreenCaptureManager.shared.getScreenGrabberFolderURL()
        NSWorkspace.shared.open(folderURL)
    }
}

// MARK: - Hotkey Configuration View
struct HotkeyConfigView: View {
    @Binding var currentHotkey: String
    let onSave: (String) -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var newHotkey: String
    @State private var conflictMessage: String?
    
    init(currentHotkey: Binding<String>, onSave: @escaping (String) -> Bool) {
        self._currentHotkey = currentHotkey
        self.onSave = onSave
        self._newHotkey = State(initialValue: currentHotkey.wrappedValue)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Set Global Hotkey")
                .font(.title2.weight(.bold))
            
            Text("Press a key combination to trigger a capture from anywhere.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            TextField("Enter hotkey (e.g., ⌘⇧C)", text: $newHotkey)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .font(.title3)
            
            if let conflictMessage = conflictMessage {
                Text(conflictMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                
                Button("Save") {
                    if onSave(newHotkey) {
                        dismiss()
                    } else {
                        conflictMessage = "This hotkey is already in use by another application. Please choose a different one."
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newHotkey.isEmpty)
            }
        }
        .padding()
        .frame(width: 350)
    }
}

// MARK: - Modern Screenshot Item
struct ModernScreenshotItem: View {
    let fileURL: URL
    let onEdit: () -> Void
    let onDeleted: () -> Void
    
    @State private var thumbnail: NSImage?
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail with modern overlay
            ZStack(alignment: .topTrailing) {
                Group {
                    if let thumbnail = thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 150, maxHeight: 150)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.gray.opacity(0.15), Color.gray.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 150)
                            .overlay(
                                ProgressView()
                                    .controlSize(.small)
                            )
                    }
                }
                
                // Hover overlay with actions
                if isHovering {
                    VStack {
                        Spacer()
                        
                        HStack(spacing: 10) {
                            // View button
                            Button(action: { NSWorkspace.shared.open(fileURL) }) {
                                Image(systemName: "eye.fill")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.6))
                                            .overlay(
                                                Circle()
                                                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                            .help("View")
                            
                            // Edit button
                            Button(action: onEdit) {
                                Image(systemName: "pencil")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(Color.blue.opacity(0.8))
                                            .overlay(
                                                Circle()
                                                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                            .help("Edit")
                            
                            // Delete button
                            Button(action: deleteFile) {
                                Image(systemName: "trash.fill")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(Color.red.opacity(0.85))
                                            .overlay(
                                                Circle()
                                                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                            .help("Delete")
                            
                            Spacer()
                        }
                        .padding(12)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.5)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                    .transition(.opacity)
                }
            }
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isHovering ? Color.accentColor.opacity(0.5) : Color.clear,
                        lineWidth: 2
                    )
            )
            .shadow(
                color: isHovering ? Color.black.opacity(0.2) : Color.black.opacity(0.08),
                radius: isHovering ? 12 : 6,
                x: 0,
                y: isHovering ? 8 : 4
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
            }
            
            // File info
            VStack(alignment: .leading, spacing: 6) {
                Text(fileURL.lastPathComponent)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(formatFileDate())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 10)
            .padding(.horizontal, 4)
        }
        .onAppear {
            loadThumbnail()
        }
        .contextMenu {
            Button("Open") {
                NSWorkspace.shared.open(fileURL)
            }
            
            Button("Edit") {
                onEdit()
            }
            
            Divider()
            
            Button("Copy") {
                if let image = NSImage(contentsOf: fileURL) {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.writeObjects([image])
                }
            }
            
            Button("Show in Finder") {
                NSWorkspace.shared.selectFile(fileURL.path, inFileViewerRootedAtPath: fileURL.deletingLastPathComponent().path)
            }
            
            Divider()
            
            Button("Delete", role: .destructive) {
                deleteFile()
            }
        }
    }
    
    private func loadThumbnail() {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let image = NSImage(contentsOf: fileURL) else { return }
            
            let thumbnailSize = NSSize(width: 300, height: 225)
            let thumbnail = image.resized(to: thumbnailSize)
            
            DispatchQueue.main.async {
                self.thumbnail = thumbnail
            }
        }
    }
    
    private func formatFileDate() -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            if let creationDate = attributes[.creationDate] as? Date {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .abbreviated
                return formatter.localizedString(for: creationDate, relativeTo: Date())
            }
        } catch {
            print("Error getting file attributes: \(error)")
        }
        return ""
    }
    
    private func deleteFile() {
        do {
            try FileManager.default.removeItem(at: fileURL)
            print("[DEL] Deleted file: \(fileURL.path)")
            onDeleted()
        } catch {
            print("[ERR] Failed to delete file: \(error)")
        }
    }
}

// MARK: - Settings Group View
struct SettingsGroupView<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Group header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [iconColor.opacity(0.2), iconColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            // Group content
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Section Header View
struct SectionHeaderView: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
        }
    }
}

// MARK: - Option Card Button
struct OptionCardButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .accentColor)
                    .frame(width: 24)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isSelected ?
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.clear : Color.primary.opacity(0.1),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let badge: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let badge = badge {
                    Image(systemName: badge)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tip Row
struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.accentColor.opacity(0.8))
                .frame(width: 16)
            
            Text(text)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - NSImage Extension
extension NSImage {
    func resized(to targetSize: NSSize) -> NSImage {
        let newImage = NSImage(size: targetSize)
        newImage.lockFocus()
        defer { newImage.unlockFocus() }
        
        let sourceRatio = size.width / size.height
        let targetRatio = targetSize.width / targetSize.height
        
        var drawRect: NSRect
        
        if sourceRatio > targetRatio {
            let newWidth = targetSize.height * sourceRatio
            drawRect = NSRect(
                x: (targetSize.width - newWidth) / 2,
                y: 0,
                width: newWidth,
                height: targetSize.height
            )
        } else {
            let newHeight = targetSize.width / sourceRatio
            drawRect = NSRect(
                x: 0,
                y: (targetSize.height - newHeight) / 2,
                width: targetSize.width,
                height: newHeight
            )
        }
        
        draw(in: drawRect, from: NSRect(origin: .zero, size: size), operation: .sourceOver, fraction: 1.0)
        return newImage
    }
}



#Preview {
    ScreenshotBrowserView()
        .modelContainer(for: Item.self, inMemory: true)
}

