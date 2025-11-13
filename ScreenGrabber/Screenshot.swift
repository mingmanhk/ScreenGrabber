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

    // Smart Tags - Automatic and manual tagging system
    var tags: [String] = []
    var autoTags: [String] = [] // Automatically generated tags

    // Project Workspaces
    var projectName: String?

    // Multi-Monitor Control
    var displayID: String?
    var displayName: String?

    // Auto-Trim / Smart Crop
    var isAutoTrimmed: Bool = false
    var originalDimensions: String? // "widthxheight" format

    init(filename: String, filePath: String, captureDate: Date, captureMethod: String, openMethod: String, tags: [String] = [], autoTags: [String] = [], projectName: String? = nil, displayID: String? = nil, displayName: String? = nil, isAutoTrimmed: Bool = false, originalDimensions: String? = nil) {
        self.filename = filename
        self.filePath = filePath
        self.captureDate = captureDate
        self.captureMethod = captureMethod
        self.openMethod = openMethod
        self.tags = tags
        self.autoTags = autoTags
        self.projectName = projectName
        self.displayID = displayID
        self.displayName = displayName
        self.isAutoTrimmed = isAutoTrimmed
        self.originalDimensions = originalDimensions
    }

    /// Returns all tags (manual + auto)
    var allTags: [String] {
        Array(Set(tags + autoTags)).sorted()
    }

    /// Add a manual tag
    func addTag(_ tag: String) {
        if !tags.contains(tag) && !tag.isEmpty {
            tags.append(tag)
        }
    }

    /// Remove a manual tag
    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
}