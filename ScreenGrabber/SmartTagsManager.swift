//
//  SmartTagsManager.swift
//  ScreenGrabber
//
//  Smart Tags - Automatic and manual tagging system
//

import Foundation
import AppKit
import Vision
import CoreML

class SmartTagsManager: ObservableObject {
    static let shared = SmartTagsManager()

    @Published var allTags: [String] = []
    @Published var autoTaggingEnabled = true

    private init() {
        loadSettings()
        loadAllTags()
    }

    // MARK: - Settings

    private func loadSettings() {
        autoTaggingEnabled = UserDefaults.standard.object(forKey: "autoTaggingEnabled") as? Bool ?? true

        if let savedTags = UserDefaults.standard.array(forKey: "allKnownTags") as? [String] {
            allTags = savedTags
        }
    }

    func saveSettings() {
        UserDefaults.standard.set(autoTaggingEnabled, forKey: "autoTaggingEnabled")
        UserDefaults.standard.set(allTags, forKey: "allKnownTags")
    }

    private func loadAllTags() {
        if let savedTags = UserDefaults.standard.array(forKey: "allKnownTags") as? [String] {
            allTags = savedTags
        }
    }

    func saveAllTags() {
        UserDefaults.standard.set(allTags, forKey: "allKnownTags")
    }

    // MARK: - Auto Tagging

    /// Generate automatic tags for a screenshot
    func generateAutoTags(for image: NSImage, captureMethod: String, filename: String) -> [String] {
        guard autoTaggingEnabled else { return [] }

        var tags: [String] = []

        // Tag by capture method
        switch captureMethod {
        case "selected_area":
            tags.append("selection")
        case "window":
            tags.append("window")
        case "full_screen":
            tags.append("fullscreen")
        case "scrolling_capture":
            tags.append("scroll")
        default:
            break
        }

        // Tag by image dimensions
        let size = image.size
        let aspectRatio = size.width / size.height

        if aspectRatio > 2.0 {
            tags.append("ultrawide")
        } else if aspectRatio > 1.5 {
            tags.append("wide")
        } else if abs(aspectRatio - 1.0) < 0.1 {
            tags.append("square")
        } else if aspectRatio < 0.7 {
            tags.append("portrait")
        }

        // Tag by size
        let area = size.width * size.height
        if area < 500 * 500 {
            tags.append("small")
        } else if area > 2000 * 2000 {
            tags.append("large")
        }

        // Tag by content (using OCR)
        if let extractedText = extractText(from: image) {
            let contentTags = analyzeContent(extractedText)
            tags.append(contentsOf: contentTags)
        }

        // Tag by filename keywords
        let filenameTags = extractKeywordsFromFilename(filename)
        tags.append(contentsOf: filenameTags)

        // Tag by date/time
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 6 {
            tags.append("night")
        } else if hour < 12 {
            tags.append("morning")
        } else if hour < 18 {
            tags.append("afternoon")
        } else {
            tags.append("evening")
        }

        // Update known tags
        for tag in tags {
            if !allTags.contains(tag) {
                allTags.append(tag)
            }
        }
        saveAllTags()

        return Array(Set(tags)) // Remove duplicates
    }

    // MARK: - Content Analysis

    private func extractText(from image: NSImage) -> String? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])

            guard let observations = request.results else { return nil }

            let text = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: " ")

            return text.isEmpty ? nil : text
        } catch {
            print("Error extracting text: \(error)")
            return nil
        }
    }

    private func analyzeContent(_ text: String) -> [String] {
        var tags: [String] = []

        let lowercased = text.lowercased()

        // Code-related keywords
        let codeKeywords = ["func", "class", "var", "let", "import", "return", "def", "function", "const", "public", "private"]
        if codeKeywords.contains(where: { lowercased.contains($0) }) {
            tags.append("code")
        }

        // Error/warning keywords
        if lowercased.contains("error") || lowercased.contains("warning") || lowercased.contains("failed") {
            tags.append("error")
        }

        // Success keywords
        if lowercased.contains("success") || lowercased.contains("complete") || lowercased.contains("done") {
            tags.append("success")
        }

        // App detection
        let appKeywords: [String: String] = [
            "xcode": "xcode",
            "safari": "safari",
            "chrome": "chrome",
            "firefox": "firefox",
            "terminal": "terminal",
            "slack": "slack",
            "figma": "figma",
            "photoshop": "photoshop",
            "vscode": "vscode",
            "sublime": "editor"
        ]

        for (keyword, tag) in appKeywords {
            if lowercased.contains(keyword) {
                tags.append(tag)
            }
        }

        // UI elements
        if lowercased.contains("button") || lowercased.contains("menu") || lowercased.contains("dialog") {
            tags.append("ui")
        }

        // Documentation
        if lowercased.contains("documentation") || lowercased.contains("readme") || lowercased.contains("guide") {
            tags.append("docs")
        }

        // Web content
        if lowercased.contains("http") || lowercased.contains("www") || lowercased.contains(".com") {
            tags.append("web")
        }

        // Email content
        if lowercased.contains("@") && lowercased.contains(".") {
            tags.append("email")
        }

        return tags
    }

    private func extractKeywordsFromFilename(_ filename: String) -> [String] {
        var tags: [String] = []

        let lowercased = filename.lowercased()

        // Common keywords
        let keywords: [String: String] = [
            "bug": "bug",
            "fix": "fix",
            "design": "design",
            "mockup": "mockup",
            "wireframe": "wireframe",
            "diagram": "diagram",
            "chart": "chart",
            "graph": "graph",
            "report": "report",
            "dashboard": "dashboard",
            "settings": "settings",
            "config": "config"
        ]

        for (keyword, tag) in keywords {
            if lowercased.contains(keyword) {
                tags.append(tag)
            }
        }

        return tags
    }

    // MARK: - Tag Management

    func addTag(_ tag: String) {
        let normalized = tag.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.isEmpty && !allTags.contains(normalized) {
            allTags.append(normalized)
            saveAllTags()
        }
    }

    func removeTag(_ tag: String) {
        allTags.removeAll { $0 == tag }
        saveAllTags()
    }

    func suggestTags(for searchText: String) -> [String] {
        guard !searchText.isEmpty else { return allTags }

        let lowercased = searchText.lowercased()
        return allTags.filter { $0.lowercased().contains(lowercased) }
    }

    // MARK: - Common Tags

    static let commonTags = [
        "bug", "feature", "design", "ui", "ux", "error",
        "code", "docs", "meeting", "notes", "important",
        "todo", "review", "draft", "final", "archive"
    ]
}
