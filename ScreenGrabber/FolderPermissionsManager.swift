//
//  FolderPermissionsManager.swift
//  ScreenGrabber
//
//  Manages folder access and creation with proper user prompts
//  Follows Apple Human Interface Guidelines
//

import Foundation
import AppKit
import SwiftUI
import Combine

@MainActor
class FolderPermissionsManager: ObservableObject {
    static let shared = FolderPermissionsManager()
    
    @Published var hasPermission = false
    @Published var showPermissionAlert = false
    
    private let defaultFolderName = "Screen Grabber"
    private var currentSecurityScopedURL: URL?
    
    private init() {
        _ = checkFolderAccess()
    }
    
    deinit {
        // Clean up security-scoped resource access
        currentSecurityScopedURL?.stopAccessingSecurityScopedResource()
    }
    
    // MARK: - Folder Access Check
    
    /// Checks if we have permission to access the Pictures folder
    func checkFolderAccess() -> Bool {
        let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
        
        guard let picturesURL = picturesURL else {
            print("[PERMISSIONS] ❌ Cannot access Pictures directory")
            return false
        }
        
        // Test if we can write to Pictures directory
        let testFileURL = picturesURL.appendingPathComponent(".screengrabber_test")
        
        do {
            try "test".write(to: testFileURL, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(at: testFileURL)
            hasPermission = true
            print("[PERMISSIONS] ✅ Have write access to Pictures folder")
            return true
        } catch {
            hasPermission = false
            print("[PERMISSIONS] ⚠️ No write access to Pictures folder: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Folder Creation with User Consent
    
    /// Creates the Screen Grabber folder with user permission
    func ensureScreenGrabberFolder() async -> Result<URL, FolderError> {
        print("[PERMISSIONS] 🔍 Checking Screen Grabber folder...")
        
        // Check if user has a custom location preference
        if let customPath = UserDefaults.standard.string(forKey: "customScreenshotLocation") {
            let customURL = URL(fileURLWithPath: customPath)
            
            if FileManager.default.fileExists(atPath: customURL.path) {
                print("[PERMISSIONS] ✅ Using existing custom location: \(customPath)")
                
                // Ensure thumbnails subfolder exists
                let thumbnailsURL = customURL.appendingPathComponent(".thumbnails")
                if !FileManager.default.fileExists(atPath: thumbnailsURL.path) {
                    do {
                        try FileManager.default.createDirectory(at: thumbnailsURL, withIntermediateDirectories: true)
                        print("[PERMISSIONS] ✅ Created thumbnails folder in custom location")
                    } catch {
                        print("[PERMISSIONS] ⚠️ Could not create thumbnails folder: \(error.localizedDescription)")
                    }
                }
                
                return .success(customURL)
            } else {
                print("[PERMISSIONS] ⚠️ Custom location no longer exists, clearing preference")
                UserDefaults.standard.removeObject(forKey: "customScreenshotLocation")
            }
        }
        
        // First check if we have basic Pictures access
        guard checkFolderAccess() else {
            print("[PERMISSIONS] ❌ No access to Pictures folder")
            return .failure(.noAccess)
        }
        
        guard let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first else {
            print("[PERMISSIONS] ❌ Pictures directory not found")
            return .failure(.picturesNotFound)
        }
        
        let screenGrabberURL = picturesURL.appendingPathComponent(defaultFolderName)
        
        // Check if folder already exists
        if FileManager.default.fileExists(atPath: screenGrabberURL.path) {
            print("[PERMISSIONS] ✅ Screen Grabber folder already exists: \(screenGrabberURL.path)")
            
            // Ensure thumbnails subfolder
            let thumbnailsURL = screenGrabberURL.appendingPathComponent(".thumbnails")
            if !FileManager.default.fileExists(atPath: thumbnailsURL.path) {
                do {
                    try FileManager.default.createDirectory(at: thumbnailsURL, withIntermediateDirectories: true)
                    print("[PERMISSIONS] ✅ Created thumbnails folder")
                } catch {
                    print("[PERMISSIONS] ⚠️ Could not create thumbnails folder: \(error.localizedDescription)")
                }
            }
            
            return .success(screenGrabberURL)
        }
        
        // Folder doesn't exist - ask user for permission
        print("[PERMISSIONS] 📋 Showing folder creation alert to user...")
        let userResponse = await showFolderCreationAlert(folderPath: screenGrabberURL.path)
        
        guard userResponse else {
            print("[PERMISSIONS] ❌ User declined folder creation")
            return .failure(.userDeclined)
        }
        
        // Check if user chose custom location during alert
        if let customPath = UserDefaults.standard.string(forKey: "customScreenshotLocation") {
            let customURL = URL(fileURLWithPath: customPath)
            
            // User selected custom location - try to create it
            do {
                if !FileManager.default.fileExists(atPath: customURL.path) {
                    try FileManager.default.createDirectory(at: customURL, withIntermediateDirectories: true)
                    print("[PERMISSIONS] ✅ Created custom Screen Grabber folder: \(customURL.path)")
                }
                
                // Create thumbnails subfolder
                let thumbnailsURL = customURL.appendingPathComponent(".thumbnails")
                try FileManager.default.createDirectory(at: thumbnailsURL, withIntermediateDirectories: true)
                print("[PERMISSIONS] ✅ Created thumbnails folder in custom location")
                
                await showSuccessNotification(folderURL: customURL)
                return .success(customURL)
                
            } catch {
                print("[PERMISSIONS] ❌ Failed to create custom folder: \(error.localizedDescription)")
                await showErrorAlert(error: error)
                return .failure(.creationFailed(error))
            }
        }
        
        // User approved default location - create the folder
        do {
            try FileManager.default.createDirectory(at: screenGrabberURL, withIntermediateDirectories: true)
            print("[PERMISSIONS] ✅ Created Screen Grabber folder: \(screenGrabberURL.path)")
            
            // Create thumbnails subfolder
            let thumbnailsURL = screenGrabberURL.appendingPathComponent(".thumbnails")
            try FileManager.default.createDirectory(at: thumbnailsURL, withIntermediateDirectories: true)
            print("[PERMISSIONS] ✅ Created thumbnails folder")
            
            // Show success notification
            await showSuccessNotification(folderURL: screenGrabberURL)
            
            return .success(screenGrabberURL)
            
        } catch {
            print("[PERMISSIONS] ❌ Failed to create folder: \(error.localizedDescription)")
            await showErrorAlert(error: error)
            return .failure(.creationFailed(error))
        }
    }
    
    // MARK: - User Alerts (Following Apple HIG)
    
    /// Shows alert asking user permission to create folder
    private func showFolderCreationAlert(folderPath: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let alert = NSAlert()
                
                // Title - Clear and direct
                alert.messageText = "Create Screenshots Folder?"
                
                // Informative text - Explain why and where
                alert.informativeText = """
                Screen Grabber needs to create a folder to save your screenshots.
                
                Location: \(folderPath)
                
                Your screenshots will be organized in this folder with automatic thumbnails for quick preview.
                """
                
                // Icon - Use standard system icon
                alert.alertStyle = .informational
                alert.icon = NSImage(systemSymbolName: "folder.badge.plus", accessibilityDescription: "Create Folder")
                
                // Buttons - Clear action labels (Apple HIG)
                alert.addButton(withTitle: "Create Folder")  // Primary action
                alert.addButton(withTitle: "Choose Different Location")  // Secondary action
                alert.addButton(withTitle: "Cancel")  // Cancel action
                
                // Make primary button prominent
                alert.buttons[0].keyEquivalent = "\r"  // Return key
                
                let response = alert.runModal()
                
                switch response {
                case .alertFirstButtonReturn:
                    // Create Folder
                    print("[PERMISSIONS] ✅ User approved folder creation")
                    continuation.resume(returning: true)
                    
                case .alertSecondButtonReturn:
                    // Choose Different Location
                    print("[PERMISSIONS] 🔄 User wants to choose custom location")
                    self.showFolderPicker { selectedURL in
                        if let url = selectedURL {
                            // User selected custom location - create "Screen Grabber" folder inside it
                            let customScreenGrabberFolder = url.appendingPathComponent(self.defaultFolderName)
                            UserDefaults.standard.set(customScreenGrabberFolder.path, forKey: "customScreenshotLocation")
                            print("[PERMISSIONS] ✅ Custom location set: \(customScreenGrabberFolder.path)")
                            continuation.resume(returning: true)
                        } else {
                            print("[PERMISSIONS] ❌ User cancelled folder picker")
                            continuation.resume(returning: false)
                        }
                    }
                    
                default:
                    // Cancel
                    print("[PERMISSIONS] ❌ User cancelled folder creation")
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    // MARK: - Proactive First-Launch Prompt
    /// Proactively prompt the user to confirm or choose a save location, even if a valid default exists.
    /// Returns the chosen/confirmed folder URL on success.
    public func promptForInitialSaveLocation() async -> Result<URL, FolderError> {
        // Build default target path under Pictures
        guard let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first else {
            return .failure(.picturesNotFound)
        }
        let defaultURL = picturesURL.appendingPathComponent(defaultFolderName)

        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Choose Where to Save Screenshots"
                alert.informativeText = "You can use the default ‘\(self.defaultFolderName)’ folder in Pictures, or choose a different location."
                alert.alertStyle = .informational
                alert.icon = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
                alert.addButton(withTitle: "Use Default")
                alert.addButton(withTitle: "Choose Location…")
                alert.addButton(withTitle: "Cancel")
                alert.buttons[0].keyEquivalent = "\r"

                let response = alert.runModal()
                switch response {
                case .alertFirstButtonReturn:
                    // Use Default: ensure folder exists
                    do {
                        if !FileManager.default.fileExists(atPath: defaultURL.path) {
                            try FileManager.default.createDirectory(at: defaultURL, withIntermediateDirectories: true)
                        }
                        let thumbs = defaultURL.appendingPathComponent(".thumbnails")
                        if !FileManager.default.fileExists(atPath: thumbs.path) {
                            try FileManager.default.createDirectory(at: thumbs, withIntermediateDirectories: true)
                        }
                        continuation.resume(returning: .success(defaultURL))
                    } catch {
                        continuation.resume(returning: .failure(.creationFailed(error)))
                    }

                case .alertSecondButtonReturn:
                    // Choose custom location
                    self.showFolderPicker { selectedURL in
                        guard let baseURL = selectedURL else {
                            continuation.resume(returning: .failure(.userDeclined))
                            return
                        }
                        let customScreenGrabberFolder = baseURL.appendingPathComponent(self.defaultFolderName)
                        do {
                            if !FileManager.default.fileExists(atPath: customScreenGrabberFolder.path) {
                                try FileManager.default.createDirectory(at: customScreenGrabberFolder, withIntermediateDirectories: true)
                            }
                            let thumbs = customScreenGrabberFolder.appendingPathComponent(".thumbnails")
                            if !FileManager.default.fileExists(atPath: thumbs.path) {
                                try FileManager.default.createDirectory(at: thumbs, withIntermediateDirectories: true)
                            }
                            UserDefaults.standard.set(customScreenGrabberFolder.path, forKey: "customScreenshotLocation")
                            continuation.resume(returning: .success(customScreenGrabberFolder))
                        } catch {
                            continuation.resume(returning: .failure(.creationFailed(error)))
                        }
                    }

                default:
                    continuation.resume(returning: .failure(.userDeclined))
                }
            }
        }
    }
    
    /// Shows folder picker for custom location
    private func showFolderPicker(completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.message = "Choose where to save screenshots"
        panel.prompt = "Select"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        
        // Start at Pictures folder
        if let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first {
            panel.directoryURL = picturesURL
        }
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                // Create a security-scoped bookmark for persistent access
                self.saveBookmark(for: url)
                completion(url)
            } else {
                completion(nil)
            }
        }
    }
    
    // MARK: - Security-Scoped Bookmarks
    
    /// Save a security-scoped bookmark for the selected folder
    private func saveBookmark(for url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmarkData, forKey: "customScreenshotLocationBookmark")
            print("[PERMISSIONS] ✅ Saved security-scoped bookmark for: \(url.path)")
        } catch {
            print("[PERMISSIONS] ⚠️ Failed to create bookmark: \(error.localizedDescription)")
            // Still save the path as fallback
        }
    }
    
