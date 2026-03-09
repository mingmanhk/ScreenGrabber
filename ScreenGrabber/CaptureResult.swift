//
//  CaptureResult.swift
//  ScreenGrabber
//
//  Data model for a completed capture.
//

import AppKit

struct CaptureResult: Identifiable {
    let id = UUID()
    let image: NSImage
    let timestamp: Date
    let mode: CaptureMode
    var recognizedText: String? // Added for OCR requirement
    
    enum CaptureMode: String {
        case area
        case window
        case fullscreen
        case scrolling
    }
    
    // MARK: - Initializers
    
    init(image: NSImage, timestamp: Date = Date(), mode: CaptureMode, recognizedText: String? = nil) {
        self.image = image
        self.timestamp = timestamp
        self.mode = mode
        self.recognizedText = recognizedText
    }
    
    init?(imageURL: URL) {
        guard let image = NSImage(contentsOf: imageURL) else {
            return nil
        }
        
        // Try to get creation date from file
        let timestamp: Date
        if let attributes = try? FileManager.default.attributesOfItem(atPath: imageURL.path),
           let creationDate = attributes[.creationDate] as? Date {
            timestamp = creationDate
        } else {
            timestamp = Date()
        }
        
        // Try to detect mode from filename
        let filename = imageURL.lastPathComponent
        let mode: CaptureMode
        if filename.contains("Scroll") {
            mode = .scrolling
        } else if filename.contains("Full") {
            mode = .fullscreen
        } else {
            mode = .area
        }
        
        // Try to load OCR text from extended attributes
        let ocrText = ScreenCaptureManager.shared.getOCRText(for: imageURL)
        
        self.init(image: image, timestamp: timestamp, mode: mode, recognizedText: ocrText)
    }
}
