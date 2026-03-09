# 📋 Enhanced Logging & Error Handling Guide

## Overview
This document provides recommended logging strategies and error handling patterns for ScreenGrabber's critical paths.

---

## 1. CENTRALIZED LOGGER

Create a unified logging system for better diagnostics:

```swift
//
//  ScreenGrabberLogger.swift
//  ScreenGrabber
//

import Foundation
import os.log

enum LogCategory: String {
    case settings = "⚙️ SETTINGS"
    case capture = "📸 CAPTURE"
    case permissions = "🔐 PERMISSIONS"
    case storage = "💾 STORAGE"
    case ui = "🖥️ UI"
    case scrolling = "📜 SCROLL"
    case error = "❌ ERROR"
}

enum LogLevel {
    case debug, info, warning, error
    
    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
}

class ScreenGrabberLogger {
    static let shared = ScreenGrabberLogger()
    
    private let osLog: OSLog
    private let enableFileLogging = true
    private let logFileURL: URL
    
    private init() {
        self.osLog = OSLog(subsystem: "com.screengrabber.app", category: "main")
        
        // Create log file in Application Support
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let appFolder = appSupport.appendingPathComponent("ScreenGrabber", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let filename = "screengrabber-\(dateFormatter.string(from: Date())).log"
        self.logFileURL = appFolder.appendingPathComponent(filename)
    }
    
    func log(
        _ message: String,
        category: LogCategory = .info,
        level: LogLevel = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        // Console output with emojis
        let consoleMessage = "\(level.emoji) [\(category.rawValue)] \(message)"
        print(consoleMessage)
        
        // Detailed file output
        if enableFileLogging {
            let detailedMessage = """
            [\(timestamp)] \(level.emoji) [\(category.rawValue)]
            Location: \(fileName):\(line) \(function)
            Message: \(message)
            ---
            """
            
            if let data = (detailedMessage + "\n").data(using: .utf8) {
                if FileManager.default.fileExists(atPath: logFileURL.path) {
                    if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    }
                } else {
                    try? data.write(to: logFileURL)
                }
            }
        }
        
        // OS unified logging (for Console.app)
        let osLogType: OSLogType
        switch level {
        case .debug: osLogType = .debug
        case .info: osLogType = .info
        case .warning: osLogType = .default
        case .error: osLogType = .error
        }
        
        os_log("%{public}@", log: osLog, type: osLogType, message)
    }
    
    func error(_ message: String, category: LogCategory = .error) {
        log(message, category: category, level: .error)
    }
    
    func warning(_ message: String, category: LogCategory) {
        log(message, category: category, level: .warning)
    }
    
    func info(_ message: String, category: LogCategory) {
        log(message, category: category, level: .info)
    }
    
    func debug(_ message: String, category: LogCategory) {
        log(message, category: category, level: .debug)
    }
    
    /// Export logs for user support/debugging
    func exportLogs() -> URL? {
        guard FileManager.default.fileExists(atPath: logFileURL.path) else {
            return nil
        }
        return logFileURL
    }
}

// MARK: - Convenience Extensions

extension ScreenGrabberLogger {
    // Settings-specific logging
    func settingChanged(_ setting: String, from oldValue: Any?, to newValue: Any) {
        info("Setting '\(setting)' changed: \(String(describing: oldValue)) → \(newValue)", category: .settings)
    }
    
    func folderValidationFailed(path: String, reason: String) {
        warning("Folder validation failed for '\(path)': \(reason)", category: .storage)
    }
    
    func captureStarted(method: String) {
        info("Capture started: \(method)", category: .capture)
    }
    
    func captureCompleted(path: String, duration: TimeInterval) {
        info("Capture completed in \(String(format: "%.2fs", duration)): \(path)", category: .capture)
    }
    
    func captureFailed(method: String, error: Error) {
        self.error("Capture failed (\(method)): \(error.localizedDescription)", category: .capture)
    }
}
```

---

## 2. USAGE IN SETTINGSMODEL

