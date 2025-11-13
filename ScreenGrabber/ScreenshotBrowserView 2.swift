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
    
    var filteredScreenshots: [URL] {
        if searchText.isEmpty {
            return recentScreenshots
        }
        return recentScreenshots.filter { url in
            url.lastPathComponent.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "camera.viewfinder")
                            .font(.largeTitle)
                            .foregroundColor(.accentColor)
                        
                        VStack(alignment: .leading) {
                            Text("Screen Grabber")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("\(recentScreenshots.count) screenshots")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Quick capture button removed as per instructions
                }
                
                Divider()
                
                // Settings Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Capture Settings")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    // Screen method
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Screen Method")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 4) {
                            ForEach(ScreenOption.allCases, id: \.self) { option in
                                Button(action: {
                                    selectedScreenOption = option
                                    UserDefaults.standard.set(option.rawValue, forKey: "selectedScreenOption")
                                }) {
                                    HStack {
                                        Image(systemName: option.icon)
                                            .frame(width: 20)
                                        Text(option.displayName)
                                        Spacer()
                                        if selectedScreenOption == option {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.accentColor)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        selectedScreenOption == option ? Color.accentColor.opacity(0.1) : Color.clear
                                    )
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.primary)
                            }
                        }
                    }
                    
                    // Output method
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Output Method")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 4) {
                            ForEach(OpenOption.allCases, id: \.self) { option in
                                Button(action: {
                                    selectedOpenOption = option
                                    UserDefaults.standard.set(option.rawValue, forKey: "selectedOpenOption")
                                }) {
                                    HStack {
                                        Image(systemName: option.icon)
                                            .frame(width: 20)
                                        Text(option.displayName)
                                        Spacer()
                                        if selectedOpenOption == option {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.accentColor)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        selectedOpenOption == option ? Color.accentColor.opacity(0.1) : Color.clear
                                    )
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.primary)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Hotkey settings
                    Button(action: { showHotkeySheet = true }) {
                        HStack {
                            Image(systemName: "keyboard")
                                .frame(width: 20)
                            VStack(alignment: .leading) {
                                Text("Global Hotkey")
                                    .fontWeight(.medium)
                                Text(currentHotkey)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.primary)
                    .sheet(isPresented: $showHotkeySheet) {
                        HotkeyConfigView(currentHotkey: $currentHotkey) { newHotkey in
                            setupGlobalHotkey(hotkey: newHotkey)
                        }
                    }
                    
                    // Folder access
                    Button(action: openScreenGrabberFolder) {
                        HStack {
                            Image(systemName: "folder")
                                .frame(width: 20)
                            VStack(alignment: .leading) {
                                Text("Screenshots Folder")
                                    .fontWeight(.medium)
                                Text("Open in Finder")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Tips section
                VStack(alignment: .leading, spacing: 8) {
                    Text("💡 Tips")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                    
                    Text("• Use menu bar for quick access")
                    Text("• Double-click to edit screenshots")
                    Text("• Right-click for more options")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
            }
            .padding()
            .frame(minWidth: 300)
            .background(Color(NSColor.controlBackgroundColor))
            
        } detail: {
            // Main content with added bottom action bar
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // Toolbar
                    HStack {
                        // Search
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            
                            TextField("Search screenshots...", text: $searchText)
                                .textFieldStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        .frame(maxWidth: 300)
                        
                        Spacer()
                        
                        Button(action: loadRecentScreenshots) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .help("Refresh")
                    }
                    .padding()
                    .background(Color(NSColor.windowBackgroundColor))
                    
                    Divider()
                    
                    // Screenshots grid
                    if filteredScreenshots.isEmpty {
                        // Empty state
                        VStack(spacing: 20) {
                            if recentScreenshots.isEmpty {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 80))
                                    .foregroundColor(.secondary)
                                
                                Text("No Screenshots Yet")
                                    .font(.title)
                                    .fontWeight(.semibold)
                                
                                Text("Capture your first screenshot to get started!")
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Button(action: quickCapture) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "camera.fill")
                                            .font(.headline)
                                        Text("Capture Screenshot")
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule()
                                            .fill(LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 6)
                                    )
                                }
                                .buttonStyle(.plain)
                            } else {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary)
                                
                                Text("No Results Found")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                Text("Try a different search term")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Screenshots grid
                        ScrollView {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 4), spacing: 20) {
                                ForEach(filteredScreenshots, id: \.self) { fileURL in
                                    SimpleScreenshotItem(
                                        fileURL: fileURL,
                                        onEdit: {
                                            selectedImageURL = fileURL
                                            showingImageEditor = true
                                        },
                                        onDeleted: {
                                            if let idx = recentScreenshots.firstIndex(of: fileURL) {
                                                recentScreenshots.remove(at: idx)
                                            }
                                        }
                                    )
                                }
                            }
                            .padding()
                        }
                    }
                }
                
                HStack {
                    Button(action: quickCapture) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [Color.white.opacity(0.25), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "camera.fill")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            Text("Capture")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(
                            Capsule(style: .continuous)
                                .fill(LinearGradient(colors: [Color.accentColor.opacity(0.98), Color.accentColor.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .shadow(color: Color.black.opacity(0.25), radius: 14, x: 0, y: 10)
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)

                    Button(action: loadRecentScreenshots) {
                        Image(systemName: "arrow.clockwise")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(10)
                            .background(
                                Circle().fill(Color(NSColor.controlBackgroundColor))
                                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 4)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08))
                        )
                        .padding(.horizontal, 12)
                )
                .padding(.bottom, 16)
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
    
    // MARK: - Actions
    
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
    
    private func setupGlobalHotkey(hotkey: String) {
        UserDefaults.standard.set(hotkey, forKey: "grabScreenHotkey")
        currentHotkey = hotkey
        
        GlobalHotkeyManager.shared.registerHotkey(hotkey) {
            DispatchQueue.main.async {
                self.quickCapture()
            }
        }
    }
    
    private func openScreenGrabberFolder() {
        let folderURL = ScreenCaptureManager.shared.getScreenGrabberFolderURL()
        NSWorkspace.shared.open(folderURL)
    }
}

