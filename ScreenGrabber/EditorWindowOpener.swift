//
//  EditorWindowOpener.swift
//  ScreenGrabber
//
//  Opens the image editor in a standalone NSWindow so its Export and Rename
//  sheets work correctly (nested sheets inside a MenuBarExtra popover or
//  ContentView sheet are silently dropped by macOS).
//

import AppKit
import SwiftUI

enum EditorWindowOpener {
    /// Opens `fileURL` in a new, independent editor window.
    static func open(fileURL: URL) {
        let content = ScreenCaptureEditorView(fileURL: fileURL)
        let controller = NSHostingController(rootView: content)

        let window = NSWindow(contentViewController: controller)
        window.title = fileURL.lastPathComponent
        window.setContentSize(NSSize(width: 1200, height: 760))
        window.minSize = NSSize(width: 1100, height: 700)
        window.styleMask.insert(.resizable)
        window.center()
        window.isReleasedWhenClosed = false   // keep alive; released on next open
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