```swift
// In SettingsModel.swift

import Foundation
import SwiftUI
import Observation

@Observable
final class SettingsModel {
    static let shared = SettingsModel()
    private let logger = ScreenGrabberLogger.shared
    
    @ObservationIgnored @AppStorage(Keys.saveFolderPath) 
    var saveFolderPath: String = "" {
        didSet {
            logger.settingChanged("saveFolderPath", from: oldValue, to: saveFolderPath)
        }
    }
    
    var effectiveSaveURL: URL {
        if !saveFolderPath.isEmpty {
            let customURL = URL(fileURLWithPath: saveFolderPath)
            
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(
                atPath: customURL.path, 
                isDirectory: &isDirectory
            )
            
            if exists && isDirectory.boolValue {
                // Test write access
                let testFile = customURL.appendingPathComponent(".screengrabber_test")
                do {
                    try "test".write(to: testFile, atomically: true, encoding: .utf8)
                    try FileManager.default.removeItem(at: testFile)
                    
                    logger.info("Using custom save location: \(customURL.path)", category: .storage)
                    return customURL
                    
                } catch {
                    logger.folderValidationFailed(
                        path: customURL.path,
                        reason: "Not writable - \(error.localizedDescription)"
                    )
                }
            } else {
                logger.folderValidationFailed(
                    path: customURL.path,
                    reason: exists ? "Not a directory" : "Does not exist"
                )
            }
            
            // Clear invalid path and notify user
            Task { @MainActor in
                saveFolderPath = ""
                showFolderErrorAlert(path: saveFolderPath)
            }
        }
        
        // Return default
        let pictures = FileManager.default.urls(
            for: .picturesDirectory, 
            in: .userDomainMask
        ).first!
        let defaultURL = pictures.appendingPathComponent("Screen Grabber", isDirectory: true)
        
        logger.debug("Using default save location: \(defaultURL.path)", category: .storage)
        return defaultURL
    }
}
```

---

## 3. USAGE IN CAPTURE MANAGER

```swift
// In ScreenCaptureManager or UnifiedCaptureManager

class ScreenCaptureManager {
    static let shared = ScreenCaptureManager()
    private let logger = ScreenGrabberLogger.shared
    
    func captureScreen(method: ScreenOption, openOption: OpenOption, modelContext: ModelContext?) {
        let startTime = Date()
        logger.captureStarted(method: method.displayName)
        
        Task {
            do {
                // Validate environment
                let validation = await CapturePermissionsManager.shared.validateCaptureEnvironment()
                guard case .success = validation else {
                    if case .failure(let error) = validation {
                        logger.captureFailed(method: method.displayName, error: error)
                        await showErrorAlert(error: error)
                    }
                    return
                }
                
                // Perform capture
                let image = try await performCapture(method: method)
                
                // Save
                let savedURL = try await saveCapture(image: image, method: method)
                
                let duration = Date().timeIntervalSince(startTime)
                logger.captureCompleted(path: savedURL.path, duration: duration)
                
                // Handle open option
                await handleOpenOption(openOption, url: savedURL, image: image)
                
            } catch {
                let duration = Date().timeIntervalSince(startTime)
                logger.captureFailed(method: method.displayName, error: error)
                logger.error("Capture failed after \(duration)s", category: .capture)
                
                await showCaptureError(error: error)
            }
        }
    }
    
    @MainActor
    private func showCaptureError(error: Error) {
        let alert = NSAlert()
        alert.messageText = "Capture Failed"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .critical
        
        if let captureError = error as? CaptureError {
            switch captureError {
            case .permissionDenied(let type):
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "Cancel")
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    CapturePermissionsManager.openSystemSettings(for: type)
                }
                return
                
            default:
                break
            }
        }
        
        alert.runModal()
    }
}
```

---

## 4. USAGE IN WINDOW PICKER

