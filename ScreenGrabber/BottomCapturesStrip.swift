//
//  BottomCapturesStrip.swift
//  ScreenGrabber
//
//  Horizontal strip of recent capture thumbnails at the bottom of the Library window.
//

import SwiftUI
import AppKit

struct BottomCapturesStrip: View {
    let recentScreenshots: [URL]
    var onEdit: (URL) -> Void
    var onRefresh: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            header
            Divider()
            thumbnailStrip
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "photo.stack")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)

                Text("Recent Captures")
                    .font(.system(size: 13, weight: .semibold))

                Text("\(recentScreenshots.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor))
            }
            .padding(.leading, 20)

            Spacer()

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 28, height: 28)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Refresh captures")
            .padding(.trailing, 20)
        }
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }

    @ViewBuilder
    private var thumbnailStrip: some View {
        if recentScreenshots.isEmpty {
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                    Text("No recent captures")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 20)
                Spacer()
            }
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recentScreenshots, id: \.self) { url in
                        ThumbnailCard(fileURL: url, onEdit: { onEdit(url) })
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .frame(height: 120)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        }
    }
}

// MARK: - Thumbnail Card

struct ThumbnailCard: View {
    let fileURL: URL
    let onEdit: () -> Void

    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AsyncThumbnail(url: fileURL, maxPixelSize: 200, contentMode: .fill)
                .frame(width: 100, height: 90)
                .clipped()
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.gray.opacity(0.2), lineWidth: 1))

            if isHovering {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.55))
                    HStack(spacing: 8) {
                        ActionIconButton(icon: "eye.fill",  color: .accentColor) { NSWorkspace.shared.open(fileURL) }
                        ActionIconButton(icon: "pencil",    color: .purple)      { onEdit() }
                        ActionIconButton(icon: "trash.fill", color: .red)        { deleteFile() }
                    }
                }
                .frame(width: 100, height: 90)
                .transition(.opacity)
            }
        }
        .onHover { hovering in withAnimation(.easeInOut(duration: 0.15)) { isHovering = hovering } }
        .contextMenu {
            Button("Open")          { NSWorkspace.shared.open(fileURL) }
            Button("Edit")          { onEdit() }
            Divider()
            Button("Show in Finder") {
                NSWorkspace.shared.selectFile(fileURL.path,
                                              inFileViewerRootedAtPath: fileURL.deletingLastPathComponent().path)
            }
            Button("Copy") {
                if let image = NSImage(contentsOf: fileURL) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.writeObjects([image])
                }
            }
            Divider()
            Button("Move to Trash", role: .destructive) { deleteFile() }
        }
    }

    private func deleteFile() {
        ThumbnailCache.shared.invalidate(url: fileURL)
        do {
            try FileManager.default.trashItem(at: fileURL, resultingItemURL: nil)
        } catch {
            CaptureLogger.log(.error, "Failed to trash file \(fileURL.lastPathComponent): \(error.localizedDescription)")
        }
    }
}

// MARK: - Action Icon Button

struct ActionIconButton: View {
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(color))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    BottomCapturesStrip(recentScreenshots: [], onEdit: { _ in }, onRefresh: {})
        .frame(height: 150)
}
