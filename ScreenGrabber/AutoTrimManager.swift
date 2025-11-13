//
//  AutoTrimManager.swift
//  ScreenGrabber
//
//  Auto-Trim / Smart Crop - Automatic edge cleanup
//

import Foundation
import AppKit
import CoreImage
import Vision

class AutoTrimManager: ObservableObject {
    static let shared = AutoTrimManager()

    @Published var autoTrimEnabled = false
    @Published var trimThreshold: CGFloat = 10.0 // Color difference threshold
    @Published var minBorderSize: CGFloat = 5.0 // Minimum pixels to trim

    private init() {
        loadSettings()
    }

    // MARK: - Settings

    private func loadSettings() {
        autoTrimEnabled = UserDefaults.standard.object(forKey: "autoTrimEnabled") as? Bool ?? false
        trimThreshold = CGFloat(UserDefaults.standard.double(forKey: "autoTrimThreshold"))
        if trimThreshold == 0 { trimThreshold = 10.0 }

        minBorderSize = CGFloat(UserDefaults.standard.double(forKey: "minBorderSize"))
        if minBorderSize == 0 { minBorderSize = 5.0 }
    }

    func saveSettings() {
        UserDefaults.standard.set(autoTrimEnabled, forKey: "autoTrimEnabled")
        UserDefaults.standard.set(Double(trimThreshold), forKey: "autoTrimThreshold")
        UserDefaults.standard.set(Double(minBorderSize), forKey: "minBorderSize")
    }

    // MARK: - Auto Trim

