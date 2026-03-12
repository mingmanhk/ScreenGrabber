//
//  RecentCapturesStrip.swift
//  ScreenGrabber
//
//  Bottom strip showing recent screenshots
//  Created by Victor Lam on 1/5/26.
//

import SwiftUI
import AppKit
import Quartz

/// Bottom horizontal strip displaying recent captures as thumbnails
struct RecentCapturesStrip: View {
    let currentImageURL: URL
    let onSelectImage: (URL) -> Void
    
    @State private var recentImages: [URL] = []
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Recent Captures", systemImage: "photo.stack")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                
                Spacer()
                
                Button(action: openScreenshotsFolder) {
                    Label("Show All", systemImage: "folder")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .padding(.trailing, 12)
                .padding(.top, 8)
            }
            
            Divider()
                .padding(.top, 8)
            
            // Thumbnails
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if isLoading {
                        ForEach(0..<5) { _ in
                            ThumbnailPlaceholder()
                        }
                    } else if recentImages.isEmpty {
                        Text("No recent captures")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(recentImages, id: \.self) { imageURL in
                            ThumbnailView(
                                imageURL: imageURL,
                                isSelected: imageURL == currentImageURL,
                                onSelect: {
                                    onSelectImage(imageURL)
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .onAppear {
            loadRecentImages()
        }
    }
    
    private func loadRecentImages() {
        isLoading = true
        Task { @MainActor in
            if let folder = await UnifiedCaptureManager.shared.getCapturesFolderURL() {
                let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles])) ?? []
                let images = files.filter { ["png", "jpg"].contains($0.pathExtension.lowercased()) }
                    .sorted { (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate ?? .distantPast)! > (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? .distantPast)! }
                self.recentImages = images
            } else {
                self.recentImages = []
            }
            self.isLoading = false
        }
    }
    
    private func openScreenshotsFolder() {
        Task { @MainActor in
            if let folderURL = await UnifiedCaptureManager.shared.getCapturesFolderURL() {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folderURL.path)
            }
        }
    }
}

// MARK: - Thumbnail View
struct ThumbnailView: View {
    let imageURL: URL
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var thumbnail: NSImage?
    @State private var isHovering = false
    @State private var showingPreview = false
    @State private var hoverTask: Task<Void, Never>?
    
    var body: some View {
        VStack(spacing: 4) {
            // Thumbnail image
            ZStack {
                if let thumbnail = thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 80)
                        .clipped()
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(borderColor, lineWidth: isSelected ? 3 : 1)
                        )
                        .shadow(color: .black.opacity(isHovering ? 0.3 : 0.1), radius: 4, x: 0, y: 2)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 120, height: 80)
                        .cornerRadius(8)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.7)
                        )
                }
            }
            .scaleEffect(isHovering ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovering)
            
            // Filename
            Text(imageURL.lastPathComponent)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: 120)
        }
        .popover(isPresented: $showingPreview, arrowEdge: .top) {
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 320, maxHeight: 240)
                    .padding(8)
            }
        }
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovering = hovering
            hoverTask?.cancel()
            if hovering {
                hoverTask = Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
                    if !Task.isCancelled {
                        showingPreview = true
                    }
                }
            } else {
                showingPreview = false
            }
        }
        .task(id: imageURL) {
            if let cached = ThumbnailCache.shared.thumbnail(for: imageURL) {
                thumbnail = cached
            } else {
                thumbnail = await ThumbnailCache.shared.load(url: imageURL, maxPixelSize: 240)
            }
        }
        .contextMenu {
            ThumbnailContextMenu(imageURL: imageURL)
        }
    }

    private var borderColor: Color {
        if isSelected {
            return .accentColor
        } else if isHovering {
            return .primary.opacity(0.3)
        } else {
            return .primary.opacity(0.1)
        }
    }
}

// MARK: - Thumbnail Placeholder
struct ThumbnailPlaceholder: View {
    var body: some View {
        VStack(spacing: 4) {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 120, height: 80)
                .cornerRadius(8)
            
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 100, height: 10)
                .cornerRadius(4)
        }
    }
}

// MARK: - Context Menu
struct ThumbnailContextMenu: View {
    let imageURL: URL
    
    var body: some View {
        Button("Open in Editor") {
            ScreenCaptureEditor.open(imageURL: imageURL)
        }
        
        Button("Show in Finder") {
            NSWorkspace.shared.selectFile(imageURL.path, inFileViewerRootedAtPath: imageURL.deletingLastPathComponent().path)
        }
        
        Button("Copy") {
            if let image = NSImage(contentsOf: imageURL) {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.writeObjects([image])
            }
        }
        
        Divider()
        
        Button("Quick Look") {
            QuickLookCoordinator.shared.show(url: imageURL)
        }
        
        Divider()
        
        Button("Move to Trash", role: .destructive) {
            moveToTrash()
        }
    }
    
    private func moveToTrash() {
        do {
            ThumbnailCache.shared.invalidate(url: imageURL)
            try FileManager.default.trashItem(at: imageURL, resultingItemURL: nil)
            CaptureLogger.log(.capture, "Moved to trash: \(imageURL.lastPathComponent)", level: .success)
            NotificationCenter.default.post(name: .screenshotCaptured, object: nil)
            ScreenCaptureManager.shared.showNotification(
                title: "Moved to Trash",
                message: imageURL.lastPathComponent
            )
        } catch {
            CaptureLogger.log(.error, "Failed to trash item: \(error.localizedDescription)", level: .error)
            ScreenCaptureManager.shared.showNotification(
                title: "Error",
                message: "Could not move file to trash"
            )
        }
    }
}

// MARK: - Quick Look Coordinator
final class QuickLookCoordinator: NSObject, QLPreviewPanelDataSource {
    static let shared = QuickLookCoordinator()

    private var urls: [URL] = []

    func show(url: URL) {
        urls = [url]
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.reloadData()
        if panel.isVisible {
            panel.reloadData()
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { urls.count }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        urls[index] as NSURL
    }
}

// MARK: - Preview
struct RecentCapturesStrip_Previews: PreviewProvider {
    static var previews: some View {
        RecentCapturesStrip(
            currentImageURL: URL(fileURLWithPath: "/tmp/test.png"),
            onSelectImage: { _ in }
        )
        .frame(height: 100)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
