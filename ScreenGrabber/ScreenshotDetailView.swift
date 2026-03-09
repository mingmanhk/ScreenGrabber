//
//  ScreenshotDetailView.swift
//  ScreenGrabber
//
//  Detailed view for a single screenshot
//

import SwiftUI

struct ScreenshotDetailView: View {
    let screenshot: Screenshot
    @Environment(\.dismiss) private var dismiss
    @State private var image: NSImage?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(screenshot.filename)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(formatDate(screenshot.captureDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Image
            ScrollView([.horizontal, .vertical]) {
                if let image = image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color(NSColor.textBackgroundColor))
            
            Divider()
            
            // Actions
            HStack(spacing: 12) {
                Button {
                    EditorWindowHelper.shared.openEditor(for: screenshot)
                    dismiss()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                
                Button {
                    if let image = image {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.writeObjects([image])
                    }
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                
                Button {
                    NSWorkspace.shared.selectFile(screenshot.filePath, inFileViewerRootedAtPath: "")
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }
                
                Spacer()
                
                // Info
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(screenshot.width) × \(screenshot.height)")
                        .font(.caption)
                    Text(captureTypeDisplayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 800, height: 600)
        .task {
            await loadImage()
        }
    }
    
    private var captureTypeDisplayName: String {
        guard let type = CaptureType(rawValue: screenshot.captureType) else {
            return screenshot.captureType
        }
        return type.displayName
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func loadImage() async {
        if let loadedImage = NSImage(contentsOf: screenshot.fileURL) {
            await MainActor.run {
                self.image = loadedImage
            }
        }
    }
}

#Preview {
    ScreenshotDetailView(
        screenshot: Screenshot(
            filename: "Screenshot_2024-01-11_10-30-00.png",
            filePath: "/tmp/test.png",
            captureType: "area",
            width: 1920,
            height: 1080
        )
    )
}