// MARK: - Simple Screenshot Item
struct SimpleScreenshotItem: View {
    let fileURL: URL
    let onEdit: () -> Void
    let onDeleted: () -> Void
    
    @State private var thumbnail: NSImage?
    @State private var showingContextMenu = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            Group {
                if let thumbnail = thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 200, height: 150)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 200, height: 150)
                        .cornerRadius(8)
                        .overlay(
                            ProgressView()
                                .controlSize(.small)
                        )
                }
            }
            .overlay(
                // Hover overlay with actions
                VStack {
                    Spacer()
                    HStack {
                        Button(action: { NSWorkspace.shared.open(fileURL) }) {
                            Image(systemName: "eye")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("View")
                        
                        Button(action: deleteFile) {
                            Image(systemName: "trash")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.red.opacity(0.85))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Delete")
                        
                        Spacer()
                    }
                    .padding(8)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.4)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .opacity(showingContextMenu ? 1 : 0)
                .cornerRadius(8)
            )
            .onHover { isHovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingContextMenu = isHovering
                }
            }
            
            // File info
            VStack(alignment: .leading, spacing: 4) {
                Text(fileURL.lastPathComponent)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(formatFileDate())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 200, alignment: .leading)
        }
        .onAppear {
            loadThumbnail()
        }
        .contextMenu {
            Button("Open") {
                NSWorkspace.shared.open(fileURL)
            }
            
            Button("Delete") {
                deleteFile()
            }
            
            Button("Show in Finder") {
                NSWorkspace.shared.selectFile(fileURL.path, inFileViewerRootedAtPath: fileURL.deletingLastPathComponent().path)
            }
        }
    }
    
    private func loadThumbnail() {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let image = NSImage(contentsOf: fileURL) else { return }
            
            let thumbnailSize = NSSize(width: 200, height: 150)
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



#Preview {
    ScreenshotBrowserView()
        .modelContainer(for: Item.self, inMemory: true)
}