```swift
// In WindowPickerOverlay.swift

class WindowPickerOverlay: NSObject {
    private let logger = ScreenGrabberLogger.shared
    
    func show(onSelect: @escaping (SelectableWindow) -> Void) {
        logger.info("Showing window picker overlay", category: .scrolling)
        self.onWindowSelected = onSelect
        
        Task {
            await fetchAvailableWindows()
            
            await MainActor.run {
                logger.info("Creating overlay on \(NSScreen.screens.count) screens", category: .ui)
                
                for screen in NSScreen.screens {
                    let overlay = createOverlayWindow(for: screen)
                    overlayWindows.append(overlay)
                    overlay.orderFrontRegardless()
                }
                
                startMouseTracking()
            }
        }
    }
    
    @MainActor
    private func fetchAvailableWindows() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            
            availableWindows = content.windows
                .filter { /* filtering logic */ }
                .map { /* mapping logic */ }
            
            logger.info(
                "Found \(availableWindows.count) selectable windows", 
                category: .scrolling
            )
            
            if availableWindows.isEmpty {
                logger.warning("No selectable windows found", category: .scrolling)
            }
            
        } catch {
            logger.error("Failed to fetch windows: \(error)", category: .scrolling)
        }
    }
    
    private func handleWindowSelection(_ window: SelectableWindow) {
        logger.info(
            "Window selected: '\(window.displayTitle)' (ID: \(window.id))", 
            category: .scrolling
        )
        
        dismiss()
        onWindowSelected?(window)
    }
    
    func dismiss() {
        logger.debug("Dismissing window picker overlay", category: .ui)
        stopMouseTracking()
        
        for window in overlayWindows {
            window.close()
        }
        overlayWindows.removeAll()
    }
}
```

---

## 5. ERROR RECOVERY PATTERNS

### Pattern 1: Automatic Retry with Backoff

```swift
func performCaptureWithRetry(
    method: ScreenOption,
    maxAttempts: Int = 3
) async throws -> NSImage {
    var lastError: Error?
    
    for attempt in 1...maxAttempts {
        do {
            logger.debug("Capture attempt \(attempt)/\(maxAttempts)", category: .capture)
            
            let image = try await performCapture(method: method)
            
            logger.info("Capture succeeded on attempt \(attempt)", category: .capture)
            return image
            
        } catch {
            lastError = error
            logger.warning(
                "Capture attempt \(attempt) failed: \(error.localizedDescription)",
                category: .capture
            )
            
            if attempt < maxAttempts {
                let delay = TimeInterval(attempt) * 0.5 // Exponential backoff
                logger.debug("Retrying in \(delay)s...", category: .capture)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }
    
    logger.error("All \(maxAttempts) capture attempts failed", category: .capture)
    throw lastError ?? CaptureError.unknown
}
```

### Pattern 2: Graceful Degradation

```swift
func ensureSaveLocation() async -> URL {
    // Try custom location
    if !settings.saveFolderPath.isEmpty {
        let customURL = URL(fileURLWithPath: settings.saveFolderPath)
        if validateAndCreateFolder(customURL) {
            return customURL
        }
        logger.warning("Custom location failed, trying default", category: .storage)
    }
    
    // Try default location
    let defaultURL = defaultSaveLocation()
    if validateAndCreateFolder(defaultURL) {
        return defaultURL
    }
    logger.warning("Default location failed, trying Desktop", category: .storage)
    
    // Fallback to Desktop
    let desktop = FileManager.default.urls(
        for: .desktopDirectory,
        in: .userDomainMask
    ).first!
    
    logger.info("Using Desktop as last resort", category: .storage)
    return desktop
}

private func validateAndCreateFolder(_ url: URL) -> Bool {
    do {
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        
        // Test write
        let test = url.appendingPathComponent(".test")
        try "test".write(to: test, atomically: true, encoding: .utf8)
        try FileManager.default.removeItem(at: test)
        
        return true
    } catch {
        logger.error("Folder validation failed for \(url.path): \(error)", category: .storage)
        return false
    }
}
```

### Pattern 3: User-Driven Recovery

```swift
@MainActor
func promptUserForFolderRecovery(invalidPath: String) async -> URL? {
    return await withCheckedContinuation { continuation in
        let alert = NSAlert()
        alert.messageText = "Save Folder Not Accessible"
        alert.informativeText = """
        The save folder is no longer accessible:
        \(invalidPath)
        
        What would you like to do?
        """
        alert.alertStyle = .warning
        
        alert.addButton(withTitle: "Choose New Folder")
        alert.addButton(withTitle: "Use Default Location")
        alert.addButton(withTitle: "Cancel Capture")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            // Choose new folder
            logger.info("User choosing new folder", category: .storage)
            showFolderPicker { url in
                continuation.resume(returning: url)
            }
            
        case .alertSecondButtonReturn:
            // Use default
            logger.info("User selected default location", category: .storage)
            let defaultURL = defaultSaveLocation()
            settings.saveFolderPath = ""
            continuation.resume(returning: defaultURL)
            
        default:
            // Cancel
            logger.info("User cancelled folder recovery", category: .storage)
            continuation.resume(returning: nil)
        }
    }
}
```

