//
//  CaptureClipboardService.swift
//  ScreenGrabber
//
//  Service for copying screenshots to the clipboard
//

import Foundation
import AppKit

/// Actor that manages clipboard operations for captures
@MainActor
class CaptureClipboardService {
    static let shared = CaptureClipboardService()
    
    private init() {}
    
    /// Copies an image to the system clipboard
    /// - Parameter image: The NSImage to copy
    /// - Returns: Result indicating success or failure
    func copyToClipboard(_ image: NSImage) async -> Result<Void, ScreenGrabberTypes.CaptureError> {
        CaptureLogger.log(.clipboard, "📋 Copying image to clipboard...", level: .info)
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        guard pasteboard.writeObjects([image]) else {
            CaptureLogger.log(.error, "❌ Failed to write image to clipboard", level: .error)
            return .failure(.captureKitError("Failed to copy to clipboard"))
        }
        
        CaptureLogger.log(.clipboard, "✅ Image copied to clipboard", level: .success)
        return .success(())
    }
    
    /// Copies an image from a file URL to the clipboard
    /// - Parameter url: The file URL of the image
    /// - Returns: Result indicating success or failure
    func copyToClipboard(from url: URL) async -> Result<Void, ScreenGrabberTypes.CaptureError> {
        guard let image = NSImage(contentsOf: url) else {
            CaptureLogger.log(.error, "❌ Failed to load image from \(url.path)", level: .error)
            return .failure(.invalidImageData)
        }
        
        return await copyToClipboard(image)
    }
}

