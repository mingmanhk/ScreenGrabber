//
//  LegacyUnifiedCaptureManager.swift (Deprecated - Use UnifiedCaptureManager 2.swift)
//  ScreenGrabber
//
//  Unified capture pipeline for all capture types
//  Created on 1/9/26.
//

import Foundation
import AppKit
import SwiftData
import UserNotifications

// Compatibility alias for code still using UnifiedCaptureManager
typealias UnifiedCaptureManager = LegacyUnifiedCaptureManager

/// Legacy unified capture manager (deprecated)
/// Use UnifiedCaptureManager from UnifiedCaptureManager 2.swift instead
@MainActor
class LegacyUnifiedCaptureManager {
    static let shared = LegacyUnifiedCaptureManager()
    
    // MARK: - Configuration
    
    private let captureFolder = "Screen Grabber"
    private let thumbnailSize = CGSize(width: 200, height: 200)
    
    // MARK: - Capture Metadata
    
    struct CaptureMetadata {
        let captureType: CaptureType
        let timestamp: Date
        let image: NSImage
        
        enum CaptureType: String {
            case fullScreen = "Full Screen"
            case area = "Area"
            case window = "Window"
            case scrolling = "Scrolling"
        }
    }
    
    // MARK: - Storage Paths
    
    public func getCapturesFolderURL() async -> URL? {
        // Use the permissions manager to ensure folder exists with user consent
        let result = await FolderPermissionsManager.shared.ensureScreenGrabberFolder()
        
        switch result {
        case .success(let url):
            return url
        case .failure(let error):
            print("[CAPTURE] ❌ Folder access error: \(error.localizedDescription)")
            return nil
        }
    }
    
    public func getThumbnailsFolderURL() async -> URL? {
        guard let capturesFolder = await getCapturesFolderURL() else {
            return nil
        }
        
        let thumbnailsFolder = capturesFolder.appendingPathComponent(".thumbnails")
        
        // Create thumbnails folder if it doesn't exist
        if !FileManager.default.fileExists(atPath: thumbnailsFolder.path) {
            do {
                try FileManager.default.createDirectory(at: thumbnailsFolder, withIntermediateDirectories: true)
                print("[CAPTURE] ✅ Created thumbnails folder: \(thumbnailsFolder.path)")
            } catch {
                print("[CAPTURE] ❌ Failed to create thumbnails folder: \(error.localizedDescription)")
                return nil
            }
        }
        
        return thumbnailsFolder
    }
    
    // MARK: - Unified Capture Pipeline
    
    /// Main capture function used by all capture types
    /// - Parameters:
    ///   - metadata: Capture metadata including image and type
    ///   - modelContext: SwiftData context for persistence
    ///   - copyToClipboard: Whether to also copy to clipboard
    /// - Returns: URL of saved file, or nil if failed
    @discardableResult
    func saveCapture(
        _ metadata: CaptureMetadata,
        to modelContext: ModelContext?,
        copyToClipboard: Bool = false
    ) async -> URL? {
        
        print("[CAPTURE] 🚀 Starting unified capture pipeline")
        print("[CAPTURE] Type: \(metadata.captureType.rawValue)")
        
        // STEP 1: Ensure folder exists with user permission
        guard let capturesFolder = await getCapturesFolderURL() else {
            print("[CAPTURE] ❌ Cannot access captures folder")
            await showNotification(title: "Error", message: "Cannot access screenshot folder. Please check Settings.")
            return nil
        }
        
        // STEP 2: Generate filename
        let filename = generateFilename(for: metadata)
        let fileURL = capturesFolder.appendingPathComponent(filename)
        
        print("[CAPTURE] Target file: \(fileURL.path)")
        
        // STEP 3: Save image to disk
        guard savePNGImage(metadata.image, to: fileURL) else {
            print("[CAPTURE] ❌ Failed to save image to disk")
            await showNotification(title: "Error", message: "Failed to save screenshot")
            return nil
        }
        
        // STEP 3a: Verify file was saved
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("[CAPTURE] ❌ File verification failed - file not found")
            await showNotification(title: "Error", message: "Screenshot file not created")
            return nil
        }
        
