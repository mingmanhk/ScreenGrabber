//
//  QuickActionsBarView.swift
//  ScreenGrabber
//
//  Post-capture quick actions panel
//

import SwiftUI
import AppKit

// MARK: - Quick Actions Bar Window
class QuickActionsBarWindow: NSPanel {
    init(imageURL: URL, image: NSImage) {
        let screenFrame = NSScreen.main?.frame ?? .zero
        let windowRect = NSRect(
            x: (screenFrame.width - 400) / 2,
            y: screenFrame.height - 150,
            width: 400,
            height: 100
        )
        
        super.init(
            contentRect: windowRect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        
        let hostingView = NSHostingView(
            rootView: QuickActionsBarView(imageURL: imageURL, image: image, window: self)
        )
        self.contentView = hostingView
        
        // Auto-dismiss after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.orderOut(nil)
        }
    }
}

// MARK: - Quick Actions Bar View
struct QuickActionsBarView: View {
    let imageURL: URL
    let image: NSImage
    weak var window: NSPanel?
    
    @StateObject private var actionsManager = QuickActionsManager.shared
    @State private var showingAnnotator = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Thumbnail preview
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 60)
                .clipped()
                .cornerRadius(8)
                .padding(8)
            
            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 1)
            
            // Actions
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(actionsManager.actions.filter { $0.enabled }) { action in
                        QuickActionButtonView(action: action) {
                            performAction(action.action)
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            
            // Close button
            Button(action: { window?.orderOut(nil) }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(12)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 80)
        .background(
            VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
    
    private func performAction(_ action: QuickAction.ActionType) {
        switch action {
        case .copyToClipboard:
            copyToClipboard()
        case .openInPreview:
            openInPreview()
        case .delete:
            deleteFile()
        case .share:
            shareFile()
        case .annotate:
            showingAnnotator = true
        case .pin:
            pinToScreen()
        case .copyFilename:
            copyFilename()
        case .copyPath:
            copyPath()
        case .showInFinder:
            showInFinder()
        }
    }
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        showNotification(title: "Copied", message: "Image copied to clipboard")
        window?.orderOut(nil)
    }
    
    private func openInPreview() {
        NSWorkspace.shared.open(imageURL)
        window?.orderOut(nil)
    }
    
    private func deleteFile() {
        do {
            try FileManager.default.removeItem(at: imageURL)
            showNotification(title: "Deleted", message: "Screenshot deleted")
            window?.orderOut(nil)
        } catch {
            print("Delete error: \(error)")
        }
    }
    
    private func shareFile() {
        let picker = NSSharingServicePicker(items: [imageURL])
        if let view = window?.contentView {
            picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
        }
    }
    
    private func pinToScreen() {
        FloatingThumbnailManager.shared.show(image: image)
        window?.orderOut(nil)
    }
    
    private func copyFilename() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(imageURL.lastPathComponent, forType: .string)
        showNotification(title: "Copied", message: "Filename copied")
        window?.orderOut(nil)
    }
    
    private func copyPath() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(imageURL.path, forType: .string)
        showNotification(title: "Copied", message: "File path copied")
        window?.orderOut(nil)
    }
    
    private func showInFinder() {
        NSWorkspace.shared.selectFile(imageURL.path, inFileViewerRootedAtPath: imageURL.deletingLastPathComponent().path)
        window?.orderOut(nil)
    }
    
    private func showNotification(title: String, message: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        NSUserNotificationCenter.default.deliver(notification)
    }
}

// MARK: - Quick Action Button
struct QuickActionButtonView: View {
    let action: QuickAction
    let onTap: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: action.icon)
                    .font(.title3)
                    .foregroundColor(.white)
                
                Text(action.name)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
            .frame(width: 70, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHovering ? Color.white.opacity(0.2) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Quick Actions Manager
class QuickActionsBarManager {
    static let shared = QuickActionsBarManager()
    private var currentWindow: QuickActionsBarWindow?
    
    func show(imageURL: URL, image: NSImage) {
        // Close existing window
        currentWindow?.orderOut(nil)
        
        // Create and show new window
        currentWindow = QuickActionsBarWindow(imageURL: imageURL, image: image)
        currentWindow?.makeKeyAndOrderFront(nil)
    }
    
    func hide() {
        currentWindow?.orderOut(nil)
        currentWindow = nil
    }
}
