//
//  NSImage+Extensions.swift
//  ScreenGrabber
//
//  Extensions for NSImage
//

import AppKit

extension NSImage {
    /// Convert NSImage to CGImage
    var cgImage: CGImage? {
        var rect = CGRect(origin: .zero, size: self.size)
        return self.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
    
    /// Create NSImage from CGImage with specific size
    convenience init(cgImage: CGImage, size: NSSize) {
        self.init(size: size)
        
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        
        if let rep = rep, let context = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = context
            context.cgContext.draw(cgImage, in: NSRect(origin: .zero, size: size))
            NSGraphicsContext.restoreGraphicsState()
            self.addRepresentation(rep)
        }
    }
}