---

## 6. DEBUGGING HELPERS

Add to Settings window:

```swift
struct AdvancedSettingsPane: View {
    @State private var showLogs = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                icon: "ant.fill",
                title: "Debugging",
                subtitle: "Advanced diagnostics and logging"
            )
            
            HStack {
                Button("Export Logs") {
                    exportLogs()
                }
                .buttonStyle(.bordered)
                
                Button("Open Log Folder") {
                    openLogFolder()
                }
                .buttonStyle(.bordered)
                
                Button("Clear Logs") {
                    clearLogs()
                }
                .buttonStyle(.bordered)
            }
            
            Toggle("Verbose Logging", isOn: .constant(true))
            
            if showLogs {
                ScrollView {
                    Text(getRecentLogs())
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
                .frame(height: 200)
                .border(Color.secondary.opacity(0.3))
            }
            
            Button(showLogs ? "Hide Logs" : "Show Recent Logs") {
                showLogs.toggle()
            }
            .buttonStyle(.borderless)
        }
    }
    
    private func exportLogs() {
        guard let logURL = ScreenGrabberLogger.shared.exportLogs() else { return }
        
        let panel = NSSavePanel()
        panel.nameFieldStringValue = logURL.lastPathComponent
        panel.allowedContentTypes = [.log, .plainText]
        
        panel.begin { response in
            if response == .OK, let destination = panel.url {
                try? FileManager.default.copyItem(at: logURL, to: destination)
            }
        }
    }
    
    private func openLogFolder() {
        guard let logURL = ScreenGrabberLogger.shared.exportLogs() else { return }
        NSWorkspace.shared.selectFile(
            logURL.path,
            inFileViewerRootedAtPath: logURL.deletingLastPathComponent().path
        )
    }
    
    private func clearLogs() {
        guard let logURL = ScreenGrabberLogger.shared.exportLogs() else { return }
        try? FileManager.default.removeItem(at: logURL)
    }
    
    private func getRecentLogs() -> String {
        guard let logURL = ScreenGrabberLogger.shared.exportLogs(),
              let content = try? String(contentsOf: logURL) else {
            return "No logs available"
        }
        
        let lines = content.components(separatedBy: "\n")
        return lines.suffix(50).joined(separator: "\n")
    }
}
```

---

## 7. PERFORMANCE MONITORING

```swift
struct PerformanceTimer {
    let name: String
    let category: LogCategory
    let startTime: Date
    
    init(_ name: String, category: LogCategory = .debug) {
        self.name = name
        self.category = category
        self.startTime = Date()
        ScreenGrabberLogger.shared.debug("▶️ Started: \(name)", category: category)
    }
    
    func end() {
        let duration = Date().timeIntervalSince(startTime)
        ScreenGrabberLogger.shared.debug(
            "⏹️ Completed: \(name) in \(String(format: "%.3fs", duration))",
            category: category
        )
    }
}

// Usage:
func captureAndProcessImage() async {
    let timer = PerformanceTimer("Full Capture Pipeline", category: .capture)
    
    // Capture
    let captureTimer = PerformanceTimer("Image Capture", category: .capture)
    let image = await captureImage()
    captureTimer.end()
    
    // Process
    let processTimer = PerformanceTimer("Image Processing", category: .capture)
    let processed = await processImage(image)
    processTimer.end()
    
    // Save
    let saveTimer = PerformanceTimer("Save to Disk", category: .storage)
    await saveImage(processed)
    saveTimer.end()
    
    timer.end()
}
```

---

**This logging system provides:**
- ✅ Structured console output with emojis
- ✅ Detailed file-based logs for debugging
- ✅ OS unified logging for Console.app integration
- ✅ User-exportable logs for support
- ✅ Performance monitoring
- ✅ Error tracking with context
- ✅ Category-based filtering
