//
//  CapturePipelineTestView.swift
//  ScreenGrabber
//
//  Test harness for validating the complete capture pipeline
//  Created on 1/9/26.
//

import SwiftUI
import SwiftData
import AppKit

/// Diagnostic view for testing and debugging the capture pipeline
struct CapturePipelineTestView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Screenshot.captureDate, order: .reverse) private var allScreenshots: [Screenshot]
    
    @State private var testResults: [TestResult] = []
    @State private var isRunning = false
    @State private var selectedTest: TestType?
    
    enum TestType: String, CaseIterable, Identifiable {
        case fullPipeline = "Full Pipeline Test"
        case fileSystem = "File System Test"
        case database = "Database Test"
        case thumbnail = "Thumbnail Test"
        case notification = "Notification Test"
        case cleanup = "Cleanup Old Files"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .fullPipeline: return "checkmark.circle.fill"
            case .fileSystem: return "folder.fill"
            case .database: return "cylinder.fill"
            case .thumbnail: return "photo.fill"
            case .notification: return "bell.fill"
            case .cleanup: return "trash.fill"
            }
        }
    }
    
    struct TestResult: Identifiable {
        let id = UUID()
        let testName: String
        let passed: Bool
        let message: String
        let timestamp: Date = Date()
        
        var icon: String {
            passed ? "checkmark.circle.fill" : "xmark.circle.fill"
        }
        
        var color: Color {
            passed ? .green : .red
        }
    }
    
    var body: some View {
        HSplitView {
            // Left: Test Controls
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Capture Pipeline Tests")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Diagnostic tools for debugging capture issues")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                // Quick Stats
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        StatRow(
                            label: "Screenshots in DB",
                            value: "\(allScreenshots.count)"
                        )
                        
                        StatRow(
                            label: "Captures Folder",
                            value: folderStatus
                        )
                        
                        if let latestCapture = allScreenshots.first {
                            StatRow(
                                label: "Latest Capture",
                                value: formatDate(latestCapture.captureDate)
                            )
                        }
                    }
                } label: {
                    Label("Quick Stats", systemImage: "chart.bar.fill")
                }
                
                Divider()
                
                // Test Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Available Tests")
                        .font(.headline)
                    
                    ForEach(TestType.allCases) { testType in
                        Button(action: { 
                            Task {
                                await runTest(testType)
                            }
                        }) {
                            HStack {
                                Image(systemName: testType.icon)
                                Text(testType.rawValue)
                                Spacer()
                                if selectedTest == testType && isRunning {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isRunning)
                    }
                }
                
                Divider()
                
                // Actions
                VStack(spacing: 8) {
                    Button(action: runAllTests) {
                        Label("Run All Tests", systemImage: "play.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning)
                    
                    Button(action: clearResults) {
                        Label("Clear Results", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isRunning)
                    
                    Button(action: openCapturesFolder) {
                        Label("Open Captures Folder", systemImage: "folder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
            }
            .padding()
            .frame(minWidth: 300, idealWidth: 350)
            
            // Right: Test Results
            VStack(alignment: .leading, spacing: 0) {
                // Results Header
                HStack {
                    Label("Test Results", systemImage: "list.bullet.clipboard")
                        .font(.headline)
                    
                    Spacer()
                    
                    if !testResults.isEmpty {
                        let passed = testResults.filter { $0.passed }.count
                        let total = testResults.count
                        
                        Text("\(passed)/\(total) Passed")
                            .font(.caption)
                            .foregroundStyle(passed == total ? .green : .orange)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                
                Divider()
                
                // Results List
                if testResults.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checklist")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        
                        Text("No test results yet")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Text("Run a test to see results here")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(testResults) { result in
                                TestResultCard(result: result)
                            }
                        }
                        .padding()
                    }
                }
            }
            .frame(minWidth: 400)
        }
        .frame(minWidth: 800, minHeight: 600)
        .task {
            await checkCapturesFolderExists()
        }
    }
    
    // MARK: - Computed Properties
    
    @State private var folderStatus: String = "Checking..."
    
    private func checkCapturesFolderExists() async {
        let exists = await withCheckedContinuation { continuation in
            Task {
                guard let url = await UnifiedCaptureManager.shared.getCapturesFolderURL() else {
                    continuation.resume(returning: false)
                    return
                }
                continuation.resume(returning: FileManager.default.fileExists(atPath: url.path))
            }
        }
        await MainActor.run {
            folderStatus = exists ? "✅ Exists" : "❌ Missing"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // MARK: - Test Execution
    
    private func runTest(_ testType: TestType) async {
        await MainActor.run {
            selectedTest = testType
            isRunning = true
        }
        
        switch testType {
        case .fullPipeline:
            await testFullPipeline()
        case .fileSystem:
            await testFileSystem()
        case .database:
            await testDatabase()
        case .thumbnail:
            await testThumbnails()
        case .notification:
            await testNotifications()
        case .cleanup:
            await performCleanup()
        }
        
        await MainActor.run {
            isRunning = false
            selectedTest = nil
        }
    }
    
    private func runAllTests() {
        Task {
            for testType in TestType.allCases where testType != .cleanup {
                await runTest(testType)
                // Small delay between tests
                do {
                    try await Task.sleep(nanoseconds: 500_000_000)
                } catch {
                    // Ignore cancellation
                }
            }
        }
    }
    
    private func clearResults() {
        testResults.removeAll()
    }
    
    private func openCapturesFolder() {
        Task {
            guard let url = await UnifiedCaptureManager.shared.getCapturesFolderURL() else {
                return
            }
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Individual Tests
    
    private func testFullPipeline() async {
        addResult("Starting full pipeline test", passed: true)
        
        // Create test image
        let testImage = createTestImage(label: "PIPELINE TEST")
        
        // Run through unified pipeline
        let metadata = UnifiedCaptureManager.CaptureMetadata(
            captureType: .area,
            timestamp: Date(),
            image: testImage
        )
        
        if let url = await UnifiedCaptureManager.shared.saveCapture(
            metadata,
            to: modelContext,
            copyToClipboard: false
        ) {
            // Verify file exists
            let fileExists = FileManager.default.fileExists(atPath: url.path)
            addResult(
                "File saved to disk",
                passed: fileExists,
                message: fileExists ? url.lastPathComponent : "File not found"
            )
            
            // Verify in database
            try? await Task.sleep(nanoseconds: 100_000_000)  // Wait for DB save
            let inDatabase = allScreenshots.contains { $0.filePath == url.path }
            addResult(
                "Entry added to database",
                passed: inDatabase,
                message: inDatabase ? "Found in history" : "Not found in database"
            )
            
            // Verify thumbnail
            if let screenshot = allScreenshots.first(where: { $0.filePath == url.path }) {
                let thumbnail = await UnifiedCaptureManager.shared.loadThumbnail(for: screenshot)
                addResult(
                    "Thumbnail generated",
                    passed: thumbnail != nil,
                    message: thumbnail != nil ? "Loaded successfully" : "Failed to load"
                )
            }
            
            addResult("✅ Full pipeline test completed", passed: true)
        } else {
            addResult("❌ Pipeline failed", passed: false, message: "saveCapture returned nil")
        }
    }
    
    private func testFileSystem() async {
        addResult("Testing file system...", passed: true)
        
        let manager = FileManager.default
        guard let capturesURL = await UnifiedCaptureManager.shared.getCapturesFolderURL() else {
            addResult("❌ Could not access captures folder", passed: false)
            return
        }
        
        // Test main folder
        let mainExists = manager.fileExists(atPath: capturesURL.path)
        addResult(
            "Captures folder exists",
            passed: mainExists,
            message: capturesURL.path
        )
        
        // Test thumbnails folder
        guard let thumbnailsURL = await UnifiedCaptureManager.shared.getThumbnailsFolderURL() else {
            addResult("❌ Could not access thumbnails folder", passed: false)
            return
        }
        
        let thumbsExist = manager.fileExists(atPath: thumbnailsURL.path)
        addResult(
            "Thumbnails folder exists",
            passed: thumbsExist,
            message: thumbnailsURL.path
        )
        
        // Count files
        if let files = try? manager.contentsOfDirectory(at: capturesURL, includingPropertiesForKeys: nil) {
            let imageFiles = files.filter { $0.pathExtension == "png" }
            addResult(
                "Image files found",
                passed: true,
                message: "\(imageFiles.count) PNG files"
            )
        }
    }
    
    private func testDatabase() async {
        addResult("Testing database...", passed: true)
        
        let count = allScreenshots.count
        addResult(
            "Screenshot count",
            passed: true,
            message: "\(count) entries in database"
        )
        
        // Test latest entry
        if let latest = allScreenshots.first {
            let fileExists = FileManager.default.fileExists(atPath: latest.filePath)
            addResult(
                "Latest entry file exists",
                passed: fileExists,
                message: latest.filename
            )
            
            addResult(
                "Latest entry details",
                passed: true,
                message: "Type: \(latest.captureType), Date: \(formatDate(latest.captureDate))"
            )
        } else {
            addResult(
                "No entries in database",
                passed: false,
                message: "Database is empty"
            )
        }
    }
    
    private func testThumbnails() async {
        addResult("Testing thumbnails...", passed: true)
        
        guard let thumbnailsFolder = await UnifiedCaptureManager.shared.getThumbnailsFolderURL() else {
            addResult("❌ Could not access thumbnails folder", passed: false)
            return
        }
        
        if let files = try? FileManager.default.contentsOfDirectory(at: thumbnailsFolder, includingPropertiesForKeys: nil) {
            addResult(
                "Thumbnail files found",
                passed: true,
                message: "\(files.count) thumbnails"
            )
            
            // Test loading
            var loadedCount = 0
            for screenshot in allScreenshots.prefix(5) {
                if await UnifiedCaptureManager.shared.loadThumbnail(for: screenshot) != nil {
                    loadedCount += 1
                }
            }
            
            addResult(
                "Thumbnails loadable",
                passed: loadedCount > 0,
                message: "\(loadedCount)/\(min(5, allScreenshots.count)) loaded"
            )
        } else {
            addResult(
                "Thumbnails folder not readable",
                passed: false,
                message: thumbnailsFolder.path
            )
        }
    }
    
    private func testNotifications() async {
        addResult("Testing notification system...", passed: true)
        
        var captureNotified = false
        var historyNotified = false
        
        let captureObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("screenshotCaptured"),
            object: nil,
            queue: .main
        ) { _ in
            captureNotified = true
        }
        
        let historyObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("screenshotSavedToHistory"),
            object: nil,
            queue: .main
        ) { _ in
            historyNotified = true
        }
        
        // Trigger a capture
        let testImage = createTestImage(label: "NOTIFY TEST")
        let metadata = UnifiedCaptureManager.CaptureMetadata(
            captureType: .area,
            timestamp: Date(),
            image: testImage
        )
        
        await UnifiedCaptureManager.shared.saveCapture(
            metadata,
            to: modelContext,
            copyToClipboard: false
        )
        
        // Wait for notifications
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        addResult(
            ".screenshotCaptured fired",
            passed: captureNotified,
            message: captureNotified ? "Received" : "Not received"
        )
        
        addResult(
            ".screenshotSavedToHistory fired",
            passed: historyNotified,
            message: historyNotified ? "Received" : "Not received"
        )
        
        NotificationCenter.default.removeObserver(captureObserver)
        NotificationCenter.default.removeObserver(historyObserver)
    }
    
    private func performCleanup() async {
        addResult("Starting cleanup...", passed: true)
        
        let beforeCount = allScreenshots.count
        
        await UnifiedCaptureManager.shared.cleanupOldCaptures(
            keepRecent: 20,
            olderThanDays: 30,
            context: modelContext
        )
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        let afterCount = allScreenshots.count
        let deleted = beforeCount - afterCount
        
        addResult(
            "Cleanup completed",
            passed: true,
            message: "Deleted \(deleted) old captures"
        )
    }
    
    // MARK: - Helpers
    
    private func addResult(_ testName: String, passed: Bool, message: String = "") {
        Task { @MainActor in
            testResults.append(TestResult(
                testName: testName,
                passed: passed,
                message: message
            ))
        }
    }
    
    private func createTestImage(label: String) -> NSImage {
        let size = NSSize(width: 800, height: 600)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Background
        NSColor.systemBlue.withAlphaComponent(0.3).setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Label
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 48),
            .foregroundColor: NSColor.white
        ]
        
        let text = label as NSString
        let textSize = text.size(withAttributes: attrs)
        let textRect = NSRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        text.draw(in: textRect, withAttributes: attrs)
        
        image.unlockFocus()
        
        return image
    }
}

// MARK: - Supporting Views

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct TestResultCard: View {
    let result: CapturePipelineTestView.TestResult
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: result.icon)
                .font(.title3)
                .foregroundStyle(result.color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.testName)
                    .font(.headline)
                
                if !result.message.isEmpty {
                    Text(result.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text(result.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

// MARK: - Preview

#Preview {
    CapturePipelineTestView()
        .modelContainer(for: Screenshot.self, inMemory: true)
        .frame(width: 1000, height: 700)
}
