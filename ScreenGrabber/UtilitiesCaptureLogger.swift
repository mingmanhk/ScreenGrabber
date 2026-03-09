//
//  CaptureLogger.swift
//  ScreenGrabber
//
//  Centralized logging for capture operations
//  PRODUCTION-READY IMPLEMENTATION
//

import Foundation
import os.log
import CoreGraphics
import AppKit

/// Centralized logging system for capture operations
struct CaptureLogger {
    
    // MARK: - Log Categories
    
    enum Category: String {
        case capture = "Capture"
        case permissions = "Permissions"
        case folder = "Folder"
        case screen = "Screen"
        case window = "Window"
        case area = "Area"
        case scrolling = "Scrolling"
        case save = "Save"
        case clipboard = "Clipboard"
        case error = "Error"
        case debug = "Debug"
        
        var emoji: String {
            switch self {
            case .capture: return "📸"
            case .permissions: return "🔐"
            case .folder: return "📁"
            case .screen: return "🖥️"
            case .window: return "🪟"
            case .area: return "📐"
            case .scrolling: return "📜"
            case .save: return "💾"
            case .clipboard: return "📋"
            case .error: return "❌"
            case .debug: return "🔍"
            }
        }
    }
    
    // MARK: - Log Levels
    
    enum Level {
        case info
        case warning
        case error
        case debug
        case success
        
        nonisolated var prefix: String {
            switch self {
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .debug: return "🔍"
            case .success: return "✅"
            }
        }
    }
    
    // MARK: - Logging Methods
    
    /// General purpose logging
    nonisolated static func log(_ category: Category, _ message: String, level: Level = .info) {
        let timestamp = formatTimestamp(Date())
        let formattedMessage = "[\(timestamp)] [\(category.rawValue.uppercased())] \(level.prefix) \(message)"
        
        print(formattedMessage)
        
        // Also log to system log for debugging
        if #available(macOS 11.0, *) {
            let logger = Logger(subsystem: "com.screengrabber", category: category.rawValue)
            
            switch level {
            case .info, .success:
                logger.info("\(message)")
            case .warning:
                logger.warning("\(message)")
            case .error:
                logger.error("\(message)")
            case .debug:
                logger.debug("\(message)")
            }
        }
    }
    
    /// Log folder operations
    nonisolated static func folderCheck(_ message: String) {
        log(.folder, message, level: .debug)
    }
    
    /// Log capture start
    nonisolated static func captureStarted(method: String) {
        log(.capture, "🎬 Starting capture: \(method)", level: .info)
    }
    
    /// Log capture success
    nonisolated static func captureCompleted(method: String, size: CGSize, duration: TimeInterval) {
        let message = "Capture completed - Method: \(method), Size: \(Int(size.width))×\(Int(size.height)), Duration: \(String(format: "%.2f", duration))s"
        log(.capture, message, level: .success)
    }
    
    /// Log capture error
    nonisolated static func captureError(_ error: Error, method: String? = nil) {
        var message = "Capture failed: \(error.localizedDescription)"
        if let method = method {
            message = "Capture failed (\(method)): \(error.localizedDescription)"
        }
        log(.error, message, level: .error)
    }
    
    /// Log screen detection
    nonisolated static func screenDetection(screens: [String]) {
        let message = "Detected \(screens.count) screen(s): \(screens.joined(separator: ", "))"
        log(.screen, message, level: .info)
    }
    
    /// Log screen detection failure
    nonisolated static func screenDetectionFailed(reason: String) {
        log(.screen, "Screen detection failed: \(reason)", level: .error)
    }
    
    /// Log permission check
    nonisolated static func permissionCheck(type: String, granted: Bool) {
        let status = granted ? "✅ Granted" : "❌ Denied"
        log(.permissions, "\(type) permission: \(status)", level: granted ? .success : .warning)
    }
    
    /// Log window selection
    nonisolated static func windowSelected(title: String, size: CGSize) {
        let message = "Selected window: \(title), Size: \(Int(size.width))×\(Int(size.height))"
        log(.window, message, level: .info)
    }
    
    /// Log area selection
    nonisolated static func areaSelected(rect: CGRect) {
        let message = "Selected area: Origin: (\(Int(rect.origin.x)), \(Int(rect.origin.y))), Size: \(Int(rect.width))×\(Int(rect.height))"
        log(.area, message, level: .info)
    }
    
    /// Log save operation
    nonisolated static func saveStarted(path: String) {
        log(.save, "Saving to: \(path)", level: .info)
    }
    
    /// Log save success
    nonisolated static func saveCompleted(path: String, fileSize: Int64) {
        let sizeString = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
        log(.save, "Saved successfully: \(path) (\(sizeString))", level: .success)
    }
    
    /// Log save error
    nonisolated static func saveError(_ error: Error, path: String) {
        log(.save, "Failed to save to \(path): \(error.localizedDescription)", level: .error)
    }
    
    // MARK: - Diagnostic Logging
    
    /// Log system environment for diagnostics
    @MainActor static func logSystemEnvironment() {
        log(.debug, "=== System Environment ===", level: .debug)
        
        // macOS version
        let os = ProcessInfo.processInfo.operatingSystemVersion
        log(.debug, "macOS: \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)", level: .debug)
        
        // Screens
        let screenCount = NSScreen.screens.count
        log(.debug, "Screens: \(screenCount)", level: .debug)
        
        for (index, screen) in NSScreen.screens.enumerated() {
            let name = screen.localizedName
            let frame = screen.frame
            let scale = screen.backingScaleFactor
            log(.debug, "  Screen \(index + 1): \(name), Frame: \(frame), Scale: \(scale)x", level: .debug)
        }
        
        // Main screen
        if let main = NSScreen.main {
            log(.debug, "Main screen: \(main.localizedName)", level: .debug)
        } else {
            log(.debug, "Main screen: nil (⚠️ WARNING)", level: .warning)
        }
        
        // Deepest screen
        if let deepest = NSScreen.deepest {
            log(.debug, "Deepest screen: \(deepest.localizedName)", level: .debug)
        } else {
            log(.debug, "Deepest screen: nil", level: .debug)
        }
        
        log(.debug, "=== End Environment ===", level: .debug)
    }
    
    /// Log detailed error with stack trace context
    nonisolated static func logDetailedError(_ error: Error, context: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let location = "\(fileName):\(line) in \(function)"
        
        log(.error, "Error in \(context)", level: .error)
        log(.error, "  Location: \(location)", level: .error)
        log(.error, "  Error: \(error.localizedDescription)", level: .error)
        
        if let localizedError = error as? LocalizedError {
            if let reason = localizedError.failureReason {
                log(.error, "  Reason: \(reason)", level: .error)
            }
            if let suggestion = localizedError.recoverySuggestion {
                log(.error, "  Suggestion: \(suggestion)", level: .error)
            }
        }
    }
    
    // MARK: - Helpers
    
    nonisolated private static func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
    
    // MARK: - Session Logging
    
    nonisolated(unsafe) private static let sessionStartTimeLock = NSLock()
    nonisolated(unsafe) private static var _sessionStartTime: Date?
    
    /// Start a new logging session
    @MainActor static func startSession() {
        // Access the start time safely using the lock
        sessionStartTimeLock.lock()
        _sessionStartTime = Date()
        sessionStartTimeLock.unlock()
        
        log(.debug, "==============================================", level: .info)
        log(.debug, "   ScreenGrabber Capture Session Started", level: .info)
        log(.debug, "==============================================", level: .info)
        logSystemEnvironment()
    }
    
    /// End the logging session
    nonisolated static func endSession() {
        // Access the start time safely using the lock
        sessionStartTimeLock.lock()
        let startTime = _sessionStartTime
        _sessionStartTime = nil
        sessionStartTimeLock.unlock()
        
        if let startTime = startTime {
            let duration = Date().timeIntervalSince(startTime)
            log(.debug, "Session duration: \(String(format: "%.2f", duration))s", level: .info)
        }
        
        log(.debug, "==============================================", level: .info)
        log(.debug, "   ScreenGrabber Capture Session Ended", level: .info)
        log(.debug, "==============================================", level: .info)
    }
}

