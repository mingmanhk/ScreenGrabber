//
//  ScreenshotGridItem.swift
//  ScreenGrabber
//
//  Created by Victor Lam on 10/23/25.
//

import SwiftUI
import AppKit

struct ScreenshotGridItem: View {
    let fileURL: URL
    let onEdit: () -> Void
    
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
                            VStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Loading...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
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
                        
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.blue.opacity(0.8))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Edit")
                        
                        Button(action: { shareFile() }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.green.opacity(0.8))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Share")
                        
                        Spacer()
                        
                        Button(action: { deleteFile() }) {
                            Image(systemName: "trash")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.red.opacity(0.8))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Delete")
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
                    .help(fileURL.lastPathComponent)
                
                HStack {
                    Text(formatFileDate())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(formatFileSize())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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
            
            Button("Edit") {
                onEdit()
            }
            
            Divider()
            
            Button("Show in Finder") {
                NSWorkspace.shared.selectFile(fileURL.path, inFileViewerRootedAtPath: fileURL.deletingLastPathComponent().path)
            }
            
            Button("Share") {
                shareFile()
            }
            
            Divider()
            
            Button("Delete") {
                deleteFile()
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
    
    private func formatFileSize() -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            if let fileSize = attributes[.size] as? Int64 {
                return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
            }
        } catch {
            print("Error getting file size: \(error)")
        }
        return ""
    }
    
    private func shareFile() {
        let sharingServicePicker = NSSharingServicePicker(items: [fileURL])
        if let view = NSApp.keyWindow?.contentView {
            sharingServicePicker.show(relativeTo: NSRect(x: 0, y: 0, width: 1, height: 1), of: view, preferredEdge: .minY)
        }
    }
    
    private func deleteFile() {
        let alert = NSAlert()
        alert.messageText = "Delete Screenshot"
        alert.informativeText = "Are you sure you want to move this screenshot to the Trash? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            do {
                try FileManager.default.trashItem(at: fileURL, resultingItemURL: nil)
            } catch {
                print("Error deleting file: \(error)")
                
                // Show error alert
                let errorAlert = NSAlert()
                errorAlert.messageText = "Delete Failed"
                errorAlert.informativeText = "Could not delete the screenshot: \(error.localizedDescription)"
                errorAlert.alertStyle = .critical
                errorAlert.runModal()
            }
        }
    }
}