        // STEP 3b: Verify file has content
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            if let fileSize = attributes[.size] as? Int64 {
                if fileSize == 0 {
                    print("[CAPTURE] ❌ File is empty (0 bytes)")
                    await showNotification(title: "Error", message: "Screenshot file is empty")
                    return nil
                }
                print("[CAPTURE] ✅ Image saved to disk: \(filename) (\(fileSize) bytes)")
            }
        } catch {
            print("[CAPTURE] ⚠️ Could not verify file size: \(error.localizedDescription)")
            // Continue anyway since file exists
        }
        
        print("[CAPTURE] ✅ File verified at: \(fileURL.path)")
        
        // STEP 4: Generate thumbnail
        let thumbnailURL = await generateThumbnail(for: metadata.image, filename: filename)
        print("[CAPTURE] ✅ Thumbnail generated: \(thumbnailURL?.lastPathComponent ?? "none")")
        
        // STEP 5: Copy to clipboard if requested
        if copyToClipboard {
            await copyImageToClipboard(metadata.image)
            print("[CAPTURE] ✅ Copied to clipboard")
        }
        
        // STEP 6: Save to history database
        await saveToHistory(
            fileURL: fileURL,
            thumbnailURL: thumbnailURL,
            metadata: metadata,
            modelContext: modelContext
        )
        
        // STEP 7: Post notification for UI updates
        await postCaptureNotification(fileURL: fileURL)
        
        // STEP 8: Show success notification to user
        await showNotification(
            title: "Screenshot Saved",
            message: "\(metadata.captureType.rawValue) capture saved"
        )
        
        print("[CAPTURE] ✅ Pipeline complete: \(filename)")
        
        return fileURL
    }
    
    // MARK: - Step Implementations
    
    private func generateFilename(for metadata: CaptureMetadata) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = dateFormatter.string(from: metadata.timestamp)
        
        let prefix: String
        switch metadata.captureType {
        case .fullScreen:
            prefix = "ScreenGrab"
        case .area:
            prefix = "AreaGrab"
        case .window:
            prefix = "WindowGrab"
        case .scrolling:
            prefix = "ScrollGrab"
        }
        
        return "\(prefix)_\(dateString).png"
    }
    
    private func savePNGImage(_ image: NSImage, to url: URL) -> Bool {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            print("[CAPTURE] ❌ Failed to convert image to PNG")
            return false
        }
        
        do {
            try pngData.write(to: url)
            return true
        } catch {
            print("[CAPTURE] ❌ Failed to write PNG: \(error.localizedDescription)")
            return false
        }
    }
    
    private func generateThumbnail(for image: NSImage, filename: String) async -> URL? {
        guard let thumbnailsFolder = await getThumbnailsFolderURL() else {
            print("[CAPTURE] ⚠️ Cannot access thumbnails folder")
            return nil
        }
        
        let thumbnailURL = thumbnailsFolder.appendingPathComponent(filename)
        
        // Calculate thumbnail size maintaining aspect ratio
        let imageSize = image.size
        let aspectRatio = imageSize.width / imageSize.height
        
        let thumbnailWidth: CGFloat
        let thumbnailHeight: CGFloat
        
        if aspectRatio > 1 {
            // Landscape
            thumbnailWidth = thumbnailSize.width
            thumbnailHeight = thumbnailSize.width / aspectRatio
        } else {
            // Portrait or square
            thumbnailHeight = thumbnailSize.height
            thumbnailWidth = thumbnailSize.height * aspectRatio
        }
        
        let finalThumbnailSize = NSSize(width: thumbnailWidth, height: thumbnailHeight)
        
        // Create thumbnail
        let thumbnail = NSImage(size: finalThumbnailSize)
        thumbnail.lockFocus()
        
        image.draw(
            in: NSRect(origin: .zero, size: finalThumbnailSize),
            from: NSRect(origin: .zero, size: imageSize),
            operation: .copy,
            fraction: 1.0
        )
        
        thumbnail.unlockFocus()
        
        // Save thumbnail
        guard savePNGImage(thumbnail, to: thumbnailURL) else {
            print("[CAPTURE] ⚠️ Failed to save thumbnail")
            return nil
        }
        
        return thumbnailURL
    }
    
    private func copyImageToClipboard(_ image: NSImage) async {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }
    
    private func saveToHistory(
        fileURL: URL,
        thumbnailURL: URL?,
        metadata: CaptureMetadata,
        modelContext: ModelContext?
    ) async {
        guard let context = modelContext else {
            print("[HISTORY] ⚠️ No ModelContext provided - screenshot will not be saved to history")
            return
        }
        
        // Create Screenshot model
        let screenshot = Screenshot(
            filename: fileURL.lastPathComponent,
            filePath: fileURL.path,
            captureType: metadata.captureType.rawValue.lowercased(),  // e.g., "fullscreen", "area", "window", "scrolling"
            width: Int(metadata.image.size.width),
            height: Int(metadata.image.size.height),
            captureDate: metadata.timestamp,
            openMethod: "save_to_file"  // Always saved to file in this pipeline
        )
        
        // Insert and save
        context.insert(screenshot)
        
        do {
            try context.save()
            print("[HISTORY] ✅ Saved to database: \(fileURL.lastPathComponent)")
            
            // Post history update notification
            NotificationCenter.default.post(
                name: .screenshotSavedToHistory,
                object: nil,
                userInfo: [
                    "screenshot": screenshot,
                    "url": fileURL,
                    "thumbnailURL": thumbnailURL as Any
                ]
            )
        } catch {
            print("[HISTORY] ❌ Failed to save to database: \(error.localizedDescription)")
        }
    }
    
    private func postCaptureNotification(fileURL: URL) async {
        NotificationCenter.default.post(
            name: .screenshotCaptured,
            object: nil,
            userInfo: ["url": fileURL]
        )
        
        print("[CAPTURE] 📢 Posted capture notification")
    }
    
    private func showNotification(title: String, message: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("[CAPTURE] ⚠️ Failed to show notification: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Load History
    
    /// Load all captures from SwiftData
    func loadCaptureHistory(from context: ModelContext) -> [Screenshot] {
        let descriptor = FetchDescriptor<Screenshot>(
            sortBy: [SortDescriptor(\.captureDate, order: .reverse)]
        )
        
        do {
            let screenshots = try context.fetch(descriptor)
            print("[HISTORY] ✅ Loaded \(screenshots.count) captures from database")
            return screenshots
        } catch {
            print("[HISTORY] ❌ Failed to load history: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Load thumbnail for a screenshot
    func loadThumbnail(for screenshot: Screenshot) async -> NSImage? {
        guard let thumbnailsFolder = await getThumbnailsFolderURL() else {
            return nil
        }
        
        let thumbnailURL = thumbnailsFolder.appendingPathComponent(screenshot.filename)
        
        if let thumbnail = NSImage(contentsOf: thumbnailURL) {
            return thumbnail
        }
        
        // Fallback: Generate thumbnail from original image
        if let originalImage = NSImage(contentsOfFile: screenshot.filePath) {
            print("[CAPTURE] Generating thumbnail on-demand for \(screenshot.filename)")
            
            Task {
                _ = await generateThumbnail(for: originalImage, filename: screenshot.filename)
            }
            
            // Return a temporary thumbnail
            return generateQuickThumbnail(from: originalImage)
        }
        
        return nil
    }
    
    private func generateQuickThumbnail(from image: NSImage) -> NSImage {
        let thumbnail = NSImage(size: thumbnailSize)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: thumbnailSize))
        thumbnail.unlockFocus()
        return thumbnail
    }
    
    // MARK: - Cleanup
    
    /// Delete old captures beyond a certain count or age
    func cleanupOldCaptures(keepRecent: Int = 100, olderThanDays: Int = 30, context: ModelContext) async {
        let allScreenshots = loadCaptureHistory(from: context)
        
        guard let thumbnailsFolder = await getThumbnailsFolderURL() else {
            print("[CLEANUP] ⚠️ Cannot access thumbnails folder")
            return
        }
        
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -olderThanDays, to: Date()) ?? Date()
        
        var deletedCount = 0
        
        // Delete old screenshots beyond keep limit
        if allScreenshots.count > keepRecent {
            let toDelete = allScreenshots.dropFirst(keepRecent)
            
            for screenshot in toDelete {
                // Delete file
                try? FileManager.default.removeItem(atPath: screenshot.filePath)
                
                // Delete thumbnail
                let thumbnailPath = thumbnailsFolder.appendingPathComponent(screenshot.filename).path
                try? FileManager.default.removeItem(atPath: thumbnailPath)
                
                // Delete from database
                context.delete(screenshot)
                deletedCount += 1
            }
        }
        
        // Delete screenshots older than cutoff date
        for screenshot in allScreenshots {
            if screenshot.captureDate < cutoffDate {
                try? FileManager.default.removeItem(atPath: screenshot.filePath)
                
                let thumbnailPath = thumbnailsFolder.appendingPathComponent(screenshot.filename).path
                try? FileManager.default.removeItem(atPath: thumbnailPath)
                
                context.delete(screenshot)
                deletedCount += 1
            }
        }
        
        if deletedCount > 0 {
            do {
                try context.save()
                print("[CLEANUP] ✅ Deleted \(deletedCount) old captures")
            } catch {
                print("[CLEANUP] ❌ Failed to save after cleanup: \(error.localizedDescription)")
            }
        }
    }
}