    /// Restore URL from security-scoped bookmark
    private func restoreBookmarkedURL() -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: "customScreenshotLocationBookmark") else {
            return nil
        }
        
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if isStale {
                print("[PERMISSIONS] ⚠️ Bookmark is stale, needs to be recreated")
                // Try to save a fresh bookmark
                saveBookmark(for: url)
            }
            
            // Stop accessing previous resource if any
            currentSecurityScopedURL?.stopAccessingSecurityScopedResource()
            
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                print("[PERMISSIONS] ❌ Failed to start accessing security-scoped resource")
                return nil
            }
            
            // Track the current security-scoped URL
            currentSecurityScopedURL = url
            
            print("[PERMISSIONS] ✅ Restored bookmarked URL: \(url.path)")
            return url
        } catch {
            print("[PERMISSIONS] ❌ Failed to restore bookmark: \(error.localizedDescription)")
            // Clean up invalid bookmark
            UserDefaults.standard.removeObject(forKey: "customScreenshotLocationBookmark")
            return nil
        }
    }
    
    /// Shows success notification after folder creation
    private func showSuccessNotification(folderURL: URL) async {
        let alert = NSAlert()
        alert.messageText = "Folder Created Successfully"
        alert.informativeText = "Your screenshots will be saved to:\n\(folderURL.path)"
        alert.alertStyle = .informational
        alert.icon = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Success")
        
        alert.addButton(withTitle: "Open Folder")
        alert.addButton(withTitle: "OK")
        
        DispatchQueue.main.async {
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Open folder in Finder
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folderURL.path)
            }
        }
    }
    
    /// Shows error alert if folder creation fails
    private func showErrorAlert(error: Error) async {
        let alert = NSAlert()
        alert.messageText = "Could Not Create Folder"
        alert.informativeText = """
        Screen Grabber was unable to create the screenshots folder.
        
        Error: \(error.localizedDescription)
        
        Please check your disk space and permissions, then try again.
        """
        alert.alertStyle = .critical
        alert.icon = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Error")
        
        alert.addButton(withTitle: "Try Again")
        alert.addButton(withTitle: "Choose Different Location")
        alert.addButton(withTitle: "Cancel")
        
        DispatchQueue.main.async {
            let response = alert.runModal()
            
            switch response {
            case .alertFirstButtonReturn:
                // Try again
                Task {
                    _ = await self.ensureScreenGrabberFolder()
                }
                
            case .alertSecondButtonReturn:
                // Choose different location
                self.showFolderPicker { selectedURL in
                    if let url = selectedURL {
                        UserDefaults.standard.set(url.path, forKey: "customScreenshotLocation")
                        print("[PERMISSIONS] ✅ User selected custom location: \(url.path)")
                    }
                }
                
            default:
                break
            }
        }
    }
    
    // MARK: - Get Save Location
    
    /// Returns the URL where screenshots should be saved
    func getScreenshotSaveLocation() -> URL? {
        print("[PERMISSIONS] 🔍 Getting screenshot save location...")
        
        // First, try to restore from security-scoped bookmark
        if let bookmarkedURL = restoreBookmarkedURL() {
            if FileManager.default.fileExists(atPath: bookmarkedURL.path) {
                print("[PERMISSIONS] 📁 Using bookmarked location: \(bookmarkedURL.path)")
                // Also update the string path for consistency
                UserDefaults.standard.set(bookmarkedURL.path, forKey: "customScreenshotLocation")
                return bookmarkedURL
            } else {
                print("[PERMISSIONS] ⚠️ Bookmarked location no longer exists")
                // Clean up (stopAccessingSecurityScopedResource is called in restoreBookmarkedURL)
                UserDefaults.standard.removeObject(forKey: "customScreenshotLocationBookmark")
                currentSecurityScopedURL = nil
            }
        }
        
        // Check if user selected custom location (fallback to path-based)
        if let customPath = UserDefaults.standard.string(forKey: "customScreenshotLocation") {
            let customURL = URL(fileURLWithPath: customPath)
            if FileManager.default.fileExists(atPath: customURL.path) {
                print("[PERMISSIONS] 📁 Using custom location: \(customPath)")
                return customURL
            } else {
                print("[PERMISSIONS] ⚠️ Custom location no longer exists: \(customPath)")
                // Clear invalid custom location
                UserDefaults.standard.removeObject(forKey: "customScreenshotLocation")
            }
        }
        
        // Use default Pictures/Screen Grabber
        guard let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first else {
            print("[PERMISSIONS] ❌ Cannot find Pictures directory")
            return nil
        }
        
        let defaultURL = picturesURL.appendingPathComponent(defaultFolderName)
        print("[PERMISSIONS] 📁 Using default location: \(defaultURL.path)")
        
        // Create if doesn't exist (without asking - silent creation for default location)
        if !FileManager.default.fileExists(atPath: defaultURL.path) {
            do {
                try FileManager.default.createDirectory(at: defaultURL, withIntermediateDirectories: true)
                print("[PERMISSIONS] ✅ Created default folder: \(defaultURL.path)")
                
                // Also create thumbnails folder
                let thumbnailsURL = defaultURL.appendingPathComponent(".thumbnails")
                try FileManager.default.createDirectory(at: thumbnailsURL, withIntermediateDirectories: true)
                print("[PERMISSIONS] ✅ Created thumbnails folder")
            } catch {
                print("[PERMISSIONS] ❌ Failed to create default folder: \(error.localizedDescription)")
                return nil
            }
        }
        
        return defaultURL
    }
    
    // MARK: - Settings Integration
    
    /// Shows folder location in Settings with option to change
    func showFolderSettingsRow() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Screenshot Location")
                    .font(.subheadline)
                
                if let location = getScreenshotSaveLocation() {
                    Text(location.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Not set")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
            
            Button("Change...") {
                self.showFolderPicker { url in
                    if let url = url {
                        UserDefaults.standard.set(url.path, forKey: "customScreenshotLocation")
                        self.saveBookmark(for: url)
                    }
                }
            }
            .buttonStyle(.bordered)
            
            Button("Open") {
                if let location = self.getScreenshotSaveLocation() {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: location.path)
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Folder Errors

enum FolderError: LocalizedError {
    case noAccess
    case picturesNotFound
    case userDeclined
    case creationFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .noAccess:
            return "No permission to access Pictures folder"
        case .picturesNotFound:
            return "Pictures folder not found on this system"
        case .userDeclined:
            return "User declined folder creation"
        case .creationFailed(let error):
            return "Failed to create folder: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noAccess:
            return "Please grant Full Disk Access in System Settings → Privacy & Security"
        case .picturesNotFound:
            return "Please choose a custom location for screenshots"
        case .userDeclined:
            return "You can change the screenshot location in Settings"
        case .creationFailed:
            return "Please check your disk space and try again"
        }
    }
}

