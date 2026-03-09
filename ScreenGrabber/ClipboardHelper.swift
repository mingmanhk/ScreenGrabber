//
//  ClipboardHelper.swift
//  ScreenGrabber
//
//  Created on 01/04/26.
//  Utility functions for clipboard operations
//

import AppKit
import SwiftUI

/// Helper class for clipboard operations
enum ClipboardHelper {
    
    /// Copies an image to the system clipboard
    /// - Parameter image: The NSImage to copy
    /// - Returns: True if the operation was successful
    @discardableResult
    static func copyImageToClipboard(_ image: NSImage) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.writeObjects([image])
    }
    
    /// Copies an image from a URL to the clipboard
    /// - Parameter url: The URL of the image file
    /// - Returns: True if the operation was successful
    @discardableResult
    static func copyImageToClipboard(from url: URL) -> Bool {
        guard let image = NSImage(contentsOf: url) else {
            return false
        }
        return copyImageToClipboard(image)
    }
    
    /// Copies text to the clipboard
    /// - Parameter text: The text string to copy
    /// - Returns: True if the operation was successful
    @discardableResult
    static func copyTextToClipboard(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }
    
    /// Gets an image from the clipboard
    /// - Returns: The image from clipboard, if available
    static func imageFromClipboard() -> NSImage? {
        let pasteboard = NSPasteboard.general
        guard let objects = pasteboard.readObjects(forClasses: [NSImage.self], options: nil),
              let image = objects.first as? NSImage else {
            return nil
        }
        return image
    }
    
    /// Gets text from the clipboard
    /// - Returns: The text from clipboard, if available
    static func textFromClipboard() -> String? {
        let pasteboard = NSPasteboard.general
        return pasteboard.string(forType: .string)
    }
    
    /// Checks if the clipboard contains an image
    /// - Returns: True if clipboard contains an image
    static func clipboardContainsImage() -> Bool {
        let pasteboard = NSPasteboard.general
        return pasteboard.availableType(from: [.tiff, .png, .fileURL]) != nil
    }
    
    /// Checks if the clipboard contains text
    /// - Returns: True if clipboard contains text
    static func clipboardContainsText() -> Bool {
        let pasteboard = NSPasteboard.general
        return pasteboard.availableType(from: [.string]) != nil
    }
}

// MARK: - Extension for SwiftUI View
extension View {
    /// Copies an image to clipboard with optional feedback
    func copyImage(_ image: NSImage?, showFeedback: Bool = true) {
        guard let image = image else { return }
        
        if ClipboardHelper.copyImageToClipboard(image) {
            if showFeedback {
                StatusManager.shared.showCopyComplete()
            }
        }
    }
    
    /// Copies an image from URL to clipboard with optional feedback
    func copyImage(from url: URL?, showFeedback: Bool = true) {
        guard let url = url else { return }
        
        if ClipboardHelper.copyImageToClipboard(from: url) {
            if showFeedback {
                StatusManager.shared.showCopyComplete()
            }
        }
    }
}
