//
//  ContentView.swift
//  ScreenGrabber
//
//  Created by Victor Lam on 10/23/25.
//

import SwiftUI
import SwiftData
import AppKit

// Lightweight blur wrapper for macOS
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var recentScreenshots: [URL] = []
    @State private var selectedScreenOption: ScreenOption = .selectedArea
    @State private var selectedOpenOption: OpenOption = .clipboard
    @State private var showingImageEditor = false
    @State private var selectedImageURL: URL?
    
    var body: some View {
        NavigationSplitView {
            // Sidebar with settings
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "camera.viewfinder")
                        .font(.title)
                        .foregroundColor(.accentColor)
                    
                    Text("Screen Grabber")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("\(recentScreenshots.count) screenshots")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                Divider()
                
                // Settings
                VStack(alignment: .leading, spacing: 16) {
                    Text("Capture Settings")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    // Screen method
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Screen Method")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        VStack(spacing: 4) {
                            ForEach(ScreenOption.allCases, id: \.self) { option in
                                Button(action: {
                                    selectedScreenOption = option
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
                                    .padding(.horizontal, 16)
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
                        .padding(.horizontal)
                    }
                    
                    // Output method
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Output Method")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        VStack(spacing: 4) {
                            ForEach(OpenOption.allCases, id: \.self) { option in
                                Button(action: {
                                    selectedOpenOption = option
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
                                    .padding(.horizontal, 16)
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
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
                
                // Folder access
                Button(action: openScreenGrabberFolder) {
                    HStack {
                        Image(systemName: "folder")
                        Text("Open Screenshots Folder")
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .frame(minWidth: 280)
            .background(Color(NSColor.controlBackgroundColor))
            
        } detail: {
            // Main screenshots view
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Screenshots")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button(action: loadRecentScreenshots) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .help("Refresh")
                    }
                    .padding()
                    
                    Divider()
                    
                    if recentScreenshots.isEmpty {
                        // Empty state
                        VStack(spacing: 20) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 80))
                                .foregroundColor(.secondary)
                            
                            Text("No Screenshots Yet")
                                .font(.title)
                                .fontWeight(.semibold)
                            
                            Text("Capture your first screenshot to get started!")
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button(action: captureScreen) {
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
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Screenshots grid
                        ScrollView {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 3), spacing: 20) {
                                ForEach(recentScreenshots, id: \.self) { fileURL in
                                    ScreenshotGridView(
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
                
                // Floating bottom action bar
                HStack {
                    Button(action: captureScreen) {
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

                    // Optional: quick refresh on the right
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
        .onAppear {
            // Test file system access on first load
            ScreenCaptureManager.shared.testFileSystemAccess()
            loadRecentScreenshots()
        }
        .sheet(isPresented: $showingImageEditor) {
            if let url = selectedImageURL {
                BasicImageEditorView(imageURL: url)
            }
        }
    }
    
    private func captureScreen() {
        ScreenCaptureManager.shared.captureScreen(
            method: selectedScreenOption,
            openOption: selectedOpenOption,
            modelContext: modelContext
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            loadRecentScreenshots()
        }
    }
    
    private func loadRecentScreenshots() {
        recentScreenshots = ScreenCaptureManager.shared.loadRecentScreenshots()
    }
    
    private func openScreenGrabberFolder() {
        let folderURL = ScreenCaptureManager.shared.getScreenGrabberFolderURL()
        NSWorkspace.shared.open(folderURL)
    }
}

// MARK: - Screenshot Grid Item
struct ScreenshotGridView: View {
    let fileURL: URL
    let onEdit: () -> Void
    let onDeleted: () -> Void
    
    @State private var thumbnail: NSImage?
    @State private var showingHover = false
    
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
                // Hover overlay
                VStack {
                    Spacer()
                    HStack {
                        Button(action: { NSWorkspace.shared.open(fileURL) }) {
                            Image(systemName: "eye")
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: deleteFile) {
                            Image(systemName: "trash")
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
                .opacity(showingHover ? 1 : 0)
                .cornerRadius(8)
            )
            .onHover { isHovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingHover = isHovering
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
            let thumbnail = resizeImage(image, to: thumbnailSize)
            
            DispatchQueue.main.async {
                self.thumbnail = thumbnail
            }
        }
    }
    
    private func resizeImage(_ image: NSImage, to targetSize: NSSize) -> NSImage {
        let newImage = NSImage(size: targetSize)
        newImage.lockFocus()
        defer { newImage.unlockFocus() }
        
        let sourceRatio = image.size.width / image.size.height
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
        
        image.draw(in: drawRect, from: NSRect(origin: .zero, size: image.size), operation: .sourceOver, fraction: 1.0)
        return newImage
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

// MARK: - Basic Image Editor
struct BasicImageEditorView: View {
    let imageURL: URL
    @State private var image: NSImage?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Simple toolbar
            HStack {
                Text("Image Editor")
                    .font(.headline)
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Image display
            if let image = image {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ProgressView("Loading image...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        image = NSImage(contentsOf: imageURL)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

