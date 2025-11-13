//
//  ScreenCaptureManager+Enhanced.swift
//  ScreenGrabber
//
//  Enhanced capture functionality
//

import Foundation
import AppKit
import SwiftData

extension ScreenCaptureManager {
    
    // MARK: - Enhanced Capture with Delay
    func captureWithDelay(
        method: ScreenOption,
        openOption: OpenOption,
        modelContext: ModelContext?,
        delay: Int = 0
    ) {
        if delay > 0 {
            // Show countdown notification
            showCountdownNotification(seconds: delay)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay)) { [weak self] in
                self?.captureScreen(method: method, openOption: openOption, modelContext: modelContext)
            }
        } else {
            captureScreen(method: method, openOption: openOption, modelContext: modelContext)
        }
    }
    
    // MARK: - Capture with Compression Profile
    func captureWithFormat(
        method: ScreenOption,
        openOption: OpenOption,
        modelContext: ModelContext?,
        profile: CompressionProfile
    ) {
        // First capture as PNG
        captureScreen(method: method, openOption: .saveToFile, modelContext: modelContext)
        
        // Then convert if needed
        if profile != .highQualityPNG {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.convertLastScreenshot(to: profile)
            }
        }
        
        // Handle additional open option
        if openOption != .saveToFile {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.handleOpenOption(openOption, for: self?.getLastScreenshotURL())
            }
        }
    }
    
    // MARK: - Capture with Region Preset
    func captureWithPreset(_ preset: RegionPreset, openOption: OpenOption, modelContext: ModelContext?) {
        let rect = preset.rect
        let timestamp = Date()
        let profile = CompressionProfile.current
        let filename = "Screenshot_\(DateFormatter.screenshotFormatter.string(from: timestamp)).\(profile.fileExtension)"
        let screenGrabberFolder = getScreenGrabberFolderURL()
        let filePath = screenGrabberFolder.appendingPathComponent(filename)
        
        // Use screencapture with specific region
        let arguments = [
            "-x", // No sound
            "-R", "\(Int(rect.origin.x)),\(Int(rect.origin.y)),\(Int(rect.width)),\(Int(rect.height))",
            filePath.path
        ]
        
        executeScreenCapture(arguments: arguments) { [weak self] (success: Bool) in
            if success {
                self?.postCaptureActions(fileURL: filePath, openOption: openOption, modelContext: modelContext)
            }
        }
    }
    
    // MARK: - Post-Capture Actions
    private func postCaptureActions(fileURL: URL, openOption: OpenOption, modelContext: ModelContext?) {
        // Load the captured image
        guard let image = NSImage(contentsOf: fileURL) else { return }
        
        // Auto-copy settings
        handleAutoCopy(for: fileURL)
        
        // Show floating thumbnail if enabled
        if FloatingThumbnailSettings.enabled {
            FloatingThumbnailManager.shared.show(image: image)
        }
        
        // Show quick actions bar
        QuickActionsBarManager.shared.show(imageURL: fileURL, image: image)
        
        // Apply organization rules
        applyOrganizationRules(for: fileURL, imageSize: image.size)
        
        // Handle open option
        handleOpenOption(openOption, for: fileURL)
        
        // Save to SwiftData if context provided
        if let modelContext = modelContext {
            saveToDatabase(fileURL: fileURL, modelContext: modelContext)
        }
    }
    
    // MARK: - Auto-Copy Handler
    private func handleAutoCopy(for fileURL: URL) {
        let option = AutoCopyOption.current
        let pasteboard = NSPasteboard.general
        
        switch option {
        case .none:
            return
        case .filename:
            pasteboard.clearContents()
            pasteboard.setString(fileURL.lastPathComponent, forType: .string)
            showNotification(title: "Copied", message: "Filename copied to clipboard")
        case .filepath:
            pasteboard.clearContents()
            pasteboard.setString(fileURL.path, forType: .string)
            showNotification(title: "Copied", message: "File path copied to clipboard")
        case .both:
            pasteboard.clearContents()
            let combined = "\(fileURL.lastPathComponent)\n\(fileURL.path)"
            pasteboard.setString(combined, forType: .string)
            showNotification(title: "Copied", message: "Filename and path copied")
        }
    }
    
    // MARK: - Organization Rules Handler
    private func applyOrganizationRules(for fileURL: URL, imageSize: CGSize) {
        let rulesManager = OrganizationRulesManager.shared
        let captureType = determineCaptureType(size: imageSize)
        
        guard let subfolder = rulesManager.determineFolder(for: imageSize, captureType: captureType) else {
            return
        }
        
        // Create subfolder if needed
        let baseFolder = getScreenGrabberFolderURL()
        let targetFolder = baseFolder.appendingPathComponent(subfolder)
        
        do {
            try FileManager.default.createDirectory(at: targetFolder, withIntermediateDirectories: true)
            
            // Move file to subfolder
            let targetPath = targetFolder.appendingPathComponent(fileURL.lastPathComponent)
            try FileManager.default.moveItem(at: fileURL, to: targetPath)
            
            print("[ORG] Moved to: \(subfolder)/\(fileURL.lastPathComponent)")
        } catch {
            print("[ERR] Organization failed: \(error)")
        }
    }
    
    // MARK: - Determine Capture Type
    private func determineCaptureType(size: CGSize) -> String {
        // Get screen dimensions
        guard let screen = NSScreen.main else { return "unknown" }
        let screenSize = screen.frame.size
        
        // Check if full screen
        if abs(size.width - screenSize.width) < 10 && abs(size.height - screenSize.height) < 10 {
            return "fullscreen"
        }
        
        // Check if it's a window (reasonable window dimensions)
        if size.width > 200 && size.height > 100 && size.width < screenSize.width && size.height < screenSize.height {
            return "window"
        }
        
        return "region"
    }
    
    // MARK: - Format Conversion
    private func convertLastScreenshot(to profile: CompressionProfile) {
        guard let lastScreenshot = getLastScreenshotURL(),
              let image = NSImage(contentsOf: lastScreenshot) else {
            return
        }
        
        let newURL = lastScreenshot.deletingPathExtension().appendingPathExtension(profile.fileExtension)
        
        if saveImage(image, to: newURL, as: profile) {
            // Delete original PNG if conversion successful
            try? FileManager.default.removeItem(at: lastScreenshot)
            print("[CONV] Converted to: \(profile.rawValue)")
        }
    }
    
    // MARK: - Save Image with Format
    private func saveImage(_ image: NSImage, to url: URL, as profile: CompressionProfile) -> Bool {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return false
        }
        
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        
        var imageData: Data?
        
        switch profile {
        case .highQualityPNG:
            imageData = bitmapRep.representation(using: .png, properties: [:])
        case .compressedPNG:
            imageData = bitmapRep.representation(using: .png, properties: [.compressionFactor: 0.7])
        case .jpeg90, .jpeg70, .jpeg50:
            imageData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: profile.quality])
        case .heif:
            // Note: HEIF requires macOS 10.13+
            if #available(macOS 10.13, *) {
                let ciImage = CIImage(cgImage: cgImage)
                let context = CIContext()
                imageData = context.heifRepresentation(of: ciImage, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
            }
        case .webp:
            // WebP would require additional framework
            print("[WARN] WebP format not yet implemented, falling back to JPEG")
            imageData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
        }
        
        guard let data = imageData else { return false }
        
        do {
            try data.write(to: url)
            return true
        } catch {
            print("[ERR] Failed to save image: \(error)")
            return false
        }
    }
    
    // MARK: - Countdown Notification
    private func showCountdownNotification(seconds: Int) {
        let notification = NSUserNotification()
        notification.title = "Screenshot in \(seconds) seconds..."
        notification.informativeText = "Get ready!"
        notification.soundName = nil
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    // MARK: - Get Last Screenshot URL
    func getLastScreenshotURL() -> URL? {
        let screenshots = loadRecentScreenshots()
        return screenshots.first
    }
    
    // MARK: - Handle Open Option
    private func handleOpenOption(_ option: OpenOption, for fileURL: URL?) {
        guard let fileURL = fileURL else { return }
        
        switch option {
        case .clipboard:
            if let image = NSImage(contentsOf: fileURL) {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.writeObjects([image])
            }
        case .preview:
            NSWorkspace.shared.open(fileURL)
        case .saveToFile:
            break // Already saved
        }
    }
    
    // MARK: - Save to Database
    private func saveToDatabase(fileURL: URL, modelContext: ModelContext) {
        // This would integrate with your SwiftData Screenshot model
        print("[DB] Saving to database: \(fileURL.lastPathComponent)")
    }
}

// MARK: - NSImage Extension for CGImage
extension NSImage {
    var cgImage: CGImage? {
        var rect = CGRect(origin: .zero, size: self.size)
        return self.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}
