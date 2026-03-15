//
//  ScreenshotThumbnailView.swift
//  ScreenGrabber
//
//  Individual thumbnail card for screenshots
//

import SwiftUI
import SwiftData

struct ScreenshotThumbnailView: View {
    let screenshot: Screenshot
    @Environment(\.modelContext) private var modelContext
    @State private var thumbnail: NSImage?
    @State private var isHovered = false
    @State private var showDeleteConfirmation = false
    @State private var showFirstTimeDeleteWarning = !UserDefaults.standard.bool(forKey: "hasSeenThumbnailDeleteWarning")
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail image
            ZStack {
                if let thumbnail = thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 150)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    Rectangle()
                        .fill(Color(NSColor.controlBackgroundColor))
                        .frame(height: 150)
                        .cornerRadius(8)
                        .overlay {
                            ProgressView()
                        }
                }
                
                // Hover overlay
                if isHovered {
                    Color.black.opacity(0.3)
                        .cornerRadius(8)
                    
                    HStack(spacing: 12) {
                        Button {
                            EditorWindowHelper.shared.openEditor(for: screenshot)
                        } label: {
                            Image(systemName: "pencil")
                                .font(.title3)
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            NSWorkspace.shared.selectFile(screenshot.filePath, inFileViewerRootedAtPath: "")
                        } label: {
                            Image(systemName: "folder")
                                .font(.title3)
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            if showFirstTimeDeleteWarning {
                                showFirstTimeDeleteWarning = false
                                UserDefaults.standard.set(true, forKey: "hasSeenThumbnailDeleteWarning")
                            }
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.title3)
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
            
            // Metadata
            VStack(alignment: .leading, spacing: 4) {
                Text(screenshot.filename)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: captureTypeIcon)
                        .font(.system(size: 10))
                    Text(formatDate(screenshot.captureDate))
                        .font(.system(size: 10))
                    Spacer()
                    Text("\(screenshot.width) × \(screenshot.height)")
                        .font(.system(size: 10))
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .task {
            await loadThumbnail()
        }
        .alert("Move to Trash?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Move to Trash", role: .destructive) {
                Task {
                    // Delete the screenshot using CaptureHistoryStore
                    _ = await CaptureHistoryStore.shared.deleteCapture(screenshot, from: modelContext)
                }
            }
        }
        .alert("First Time Delete Warning", isPresented: $showFirstTimeDeleteWarning) {
            Button("OK") {
                showFirstTimeDeleteWarning = false
                UserDefaults.standard.set(true, forKey: "hasSeenThumbnailDeleteWarning")
                showDeleteConfirmation = true
            }
        } message: {
            Text("Deleting a capture will move the file to Trash.")
        }
    }
    
    private var captureTypeIcon: String {
        guard let type = CaptureType(rawValue: screenshot.captureType) else {
            return "photo"
        }
        return type.icon
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func loadThumbnail() async {
        // Try to load thumbnail data first
        if let thumbnailData = screenshot.thumbnailData,
           let image = NSImage(data: thumbnailData) {
            await MainActor.run {
                self.thumbnail = image
            }
            return
        }
        
        // Try thumbnail path if available
        if let thumbnailPath = screenshot.thumbnailPath,
           let image = NSImage(contentsOf: URL(fileURLWithPath: thumbnailPath)) {
            await MainActor.run {
                self.thumbnail = image
            }
            return
        }
        
        // Fall back to original image
        if let image = NSImage(contentsOf: screenshot.fileURL) {
            await MainActor.run {
                self.thumbnail = image
            }
        }
    }
}

#Preview {
    ScreenshotThumbnailView(
        screenshot: Screenshot(
            filename: "Screenshot_2024-01-11_10-30-00.png",
            filePath: "/tmp/test.png",
            captureType: "area",
            width: 1920,
            height: 1080
        )
    )
    .frame(width: 200)
}