// MARK: - Convenience Global Functions

/// Quick logging function for capture operations
func logCapture(_ message: String, level: CaptureLogger.Level = .info) {
    CaptureLogger.log(.capture, message, level: level)
}

/// Quick logging function for errors
func logError(_ error: Error, context: String) {
    CaptureLogger.logDetailedError(error, context: context)
}

// MARK: - Log File Management (Optional)

extension CaptureLogger {
    /// Get the log file URL for persistent logging
    nonisolated static var logFileURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let logsDirectory = appSupport.appendingPathComponent("ScreenGrabber/Logs", isDirectory: true)
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        
        // Create log file with date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        
        return logsDirectory.appendingPathComponent("capture-\(dateString).log")
    }
    
    /// Write log to file
    nonisolated static func writeToFile(_ message: String) {
        guard let logURL = logFileURL else { return }
        
        let timestamp = formatTimestamp(Date())
        let logLine = "[\(timestamp)] \(message)\n"
        
        if let data = logLine.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logURL.path) {
                // Append to existing file
                if let fileHandle = try? FileHandle(forWritingTo: logURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                // Create new file
                try? data.write(to: logURL, options: .atomic)
            }
        }
    }
    
    /// Clear old log files (keep last 7 days)
    nonisolated static func cleanupOldLogs() {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        
        let logsDirectory = appSupport.appendingPathComponent("ScreenGrabber/Logs", isDirectory: true)
        
        guard let files = try? FileManager.default.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: [.creationDateKey]) else {
            return
        }
        
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        for file in files {
            if let creationDate = (try? file.resourceValues(forKeys: [.creationDateKey]))?.creationDate,
               creationDate < cutoffDate {
                try? FileManager.default.removeItem(at: file)
                log(.debug, "Cleaned up old log file: \(file.lastPathComponent)", level: .debug)
            }
        }
    }
}
