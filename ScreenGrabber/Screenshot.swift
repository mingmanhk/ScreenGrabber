//
//  Screenshot.swift
//  ScreenGrabber
//
//  Created by Victor Lam on 10/23/25.
//

import Foundation
import SwiftData

@Model
final class Screenshot {
    var filename: String
    var filePath: String
    var captureDate: Date
    var captureMethod: String // "selected_area", "window", "full_screen", "scrolling_capture"
    var openMethod: String // "clipboard", "save_to_file", "preview"

    // OCR & Search features
    var extractedText: String?
    var searchableKeywords: [String]
    var isOCRProcessed: Bool
    var ocrProcessedDate: Date?

    // Collaboration features
    var collaborationId: String?
    var collaborationURL: String?
    var sharedWith: [String]
    var annotations: Data? // Serialized annotation data for collaboration

    // Organization & Tagging
    var tags: [String]
    var projectName: String?
    var category: String?
    var isFavorite: Bool

    // Sharing features
    var shareLinks: [String]
    var lastSharedDate: Date?
    var shareCount: Int

    // Metadata
    var fileSize: Int64
    var dimensions: String? // e.g., "1920x1080"
    var notes: String?

    init(filename: String, filePath: String, captureDate: Date, captureMethod: String, openMethod: String) {
        self.filename = filename
        self.filePath = filePath
        self.captureDate = captureDate
        self.captureMethod = captureMethod
        self.openMethod = openMethod

        // Initialize new properties
        self.extractedText = nil
        self.searchableKeywords = []
        self.isOCRProcessed = false
        self.ocrProcessedDate = nil

        self.collaborationId = nil
        self.collaborationURL = nil
        self.sharedWith = []
        self.annotations = nil

        self.tags = []
        self.projectName = nil
        self.category = nil
        self.isFavorite = false

        self.shareLinks = []
        self.lastSharedDate = nil
        self.shareCount = 0

        self.fileSize = 0
        self.dimensions = nil
        self.notes = nil
    }
}