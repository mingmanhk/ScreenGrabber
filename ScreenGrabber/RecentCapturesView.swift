//
//  RecentCapturesView.swift
//  ScreenGrabber
//
//  Horizontal strip showing recent captures
//

import SwiftUI
import SwiftData

struct RecentCapturesView: View {
    @Query(
        filter: nil,
        sort: \Screenshot.captureDate,
        order: .reverse
    ) private var allScreenshots: [Screenshot]
    
    private var recentScreenshots: [Screenshot] {
        Array(allScreenshots.prefix(10))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Captures")
                    .font(.headline)
                
                Spacer()
                
                if !recentScreenshots.isEmpty {
                    Button("View All") {
                        // Navigate to browser
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }
            
            if recentScreenshots.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    
                    Text("No recent captures")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(recentScreenshots) { screenshot in
                            RecentCaptureCard(screenshot: screenshot)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct RecentCaptureCard: View {
    let screenshot: Screenshot
    @State private var thumbnail: NSImage?
    @State private var isHovered: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                if let thumbnail = thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 80)
                        .clipped()
                        .cornerRadius(6)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 120, height: 80)
                        .cornerRadius(6)
                }
                
                if isHovered {
                    Color.black.opacity(0.3)
                        .cornerRadius(6)
                    
                    Button {
                        EditorWindowHelper.shared.openEditor(for: screenshot)
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .onHover { hovering in
                isHovered = hovering
            }
            
            Text(formatDate(screenshot.captureDate))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 120)
        .task {
            await loadThumbnail()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func loadThumbnail() async {
        // Attempt to load directly from the full-size image URL.
        if let image = NSImage(contentsOf: screenshot.fileURL) {
            await MainActor.run {
                self.thumbnail = image
            }
            return
        }
        
        // If loading fails, clear any existing thumbnail.
        await MainActor.run {
            self.thumbnail = nil
        }
    }
}

#Preview {
    RecentCapturesView()
        .modelContainer(for: Screenshot.self, inMemory: true)
        .frame(width: 600)
}
