//
//  EditorWindowHelper.swift
//  ScreenGrabber
//
//  Manages editor window lifecycle
//

import Foundation
import AppKit
import SwiftUI
import Combine

@MainActor
class EditorWindowHelper: ObservableObject {
    static let shared = EditorWindowHelper()
    
    private var editorWindows: [UUID: NSWindow] = [:]
    private var windowDelegates: [UUID: WindowDelegate] = [:] // Store delegates to prevent deallocation
    
    private init() {}
    
    func openEditor(for screenshot: Screenshot) {
        // Check if window already exists for this screenshot
        if let existingWindow = editorWindows[screenshot.id] {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }
        
        // Create new editor window
        let editorView = ScreenshotEditorView(screenshot: screenshot)
        let hostingController = NSHostingController(rootView: editorView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Edit - \(screenshot.filename)"
        window.contentViewController = hostingController
        window.center()
        window.setFrameAutosaveName("EditorWindow_\(screenshot.id)")
        
        // Handle window close
        let delegate = WindowDelegate(onClose: { [weak self] in
            self?.editorWindows.removeValue(forKey: screenshot.id)
            self?.windowDelegates.removeValue(forKey: screenshot.id)
        })
        
        window.delegate = delegate
        windowDelegates[screenshot.id] = delegate
        
        editorWindows[screenshot.id] = window
        window.makeKeyAndOrderFront(nil)
    }
    
    func closeEditor(for screenshotID: UUID) {
        editorWindows[screenshotID]?.close()
        editorWindows.removeValue(forKey: screenshotID)
        windowDelegates.removeValue(forKey: screenshotID)
    }
    
    func closeAllEditors() {
        editorWindows.values.forEach { $0.close() }
        editorWindows.removeAll()
        windowDelegates.removeAll()
    }
    
    // MARK: - Window Delegate
    
    private class WindowDelegate: NSObject, NSWindowDelegate {
        let onClose: () -> Void
        
        init(onClose: @escaping () -> Void) {
            self.onClose = onClose
        }
        
        func windowWillClose(_ notification: Notification) {
            onClose()
        }
    }
}
