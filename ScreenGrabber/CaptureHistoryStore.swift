//
//  CaptureHistoryStore.swift
//  ScreenGrabber
//
//  Manages screenshot history using SwiftData
//

import Foundation
import SwiftData
import AppKit
import Combine

@MainActor
class CaptureHistoryStore: ObservableObject {
    static let shared = CaptureHistoryStore()
    
    @Published var recentCaptures: [Screenshot] = []
    
    private init() {}
    
    func addCapture(
        fileURL: URL,
        thumbnailURL: URL?,
        type: ScreenGrabberTypes.CaptureType,
        timestamp: Date,
        imageSize: CGSize,
        modelContext: ModelContext
    ) async -> Result<Screenshot, ScreenGrabberTypes.CaptureError> {
        // Get file size
        let fileSize: Int64
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            fileSize = attributes[.size] as? Int64 ?? 0
        } catch {
            fileSize = 0
        }
        
        let screenshot = Screenshot(
            filename: fileURL.lastPathComponent,
            filePath: fileURL.path,
            captureType: type.rawValue,
            width: Int(imageSize.width),
            height: Int(imageSize.height),
            fileSize: fileSize,
            timestamp: timestamp,
            sourceDisplay: nil,
            sourceWindow: nil,
            thumbnailPath: thumbnailURL?.path,
            captureDate: timestamp,
            openMethod: "save_to_file"
        )
        
        do {
            modelContext.insert(screenshot)
            try modelContext.save()
            
            // Update recent captures immediately
            await loadRecentCaptures(from: modelContext)
            
            CaptureLogger.log(.debug, "✅ Added screenshot to history: \(screenshot.filename)", level: .info)
            
            // Post notification that history was updated
            NotificationCenter.default.post(
                name: .screenshotSavedToHistory,
                object: screenshot,
                userInfo: ["url": fileURL]
            )
            
            return .success(screenshot)
        } catch {
            CaptureLogger.logDetailedError(error, context: "Failed to add screenshot to history")
            return .failure(.historyUpdateFailed(underlying: error))
        }
    }
    
    func loadRecentCaptures(from modelContext: ModelContext, limit: Int = 20) async {
        let descriptor = FetchDescriptor<Screenshot>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            let allScreenshots = try modelContext.fetch(descriptor)
            recentCaptures = Array(allScreenshots.prefix(limit))
            
            CaptureLogger.log(.debug, "📚 Loaded \(recentCaptures.count) screenshots from history", level: .info)
        } catch {
            CaptureLogger.logDetailedError(error, context: "Failed to load recent captures")
            recentCaptures = []
        }
    }
    
    func deleteCapture(_ screenshot: Screenshot, from modelContext: ModelContext) async -> Result<Void, ScreenGrabberTypes.CaptureError> {
        // Delete file
        let fileURL = URL(fileURLWithPath: screenshot.filePath)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                return .failure(.fileWriteFailed(underlying: error))
            }
        }
        
        // Delete thumbnail
        if let thumbnailPath = screenshot.thumbnailPath {
            let thumbnailURL = URL(fileURLWithPath: thumbnailPath)
            try? FileManager.default.removeItem(at: thumbnailURL)
        }
        
        // Delete from database
        modelContext.delete(screenshot)
        
        do {
            try modelContext.save()
            await loadRecentCaptures(from: modelContext)
            return .success(())
        } catch {
            return .failure(.historyUpdateFailed(underlying: error))
        }
    }
    
    func updateAnnotations(
        for screenshot: Screenshot,
        annotations: [Annotation],
        modelContext: ModelContext
    ) async -> Result<Void, ScreenGrabberTypes.CaptureError> {
        screenshot.saveAnnotations(annotations)
        
        do {
            try modelContext.save()
            return .success(())
        } catch {
            return .failure(.historyUpdateFailed(underlying: error))
        }
    }
}

