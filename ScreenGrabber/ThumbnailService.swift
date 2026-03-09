//
//  ThumbnailService.swift
//  ScreenGrabber
//
//  Generates thumbnails for screenshots
//

import Foundation
import AppKit

// MARK: - Type Aliases
typealias CaptureError = ScreenGrabberTypes.CaptureError

actor ThumbnailService {
    static let shared = ThumbnailService()
    
    private init() {}
    
    func generateThumbnail(
        for imageURL: URL,
        targetSize: CGFloat = 200
    ) async -> Result<URL, CaptureError> {
        guard let originalImage = NSImage(contentsOf: imageURL) else {
            return .failure(.thumbnailGenerationFailed(underlying: nil))
        }
        
        let thumbnail = resizeImage(originalImage, targetSize: targetSize)
        
        // Save thumbnail in same directory with "_thumb" suffix
        let thumbnailURL = imageURL.deletingPathExtension()
            .appendingPathExtension("thumb.png")
        
        guard let tiffData = thumbnail.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return .failure(.thumbnailGenerationFailed(underlying: nil))
        }
        
        do {
            try pngData.write(to: thumbnailURL, options: .atomic)
            CaptureLogger.log(.save, "Generated thumbnail at \(thumbnailURL.path)", level: .success)
            return .success(thumbnailURL)
        } catch {
            CaptureLogger.saveError(error, path: thumbnailURL.path)
            return .failure(.thumbnailGenerationFailed(underlying: error))
        }
    }
    
    private func resizeImage(_ image: NSImage, targetSize: CGFloat) -> NSImage {
        let originalSize = image.size
        let aspectRatio = originalSize.width / originalSize.height
        
        var newSize: CGSize
        if aspectRatio > 1 {
            // Landscape
            newSize = CGSize(width: targetSize, height: targetSize / aspectRatio)
        } else {
            // Portrait or square
            newSize = CGSize(width: targetSize * aspectRatio, height: targetSize)
        }
        
        let resizedImage = NSImage(size: newSize)
        resizedImage.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: originalSize),
            operation: .sourceOver,
            fraction: 1.0
        )
        resizedImage.unlockFocus()
        
        return resizedImage
    }
}
