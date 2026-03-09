//
//  FloatingThumbnailManager.swift
//  ScreenGrabber
//
//  Manages floating thumbnail preview after screenshots
//  Created on 11/13/25.
//

import Foundation
import AppKit
import SwiftUI
import Combine

@MainActor
class FloatingThumbnailManager: ObservableObject {
    static let shared = FloatingThumbnailManager()
    
    @Published var settings = FloatingThumbnailSettings.default
    private var currentWindow: NSWindow?
    
    private init() {}
    
    /// Shows a floating thumbnail for the given image
    func showThumbnail(for image: NSImage, at position: FloatingThumbnailSettings.ThumbnailPosition? = nil) {
        // Dismiss any existing thumbnail
        dismissThumbnail()
        
        guard settings.enabled else { return }
        
        let thumbnailPosition = position ?? settings.position
        let size = max(settings.size.width, settings.size.height)
        
        // Create the thumbnail view
        let thumbnailView = FloatingThumbnailView(
            image: image,
            size: size,
            onDismiss: { [weak self] in
                self?.dismissThumbnail()
            }
        )
        
        // Create a window to host the thumbnail
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: size + 20, height: size + 20),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.level = NSWindow.Level.floating
        window.collectionBehavior = [NSWindow.CollectionBehavior.canJoinAllSpaces, NSWindow.CollectionBehavior.stationary]
        window.contentView = NSHostingView(rootView: thumbnailView)
        
        // Position the window
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowSize = window.frame.size
            
            let x: CGFloat
            let y: CGFloat
            
            switch thumbnailPosition {
            case .topLeft:
                x = screenFrame.minX + 20
                y = screenFrame.maxY - windowSize.height - 20
            case .topRight:
                x = screenFrame.maxX - windowSize.width - 20
                y = screenFrame.maxY - windowSize.height - 20
            case .bottomLeft:
                x = screenFrame.minX + 20
                y = screenFrame.minY + 20
            case .bottomRight:
                x = screenFrame.maxX - windowSize.width - 20
                y = screenFrame.minY + 20
            }
            
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        window.makeKeyAndOrderFront(nil as Any?)
        currentWindow = window
        
        // Auto-dismiss after duration
        Task {
            try? await Task.sleep(nanoseconds: UInt64(settings.duration * 1_000_000_000))
            dismissThumbnail()
        }
    }
    
    /// Dismisses the current thumbnail
    func dismissThumbnail() {
        currentWindow?.close()
        currentWindow = nil
    }
}

// MARK: - Floating Thumbnail View
private struct FloatingThumbnailView: View {
    let image: NSImage
    let size: CGFloat
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                .overlay(alignment: .topTrailing) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white, .black.opacity(0.5))
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
