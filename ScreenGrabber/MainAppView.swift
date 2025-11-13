//
//  MainAppView.swift
//  ScreenGrabber
//
//  Created by Victor Lam on 10/23/25.
//

import SwiftUI
import SwiftData

struct MainAppView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Screenshot.captureDate, order: .reverse) private var screenshots: [Screenshot]
    
    @State private var selectedScreenOption: ScreenOption = .selectedArea
    @State private var selectedOpenOption: OpenOption = .clipboard
    @State private var showHotkeySheet = false
    @State private var currentHotkey = "⌘⇧C"
    @State private var recentScreenshots: [URL] = []
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "camera.viewfinder")
                            .font(.largeTitle)
                            .foregroundColor(.accentColor)
                        
                        VStack(alignment: .leading) {
                            Text("Screen Grabber")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("Capture & Save Screenshots")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                
                Divider()
                
                // Quick Capture Section
                VStack(alignment: .leading, spacing: 12) {
                    Label("Quick Capture", systemImage: "bolt.fill")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                    
                    Button(action: { quickCapture() }) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.accentColor, Color.pink.opacity(0.9)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 44, height: 44)
                                    .shadow(color: Color.accentColor.opacity(0.35), radius: 8, x: 0, y: 6)

                                Image(systemName: "camera.aperture")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.white)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Grab Screen Now")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Text("Using current settings")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.85))
                            }

                            Spacer()
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.accentColor, Color.pink.opacity(0.9)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: Color.accentColor.opacity(0.25), radius: 10, x: 0, y: 8)
                        )
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                
                Divider()
                
                // Settings Section
                VStack(alignment: .leading, spacing: 12) {
                    Label("Settings", systemImage: "gear")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                    
                    Button(action: { showHotkeySheet = true }) {
                        HStack {
                            Image(systemName: "keyboard")
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
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.primary)
                    .sheet(isPresented: $showHotkeySheet) {
                        MenuBarContentView.HotkeyConfigView(currentHotkey: $currentHotkey, onSave: setupGlobalHotkey)
                    }
                    
                    Button(action: { openScreenGrabberFolder() }) {
                        HStack {
                            Image(systemName: "folder")
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
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.primary)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Menu bar note
                VStack(alignment: .leading, spacing: 8) {
                    Text("💡 Tip")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                    
                    Text("This app also runs in your menu bar for quick access!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.1))
                )
                .padding(.horizontal)
                .padding(.bottom)
            }
            .frame(minWidth: 280)
            
        } detail: {
            // Main content area
            VStack(spacing: 20) {
                // Capture Options
                VStack(alignment: .leading, spacing: 16) {
                    Text("Capture Options")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    // Screen capture method
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Screen Method")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            ForEach(ScreenOption.allCases, id: \.self) { option in
                                ScreenOptionCard(
                                    option: option,
                                    isSelected: selectedScreenOption == option,
                                    action: {
                                        selectedScreenOption = option
                                        UserDefaults.standard.set(option.rawValue, forKey: "selectedScreenOption")
                                    }
                                )
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Output method
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Output Method")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                            ForEach(OpenOption.allCases, id: \.self) { option in
                                OpenOptionCard(
                                    option: option,
                                    isSelected: selectedOpenOption == option,
                                    action: {
                                        selectedOpenOption = option
                                        UserDefaults.standard.set(option.rawValue, forKey: "selectedOpenOption")
                                    }
                                )
                            }
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                
                // Recent Screenshots
                if !recentScreenshots.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Recent Screenshots")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 12) {
                                ForEach(recentScreenshots.prefix(10), id: \.self) { fileURL in
                                    ScreenshotThumbnail(fileURL: fileURL)
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Screen Grabber")
        .onAppear {
            loadSettings()
            loadRecentScreenshots()
        }
    }
}

// MARK: - Custom Views

struct ScreenOptionCard: View {
    let option: ScreenOption
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: option.icon)
                    .font(.largeTitle)
                    .foregroundColor(isSelected ? .white : .accentColor)
                
                VStack(spacing: 4) {
                    Text(option.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(option.shortcut)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor, lineWidth: isSelected ? 0 : 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct OpenOptionCard: View {
    let option: OpenOption
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: option.icon)
                    .font(.title)
                    .foregroundColor(isSelected ? .white : .accentColor)
                
                Text(option.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor, lineWidth: isSelected ? 0 : 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ScreenshotThumbnail: View {
    let fileURL: URL
    @State private var thumbnail: NSImage?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let thumbnail = thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                        )
                }
            }
            .frame(width: 120, height: 80)
            .cornerRadius(8)
            .clipped()
            
            VStack(alignment: .leading, spacing: 2) {
                Text(fileURL.lastPathComponent)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(formatFileDate())
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 120, alignment: .leading)
        }
        .onTapGesture {
            NSWorkspace.shared.open(fileURL)
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        DispatchQueue.global(qos: .background).async {
            if let image = NSImage(contentsOf: fileURL) {
                let thumbnailSize = NSSize(width: 120, height: 80)
                let thumbnail = image.resizedForThumbnail(to: thumbnailSize)
                
                DispatchQueue.main.async {
                    self.thumbnail = thumbnail
                }
            }
        }
    }
    
    private func formatFileDate() -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            if let creationDate = attributes[.creationDate] as? Date {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                formatter.dateStyle = .short
                return formatter.string(from: creationDate)
            }
        } catch {
            print("Error getting file attributes: \(error)")
        }
        return ""
    }
}

// MARK: - Type Extensions
extension ScreenOption {
    var shortcut: String {
        switch self {
        case .selectedArea:
            return "⌘⇧4"
        case .window:
            return "⌘⇧4, then Space"
        case .fullScreen:
            return "⌘⇧3"
        case .scrollingCapture:
            return "Custom Action"
        }
    }
}

// MARK: - Actions Extension

extension MainAppView {
    
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

// MARK: - NSImage Extension

// Note: Named uniquely to avoid duplicate extensions across the project.
extension NSImage {
    func resizedForThumbnail(to targetSize: NSSize) -> NSImage {
        let newImage = NSImage(size: targetSize)
        newImage.lockFocus()
        draw(in: NSRect(origin: .zero, size: targetSize))
        newImage.unlockFocus()
        return newImage
    }
}

#Preview {
    MainAppView()
        .modelContainer(for: Screenshot.self, inMemory: true)
}
