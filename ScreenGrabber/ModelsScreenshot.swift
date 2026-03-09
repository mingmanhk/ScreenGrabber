//
//  Screenshot.swift
//  ScreenGrabber
//
//  Complete SwiftData model for captured screenshots
//  PRODUCTION-READY IMPLEMENTATION
//

import Foundation
import SwiftData
import AppKit

@Model
final class Screenshot {
    // MARK: - Identity
    var id: UUID
    var timestamp: Date
    
    // MARK: - File Information
    var filename: String
    var filePath: String
    var fileSize: Int64
    
    // MARK: - Capture Details
    var captureType: String  // "area", "window", "fullscreen", "scrolling"
    var width: Int
    var height: Int
    var sourceDisplay: String?  // Display name for multi-monitor
    var sourceWindow: String?   // Window title for window captures
    var openMethod: String?     // How the screenshot was opened/saved
    var thumbnailPath: String?  // Path to thumbnail file (for compatibility)
    
    // MARK: - Metadata
    var displayName: String?
    var notes: String?
    var tags: [String]
    var isFavorite: Bool
    
    // MARK: - Thumbnail & Preview
    @Attribute(.externalStorage)
    var thumbnailData: Data?
    
    @Attribute(.externalStorage)
    var previewData: Data?  // Medium-size preview
    
    // MARK: - OCR Data
    var ocrText: String?
    var ocrLanguage: String?
    var ocrConfidence: Double?
    
    // MARK: - Edit History
    var editCount: Int
    var lastEditedAt: Date?
    var hasAnnotations: Bool
    
    // MARK: - Relationships
    @Relationship(deleteRule: .cascade, inverse: \Annotation.screenshot)
    var annotations: [Annotation]?
    
    // MARK: - Computed Properties
    var fileURL: URL {
        URL(fileURLWithPath: filePath)
    }
    
    // Compatibility property for code expecting captureDate
    var captureDate: Date {
        get { timestamp }
        set { timestamp = newValue }
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    var annotationCount: Int {
        annotations?.count ?? 0
    }
    
    var aspectRatio: Double {
        guard height > 0 else { return 1.0 }
        return Double(width) / Double(height)
    }
    
    var isLandscape: Bool {
        width > height
    }
    
    var isPortrait: Bool {
        height > width
    }
    
    var isTallCapture: Bool {
        // Consider tall if height is more than 2x width
        height > width * 2
    }
    
    // MARK: - Initialization
    init(
        filename: String,
        filePath: String,
        captureType: String,
        width: Int,
        height: Int,
        fileSize: Int64 = 0,
        timestamp: Date = Date(),
        sourceDisplay: String? = nil,
        sourceWindow: String? = nil,
        thumbnailPath: String? = nil,
        captureDate: Date? = nil,
        openMethod: String? = nil
    ) {
        self.id = UUID()
        self.filename = filename
        self.filePath = filePath
        self.captureType = captureType
        self.width = width
        self.height = height
        self.fileSize = fileSize
        self.timestamp = captureDate ?? timestamp
        self.sourceDisplay = sourceDisplay
        self.sourceWindow = sourceWindow
        self.thumbnailPath = thumbnailPath
        self.openMethod = openMethod
        self.tags = []
        self.isFavorite = false
        self.editCount = 0
        self.hasAnnotations = false
    }
    
    // MARK: - Thumbnail Generation
    @MainActor
    func generateThumbnail(maxSize: CGSize = CGSize(width: 400, height: 400)) async {
        guard let image = NSImage(contentsOf: fileURL) else {
            print("[SCREENSHOT] ❌ Failed to load image for thumbnail: \(filePath)")
            return
        }
        
        let thumbnailData = await Task.detached(priority: .utility) {
            self.createThumbnail(from: image, maxSize: maxSize)
        }.value
        
        self.thumbnailData = thumbnailData
    }
    
    @MainActor
    func generatePreview(maxSize: CGSize = CGSize(width: 1200, height: 1200)) async {
        guard let image = NSImage(contentsOf: fileURL) else {
            print("[SCREENSHOT] ❌ Failed to load image for preview: \(filePath)")
            return
        }
        
        let previewData = await Task.detached(priority: .utility) {
            self.createThumbnail(from: image, maxSize: maxSize)
        }.value
        
        self.previewData = previewData
    }
    
    private func createThumbnail(from image: NSImage, maxSize: CGSize) -> Data? {
        let aspectRatio = image.size.width / image.size.height
        var thumbnailSize = maxSize
        
        if aspectRatio > 1 {
            thumbnailSize.height = maxSize.width / aspectRatio
        } else {
            thumbnailSize.width = maxSize.height * aspectRatio
        }
        
        let thumbnailImage = NSImage(size: thumbnailSize)
        thumbnailImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: thumbnailSize))
        thumbnailImage.unlockFocus()
        
