//
//  SearchIndexManager.swift
//  ScreenGrabber
//
//  Search index manager for OCR text extraction and search
//

import Foundation
import SwiftData
import AppKit
import Vision

// MARK: - Search Index Manager
class SearchIndexManager: ObservableObject {
    static let shared = SearchIndexManager()

    @Published var isIndexing: Bool = false
    @Published var indexProgress: Double = 0.0
    @Published var searchResults: [Screenshot] = []
    @Published var lastSearchQuery: String = ""

    private var modelContext: ModelContext?

    private init() {}

    /// Set the model context for database operations
    func configure(with context: ModelContext) {
        self.modelContext = context
    }

    /// Process OCR for a single screenshot
    func processOCR(for screenshot: Screenshot, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: screenshot.filePath) ?? URL(fileURLWithPath: screenshot.filePath),
              let image = NSImage(contentsOf: url) else {
            completion(false)
            return
        }

        OCRManager.shared.extractText(from: image) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let text):
                DispatchQueue.main.async {
                    screenshot.extractedText = text
                    screenshot.searchableKeywords = self.extractKeywords(from: text)
                    screenshot.isOCRProcessed = true
                    screenshot.ocrProcessedDate = Date()

                    // Save to database
                    do {
                        try self.modelContext?.save()
                        completion(true)
                    } catch {
                        print("[SearchIndex] Failed to save OCR data: \(error)")
                        completion(false)
                    }
                }

            case .failure(let error):
                print("[SearchIndex] OCR failed: \(error)")
                completion(false)
            }
        }
    }

    /// Batch process OCR for multiple screenshots
    func batchProcessOCR(screenshots: [Screenshot], completion: @escaping (Int, Int) -> Void) {
        isIndexing = true
        indexProgress = 0.0

        let total = screenshots.count
        var processed = 0
        var successful = 0

        let queue = DispatchQueue(label: "com.screengrabber.ocr.batch", qos: .userInitiated)
        let group = DispatchGroup()

        for screenshot in screenshots {
            guard !screenshot.isOCRProcessed else {
                processed += 1
                continue
            }

            group.enter()
            queue.async {
                self.processOCR(for: screenshot) { success in
                    processed += 1
                    if success {
                        successful += 1
                    }

                    DispatchQueue.main.async {
                        self.indexProgress = Double(processed) / Double(total)
                    }

                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            self.isIndexing = false
            self.indexProgress = 1.0
            completion(successful, total)
        }
    }

    /// Search screenshots by text query
    func search(query: String, in screenshots: [Screenshot]) -> [Screenshot] {
        guard !query.isEmpty else { return screenshots }

        lastSearchQuery = query
        let lowercasedQuery = query.lowercased()
        let queryKeywords = extractKeywords(from: query)

        let results = screenshots.filter { screenshot in
            // Search in filename
            if screenshot.filename.lowercased().contains(lowercasedQuery) {
                return true
            }

            // Search in extracted text
            if let extractedText = screenshot.extractedText,
               extractedText.lowercased().contains(lowercasedQuery) {
                return true
            }

            // Search in keywords
            let matchingKeywords = screenshot.searchableKeywords.filter { keyword in
                queryKeywords.contains { queryKeyword in
                    keyword.lowercased().contains(queryKeyword.lowercased())
                }
            }
            if !matchingKeywords.isEmpty {
                return true
            }

            // Search in tags
            if screenshot.tags.contains(where: { $0.lowercased().contains(lowercasedQuery) }) {
                return true
            }

            // Search in notes
            if let notes = screenshot.notes, notes.lowercased().contains(lowercasedQuery) {
                return true
            }

            // Search in project name
            if let projectName = screenshot.projectName,
               projectName.lowercased().contains(lowercasedQuery) {
                return true
            }

            return false
        }

        searchResults = results
        return results
    }

    /// Advanced search with filters
    func advancedSearch(
        query: String? = nil,
        tags: [String]? = nil,
        dateRange: ClosedRange<Date>? = nil,
        hasOCR: Bool? = nil,
        projectName: String? = nil,
        in screenshots: [Screenshot]
    ) -> [Screenshot] {
        var results = screenshots

        // Text search
        if let query = query, !query.isEmpty {
            results = search(query: query, in: results)
        }

        // Filter by tags
        if let tags = tags, !tags.isEmpty {
            results = results.filter { screenshot in
                tags.allSatisfy { tag in
                    screenshot.tags.contains(tag)
                }
            }
        }

        // Filter by date range
        if let dateRange = dateRange {
            results = results.filter { screenshot in
                dateRange.contains(screenshot.captureDate)
            }
        }

        // Filter by OCR status
        if let hasOCR = hasOCR {
            results = results.filter { $0.isOCRProcessed == hasOCR }
        }

        // Filter by project
        if let projectName = projectName {
            results = results.filter { $0.projectName == projectName }
        }

        searchResults = results
        return results
    }

    /// Extract keywords from text for indexing
    private func extractKeywords(from text: String) -> [String] {
        // Split into words and filter
        let words = text
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count >= 3 } // Only words with 3+ characters
            .map { $0.lowercased() }

        // Remove common stop words
        let stopWords = Set([
            "the", "and", "for", "are", "but", "not", "you", "all", "can",
            "her", "was", "one", "our", "out", "day", "get", "has", "him",
            "his", "how", "its", "may", "now", "old", "see", "than", "that",
            "this", "two", "use", "way", "who", "with"
        ])

        let keywords = words.filter { !stopWords.contains($0) }

        // Return unique keywords
        return Array(Set(keywords))
    }

    /// Get search suggestions based on indexed content
    func getSearchSuggestions(for query: String, limit: Int = 10) -> [String] {
        guard !query.isEmpty else { return [] }

        let lowercasedQuery = query.lowercased()

        // Collect all keywords from all screenshots
        guard let context = modelContext else { return [] }

        do {
            let descriptor = FetchDescriptor<Screenshot>(
                predicate: #Predicate { $0.isOCRProcessed == true }
            )
            let screenshots = try context.fetch(descriptor)

            var allKeywords = Set<String>()
            for screenshot in screenshots {
                allKeywords.formUnion(screenshot.searchableKeywords)
                allKeywords.formUnion(screenshot.tags)
            }

            // Filter keywords that start with or contain the query
            let matchingKeywords = allKeywords
                .filter { $0.lowercased().contains(lowercasedQuery) }
                .sorted()
                .prefix(limit)

            return Array(matchingKeywords)
        } catch {
            print("[SearchIndex] Failed to fetch suggestions: \(error)")
            return []
        }
    }

    /// Get statistics about the search index
    func getIndexStatistics() -> SearchIndexStatistics? {
        guard let context = modelContext else { return nil }

        do {
            let allDescriptor = FetchDescriptor<Screenshot>()
            let processedDescriptor = FetchDescriptor<Screenshot>(
                predicate: #Predicate { $0.isOCRProcessed == true }
            )

            let totalCount = try context.fetchCount(allDescriptor)
            let processedCount = try context.fetchCount(processedDescriptor)

            let screenshots = try context.fetch(processedDescriptor)
            let totalKeywords = screenshots.reduce(0) { $0 + $1.searchableKeywords.count }
            let uniqueKeywords = Set(screenshots.flatMap { $0.searchableKeywords }).count

            return SearchIndexStatistics(
                totalScreenshots: totalCount,
                processedScreenshots: processedCount,
                pendingScreenshots: totalCount - processedCount,
                totalKeywords: totalKeywords,
                uniqueKeywords: uniqueKeywords,
                indexingProgress: Double(processedCount) / Double(max(totalCount, 1))
            )
        } catch {
            print("[SearchIndex] Failed to fetch statistics: \(error)")
            return nil
        }
    }

    /// Clear OCR data for a screenshot
    func clearOCRData(for screenshot: Screenshot) {
        screenshot.extractedText = nil
        screenshot.searchableKeywords = []
        screenshot.isOCRProcessed = false
        screenshot.ocrProcessedDate = nil

        do {
            try modelContext?.save()
        } catch {
            print("[SearchIndex] Failed to clear OCR data: \(error)")
        }
    }

    /// Rebuild entire search index
    func rebuildIndex(completion: @escaping (Bool) -> Void) {
        guard let context = modelContext else {
            completion(false)
            return
        }

        do {
            let descriptor = FetchDescriptor<Screenshot>()
            let screenshots = try context.fetch(descriptor)

            // Clear all existing OCR data
            for screenshot in screenshots {
                screenshot.extractedText = nil
                screenshot.searchableKeywords = []
                screenshot.isOCRProcessed = false
                screenshot.ocrProcessedDate = nil
            }

            try context.save()

            // Reprocess all screenshots
            batchProcessOCR(screenshots: screenshots) { successful, total in
                completion(successful == total)
            }
        } catch {
            print("[SearchIndex] Failed to rebuild index: \(error)")
            completion(false)
        }
    }
}

// MARK: - Search Statistics
struct SearchIndexStatistics {
    let totalScreenshots: Int
    let processedScreenshots: Int
    let pendingScreenshots: Int
    let totalKeywords: Int
    let uniqueKeywords: Int
    let indexingProgress: Double

    var progressPercentage: String {
        String(format: "%.1f%%", indexingProgress * 100)
    }
}
