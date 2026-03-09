//
//  CaptureDebugView.swift
//  ScreenGrabber
//
//  Diagnostic view to test and verify the capture pipeline
//  Created on 1/9/26.
//

import SwiftUI
import SwiftData
import AppKit
import Combine
import OSLog

struct CaptureDebugView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Screenshot.timestamp, order: .reverse) private var screenshots: [Screenshot]
    
    @State private var testResults: [String] = []
    @State private var isRunningTests = false
    @State private var capturesFolderURL: URL?
    @State private var filesCount: Int = 0
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Capture Pipeline Diagnostics")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Use this view to verify that all capture types are working correctly")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                // Quick Stats
                VStack(alignment: .leading, spacing: 8) {
                    Text("Database Statistics")
                        .font(.headline)
                    
                    HStack {
                        Label("\(screenshots.count) captures", systemImage: "photo.stack")
                        Spacer()
                        Button("Refresh") {
                            // SwiftData auto-refreshes via @Query
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    if !screenshots.isEmpty {
                        Text("Last capture: \(screenshots.first?.timestamp ?? Date(), style: .relative) ago")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                
                Divider()
                
                // File System Check
                VStack(alignment: .leading, spacing: 8) {
                    Text("File System Status")
                        .font(.headline)
                    
                    let capturesFolderExists = capturesFolderURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
                    
                    HStack {
                        Image(systemName: capturesFolderExists ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(capturesFolderExists ? .green : .red)
                        
                        Text("Captures Folder")
                        
                        Spacer()
                        
                        Text(capturesFolderURL?.lastPathComponent ?? "Not Found")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let url = capturesFolderURL {
                        Text("Path: \(url.path)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    
                    Text("\(filesCount) files in captures folder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Button("Create/Check Folder") {
                            Task {
                                testResults = ["🔍 Checking folder creation..."]
                                let result = await CapturePermissionsManager.shared.ensureCaptureFolderExists()
                                switch result {
                                case .success(let url):
                                    testResults.append("✅ Folder ready: \(url.path)")
                                    await loadFolderInfo()
                                case .failure(let error):
                                    testResults.append("❌ Error: \(error.localizedDescription)")
                                    // Error is already CaptureError from the Result type
                                    if let suggestion = error.recoverySuggestion {
                                        testResults.append("💡 \(suggestion)")
                                    }
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        
                        Button("Open in Finder") {
                            if let url = capturesFolderURL {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(capturesFolderURL == nil)
                        
                        Button("Refresh") {
                            Task {
                                await loadFolderInfo()
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                
                Divider()
                
                // Test Harness
                VStack(alignment: .leading, spacing: 12) {
                    Text("Test Pipeline")
                        .font(.headline)
                    
                    Text("Create a test capture to verify the entire pipeline")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Button(action: runTestCapture) {
                        Label(isRunningTests ? "Running..." : "Run Test Capture", systemImage: "play.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunningTests)
                    
                    if !testResults.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(testResults.enumerated()), id: \.offset) { _, result in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: result.contains("✅") ? "checkmark.circle.fill" : result.contains("❌") ? "xmark.circle.fill" : "circle")
                                        .foregroundStyle(result.contains("✅") ? .green : result.contains("❌") ? .red : .secondary)
                                    
                                    Text(result)
                                        .font(.caption)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
                
                Divider()
                
                // Recent Captures List
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Captures (\(screenshots.count))")
                        .font(.headline)
                    
                    if screenshots.isEmpty {
                        Text("No captures yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ForEach(screenshots.prefix(10)) { screenshot in
                            CaptureRowView(screenshot: screenshot)
                        }
                    }
                }
                
                Divider()
                
                // Cleanup Tools
                VStack(alignment: .leading, spacing: 8) {
                    Text("Maintenance")
                        .font(.headline)
                    
                    Button("Clean Up Old Captures (keep 50)") {
                        Task {
                            await UnifiedCaptureManager.shared.cleanupOldCaptures(
                                keepRecent: 50,
                                olderThanDays: 30,
                                context: modelContext
                            )
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                
                Spacer()
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 800)
        .task {
            await loadFolderInfo()
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadFolderInfo() async {
        capturesFolderURL = await UnifiedCaptureManager.shared.getCapturesFolderURL()
        
        if let url = capturesFolderURL {
            filesCount = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil))?.count ?? 0
        } else {
            filesCount = 0
        }
    }
    
    // MARK: - Test Functions
    
    private func runTestCapture() {
        isRunningTests = true
        testResults = []
        
        Task {
            await performCaptureTest()
        }
    }
    
    /// Performs comprehensive capture pipeline test
    private func performCaptureTest() async {
        await MainActor.run {
            testResults.append("🚀 Starting test capture pipeline...")
        }
        
        // Step 0: Validate capture environment (permissions & storage)
        guard await validateEnvironment() else {
            return
        }
        
        // Step 1: Verify folder exists
        guard await verifyFolderExists() else {
            return
        }
        
        // Step 2: Create and save test capture
        guard let savedURL = await createAndSaveTestCapture() else {
            return
        }
        
        // Step 3-6: Verify all aspects of the capture
        await verifyCaptureSuccess(savedURL: savedURL)
    }
    
    /// Validates the capture environment
    private func validateEnvironment() async -> Bool {
        await MainActor.run {
            testResults.append("🔍 Validating capture environment...")
        }
        
        let validation = await CapturePermissionsManager.shared.validateCaptureEnvironment()
        
        switch validation {
        case .success:
            await MainActor.run {
                testResults.append("✅ Environment validated (permissions & storage)")
            }
            return true
            
        case .failure(let error):
            await MainActor.run {
                testResults.append("❌ Validation failed: \(error.localizedDescription)")
                // Error is already CaptureError from the Result type
                if let suggestion = error.recoverySuggestion {
                    testResults.append("💡 \(suggestion)")
                }
                testResults.append("❌ TEST ABORTED - Fix the above and try again")
                isRunningTests = false
            }
            return false
        }
    }
    
    /// Verifies that the captures folder exists
    private func verifyFolderExists() async -> Bool {
        if let url = await UnifiedCaptureManager.shared.getCapturesFolderURL() {
            await MainActor.run {
                let exists = FileManager.default.fileExists(atPath: url.path)
                if exists {
                    testResults.append("✅ Folder exists on disk")
                } else {
                    testResults.append("❌ Folder path returned but doesn't exist!")
                    isRunningTests = false
                }
            }
            return FileManager.default.fileExists(atPath: url.path)
        } else {
            await MainActor.run {
                testResults.append("❌ Could not retrieve captures folder URL")
                isRunningTests = false
            }
            return false
        }
    }
    
    /// Creates test image and saves through the unified pipeline
    private func createAndSaveTestCapture() async -> URL? {
        // Create test image
        await MainActor.run {
            testResults.append("📸 Creating test image...")
        }
        
        let testImage = await MainActor.run { createTestImage() }
        
        await MainActor.run {
            testResults.append("✅ Test image created: \(Int(testImage.size.width))x\(Int(testImage.size.height))")
        }
        
        // Create metadata
        let metadata = UnifiedCaptureManager.CaptureMetadata(
            captureType: .area,
            timestamp: Date(),
            image: testImage
        )
        
        await MainActor.run {
            testResults.append("✅ Metadata created: \(metadata.captureType.rawValue)")
        }
        
        // Save through unified pipeline
        await MainActor.run {
            CaptureLogger.captureStarted(method: "Test")
            testResults.append("💾 Saving through unified pipeline...")
        }
        
        let savedURL = await UnifiedCaptureManager.shared.saveCapture(
            metadata,
            to: modelContext,
            copyToClipboard: false
        )
        
        if let url = savedURL {
            await MainActor.run {
                testResults.append("✅ Image saved: \(url.lastPathComponent)")
            }
            CaptureLogger.log(.save, "Saved image to \(url.path)", level: .success)
        } else {
            await MainActor.run {
                testResults.append("❌ Failed to save capture!")
                testResults.append("❌ TEST FAILED - Check console for errors")
                isRunningTests = false
            }
            CaptureLogger.logDetailedError(
                CaptureError.fileWriteFailed(underlying: nil),
                context: "Test capture save failed"
            )
        }
        
        return savedURL
    }
    
    /// Verifies all aspects of a successful capture
    private func verifyCaptureSuccess(savedURL: URL) async {
        // Verify file exists
        let fileExists = FileManager.default.fileExists(atPath: savedURL.path)
        await MainActor.run {
            if fileExists {
                testResults.append("✅ File verified on disk")
            } else {
                testResults.append("❌ File not found on disk!")
            }
        }
        
        // Give SwiftData time to persist
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Verify database entry
        await verifyDatabaseEntry(savedURL: savedURL)
        
        // Verify thumbnail
        await verifyThumbnail(savedURL: savedURL)
        
        await MainActor.run {
            testResults.append("✅ TEST COMPLETE - Pipeline working correctly!")
            isRunningTests = false
        }
    }
    
    /// Verifies database entry for the saved capture
    private func verifyDatabaseEntry(savedURL: URL) async {
        await MainActor.run {
            let descriptor = FetchDescriptor<Screenshot>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            let latest = try? modelContext.fetch(descriptor).first
            if let latestScreenshot = latest {
                if latestScreenshot.filename == savedURL.lastPathComponent {
                    testResults.append("✅ Database entry verified")
                    testResults.append("   Filename: \(latestScreenshot.filename)")
                    testResults.append("   Type: \(latestScreenshot.captureType)")
                    testResults.append("   Date: \(latestScreenshot.timestamp)")
                } else {
                    testResults.append("❌ Database entry mismatch")
                }
            } else {
                testResults.append("❌ Database entry not found!")
            }
        }
    }
    
    /// Verifies thumbnail generation
    private func verifyThumbnail(savedURL: URL) async {
        guard let thumbnailURL = await UnifiedCaptureManager.shared.getThumbnailsFolderURL()?
            .appendingPathComponent(savedURL.lastPathComponent) else {
            await MainActor.run {
                testResults.append("❌ Could not determine thumbnail URL")
            }
            return
        }
        
        let thumbnailExists = FileManager.default.fileExists(atPath: thumbnailURL.path)
        await MainActor.run {
            if thumbnailExists {
                testResults.append("✅ Thumbnail generated and saved")
            } else {
                testResults.append("❌ Thumbnail not found!")
            }
        }
    }
    
    private func createTestImage() -> NSImage {
        let size = NSSize(width: 800, height: 600)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Draw gradient background
        let gradient = NSGradient(colors: [.systemBlue, .systemPurple])
        gradient?.draw(in: NSRect(origin: .zero, size: size), angle: 45)
        
        // Draw test text
        let text = "Test Capture\n\(Date())"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 48, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        
        let textSize = (text as NSString).size(withAttributes: attrs)
        let textRect = NSRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        (text as NSString).draw(in: textRect, withAttributes: attrs)
        
        image.unlockFocus()
        
        return image
    }
    
    private func iconFor(captureType: String) -> String {
        switch captureType {
        case "fullScreen":
            return "display"
        case "area":
            return "rectangle.dashed"
        case "window":
            return "macwindow"
        case "scrolling":
            return "arrow.up.arrow.down.square"
        default:
            return "photo"
        }
    }
}

// MARK: - Helper Views

/// Row view for displaying a capture with async thumbnail loading
private struct CaptureRowView: View {
    let screenshot: Screenshot
    @State private var thumbnail: NSImage?
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(screenshot.filename)
                    .font(.caption)
                    .lineLimit(1)
                
                Text(screenshot.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Label(screenshot.captureType, systemImage: iconFor(captureType: screenshot.captureType))
                .font(.caption2)
                .padding(4)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(4)
        }
        .padding(8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
        .task {
            // Load thumbnail asynchronously
            thumbnail = await UnifiedCaptureManager.shared.loadThumbnail(for: screenshot)
        }
    }
    
    private func iconFor(captureType: String) -> String {
        switch captureType {
        case "fullScreen":
            return "display"
        case "area":
            return "rectangle.dashed"
        case "window":
            return "macwindow"
        case "scrolling":
            return "arrow.up.arrow.down.square"
        default:
            return "photo"
        }
    }
}

// MARK: - Extension removed - functions already exist in UnifiedCaptureManager.swift

#Preview {
    CaptureDebugView()
        .modelContainer(for: Screenshot.self)
}
