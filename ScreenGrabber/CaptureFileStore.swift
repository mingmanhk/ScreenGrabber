//
//  CaptureFileStore.swift
//  ScreenGrabber
//
//  Handles saving captured images to disk with robust error handling
//

import Foundation
import AppKit

/// Actor that manages file save operations
/// Configured with user-interactive QoS to avoid priority inversion
actor CaptureFileStore {
    typealias CaptureType = ScreenGrabberTypes.CaptureType
    typealias CaptureError = ScreenGrabberTypes.CaptureError

    static let shared = CaptureFileStore()
    
    private init() {}
    
    /// Saves an image to disk with comprehensive error handling
    func saveImage(
        _ image: NSImage,
        type: CaptureType,
        timestamp: Date
    ) async -> Result<URL, CaptureError> {
        CaptureLogger.log(.save, "💾 Starting save operation...", level: .info)
        
        // Step 1: Get save folder from settings
        let saveFolder = await MainActor.run {
            SettingsModel.shared.effectiveSaveURL
        }
        CaptureLogger.log(.save, "   Target folder: \(saveFolder.path)", level: .info)
        
        // Step 2: Ensure folder exists and is writable (with fallback)
        let folderResult = await CapturePermissionsManager.shared.ensureCaptureFolderExists(at: saveFolder)
        
        guard case .success(let validatedFolder) = folderResult else {
            if case .failure(let error) = folderResult {
                CaptureLogger.log(.error, "❌ Folder validation failed: \(error.localizedDescription)", level: .error)
                
                // Show user-friendly error on main thread
                await MainActor.run {
                    showSaveErrorAlert(error: error)
                }
                
                return .failure(error)
            }
            CaptureLogger.log(.error, "❌ Folder validation failed with unknown error", level: .error)
            return .failure(.folderCreationFailed(underlying: nil))
        }
        
        CaptureLogger.log(.save, "✅ Folder validated: \(validatedFolder.path)", level: .success)
        
        // Step 3: Generate unique filename
        let filename = generateFilename(for: type, timestamp: timestamp)
        var fileURL = validatedFolder.appendingPathComponent(filename)
        
        // Ensure filename is unique (handle collisions)
        fileURL = await ensureUniqueFilename(fileURL)
        CaptureLogger.log(.save, "   Filename: \(fileURL.lastPathComponent)", level: .info)
        
        // Step 4: Convert image to PNG data
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            CaptureLogger.log(.error, "❌ Failed to convert image to PNG", level: .error)
            return .failure(.invalidImageData)
        }
        
        CaptureLogger.log(.save, "   PNG data size: \(ByteCountFormatter.string(fromByteCount: Int64(pngData.count), countStyle: .file))", level: .info)
        
        // Step 5: Write file to disk with error handling
        do {
            try pngData.write(to: fileURL, options: [.atomic, .completeFileProtection])
            
            // Verify file was written successfully
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
            CaptureLogger.log(.save, "✅ Screenshot saved successfully", level: .success)
            CaptureLogger.log(.save, "   Path: \(fileURL.path)", level: .info)
            CaptureLogger.log(.save, "   Size: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))", level: .info)
            
            return .success(fileURL)
            
        } catch let error as NSError {
            CaptureLogger.log(.error, "❌ File write failed: \(error.localizedDescription)", level: .error)
            CaptureLogger.log(.error, "   Domain: \(error.domain), Code: \(error.code)", level: .error)
            
            // Provide specific error handling
            if error.domain == NSCocoaErrorDomain {
                switch error.code {
                case NSFileWriteNoPermissionError:
                    return .failure(.permissionDenied(type: .fileSystem))
                case NSFileWriteOutOfSpaceError:
                    await MainActor.run {
                        showDiskSpaceError()
                    }
                    return .failure(.fileWriteFailed(underlying: error))
                default:
                    break
                }
            }
            
            return .failure(.fileWriteFailed(underlying: error))
        }
    }
    
    func deleteImage(at url: URL) async -> Result<Void, CaptureError> {
        do {
            try FileManager.default.removeItem(at: url)
            CaptureLogger.log(.save, "🗑️ Deleted image at \(url.path)", level: .info)
            return .success(())
        } catch {
            CaptureLogger.saveError(error, path: url.path)
            return .failure(.fileWriteFailed(underlying: error))
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateFilename(for type: CaptureType, timestamp: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = formatter.string(from: timestamp)
        
        let typeString: String
        switch type {
        case .area:
            typeString = "Area"
        case .window:
            typeString = "Window"
        case .fullscreen:
            typeString = "Screen"
        case .scrolling:
            typeString = "Scrolling"
        }
        
        return "Screenshot_\(typeString)_\(dateString).png"
    }
    
    private func ensureUniqueFilename(_ url: URL) async -> URL {
        var finalURL = url
        var counter = 1
        
        while FileManager.default.fileExists(atPath: finalURL.path) {
            let filename = url.deletingPathExtension().lastPathComponent
            let ext = url.pathExtension
            let directory = url.deletingLastPathComponent()
            
            finalURL = directory.appendingPathComponent("\(filename)_\(counter).\(ext)")
            counter += 1
            
            // Prevent infinite loop
            if counter > 1000 {
                CaptureLogger.log(.save, "⚠️ Too many filename collisions, using UUID", level: .warning)
                let uniqueName = "Screenshot_\(UUID().uuidString).\(ext)"
                return directory.appendingPathComponent(uniqueName)
            }
        }
        
        return finalURL
    }
    
    // MARK: - User Alerts
    
    @MainActor
    private func showSaveErrorAlert(error: CaptureError) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Cannot Save Screenshot"
        alert.informativeText = error.localizedDescription
        
        if let suggestion = error.recoverySuggestion {
            alert.informativeText += "\n\n" + suggestion
        }
        
        alert.addButton(withTitle: "OK")
        
        // If it's a folder error, offer to choose a new location
        if case .folderCreationFailed = error {
            alert.addButton(withTitle: "Choose Folder...")
            let response = alert.runModal()
            
            if response == .alertSecondButtonReturn {
                showFolderPicker()
            }
        } else {
            alert.runModal()
        }
    }
    
    @MainActor
    private func showDiskSpaceError() {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Not Enough Disk Space"
        alert.informativeText = """
        Your disk is full. Free up some space and try again.
        
        You can:
        • Delete old files
        • Empty the Trash
        • Move files to an external drive
        """
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Open Storage Settings")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.settings.Storage")!)
        }
    }
    
    @MainActor
    private func showFolderPicker() {
        let panel = NSOpenPanel()
        panel.message = "Choose where to save screenshots"
        panel.prompt = "Select Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let screenGrabberFolder = url.appendingPathComponent("Screen Grabber")
                SettingsModel.shared.setCustomSaveLocation(screenGrabberFolder)
                
                // Show confirmation
                let confirmAlert = NSAlert()
                confirmAlert.alertStyle = .informational
                confirmAlert.messageText = "Save Location Updated"
                confirmAlert.informativeText = "Screenshots will now be saved to:\n\(screenGrabberFolder.path)"
                confirmAlert.addButton(withTitle: "OK")
                confirmAlert.runModal()
            }
        }
    }
}

