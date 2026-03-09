//
//  ContentTypeExtensions.swift
//  ScreenGrabber
//
//  Provides UTType extensions for file handling
//

import Foundation
import UniformTypeIdentifiers

extension UTType {
    /// Convenience access to common image types
    static var screenshotTypes: [UTType] {
        [.png, .jpeg, .tiff]
    }
}

// Helper to avoid repeated imports
struct FileTypeHelper {
    static let imageTypes: [UTType] = [.png, .jpeg, .tiff]
    static let pngType: UTType = .png
    static let jpegType: UTType = .jpeg
    static let tiffType: UTType = .tiff
}
