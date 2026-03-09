import Foundation
import AppKit
#if canImport(AVFoundation)
import AVFoundation
#endif

/// Actor that manages capture permissions and folder validation
/// Configured with user-interactive QoS to avoid priority inversion
actor CapturePermissionsManager {
    static let shared = CapturePermissionsManager()

    // Default save location: ~/Pictures/Screen Grabber/
    private var defaultFolderURL: URL {
        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures")
        return pictures.appendingPathComponent("Screen Grabber", isDirectory: true)
    }

    func ensureCaptureFolderExists() async -> Result<URL, ScreenGrabberTypes.CaptureError> {
        await ensureCaptureFolderExists(at: defaultFolderURL)
    }

    /// Enhanced folder creation with robust error handling and recovery
    func ensureCaptureFolderExists(at url: URL) async -> Result<URL, ScreenGrabberTypes.CaptureError> {
        CaptureLogger.folderCheck("🔍 Validating folder: \(url.path)")
        
        // Check if this folder requires Files & Folders permission (sandboxed apps)
        let requiresFilesPermission = Self.requiresFilesFoldersPermission(for: url)
        let requiresFDA = Self.requiresFullDiskAccess(for: url)
        let folderName = Self.folderDisplayName(for: url)
        
        if requiresFilesPermission {
            CaptureLogger.folderCheck("⚠️ Folder requires Files & Folders permission: \(url.path)")
            
            // First check if we can access the folder
            if !Self.hasFolderAccess(for: url) {
                CaptureLogger.folderCheck("❌ Files & Folders permission not granted for \(folderName)")
                
                // Trigger permission prompt
                Self.triggerFilesFoldersPermissionPrompt(for: url)
                
                // Check again after triggering
                if !Self.hasFolderAccess(for: url) {
                    // Show appropriate alert based on permission type
                    await MainActor.run {
                        Self.showFilesFoldersAccessDeniedAlert(attemptedPath: url.path, folderName: folderName)
                    }
                    return .failure(.permissionDenied(type: .fileSystem))
                }
            } else {
                CaptureLogger.folderCheck("✅ Files & Folders permission granted for \(folderName)")
            }
        }
        
        if requiresFDA {
            CaptureLogger.folderCheck("⚠️ Folder requires Full Disk Access: \(url.path)")
            
            // Check if we have Full Disk Access
            if !Self.hasFullDiskAccess() {
                CaptureLogger.folderCheck("❌ Full Disk Access not granted")
                
                // Show alert on main actor
                await MainActor.run {
                    Self.showFullDiskAccessDeniedAlert(attemptedPath: url.path)
                }
                
                return .failure(.permissionDenied(type: .fullDiskAccess))
            } else {
                CaptureLogger.folderCheck("✅ Full Disk Access granted")
            }
        }
        
        do {
            // Step 1: Check if folder exists
            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            
            if exists && isDir.boolValue {
                CaptureLogger.folderCheck("✅ Folder exists: \(url.path)")
            } else if exists && !isDir.boolValue {
                // Path exists but it's a file, not a directory - this is a problem
                CaptureLogger.folderCheck("❌ Path exists but is a file, not a directory: \(url.path)")
                return .failure(.folderCreationFailed(underlying: NSError(
                    domain: "ScreenGrabber",
                    code: 1001,
                    userInfo: [NSLocalizedDescriptionKey: "A file exists at the target path. Please choose a different location."]
                )))
            } else {
                // Step 2: Create folder with intermediate directories
                CaptureLogger.folderCheck("📁 Creating folder at: \(url.path)")
                try FileManager.default.createDirectory(
                    at: url,
                    withIntermediateDirectories: true,
                    attributes: [
                        .posixPermissions: 0o755  // rwxr-xr-x
                    ]
                )
                CaptureLogger.folderCheck("✅ Successfully created folder at: \(url.path)")
            }
            
            // Step 3: Verify folder is writable
            CaptureLogger.folderCheck("🔒 Testing write permissions...")
            let probe = url.appendingPathComponent(".screengrabber_write_test_\(UUID().uuidString)")
            do {
                try "test".write(to: probe, atomically: true, encoding: .utf8)
                try FileManager.default.removeItem(at: probe)
                CaptureLogger.folderCheck("✅ Folder is writable")
            } catch {
                CaptureLogger.folderCheck("❌ Folder is not writable: \(error.localizedDescription)")
                
                // If it's a permission error and the folder requires permissions, suggest enabling them
                if requiresFilesPermission && !Self.hasFolderAccess(for: url) {
                    await MainActor.run {
                        Self.showFilesFoldersAccessDeniedAlert(attemptedPath: url.path, folderName: folderName)
                    }
                    return .failure(.permissionDenied(type: .fileSystem))
                } else if requiresFDA && !Self.hasFullDiskAccess() {
                    await MainActor.run {
                        Self.showFullDiskAccessDeniedAlert(attemptedPath: url.path)
                    }
                    return .failure(.permissionDenied(type: .fullDiskAccess))
                }
                
                return .failure(.permissionDenied(type: .fileSystem))
            }
            
            // Step 4: Ensure .thumbnails subfolder exists
            let thumbnailsURL = url.appendingPathComponent(".thumbnails", isDirectory: true)
            if !FileManager.default.fileExists(atPath: thumbnailsURL.path) {
                do {
                    try FileManager.default.createDirectory(
                        at: thumbnailsURL,
                        withIntermediateDirectories: true,
                        attributes: [.posixPermissions: 0o755]
                    )
                    CaptureLogger.folderCheck("✅ Created thumbnails folder")
                } catch {
                    // Non-fatal: thumbnails folder is optional
                    CaptureLogger.folderCheck("⚠️ Could not create thumbnails folder (non-fatal): \(error.localizedDescription)")
                }
            }
            
            return .success(url)
            
        } catch let error as NSError {
            CaptureLogger.folderCheck("❌ Folder validation failed: \(error.localizedDescription)")
            CaptureLogger.folderCheck("   Domain: \(error.domain), Code: \(error.code)")
            
            // Provide specific error guidance
            if error.domain == NSCocoaErrorDomain {
                switch error.code {
                case NSFileWriteNoPermissionError, NSFileWriteVolumeReadOnlyError:
                    // Check if this is a Files & Folders or Full Disk Access issue
                    if requiresFilesPermission && !Self.hasFolderAccess(for: url) {
                        await MainActor.run {
                            Self.showFilesFoldersAccessDeniedAlert(attemptedPath: url.path, folderName: folderName)
                        }
                        return .failure(.permissionDenied(type: .fileSystem))
                    } else if requiresFDA && !Self.hasFullDiskAccess() {
                        await MainActor.run {
                            Self.showFullDiskAccessDeniedAlert(attemptedPath: url.path)
                        }
                        return .failure(.permissionDenied(type: .fullDiskAccess))
                    }
                    return .failure(.permissionDenied(type: .fileSystem))
                case NSFileWriteOutOfSpaceError:
                    return .failure(.folderCreationFailed(underlying: NSError(
                        domain: "ScreenGrabber",
                        code: 1002,
                        userInfo: [NSLocalizedDescriptionKey: "Not enough disk space to create folder."]
                    )))
                default:
                    return .failure(.folderCreationFailed(underlying: error))
                }
            }
            
            return .failure(.folderCreationFailed(underlying: error))
        }
    }

    func checkAndRequestPermissions(needsMicrophone: Bool = false) async -> Result<Void, ScreenGrabberTypes.CaptureError> {
        // Screen Recording permission: there's no programmatic prompt; we can detect and guide the user.
        // We'll attempt to capture a single pixel using CGDisplayStream-like checks, but here we simulate a check via CGPreflightScreenCaptureAccess.
        if !Self.hasScreenRecordingPermission() {
            CaptureLogger.log(.permissions, "Screen recording permission missing")
            return .failure(.permissionDenied(type: .screenRecording))
        }

        if needsMicrophone {
            let mic = await Self.requestMicrophoneIfNeeded()
            if !mic {
                CaptureLogger.log(.permissions, "Microphone permission denied")
                return .failure(.permissionDenied(type: .microphone))
            }
        }

        // File system (Pictures) access is generally allowed for user-space within sandbox exceptions; we validate via write probe in ensureCaptureFolderExists.
        return .success(())
    }

    func validateCaptureEnvironment(needsMicrophone: Bool = false) async -> Result<Void, ScreenGrabberTypes.CaptureError> {
        // Get the target URL in a sendable way
        let targetURL = await MainActor.run { SettingsModel.shared.effectiveSaveURL }
        
        CaptureLogger.folderCheck("🔍 Validating capture environment...")
        CaptureLogger.folderCheck("   Target folder: \(targetURL.path)")
        
        // Step 1: Ensure folder exists and is writable
        switch await ensureCaptureFolderExists(at: targetURL) {
        case .failure(let error):
            CaptureLogger.folderCheck("❌ Folder validation failed, attempting fallback...")
            
            // Attempt fallback to default location if custom location failed
            let isCustomLocation = await MainActor.run {
                SettingsModel.shared.customSaveLocationPath != nil
            }
            
            if isCustomLocation {
                CaptureLogger.folderCheck("⚠️ Custom location failed, trying default location...")
                
                // Try default location as fallback
                switch await ensureCaptureFolderExists(at: defaultFolderURL) {
                case .success(let fallbackURL):
                    CaptureLogger.folderCheck("✅ Fallback to default location successful: \(fallbackURL.path)")
                    
                    // Clear invalid custom location
                    await MainActor.run {
                        SettingsModel.shared.customSaveLocationPath = nil
                    }
                    
                    // Show user notification about fallback
                    await showFallbackNotification(originalError: error)
                    
                    // Continue with permissions check
                    break
                    
                case .failure(let fallbackError):
                    CaptureLogger.folderCheck("❌ Both custom and default locations failed")
                    await showFolderErrorAlert(error: error, fallbackError: fallbackError)
                    return .failure(fallbackError)
                }
            } else {
                // Default location itself failed - show error
                await showFolderErrorAlert(error: error, fallbackError: nil)
                return .failure(error)
            }
            
        case .success(let url):
            CaptureLogger.folderCheck("✅ Folder validation successful: \(url.path)")
        }
        
        // Step 2: Check system permissions
        switch await checkAndRequestPermissions(needsMicrophone: needsMicrophone) {
        case .failure(let error):
            return .failure(error)
        case .success:
            return .success(())
        }
    }
    
    // MARK: - User Notifications
    
    @MainActor
    private func showFallbackNotification(originalError: ScreenGrabberTypes.CaptureError) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Save Location Changed"
        alert.informativeText = """
        The custom save location could not be accessed:
        
        \(originalError.localizedDescription)
        
        Screenshots will now be saved to the default location:
        ~/Pictures/Screen Grabber/
        
        You can change this in Settings.
        """
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Open Settings")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            // Open settings
            NSWorkspace.shared.open(URL(string: "screengrabber://settings")!)
        }
    }
    
    @MainActor
    private func showFolderErrorAlert(error: ScreenGrabberTypes.CaptureError, fallbackError: ScreenGrabberTypes.CaptureError?) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Cannot Create Screenshot Folder"
        
        var infoText = """
        ScreenGrabber could not create or access the screenshot folder.
        
        Error: \(error.localizedDescription)
        """
        
        if let suggestion = error.recoverySuggestion {
            infoText += "\n\n\(suggestion)"
        }
        
        if let fallbackError = fallbackError {
            infoText += "\n\nDefault location also failed: \(fallbackError.localizedDescription)"
        }
        
        alert.informativeText = infoText
        alert.addButton(withTitle: "Choose Folder...")
        alert.addButton(withTitle: "Try Again")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            // Show folder picker
            showFolderPicker()
            
        case .alertSecondButtonReturn:
            // User wants to try again - nothing to do, they can capture again
            break
            
        default:
            break
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
        
        // Start at user's home directory
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task { @MainActor in
                    let screenGrabberFolder = url.appendingPathComponent("Screen Grabber")
                    SettingsModel.shared.setCustomSaveLocation(screenGrabberFolder)
                    
                    // Try to create the folder immediately
                    let result = await self.ensureCaptureFolderExists(at: screenGrabberFolder)
                    
                    if case .success = result {
                        let confirmAlert = NSAlert()
                        confirmAlert.alertStyle = .informational
                        confirmAlert.messageText = "Folder Set Successfully"
                        confirmAlert.informativeText = "Screenshots will be saved to:\n\(screenGrabberFolder.path)"
                        confirmAlert.addButton(withTitle: "OK")
                        confirmAlert.runModal()
                    }
                }
            }
        }
    }

    // MARK: - Helpers
    
    /// Check if the app has access to a specific user folder (Desktop, Documents, Downloads)
    nonisolated static func hasFolderAccess(for folderURL: URL) -> Bool {
        // First, check if the folder exists
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folderURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }
        
        // Try to list contents - this is the most reliable test
        do {
            _ = try FileManager.default.contentsOfDirectory(atPath: folderURL.path)
            return true
        } catch {
            CaptureLogger.log(.permissions, "Cannot access \(folderURL.lastPathComponent): \(error.localizedDescription)")
            return false
        }
    }
    
    /// Request access to a folder by attempting to open a bookmark
    /// This triggers the macOS permission prompt
    @MainActor
    static func requestFolderAccess(for folderURL: URL) -> Bool {
        // Create an open panel to request access
        let panel = NSOpenPanel()
        panel.message = "ScreenGrabber needs access to \(folderURL.lastPathComponent) to save screenshots."
        panel.prompt = "Grant Access"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = folderURL
        
        let response = panel.runModal()
        return response == .OK
    }
    
    /// Trigger Files & Folders permission prompt by attempting access
    /// This makes the app appear in System Settings → Privacy & Security → Files & Folders
    nonisolated static func triggerFilesFoldersPermissionPrompt(for folderURL: URL) {
        // Attempt to access the folder - this triggers TCC
        _ = hasFolderAccess(for: folderURL)
        
        // Attempt to get a security-scoped bookmark (sandbox-compatible)
        do {
            let bookmarkData = try folderURL.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            _ = bookmarkData
            CaptureLogger.log(.permissions, "Created security-scoped bookmark for \(folderURL.lastPathComponent)")
        } catch {
            CaptureLogger.log(.permissions, "Could not create bookmark for \(folderURL.lastPathComponent): \(error.localizedDescription)")
        }
    }
    
    /// Check if the app has Full Disk Access permission
    nonisolated static func hasFullDiskAccess() -> Bool {
        // Test by attempting to read from a known protected directory
        // The Library/Safari directory is a reliable indicator for Full Disk Access
        let testPaths = [
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Safari/Bookmarks.plist"),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments"),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Mail")
        ]
        
        // Try to access each test path
        for testPath in testPaths {
            if FileManager.default.isReadableFile(atPath: testPath.path) {
                // Successfully accessed a protected folder
                return true
            }
        }
        
        // Try listing contents of protected directory
        let protectedDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Safari")
        
        do {
            _ = try FileManager.default.contentsOfDirectory(atPath: protectedDir.path)
            return true
        } catch {
            // Cannot access - likely no Full Disk Access
            return false
        }
    }
    
    /// Check if a specific folder requires Full Disk Access
    nonisolated static func requiresFullDiskAccess(for url: URL) -> Bool {
        let path = url.path
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        
        // Desktop and Documents typically require Full Disk Access on macOS 10.15+
        let protectedFolders = [
            "\(homeDir)/Desktop",
            "\(homeDir)/Documents",
            "\(homeDir)/Downloads",
            "\(homeDir)/Library"
        ]
        
        return protectedFolders.contains { path.hasPrefix($0) }
    }
    
    /// Check if a folder requires Files & Folders permission (sandboxed apps)
    nonisolated static func requiresFilesFoldersPermission(for url: URL) -> Bool {
        let path = url.path
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        
        // These folders require Files & Folders permission in sandboxed apps
        let userFolders = [
            "\(homeDir)/Desktop",
            "\(homeDir)/Documents",
            "\(homeDir)/Downloads"
        ]
        
        return userFolders.contains { path.hasPrefix($0) }
    }
    
    /// Get the user-facing name for a protected folder
    nonisolated static func folderDisplayName(for url: URL) -> String {
        let path = url.path
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        
        if path.hasPrefix("\(homeDir)/Desktop") {
            return "Desktop"
        } else if path.hasPrefix("\(homeDir)/Documents") {
            return "Documents"
        } else if path.hasPrefix("\(homeDir)/Downloads") {
            return "Downloads"
        } else if path.hasPrefix("\(homeDir)/Library") {
            return "Library"
        } else {
            return url.lastPathComponent
        }
    }
    
    /// Trigger Full Disk Access prompt by attempting to access a protected folder
    @MainActor
    static func triggerFullDiskAccessPrompt() {
        // Use the dedicated trigger utility for comprehensive FDA setup
        FullDiskAccessTrigger.shared.triggerFullDiskAccessPrompt()
    }
    
    @MainActor
    static func showFullDiskAccessDeniedAlert(attemptedPath: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Full Disk Access Required"
        alert.informativeText = """
        ScreenGrabber cannot access the following location:
        
        \(attemptedPath)
        
        This folder requires Full Disk Access permission.
        
        Options:
        • Enable Full Disk Access in System Settings
        • Choose a different save location (e.g., Pictures folder)
        
        Would you like to open System Settings now?
        """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Choose Different Folder")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            openSystemSettings(for: .fullDiskAccess)
            
            // Show follow-up alert
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let followUp = NSAlert()
                followUp.alertStyle = .informational
                followUp.messageText = "Grant Full Disk Access"
                followUp.informativeText = """
                In System Settings:
                
                1. Click the lock icon and enter your password
                2. Scroll to find "ScreenGrabber" in the list
                3. Toggle the switch ON
                4. Quit and restart ScreenGrabber
                
                If ScreenGrabber is not in the list:
                • Try capturing a screenshot first, then check again
                • Manually drag ScreenGrabber.app into the list
                • Restart your Mac if the issue persists
                """
                followUp.addButton(withTitle: "OK")
                followUp.runModal()
            }
            
        case .alertSecondButtonReturn:
            // Show folder picker
            Task { @MainActor in
                shared.showFolderPicker()
            }
            
        default:
            break
        }
    }
    
    /// Show alert when Files & Folders permission is needed
    @MainActor
    static func showFilesFoldersAccessDeniedAlert(attemptedPath: String, folderName: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Folder Access Required"
        alert.icon = NSImage(systemSymbolName: "folder.badge.questionmark", accessibilityDescription: nil)
        
        alert.informativeText = """
        ScreenGrabber needs permission to access your \(folderName) folder.
        
        Attempted path:
        \(attemptedPath)
        
        📁 How to Enable Access:
        
        1. Click "Open System Settings" below
        2. Go to Privacy & Security → Files and Folders
        3. Find "ScreenGrabber" in the list
        4. Enable access to "\(folderName)"
        
        Alternative Options:
        • Choose a different save location that doesn't require permission
        • Use ~/Pictures/Screen Grabber (recommended, no permission needed)
        
        Note: If ScreenGrabber doesn't appear in the Files and Folders list, try:
        • Quit and restart ScreenGrabber
        • Try saving a screenshot to trigger the permission prompt
        • Ensure the app is properly signed and sandboxed
        """
        
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Use Pictures Folder")
        alert.addButton(withTitle: "Choose Different Folder")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            // Open Files & Folders settings
            openSystemSettings(for: .fileSystem)
            
            // Show follow-up guidance
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showFilesFoldersFollowUpGuidance(folderName: folderName)
            }
            
        case .alertSecondButtonReturn:
            // Use Pictures folder (safe default)
            let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures")
            let screenGrabberFolder = picturesURL.appendingPathComponent("Screen Grabber")
            SettingsModel.shared.setCustomSaveLocation(screenGrabberFolder)
            
            let confirm = NSAlert()
            confirm.alertStyle = .informational
            confirm.messageText = "Save Location Changed"
            confirm.informativeText = """
            Screenshots will now be saved to:
            \(screenGrabberFolder.path)
            
            This location does not require special permissions.
            """
            confirm.addButton(withTitle: "OK")
            confirm.runModal()
            
        case .alertThirdButtonReturn:
            // Show folder picker
            Task { @MainActor in
                shared.showFolderPicker()
            }
            
        default:
            break
        }
    }
    
    /// Show detailed follow-up guidance for Files & Folders permission
    @MainActor
    private static func showFilesFoldersFollowUpGuidance(folderName: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "In System Settings..."
        alert.icon = NSImage(systemSymbolName: "checklist", accessibilityDescription: nil)
        
        alert.informativeText = """
        You should now see the Privacy & Security settings.
        
        ✅ Step-by-Step Instructions:
        
        1. Click "Files and Folders" in the sidebar
           (Under "Privacy & Security")
        
        2. Look for "ScreenGrabber" in the list
           • It should show "\(folderName)" as an option
           • Toggle the switch to ON (blue)
        
        3. If ScreenGrabber is NOT in the list:
           → Close System Settings
           → Return to ScreenGrabber
           → Try saving a screenshot to \(folderName)
           → Check System Settings again
        
        4. Still having issues?
           → Click "Troubleshoot" below for advanced help
           → Or choose a different save location
        
        💡 Tip: You don't need to restart ScreenGrabber after granting permission. Changes take effect immediately.
        """
        
        alert.addButton(withTitle: "Got It")
        alert.addButton(withTitle: "Troubleshoot")
        alert.addButton(withTitle: "Choose Different Folder")
        
        let response = alert.runModal()
        
        switch response {
        case .alertSecondButtonReturn:
            showFilesFoldersTroubleshooting(folderName: folderName)
            
        case .alertThirdButtonReturn:
            Task { @MainActor in
                shared.showFolderPicker()
            }
            
        default:
            break
        }
    }
    
    /// Show troubleshooting steps for Files & Folders permission
    @MainActor
    private static func showFilesFoldersTroubleshooting(folderName: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Files & Folders Troubleshooting"
        
        alert.informativeText = """
        Common Issues and Solutions:
        
        ❓ ISSUE: ScreenGrabber doesn't appear in Files & Folders list
        
        Solution 1: Trigger the Permission Prompt
        • Quit ScreenGrabber completely (⌘Q)
        • Relaunch the app
        • Try saving a screenshot to \(folderName)
        • macOS should prompt for permission
        • Check System Settings again
        
        Solution 2: Check App Sandbox
        • Ensure ScreenGrabber.app is properly signed
        • Check that app has sandbox entitlements
        • Verify Info.plist has usage descriptions
        • Re-download or reinstall the app if needed
        
        Solution 3: Reset TCC Database (Advanced)
        • Open Terminal
        • Run: tccutil reset FilesAndFolders
        • Restart ScreenGrabber
        • Try accessing \(folderName) again
        
        ❓ ISSUE: Permission is enabled but access still denied
        
        Solution: Verify Permission Settings
        • Open System Settings → Files and Folders
        • Find ScreenGrabber in the list
        • Ensure "\(folderName)" toggle is ON (blue)
        • Try toggling OFF then ON again
        • Test saving a screenshot
        
        ❓ ISSUE: Don't want to grant permission
        
        Solution: Use Alternative Location
        • Pictures folder (no permission needed) ✓
        • Custom folder outside protected areas
        • External drive or network location
        • Click "Choose Folder" below
        
        ⚠️ Important Notes:
        • macOS 10.15+ requires explicit folder permissions
        • Desktop, Documents, Downloads need permission
        • Pictures folder does NOT require permission
        • Full Disk Access is different from Files & Folders
        
        Need more help? Check the app documentation or support resources.
        """
        
        alert.addButton(withTitle: "Choose Different Folder")
        alert.addButton(withTitle: "Open Terminal Instructions")
        alert.addButton(withTitle: "Close")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            Task { @MainActor in
                shared.showFolderPicker()
            }
            
        case .alertSecondButtonReturn:
            showTerminalResetInstructions()
            
        default:
            break
        }
    }
    
    /// Show Terminal instructions for resetting Files & Folders permissions
    @MainActor
    private static func showTerminalResetInstructions() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Reset Files & Folders Permissions (Advanced)"
        
        alert.informativeText = """
        ⚠️ WARNING: This will reset ALL Files & Folders permissions.
        
        Only do this if other solutions haven't worked.
        
        Steps:
        
        1. Open Terminal.app
           (Applications → Utilities → Terminal)
        
        2. Copy and paste this command:
        
           tccutil reset FilesAndFolders
        
        3. Press Return/Enter
        
        4. Quit ScreenGrabber completely
        
        5. Relaunch ScreenGrabber
        
        6. Try saving a screenshot again
        
        7. Grant permission when prompted
        
        Note: All apps will lose their Files & Folders permissions.
        You'll need to re-grant them as needed.
        """
        
        alert.addButton(withTitle: "Copy Command")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("tccutil reset FilesAndFolders", forType: .string)
            
            let confirm = NSAlert()
            confirm.messageText = "Command Copied!"
            confirm.informativeText = "The command has been copied to your clipboard.\n\nPaste it into Terminal and press Return."
            confirm.addButton(withTitle: "OK")
            confirm.runModal()
        }
    }
    
    @MainActor
    static func openSystemSettings(for type: ScreenGrabberTypes.PermissionType) {
        if let url = URL(string: type.systemSettingsURL) {
            NSWorkspace.shared.open(url)
        }
    }

    nonisolated private static func hasScreenRecordingPermission() -> Bool {
        // Best-effort check: CGPreflightScreenCaptureAccess or NSScreen.main?.cgDisplayID usage would be ideal.
        // Use private API guards by checking if the process is trusted for screen capture; as a placeholder, return true and rely on actual capture failures to re-signal.
        // Replace with proper CGPreflightScreenCaptureAccess() when linked.
        if let fn = dlsym(nil, "CGPreflightScreenCaptureAccess") {
            typealias Fn = @convention(c) () -> Bool
            let casted = unsafeBitCast(fn, to: Fn.self)
            return casted()
        }
        return true
    }

    nonisolated private static func requestMicrophoneIfNeeded() async -> Bool {
        // AVAudioSession isn't on macOS; use AVCaptureDevice.authorizationStatus for .audio
        return await withCheckedContinuation { cont in
            #if canImport(AVFoundation)
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            switch status {
            case .authorized:
                cont.resume(returning: true)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    cont.resume(returning: granted)
                }
            case .denied, .restricted:
                cont.resume(returning: false)
            @unknown default:
                cont.resume(returning: false)
            }
            #else
            cont.resume(returning: true)
            #endif
        }
    }
}
