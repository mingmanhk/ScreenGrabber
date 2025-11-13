//
//  FloatingThumbnailWindow.swift
//  ScreenGrabber
//
//  Floating thumbnail preview after capture
//

import SwiftUI
import AppKit

// MARK: - Floating Thumbnail Window
class FloatingThumbnailWindow: NSWindow {
    init(image: NSImage, at point: CGPoint) {
        super.init(
            contentRect: NSRect(x: point.x, y: point.y, width: 200, height: 150),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        
        let hostingView = NSHostingView(rootView: FloatingThumbnailView(image: image, window: self))
        self.contentView = hostingView
        
        // Auto-dismiss if enabled
        if FloatingThumbnailSettings.enabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + FloatingThumbnailSettings.autoDismissDelay) { [weak self] in
                self?.close()
            }
        }
    }
}

// MARK: - Floating Thumbnail View
struct FloatingThumbnailView: View {
    let image: NSImage
    weak var window: NSWindow?
    
    @State private var isHovering = false
    @State private var isDragging = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Image preview
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 150)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            
            // Action buttons (show on hover)
            if isHovering {
                HStack(spacing: 8) {
                    FloatingActionButton(icon: "pin.fill", color: .blue) {
                        // Pin action
                        togglePin()
                    }
                    
                    FloatingActionButton(icon: "square.and.arrow.up", color: .green) {
                        // Share action
                        shareImage()
                    }
                    
                    FloatingActionButton(icon: "doc.on.clipboard", color: .purple) {
                        // Copy action
                        copyToClipboard()
                    }
                    
                    FloatingActionButton(icon: "xmark", color: .red) {
                        // Close action
                        window?.close()
                    }
                }
                .padding(8)
                .background(
                    VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
                        .cornerRadius(10)
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
    
    private func togglePin() {
        if let window = window {
            window.level = window.level == .floating ? .popUpMenu : .floating
        }
    }
    
    private func shareImage() {
        let picker = NSSharingServicePicker(items: [image])
        if let view = window?.contentView {
            picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
        }
    }
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        
        // Show confirmation
        print("Image copied to clipboard")
        window?.close()
    }
}

struct FloatingActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(color)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Floating Thumbnail Manager
class FloatingThumbnailManager {
    static let shared = FloatingThumbnailManager()
    private var currentWindow: FloatingThumbnailWindow?
    
    func show(image: NSImage, at point: CGPoint? = nil) {
        guard FloatingThumbnailSettings.enabled else { return }
        
        // Close existing window
        currentWindow?.close()
        
        // Determine position (default to mouse location)
        let position = point ?? NSEvent.mouseLocation
        
        // Create and show new window
        currentWindow = FloatingThumbnailWindow(image: image, at: position)
        currentWindow?.makeKeyAndOrderFront(nil)
    }
    
    func hide() {
        currentWindow?.close()
        currentWindow = nil
    }
}

// MARK: - Visual Effect Blur (if not already defined)
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
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
    }
}
