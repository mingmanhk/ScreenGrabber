//
//  QuickActionsBarManager.swift
//  ScreenGrabber
//
//  Manages quick actions bar for screenshot operations
//  Created on 11/13/25.
//

import Foundation
import AppKit
import SwiftUI
import Combine
import UniformTypeIdentifiers

@MainActor
class QuickActionsBarManager: ObservableObject {
    static let shared = QuickActionsBarManager()
    
    @Published var isVisible = false
    private var currentWindow: NSWindow?
    
    private init() {
        self.isVisible = false
        self.currentWindow = nil
    }
    
    /// Shows the quick actions bar
    func showActionsBar(for image: NSImage, at point: NSPoint? = nil) {
        // Dismiss any existing bar
        dismissActionsBar()
        
        let actionsView = QuickActionsBarView(
            image: image,
            onCopy: { [weak self] in
                self?.copyImageToClipboard(image)
                self?.dismissActionsBar()
            },
            onSave: { [weak self] in
                self?.saveImageToFile(image)
                self?.dismissActionsBar()
            },
            onEdit: { [weak self] in
                self?.openImageEditor(image)
                self?.dismissActionsBar()
            },
            onDismiss: { [weak self] in
                self?.dismissActionsBar()
            }
        )
        
        // Create a window to host the actions bar
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 60),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .transient]
        window.contentView = NSHostingView(rootView: actionsView)
        
        // Position the window
        if let point = point {
            window.setFrameOrigin(point)
        } else if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 150
            let y = screenFrame.maxY - 100
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        window.makeKeyAndOrderFront(nil)
        currentWindow = window
        isVisible = true
    }
    
    /// Dismisses the actions bar
    func dismissActionsBar() {
        currentWindow?.close()
        currentWindow = nil
        isVisible = false
    }
    
    // MARK: - Action Handlers
    
    private func copyImageToClipboard(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        print("[QuickActions] Image copied to clipboard")
    }
    
    private func saveImageToFile(_ image: NSImage) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        savePanel.nameFieldStringValue = "Screenshot_\(dateFormatter.string(from: Date()))"
        
        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            
            if let tiffData = image.tiffRepresentation,
               let bitmapImage = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                do {
                    try pngData.write(to: url)
                    print("[QuickActions] Image saved to: \(url.path)")
                } catch {
                    print("[QuickActions] Failed to save image: \(error)")
                }
            }
        }
    }
    
    private func openImageEditor(_ image: NSImage) {
        // TODO: Implement image editor integration
        print("[QuickActions] Opening image editor (not yet implemented)")
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Preview.app"))
    }
}

// MARK: - Quick Actions Bar View
private struct QuickActionsBarView: View {
    let image: NSImage
    let onCopy: () -> Void
    let onSave: () -> Void
    let onEdit: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ActionButton(icon: "doc.on.clipboard", title: "Copy", action: onCopy)
            ActionButton(icon: "square.and.arrow.down", title: "Save", action: onSave)
            ActionButton(icon: "pencil", title: "Edit", action: onEdit)
            
            Divider()
                .frame(height: 30)
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}

private struct ActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption)
            }
            .frame(width: 60)
        }
        .buttonStyle(.plain)
        .foregroundColor(.primary)
    }
}
