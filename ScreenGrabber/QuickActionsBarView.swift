//
//  QuickActionsBarView.swift
//  ScreenGrabber
//
//  Post-capture quick actions panel
//

import SwiftUI
import AppKit
import UserNotifications

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
        HStack(spacing: 8) {
            // Thumbnail preview
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 60)
                .clipped()
                .cornerRadius(8)
                .padding(8)
            
            VerticalDivider()
            
            // Actions
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(actionsManager.actions.filter { $0.enabled }) { action in
                        QuickActionButtonView(action: action) {
                            // Run the action in an async Task
                            Task {
                                await performAction(action.action)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            
            VerticalDivider()
            
            // Close button
            Button(action: { window?.orderOut(nil) }) {
                Image(systemName: "xmark")
                    .font(.title3.weight(.medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
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
    
    private func performAction(_ action: QuickAction.ActionType) async {
        switch action {
        case .copyToClipboard:
            await copyToClipboard()
        case .openInPreview:
            openInPreview()
        case .delete:
            await deleteFile()
        case .share:
            shareFile() // NSSharingServicePicker needs to be main-thread and synchronous
        case .annotate:
            showingAnnotator = true
        case .pin:
            pinToScreen()
        case .copyFilename:
            await copyFilename()
        case .copyPath:
            await copyPath()
        case .showInFinder:
            showInFinder()
        }
    }
    
    private func copyToClipboard() async {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        await showNotification(title: "Copied", message: "Image copied to clipboard")
        window?.orderOut(nil)
    }
    
    private func openInPreview() {
        _ = NSWorkspace.shared.open(imageURL)
        window?.orderOut(nil)
    }
    
    private func deleteFile() async {
        do {
            // Perform blocking file I/O in a background task
            try await Task.detached {
                try FileManager.default.removeItem(at: imageURL)
            }.value
            
            await showNotification(title: "Deleted", message: "Screenshot deleted")
            window?.orderOut(nil)
        } catch {
            print("Delete error: \(error)")
            // Consider showing an error alert to the user
        }
    }
    
    private func shareFile() {
        let picker = NSSharingServicePicker(items: [imageURL])
        // This view-related operation should be on the main thread.
        if let view = window?.contentView {
            picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
        }
    }
    
    private func pinToScreen() {
        FloatingThumbnailManager.shared.show(image: image)
        window?.orderOut(nil)
    }
    
    private func copyFilename() async {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(imageURL.lastPathComponent, forType: .string)
        await showNotification(title: "Copied", message: "Filename copied")
        window?.orderOut(nil)
    }
    
    private func copyPath() async {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(imageURL.path, forType: .string)
        await showNotification(title: "Copied", message: "File path copied")
        window?.orderOut(nil)
    }
    
    private func showInFinder() {
        NSWorkspace.shared.selectFile(imageURL.path, inFileViewerRootedAtPath: imageURL.deletingLastPathComponent().path)
        window?.orderOut(nil)
    }
    
    private func showNotification(title: String, message: String) async {
        do {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            
            if settings.authorizationStatus != .authorized {
                guard try await center.requestAuthorization(options: [.alert]) else {
                    print("Notification permission was not granted.")
                    return
                }
            }
            
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = message
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            
            try await center.add(request)
        } catch {
            print("Error delivering notification: \(error.localizedDescription)")
        }
    }
}

// MARK: - Quick Action Button
struct QuickActionButtonView: View {
    let action: QuickAction
    let onTap: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onTap) {
            Image(systemName: action.icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isHovering ? Color.white.opacity(0.25) : Color.white.opacity(0.1))
                )
                .scaleEffect(isHovering ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isHovering = hovering
            }
        }
        .help(action.name) // This adds a tooltip on hover
    }
}

// MARK: - UI Helper
struct VerticalDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.2))
            .frame(width: 1)
            .padding(.vertical, 16)
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