        return thumbnailImage.tiffRepresentation
    }
    
    // MARK: - OCR Integration
    @MainActor
    func extractText() async {
        guard let image = NSImage(contentsOf: fileURL) else {
            print("[SCREENSHOT] ❌ Failed to load image for OCR: \(filePath)")
            return
        }

        do {
            if let result = try await OCRManager.shared.extractTextWithConfidence(from: image) {
                self.ocrText = result.text
                self.ocrLanguage = "en-US"
                self.ocrConfidence = result.confidence
                print("[SCREENSHOT] ✅ OCR extracted \(result.text.count) characters with \(Int(result.confidence * 100))% confidence")
            } else {
                print("[SCREENSHOT] ℹ️ No text found in image")
                self.ocrText = nil
            }
        } catch {
            print("[SCREENSHOT] ⚠️ OCR failed: \(error.localizedDescription)")
            self.ocrText = nil
        }
    }
    
    // MARK: - Annotation Management
    func addAnnotation(_ annotation: Annotation) {
        if annotations == nil {
            annotations = []
        }
        annotations?.append(annotation)
        annotation.screenshot = self
        
        hasAnnotations = true
        editCount += 1
        lastEditedAt = Date()
    }
    
    func removeAnnotation(_ annotation: Annotation) {
        annotations?.removeAll { $0.id == annotation.id }
        hasAnnotations = !(annotations?.isEmpty ?? true)
        editCount += 1
        lastEditedAt = Date()
    }
    
    /// Save/replace all annotations for this screenshot
    func saveAnnotations(_ newAnnotations: [Annotation]) {
        // Remove existing annotations
        self.annotations?.removeAll()
        
        // Add new annotations
        for annotation in newAnnotations {
            addAnnotation(annotation)
        }
    }
    
    // MARK: - Metadata Updates
    func updateMetadata(displayName: String? = nil, notes: String? = nil, tags: [String]? = nil) {
        if let displayName = displayName {
            self.displayName = displayName
        }
        if let notes = notes {
            self.notes = notes
        }
        if let tags = tags {
            self.tags = tags
        }
        lastEditedAt = Date()
    }
    
    func toggleFavorite() {
        isFavorite.toggle()
    }
}

// MARK: - Query Helpers
extension Screenshot {
    static func all(context: ModelContext) -> [Screenshot] {
        let descriptor = FetchDescriptor<Screenshot>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    static func recent(limit: Int, context: ModelContext) -> [Screenshot] {
        let descriptor = FetchDescriptor<Screenshot>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return Array((try? context.fetch(descriptor))?.prefix(limit) ?? [])
    }
    
    static func byType(_ type: String, context: ModelContext) -> [Screenshot] {
        let predicate = #Predicate<Screenshot> { screenshot in
            screenshot.captureType == type
        }
        let descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    static func favorites(context: ModelContext) -> [Screenshot] {
        let predicate = #Predicate<Screenshot> { screenshot in
            screenshot.isFavorite == true
        }
        let descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    static func withAnnotations(context: ModelContext) -> [Screenshot] {
        let predicate = #Predicate<Screenshot> { screenshot in
            screenshot.hasAnnotations == true
        }
        let descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    static func search(_ query: String, context: ModelContext) -> [Screenshot] {
        // Fetch all screenshots first, then filter in memory
        // This is necessary because lowercased() is not supported in SwiftData predicates
        let descriptor = FetchDescriptor<Screenshot>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        guard let allScreenshots = try? context.fetch(descriptor) else { return [] }
        
        let lowercaseQuery = query.lowercased()
        return allScreenshots.filter { screenshot in
            screenshot.filename.lowercased().contains(lowercaseQuery) ||
            screenshot.displayName?.lowercased().contains(lowercaseQuery) == true ||
            screenshot.notes?.lowercased().contains(lowercaseQuery) == true ||
            screenshot.ocrText?.lowercased().contains(lowercaseQuery) == true
        }
    }
    
    static func tagged(with tag: String, context: ModelContext) -> [Screenshot] {
        let predicate = #Predicate<Screenshot> { screenshot in
            screenshot.tags.contains(tag)
        }
        let descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}

// MARK: - File Management
extension Screenshot {
    func delete() throws {
        // Delete file from disk
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: filePath) {
            try fileManager.removeItem(at: fileURL)
            print("[SCREENSHOT] ✅ Deleted file: \(filename)")
        }
    }
    
    func duplicate() -> URL? {
        let fileManager = FileManager.default
        let directory = fileURL.deletingLastPathComponent()
        let ext = fileURL.pathExtension
        let baseName = fileURL.deletingPathExtension().lastPathComponent
        let newName = "\(baseName)_copy.\(ext)"
        let newURL = directory.appendingPathComponent(newName)
        
        do {
            try fileManager.copyItem(at: fileURL, to: newURL)
            print("[SCREENSHOT] ✅ Duplicated to: \(newName)")
            return newURL
        } catch {
            print("[SCREENSHOT] ❌ Failed to duplicate: \(error)")
            return nil
        }
    }
    
    func rename(to newName: String) throws {
        let fileManager = FileManager.default
        let directory = fileURL.deletingLastPathComponent()
        let ext = fileURL.pathExtension
        let newFilename = newName.hasSuffix(".\(ext)") ? newName : "\(newName).\(ext)"
        let newURL = directory.appendingPathComponent(newFilename)
        
        try fileManager.moveItem(at: fileURL, to: newURL)
        
        self.filename = newFilename
        self.filePath = newURL.path
        
        print("[SCREENSHOT] ✅ Renamed to: \(newFilename)")
    }
    
    func showInFinder() {
        NSWorkspace.shared.selectFile(filePath, inFileViewerRootedAtPath: fileURL.deletingLastPathComponent().path)
    }
    
    func copyImageToClipboard() {
        guard let image = NSImage(contentsOf: fileURL) else {
            print("[SCREENSHOT] ❌ Failed to load image for clipboard")
            return
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        
        print("[SCREENSHOT] ✅ Copied to clipboard")
    }
}

// MARK: - Equatable
extension Screenshot: Equatable {
    static func == (lhs: Screenshot, rhs: Screenshot) -> Bool {
        lhs.id == rhs.id
    }
}

