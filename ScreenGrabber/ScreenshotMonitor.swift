//
//  ScreenshotMonitor.swift
//  ScreenGrabber
//
//  Created on 11/13/25.
//

import Foundation
import Combine

/// Monitors the screenshots folder for changes and notifies observers
class ScreenshotMonitor: ObservableObject {
    static let shared = ScreenshotMonitor()
    
    // Notification names
    static let screenshotAddedNotification = Notification.Name("ScreenshotAdded")
    static let screenshotDeletedNotification = Notification.Name("ScreenshotDeleted")
    static let screenshotsChangedNotification = Notification.Name("ScreenshotsChanged")
    
    private var directoryMonitor: DispatchSourceFileSystemObject?
    private var monitoredURL: URL?
    
    private init() {}
    
    /// Start monitoring the screenshots folder
    func startMonitoring(url: URL) {
        stopMonitoring()
        
        monitoredURL = url
        
        // Ensure the directory exists
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
                print("[MONITOR] Created screenshots directory: \(url.path)")
            } catch {
                print("[MONITOR ERROR] Failed to create directory: \(error)")
                return
            }
        }
        
        // Open the directory for monitoring
        let fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            print("[MONITOR ERROR] Failed to open directory for monitoring")
            return
        }
        
        // Create a dispatch source for monitoring
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .delete, .rename],
            queue: DispatchQueue.global(qos: .background)
        )
        
        source.setEventHandler { [weak self] in
            self?.handleDirectoryChange()
        }
        
        source.setCancelHandler {
            close(fileDescriptor)
        }
        
        source.resume()
        directoryMonitor = source
        
        print("[MONITOR] Started monitoring: \(url.path)")
    }
    
    /// Stop monitoring
    func stopMonitoring() {
        directoryMonitor?.cancel()
        directoryMonitor = nil
        monitoredURL = nil
        print("[MONITOR] Stopped monitoring")
    }
    
    /// Handle directory changes
    private func handleDirectoryChange() {
        DispatchQueue.main.async {
            print("[MONITOR] Directory changed, posting notification")
            NotificationCenter.default.post(
                name: ScreenshotMonitor.screenshotsChangedNotification,
                object: nil
            )
        }
    }
    
    deinit {
        stopMonitoring()
    }
}
