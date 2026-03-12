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
        guard originalSize.width > 0, originalSize.height > 0 else { return image }
        let aspectRatio = originalSize.width / originalSize.height

        let newSize: CGSize = aspectRatio > 1
            ? CGSize(width: targetSize, height: (targetSize / aspectRatio).rounded())
            : CGSize(width: (targetSize * aspectRatio).rounded(), height: targetSize)

        let w = Int(newSize.width)
        let h = Int(newSize.height)
        guard w > 0, h > 0 else { return image }

        // Use CGContext — thread-safe, no lockFocus required
        guard let cgSource = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let ctx = CGContext(
                data: nil, width: w, height: h,
                bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return image }

        ctx.interpolationQuality = .high
        ctx.draw(cgSource, in: CGRect(x: 0, y: 0, width: w, height: h))

        guard let cgOut = ctx.makeImage() else { return image }
        return NSImage(cgImage: cgOut, size: newSize)
    }
}