    func trimImage(_ image: NSImage) -> (image: NSImage, wasTrimmed: Bool, originalSize: CGSize) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return (image, false, image.size)
        }

        let originalSize = image.size

        // Detect borders and calculate crop rect
        if let cropRect = detectBorders(in: cgImage) {
            // Check if trim is significant enough
            let trimmedWidth = cropRect.width
            let trimmedHeight = cropRect.height

            if trimmedWidth < originalSize.width - minBorderSize ||
               trimmedHeight < originalSize.height - minBorderSize {

                // Crop the image
                if let croppedCGImage = cgImage.cropping(to: cropRect) {
                    let croppedImage = NSImage(cgImage: croppedCGImage, size: NSSize(width: cropRect.width, height: cropRect.height))
                    return (croppedImage, true, originalSize)
                }
            }
        }

        return (image, false, originalSize)
    }

    private func detectBorders(in cgImage: CGImage) -> CGRect? {
        let width = cgImage.width
        let height = cgImage.height

        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return nil
        }

        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow

        // Sample edge colors
        let topLeftColor = getPixelColor(bytes: bytes, x: 10, y: 10, bytesPerRow: bytesPerRow, bytesPerPixel: bytesPerPixel)
        let topRightColor = getPixelColor(bytes: bytes, x: width - 10, y: 10, bytesPerRow: bytesPerRow, bytesPerPixel: bytesPerPixel)
        let bottomLeftColor = getPixelColor(bytes: bytes, x: 10, y: height - 10, bytesPerRow: bytesPerRow, bytesPerPixel: bytesPerPixel)
        let bottomRightColor = getPixelColor(bytes: bytes, x: width - 10, y: height - 10, bytesPerRow: bytesPerRow, bytesPerPixel: bytesPerPixel)

        // Determine if edges are uniform (likely borders)
        let edgesAreUniform = colorsAreSimilar(topLeftColor, topRightColor) &&
                             colorsAreSimilar(topLeftColor, bottomLeftColor) &&
                             colorsAreSimilar(topLeftColor, bottomRightColor)

        guard edgesAreUniform else { return nil }

        let borderColor = topLeftColor

        // Find trim boundaries
        var top = 0
        var bottom = height
        var left = 0
        var right = width

        // Scan from top
        for y in 0..<height {
            var nonBorderFound = false
            for x in stride(from: 0, to: width, by: max(1, width / 20)) {
                let color = getPixelColor(bytes: bytes, x: x, y: y, bytesPerRow: bytesPerRow, bytesPerPixel: bytesPerPixel)
                if !colorsAreSimilar(color, borderColor) {
                    nonBorderFound = true
                    break
                }
            }
            if nonBorderFound {
                top = max(0, y - Int(minBorderSize))
                break
            }
        }

        // Scan from bottom
        for y in stride(from: height - 1, through: 0, by: -1) {
            var nonBorderFound = false
            for x in stride(from: 0, to: width, by: max(1, width / 20)) {
                let color = getPixelColor(bytes: bytes, x: x, y: y, bytesPerRow: bytesPerRow, bytesPerPixel: bytesPerPixel)
                if !colorsAreSimilar(color, borderColor) {
                    nonBorderFound = true
                    break
                }
            }
            if nonBorderFound {
                bottom = min(height, y + Int(minBorderSize) + 1)
                break
            }
        }

        // Scan from left
        for x in 0..<width {
            var nonBorderFound = false
            for y in stride(from: 0, to: height, by: max(1, height / 20)) {
                let color = getPixelColor(bytes: bytes, x: x, y: y, bytesPerRow: bytesPerRow, bytesPerPixel: bytesPerPixel)
                if !colorsAreSimilar(color, borderColor) {
                    nonBorderFound = true
                    break
                }
            }
            if nonBorderFound {
                left = max(0, x - Int(minBorderSize))
                break
            }
        }

        // Scan from right
        for x in stride(from: width - 1, through: 0, by: -1) {
            var nonBorderFound = false
            for y in stride(from: 0, to: height, by: max(1, height / 20)) {
                let color = getPixelColor(bytes: bytes, x: x, y: y, bytesPerRow: bytesPerRow, bytesPerPixel: bytesPerPixel)
                if !colorsAreSimilar(color, borderColor) {
                    nonBorderFound = true
                    break
                }
            }
            if nonBorderFound {
                right = min(width, x + Int(minBorderSize) + 1)
                break
            }
        }

        // Validate crop rect
        guard right > left && bottom > top else { return nil }

        return CGRect(x: left, y: top, width: right - left, height: bottom - top)
    }

    private func getPixelColor(bytes: UnsafePointer<UInt8>, x: Int, y: Int, bytesPerRow: Int, bytesPerPixel: Int) -> (r: UInt8, g: UInt8, b: UInt8) {
        let offset = y * bytesPerRow + x * bytesPerPixel

        let r = bytes[offset]
        let g = bytes[offset + 1]
        let b = bytes[offset + 2]

        return (r, g, b)
    }

    private func colorsAreSimilar(_ color1: (r: UInt8, g: UInt8, b: UInt8), _ color2: (r: UInt8, g: UInt8, b: UInt8)) -> Bool {
        let threshold = Int(trimThreshold)

        let rDiff = abs(Int(color1.r) - Int(color2.r))
        let gDiff = abs(Int(color1.g) - Int(color2.g))
        let bDiff = abs(Int(color1.b) - Int(color2.b))

        return rDiff <= threshold && gDiff <= threshold && bDiff <= threshold
    }

    // MARK: - Smart Crop

    /// Smart crop based on content detection
    func smartCrop(_ image: NSImage, aspectRatio: CGFloat? = nil) -> NSImage {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image
        }

        // Use Vision framework to detect salient regions
        if let cropRect = detectSalientRegion(in: cgImage, aspectRatio: aspectRatio) {
            if let croppedCGImage = cgImage.cropping(to: cropRect) {
                return NSImage(cgImage: croppedCGImage, size: NSSize(width: cropRect.width, height: cropRect.height))
            }
        }

        return image
    }

    private func detectSalientRegion(in cgImage: CGImage, aspectRatio: CGFloat?) -> CGRect? {
        let request = VNGenerateAttentionBasedSaliencyImageRequest()

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])

            guard let results = request.results?.first else { return nil }

            // Get the salient objects
            let salientObjects = results.salientObjects ?? []

            if salientObjects.isEmpty {
                return nil
            }

            // Find bounding box that contains all salient objects
            var minX: CGFloat = 1.0
            var minY: CGFloat = 1.0
            var maxX: CGFloat = 0.0
            var maxY: CGFloat = 0.0

            for object in salientObjects {
                let box = object.boundingBox
                minX = min(minX, box.minX)
                minY = min(minY, box.minY)
                maxX = max(maxX, box.maxX)
                maxY = max(maxY, box.maxY)
            }

            // Add padding
            let padding: CGFloat = 0.05
            minX = max(0, minX - padding)
            minY = max(0, minY - padding)
            maxX = min(1, maxX + padding)
            maxY = min(1, maxY + padding)

            // Convert from normalized coordinates to image coordinates
            let width = CGFloat(cgImage.width)
            let height = CGFloat(cgImage.height)

            // Vision framework uses bottom-left origin, CGImage uses top-left
            let x = minX * width
            let y = (1 - maxY) * height
            let w = (maxX - minX) * width
            let h = (maxY - minY) * height

            var cropRect = CGRect(x: x, y: y, width: w, height: h)

            // Adjust for aspect ratio if specified
            if let targetAspectRatio = aspectRatio {
                cropRect = adjustRectForAspectRatio(cropRect, aspectRatio: targetAspectRatio, imageSize: CGSize(width: width, height: height))
            }

            return cropRect

        } catch {
            print("Error detecting salient region: \(error)")
            return nil
        }
    }

    private func adjustRectForAspectRatio(_ rect: CGRect, aspectRatio: CGFloat, imageSize: CGSize) -> CGRect {
        let currentAspectRatio = rect.width / rect.height

        if abs(currentAspectRatio - aspectRatio) < 0.01 {
            return rect // Already close enough
        }

        var newRect = rect

        if currentAspectRatio > aspectRatio {
            // Too wide, increase height
            let newHeight = rect.width / aspectRatio
            let heightDiff = newHeight - rect.height
            newRect.origin.y -= heightDiff / 2
            newRect.size.height = newHeight
        } else {
            // Too tall, increase width
            let newWidth = rect.height * aspectRatio
            let widthDiff = newWidth - rect.width
            newRect.origin.x -= widthDiff / 2
            newRect.size.width = newWidth
        }

        // Ensure rect is within image bounds
        newRect = newRect.intersection(CGRect(origin: .zero, size: imageSize))

        return newRect
    }

    // MARK: - Shadow Detection and Removal

    func removeShadows(from image: NSImage) -> NSImage {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let ciImage = CIImage(image: image) else {
            return image
        }

        // Apply shadow removal filter
        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(1.2, forKey: kCIInputBrightnessKey)
        filter?.setValue(1.1, forKey: kCIInputContrastKey)

        guard let outputImage = filter?.outputImage else { return image }

        let context = CIContext()
        guard let outputCGImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }

        return NSImage(cgImage: outputCGImage, size: image.size)
    }

    // MARK: - Edge Enhancement

    func enhanceEdges(in image: NSImage) -> NSImage {
        guard let ciImage = CIImage(image: image) else { return image }

        let filter = CIFilter(name: "CISharpenLuminance")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(0.4, forKey: kCIInputSharpnessKey)

        guard let outputImage = filter?.outputImage else { return image }

        let context = CIContext()
        guard let outputCGImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }

        return NSImage(cgImage: outputCGImage, size: image.size)
    }
}
