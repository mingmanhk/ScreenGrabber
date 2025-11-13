//
//  ScreenCaptureManager.swift
//  ScreenGrabber
//
//  Created by Victor Lam on 10/23/25.
//

import Foundation
import AppKit
import SwiftData
import UserNotifications
import ScreenCaptureKit

class ScreenCaptureManager {
    static let shared = ScreenCaptureManager()
    
    // Permission status tracking
    private var hasScreenRecordingPermission = false
    private var hasFullDiskAccess = false
    private var permissionsChecked = false
    
    private init() {}
    
    // MARK: - Permission Management
    
    /// Checks all required permissions and requests them if needed
    func checkAndRequestPermissions(completion: @escaping (Bool) -> Void) {
        guard !permissionsChecked else {
            completion(hasScreenRecordingPermission && hasFullDiskAccess)
            return
        }
        
        print("[SEC] Checking all required permissions...")
        
        // Check permissions in order
        checkFullDiskAccess { [weak self] hasDiskAccess in
            self?.hasFullDiskAccess = hasDiskAccess
            
            self?.checkScreenRecordingPermission { hasScreenRecording in
                self?.hasScreenRecordingPermission = hasScreenRecording
                self?.permissionsChecked = true
                
                let allPermissionsGranted = hasDiskAccess && hasScreenRecording
                
                if !allPermissionsGranted {
                    self?.showPermissionRequestDialog()
                }
                
                completion(allPermissionsGranted)
            }
        }
    }
    
    /// Checks if the app has Full Disk Access permission
    private func checkFullDiskAccess(completion: @escaping (Bool) -> Void) {
        print("[SEC] Checking Full Disk Access permission...")
        
        // Test multiple locations that require Full Disk Access
        var testPaths: [URL] = [
            // Try to access a user's Library folder
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library")
        ]
        
        // Add optional URLs if they exist
        if let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
            testPaths.append(desktopURL)
        }
        
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            testPaths.append(documentsURL)
        }
        
        var hasAccess = false
        
        for url in testPaths {
            
            do {
                // Try to read the contents of the directory
                let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
                print("[OK] Successfully accessed: \(url.path) (\(contents.count) items)")
                
                // Also test if we can write to a safe location
                if url.lastPathComponent != "Library" { // Don't test write access to Library
                    let testFile = url.appendingPathComponent(".screengrabber_permission_test")
                    do {
                        try "test".write(to: testFile, atomically: true, encoding: .utf8)
                        try FileManager.default.removeItem(at: testFile)
                        print("[OK] Write access confirmed for: \(url.path)")
                        hasAccess = true
                        break
                    } catch {
                        print("[WARN]  Read access but no write access for: \(url.path)")
                        // Continue to next test - we need write access
                    }
                } else {
                    // For Library, read access is sufficient
                    hasAccess = true
                    break
                }
            } catch {
                print("[ERR] No access to: \(url.path) - \(error.localizedDescription)")
            }
        }
        
        if hasAccess {
            print("[OK] Full Disk Access appears to be granted")
        } else {
            print("[ERR] Full Disk Access appears to be denied")
        }
        
        completion(hasAccess)
    }
    
    /// Checks if the app has Screen Recording permission
    private func checkScreenRecordingPermission(completion: @escaping (Bool) -> Void) {
        print("[SEC] Checking Screen Recording permission...")
        
        if #available(macOS 12.3, *) {
            Task {
                do {
                    let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                    
                    let hasPermission = !availableContent.displays.isEmpty
                    
                    await MainActor.run {
                        if hasPermission {
                            print("[OK] Screen Recording permission granted")
                        } else {
                            print("[ERR] Screen Recording permission denied")
                        }
                        completion(hasPermission)
                    }
                } catch {
                    print("[ERR] Screen Recording permission error: \(error)")
                    await MainActor.run {
                        completion(false)
                    }
                }
            }
        } else {
            // Fallback for older macOS versions
            print("[WARN]  macOS version below 12.3 - using fallback permission check")
            
            // Try a quick screenshot test
            let testPath = "/tmp/screen_permission_test.png"
            let task = Process()
            task.launchPath = "/usr/sbin/screencapture"
            task.arguments = ["-x", "-t", "png", "-R", "0,0,1,1", testPath]
            
            task.terminationHandler = { process in
                DispatchQueue.main.async {
                    let hasPermission = process.terminationStatus == 0
                    
                    if hasPermission {
                        print("[OK] Screen Recording permission appears to be granted (fallback)")
                        // Clean up test file
                        try? FileManager.default.removeItem(atPath: testPath)
                    } else {
                        print("[ERR] Screen Recording permission denied (fallback)")
                    }
                    
                    completion(hasPermission)
                }
            }
            
            do {
                try task.run()
            } catch {
                print("[ERR] Could not run screen recording test: \(error)")
                completion(false)
            }
        }
    }
    
    /// Shows a dialog asking user to grant permissions
    private func showPermissionRequestDialog() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Permissions Required"
            alert.informativeText = """
            ScreenGrabber needs the following permissions to work properly:
            
            • Screen Recording: To capture screenshots
            • Full Disk Access: To save screenshots to your preferred folder (Pictures, Documents, etc.)
            
            Without Full Disk Access, screenshots will be saved to a temporary location.
            
            Please grant these permissions in System Settings/Preferences.
            """
            
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Continue Without Full Access")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .informational
            
            let response = alert.runModal()
            
            switch response {
            case .alertFirstButtonReturn:
                self.openSystemPreferences()
            case .alertSecondButtonReturn:
                print("[INFO]  User chose to continue without Full Disk Access")
                // Continue with limited functionality
            default:
                print("[INFO]  User cancelled permission request")
            }
        }
    }
    
    /// Opens System Preferences to the relevant permission settings
    private func openSystemPreferences() {
        // For macOS 13+ (Ventura), it's System Settings
        // For macOS 12 and below, it's System Preferences
        
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        
        if osVersion.majorVersion >= 13 {
            // macOS Ventura and later - System Settings
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        } else {
            // macOS Monterey and earlier - System Preferences
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
        
        // Show instructions
        showNotification(
            title: "Permission Setup",
            message: """
            1. Enable Screen Recording for ScreenGrabber
            2. Enable Full Disk Access for ScreenGrabber
            3. Restart ScreenGrabber after granting permissions
            """
        )
    }
    
    /// Public method to check if all permissions are granted
    func hasAllRequiredPermissions() -> Bool {
        return hasScreenRecordingPermission && hasFullDiskAccess && permissionsChecked
    }
    
    /// Forces a recheck of permissions (useful after user grants them)
    func recheckPermissions(completion: @escaping (Bool) -> Void) {
        permissionsChecked = false
        hasScreenRecordingPermission = false
        hasFullDiskAccess = false
        checkAndRequestPermissions(completion: completion)
    }
    
    // MARK: - ScreenGrabber Folder Management
    func createScreenGrabberFolder() -> URL {
        // Always prefer ~/Pictures/ScreenGrabber; fall back to temp only if needed
        let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first

        if let picturesURL = picturesURL {
            let screenGrabberURL = picturesURL.appendingPathComponent("ScreenGrabber")
            print("[FILE] Targeting Pictures location: \(screenGrabberURL.path)")

            // Create if needed
            if !FileManager.default.fileExists(atPath: screenGrabberURL.path) {
                do {
                    try FileManager.default.createDirectory(
                        at: screenGrabberURL,
                        withIntermediateDirectories: true,
                        attributes: [.posixPermissions: 0o755]
                    )
                    print("[OK] Created ScreenGrabber folder at: \(screenGrabberURL.path)")
                } catch {
                    print("[ERR] Failed to create ScreenGrabber folder in Pictures: \(error)")
                }
            }

            // Verify writability
            if FileManager.default.isWritableFile(atPath: screenGrabberURL.path) {
                return screenGrabberURL
            } else {
                print("[WARN] ScreenGrabber folder in Pictures is not writable: \(screenGrabberURL.path)")
            }
        } else {
            print("[ERR] Could not resolve Pictures directory URL")
        }

        // Fallback: use temporary directory if Pictures is unavailable or not writable
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("ScreenGrabber")
        print("[WARN] Using temporary directory as fallback: \(tempURL.path)")
        do {
            try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true, attributes: nil)
            print("[OK] Created ScreenGrabber folder in temp directory: \(tempURL.path)")
            return tempURL
        } catch {
            print("[ERR] Failed to create folder even in temp directory: \(error)")
            return FileManager.default.temporaryDirectory
        }
    }
    
    func getScreenGrabberFolderURL() -> URL {
        return createScreenGrabberFolder()
    }
    
    /// Attempts to fix common permission issues with the ScreenGrabber folder
    func fixFolderPermissions() -> Bool {
        let folderURL = getScreenGrabberFolderURL()
        
        print("[INFO] Attempting to fix folder permissions for: \(folderURL.path)")
        
        do {
            // Try to set proper permissions (rwxr-xr-x = 755)
            let attributes: [FileAttributeKey: Any] = [
                .posixPermissions: 0o755
            ]
            
            try FileManager.default.setAttributes(attributes, ofItemAtPath: folderURL.path)
            print("[OK] Successfully updated folder permissions to 755")
            
            // Verify the change
            let newAttributes = try FileManager.default.attributesOfItem(atPath: folderURL.path)
            let newPermissions = (newAttributes[.posixPermissions] as? NSNumber)?.intValue ?? 0
            print("[OK] Verified new permissions: \(String(format: "0o%o", newPermissions))")
            
            return FileManager.default.isWritableFile(atPath: folderURL.path)
            
        } catch {
            print("[ERR] Failed to fix folder permissions: \(error)")
            return false
        }
    }
    
    // MARK: - Debugging & Testing
    func testFileSystemAccess() {
        let folderURL = getScreenGrabberFolderURL()
        print("[TEST] Testing file system access:")
        print("   - Folder URL: \(folderURL.path)")
        print("   - Folder exists: \(FileManager.default.fileExists(atPath: folderURL.path))")
        print("   - Folder is writable: \(FileManager.default.isWritableFile(atPath: folderURL.path))")
        print("   - Folder is readable: \(FileManager.default.isReadableFile(atPath: folderURL.path))")
        
        // Check if it's actually a directory
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: folderURL.path, isDirectory: &isDirectory)
        print("   - Is directory: \(isDirectory.boolValue)")
        print("   - Exists and is directory: \(exists && isDirectory.boolValue)")
        
        // Check folder attributes
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: folderURL.path)
            let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0
            print("   - Folder permissions: \(String(format: "%o", permissions)) (\(String(format: "0o%o", permissions)))")
            print("   - Owner: \(attributes[.ownerAccountName] ?? "unknown")")
            print("   - Group: \(attributes[.groupOwnerAccountName] ?? "unknown")")
            
            // Check if we have proper read/write/execute permissions
            let ownerPerms = (permissions >> 6) & 0o7
            let groupPerms = (permissions >> 3) & 0o7
            let otherPerms = permissions & 0o7
            
            let ownerR = ((ownerPerms & 0o4) != 0) ? "Y" : "N"
            let ownerW = ((ownerPerms & 0o2) != 0) ? "Y" : "N"
            let ownerX = ((ownerPerms & 0o1) != 0) ? "Y" : "N"
            print("   - Owner permissions: \(String(format: "%o", ownerPerms)) (r:\(ownerR) w:\(ownerW) x:\(ownerX))")

            let groupR = ((groupPerms & 0o4) != 0) ? "Y" : "N"
            let groupW = ((groupPerms & 0o2) != 0) ? "Y" : "N"
            let groupX = ((groupPerms & 0o1) != 0) ? "Y" : "N"
            print("   - Group permissions: \(String(format: "%o", groupPerms)) (r:\(groupR) w:\(groupW) x:\(groupX))")

            let otherR = ((otherPerms & 0o4) != 0) ? "Y" : "N"
            let otherW = ((otherPerms & 0o2) != 0) ? "Y" : "N"
            let otherX = ((otherPerms & 0o1) != 0) ? "Y" : "N"
            print("   - Other permissions: \(String(format: "%o", otherPerms)) (r:\(otherR) w:\(otherW) x:\(otherX))")
            
        } catch {
            print("   [ERR] Failed to get folder attributes: \(error)")
        }
        
        // Test creating a small file with specific filename pattern like screenshots
        let testFilename = "TEST_Screenshot_\(DateFormatter.screenshotFormatter.string(from: Date())).txt"
        let testFilePath = folderURL.appendingPathComponent(testFilename)
        print("   - Testing file creation at: \(testFilePath.path)")
        
        do {
            let testContent = "Test content for screenshot folder access test"
            try testContent.write(to: testFilePath, atomically: true, encoding: .utf8)
            print("   [OK] Successfully wrote test file")
            
            // Verify file was actually written and has content
            if FileManager.default.fileExists(atPath: testFilePath.path) {
                do {
                    let readContent = try String(contentsOf: testFilePath, encoding: .utf8)
                    let attributes = try FileManager.default.attributesOfItem(atPath: testFilePath.path)
                    let fileSize = attributes[.size] as? Int64 ?? 0
                    print("   [OK] File verified: size=\(fileSize) bytes, content matches: \(readContent == testContent)")
                } catch {
                    print("   [WARN]  File exists but couldn't read: \(error)")
                }
            } else {
                print("   [ERR] File write appeared successful but file doesn't exist")
            }
            
            // Clean up
            try FileManager.default.removeItem(at: testFilePath)
            print("   [OK] Successfully removed test file")
        } catch {
            print("   [ERR] Failed to write test file: \(error)")
            print("   [ERR] Error details: \(error.localizedDescription)")
            
            // Additional debugging for common errors
            if let nsError = error as NSError? {
                print("   [ERR] Error domain: \(nsError.domain)")
                print("   [ERR] Error code: \(nsError.code)")
                print("   [ERR] Error user info: \(nsError.userInfo)")
                
                // Check for specific macOS permission errors
                if nsError.domain == NSCocoaErrorDomain {
                    switch nsError.code {
                    case CocoaError.fileWriteNoPermission.rawValue:
                        print("   [ERR] Specific issue: No write permission")
                    case CocoaError.fileWriteFileExists.rawValue:
                        print("   [ERR] Specific issue: File already exists")
                    case CocoaError.fileWriteVolumeReadOnly.rawValue:
                        print("   [ERR] Specific issue: Volume is read-only")
                    default:
                        break
                    }
                }
            }
        }
        
        // Test screencapture command directly
        print("[TEST] Testing screencapture command availability:")
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["-h"] // Help command to test if screencapture is available
        
        do {
            try task.run()
            task.waitUntilExit()
            print("   [OK] screencapture command is available (exit code: \(task.terminationStatus))")
        } catch {
            print("   [ERR] Failed to run screencapture command: \(error)")
        }
        
        // Test with a specific screenshot file pattern
        print("[TEST] Testing screenshot filename pattern:")
        let screenshotFilename = "Screenshot_\(DateFormatter.screenshotFormatter.string(from: Date())).png"
        let screenshotTestPath = folderURL.appendingPathComponent(screenshotFilename)
        print("   - Screenshot test path: \(screenshotTestPath.path)")
        print("   - Path length: \(screenshotTestPath.path.count) characters")
        print("   - Contains spaces: \(screenshotTestPath.path.contains(" "))")
        print("   - Contains special chars: \(screenshotTestPath.path.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted.subtracting(CharacterSet(charactersIn: "/_-."))) != nil)")
    }
    
    // MARK: - Screenshot Capture Methods
    func captureScreen(method: ScreenOption, openOption: OpenOption, modelContext: ModelContext? = nil) {
        // Check permissions first, but don't block if only Full Disk Access is missing
        checkAndRequestPermissions { [weak self] allGranted in
            if !allGranted {
                // Check specifically which permissions are missing
                if !(self?.hasScreenRecordingPermission ?? false) {
                    print("[ERR] Screen Recording permission denied, cannot proceed")
                    self?.showNotification(title: "Permission Required", message: "Screen Recording permission is required to capture screenshots")
                    return
                } else if !(self?.hasFullDiskAccess ?? false) {
                    print("[WARN]  Full Disk Access not granted, using fallback save location")
                    self?.showNotification(title: "Limited Access", message: "Screenshots will be saved to a temporary location. Grant Full Disk Access for better file management.")
                }
            }
            
            self?.performScreenCapture(method: method, openOption: openOption, modelContext: modelContext)
        }
    }
    
    private func performScreenCapture(method: ScreenOption, openOption: OpenOption, modelContext: ModelContext?) {
        // Special handling for scrolling capture
        if case .scrollingCapture = method {
            performScrollingCapture(openOption: openOption, modelContext: modelContext)
            return
        }
        
        let timestamp = Date()
        let filename = "Screenshot_\(DateFormatter.screenshotFormatter.string(from: timestamp)).png"
        let screenGrabberFolder = getScreenGrabberFolderURL()
        let filePath = screenGrabberFolder.appendingPathComponent(filename)
        
        print("[CHECK] Screen capture initiated:")
        print("   - Method: \(method.displayName)")
        print("   - Open option: \(openOption.displayName)")
        print("   - Save path: \(filePath.path)")
        print("   - Folder exists: \(FileManager.default.fileExists(atPath: screenGrabberFolder.path))")
        print("   - Folder writable: \(FileManager.default.isWritableFile(atPath: screenGrabberFolder.path))")
        
        // Pre-flight checks
        if !FileManager.default.fileExists(atPath: screenGrabberFolder.path) {
            print("[ERR] ScreenGrabber folder does not exist!")
            showNotification(title: "Error", message: "ScreenGrabber folder does not exist")
            return
        }
        
        if !FileManager.default.isWritableFile(atPath: screenGrabberFolder.path) {
            print("[ERR] ScreenGrabber folder is not writable!")
            print("[INFO] Attempting to fix permissions...")
            
            if fixFolderPermissions() {
                print("[OK] Fixed folder permissions, continuing with capture")
            } else {
                print("[ERR] Could not fix folder permissions")
                showNotification(title: "Permission Error", message: "Cannot write to ScreenGrabber folder. Check permissions.")
                return
            }
        }
        
        // Test file system access before attempting capture (only in debug mode)
        #if DEBUG
        testFileSystemAccess()
        #endif
        
        // Check if file already exists (shouldn't happen with timestamp, but just in case)
        if FileManager.default.fileExists(atPath: filePath.path) {
            print("[WARN]  File already exists at path: \(filePath.path)")
            // Add milliseconds to make it unique
            let milliseconds = Int(timestamp.timeIntervalSince1970 * 1000) % 1000
            let uniqueFilename = "Screenshot_\(DateFormatter.screenshotFormatter.string(from: timestamp))_\(milliseconds).png"
            let uniqueFilePath = screenGrabberFolder.appendingPathComponent(uniqueFilename)
            print("[INFO] Using unique filename: \(uniqueFilePath.path)")
        }
        
        // ALWAYS save to file first, then handle additional actions
        var arguments: [String] = []
        
        // Add screen capture method arguments
        switch method {
        case .selectedArea:
            arguments.append(contentsOf: ["-i", "-s"])
        case .window:
            arguments.append(contentsOf: ["-i", "-w"])
        case .fullScreen:
            arguments.append("-i")
        case .scrollingCapture:
            // This case is handled above, but keep for completeness
            arguments.append(contentsOf: ["-i", "-s"])
        }
        
        // Always save to file first
        arguments.append(filePath.path)
        
        print("[CAPTURE] About to execute screencapture with args: \(arguments)")
        
        // Execute the capture
        executeScreenCapture(arguments: arguments) { [weak self] success in
            if success {
                DispatchQueue.main.async {
                    // Verify the file was actually created
                    if FileManager.default.fileExists(atPath: filePath.path) {
                        // Additional verification - check file size
                        do {
                            let attributes = try FileManager.default.attributesOfItem(atPath: filePath.path)
                            let fileSize = attributes[.size] as? Int64 ?? 0
                            
                            if fileSize > 0 {
                                print("[OK] File confirmed to exist at: \(filePath.path) (Size: \(fileSize) bytes)")
                                
                                // Save record to database
                                self?.saveScreenshotRecord(filePath: filePath, timestamp: timestamp, method: method, openOption: openOption, modelContext: modelContext)
                                
                                // Handle additional actions based on open option
                                switch openOption {
                                case .clipboard:
                                    // Copy the saved file to clipboard
                                    self?.copyImageToClipboard(filePath: filePath)
                                    self?.showNotification(title: "Screen Grabber", message: "Screenshot copied to clipboard and saved to ScreenGrabber folder")
                                    
                                case .saveToFile:
                                    self?.showNotification(title: "Screen Grabber", message: "Screenshot saved to ScreenGrabber folder")
                                    
                                case .preview:
                                    NSWorkspace.shared.open(filePath)
                                    self?.showNotification(title: "Screen Grabber", message: "Screenshot saved and opened in Preview")
                                }
                            } else {
                                print("[ERR] File was created but is empty (0 bytes)")
                                self?.showNotification(title: "Screen Grabber", message: "Screenshot file was created but appears to be empty")
                            }
                        } catch {
                            print("[ERR] File exists but couldn't read attributes: \(error)")
                            self?.showNotification(title: "Screen Grabber", message: "Screenshot may have been created but couldn't verify")
                        }
                    } else {
                        print("[ERR] File was not created at expected path: \(filePath.path)")
                        self?.showNotification(title: "Screen Grabber", message: "Screenshot capture was cancelled or failed to save")
                    }
                }
            } else {
                DispatchQueue.main.async {
                    print("[ERR] Screenshot capture process failed")
                    self?.showNotification(title: "Screen Grabber", message: "Failed to capture screenshot - check permissions")
                }
            }
        }
    }
    
    // MARK: - Scrolling Capture
    
    /// Performs a scrolling capture that allows user to scroll and capture a larger area
    private func performScrollingCapture(openOption: OpenOption, modelContext: ModelContext?) {
        print("[SCROLL] Starting enhanced scrolling capture mode...")
        
        // Show improved instructions to the user
        DispatchQueue.main.async { [weak self] in
            let alert = NSAlert()
            alert.messageText = "📜 Scrolling Capture"
            alert.informativeText = """
            Easy Scrolling Capture Workflow:
            
            ✓ Step 1: Select the scrollable area
            ✓ Step 2: Take screenshots as you scroll
            ✓ Step 3: Merge them automatically
            
            How it works:
            • Select the same area each time
            • Scroll between captures
            • We'll stitch everything together
            
            💡 Tip: Works great for long web pages, documents, and conversations!
            """
            alert.alertStyle = .informational
            
            // Add icon (using system symbol name for macOS 11+)
            if #available(macOS 11.0, *) {
                if let icon = NSImage(systemSymbolName: "scroll.fill", accessibilityDescription: "Scrolling Capture") {
                    alert.icon = icon
                }
            }
            
            alert.addButton(withTitle: "Let's Go! 🚀")
            alert.addButton(withTitle: "Maybe Later")
            
            let response = alert.runModal()
            
            if response == .alertFirstButtonReturn {
                self?.initiateScrollingCaptureSequence(openOption: openOption, modelContext: modelContext)
            } else {
                print("[SCROLL] User cancelled scrolling capture")
            }
        }
    }
    
    /// Initiates the scrolling capture sequence
    private func initiateScrollingCaptureSequence(openOption: OpenOption, modelContext: ModelContext?) {
        let timestamp = Date()
        let sessionID = UUID().uuidString.prefix(8)
        let screenGrabberFolder = getScreenGrabberFolderURL()
        
        // Create a temporary folder for this capture session
        let sessionFolder = screenGrabberFolder.appendingPathComponent("ScrollCapture_\(sessionID)")
        
        do {
            try FileManager.default.createDirectory(at: sessionFolder, withIntermediateDirectories: true, attributes: nil)
            print("[SCROLL] Created session folder: \(sessionFolder.path)")
        } catch {
            print("[ERR] Failed to create session folder: \(error)")
            showNotification(title: "Error", message: "Could not create temporary folder for scrolling capture")
            return
        }
        
        // Capture first frame with user selection
        let firstFramePath = sessionFolder.appendingPathComponent("frame_001.png")
        let arguments = ["-i", "-s", firstFramePath.path]
        
        print("[SCROLL] Capturing first frame...")
        showNotification(title: "Scrolling Capture", message: "Select the area to capture, then scroll and press Space for each frame")
        
        executeScreenCapture(arguments: arguments) { [weak self] success in
            guard success, let self = self else {
                print("[ERR] First frame capture failed")
                try? FileManager.default.removeItem(at: sessionFolder)
                return
            }
            
            // Check if user actually captured (didn't press Esc)
            if !FileManager.default.fileExists(atPath: firstFramePath.path) {
                print("[SCROLL] User cancelled during first frame")
                try? FileManager.default.removeItem(at: sessionFolder)
                self.showNotification(title: "Cancelled", message: "Scrolling capture was cancelled")
                return
            }
            
            print("[OK] First frame captured successfully")
            
            // For now, since implementing a full interactive scrolling capture system
            // requires event monitoring and complex UI, we'll provide a simpler workflow:
            // The user manually captures multiple frames, and we'll guide them
            
            DispatchQueue.main.async {
                self.showScrollingCaptureInstructions(
                    sessionFolder: sessionFolder,
                    frameCount: 1,
                    openOption: openOption,
                    modelContext: modelContext,
                    timestamp: timestamp
                )
            }
        }
    }
    
    /// Shows instructions for continuing the scrolling capture
    private func showScrollingCaptureInstructions(sessionFolder: URL, frameCount: Int, openOption: OpenOption, modelContext: ModelContext?, timestamp: Date) {
        let alert = NSAlert()
        alert.messageText = "📸 Frame \(frameCount) Captured!"
        alert.informativeText = """
        Great! You've captured \(frameCount) frame\(frameCount == 1 ? "" : "s").
        
        What's next?
        
        📸 More Content? - Scroll and capture another frame
        ✅ All Done? - Merge all frames into one image
        ❌ Changed Mind? - Cancel and discard
        
        💡 Pro tip: Try to keep consistent overlap between frames for smoother results!
        """
        alert.alertStyle = .informational
        
        // Add custom icon
        if #available(macOS 11.0, *) {
            if let icon = NSImage(systemSymbolName: "camera.metering.multispot", accessibilityDescription: "Multiple frames captured") {
                icon.size = NSSize(width: 64, height: 64)
                alert.icon = icon
            }
        }
        
        alert.addButton(withTitle: "📸 Capture More")
        alert.addButton(withTitle: "✅ Finish & Merge")
        alert.addButton(withTitle: "❌ Cancel")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn: // Capture More
            captureNextScrollFrame(sessionFolder: sessionFolder, frameCount: frameCount, openOption: openOption, modelContext: modelContext, timestamp: timestamp)
            
        case .alertSecondButtonReturn: // Finish & Merge
            mergeScrollingFrames(sessionFolder: sessionFolder, frameCount: frameCount, openOption: openOption, modelContext: modelContext, timestamp: timestamp)
            
        default: // Cancel
            print("[SCROLL] User cancelled scrolling capture")
            try? FileManager.default.removeItem(at: sessionFolder)
            showNotification(title: "Cancelled", message: "Frames discarded")
        }
    }
    
    /// Captures the next frame in the scrolling sequence
    private func captureNextScrollFrame(sessionFolder: URL, frameCount: Int, openOption: OpenOption, modelContext: ModelContext?, timestamp: Date) {
        let nextFrameNumber = frameCount + 1
        let framePath = sessionFolder.appendingPathComponent(String(format: "frame_%03d.png", nextFrameNumber))
        
        // Use the same region by having user select again (screencapture doesn't remember regions)
        let arguments = ["-i", "-s", framePath.path]
        
        print("[SCROLL] Capturing frame \(nextFrameNumber)...")
        
        executeScreenCapture(arguments: arguments) { [weak self] success in
            guard success, let self = self else {
                print("[ERR] Frame \(nextFrameNumber) capture failed")
                return
            }
            
            // Check if user actually captured
            if !FileManager.default.fileExists(atPath: framePath.path) {
                print("[SCROLL] User cancelled during frame \(nextFrameNumber)")
                self.showNotification(title: "Cancelled", message: "Frame capture was cancelled")
                // Go back to instructions with current frame count
                DispatchQueue.main.async {
                    self.showScrollingCaptureInstructions(
                        sessionFolder: sessionFolder,
                        frameCount: frameCount,
                        openOption: openOption,
                        modelContext: modelContext,
                        timestamp: timestamp
                    )
                }
                return
            }
            
            print("[OK] Frame \(nextFrameNumber) captured successfully")
            
            // Show instructions again for next frame
            DispatchQueue.main.async {
                self.showScrollingCaptureInstructions(
                    sessionFolder: sessionFolder,
                    frameCount: nextFrameNumber,
                    openOption: openOption,
                    modelContext: modelContext,
                    timestamp: timestamp
                )
            }
        }
    }
    
    /// Merges all captured frames into a single scrolling screenshot
    private func mergeScrollingFrames(sessionFolder: URL, frameCount: Int, openOption: OpenOption, modelContext: ModelContext?, timestamp: Date) {
        print("[SCROLL] Merging \(frameCount) frames...")
        
        // Load all frame images
        var frames: [NSImage] = []
        for i in 1...frameCount {
            let framePath = sessionFolder.appendingPathComponent(String(format: "frame_%03d.png", i))
            if let image = NSImage(contentsOf: framePath) {
                frames.append(image)
            } else {
                print("[WARN] Could not load frame \(i)")
            }
        }
        
        guard !frames.isEmpty else {
            print("[ERR] No frames to merge")
            showNotification(title: "Error", message: "No frames available to merge")
            try? FileManager.default.removeItem(at: sessionFolder)
            return
        }
        
        // For a basic implementation, stack images vertically
        // Note: A more sophisticated approach would detect overlap and stitch intelligently
        guard let mergedImage = stackImagesVertically(frames) else {
            print("[ERR] Failed to merge frames")
            showNotification(title: "Error", message: "Could not merge frames into final image")
            try? FileManager.default.removeItem(at: sessionFolder)
            return
        }
        
        // Save the merged image
        let finalFilename = "ScrollCapture_\(DateFormatter.screenshotFormatter.string(from: timestamp)).png"
        let screenGrabberFolder = getScreenGrabberFolderURL()
        let finalPath = screenGrabberFolder.appendingPathComponent(finalFilename)
        
        if savePNGImage(mergedImage, to: finalPath) {
            print("[OK] Scrolling capture saved to: \(finalPath.path)")
            
            // Clean up session folder
            try? FileManager.default.removeItem(at: sessionFolder)
            
            // Save record and handle open option
            saveScreenshotRecord(filePath: finalPath, timestamp: timestamp, method: .scrollingCapture, openOption: openOption, modelContext: modelContext)
            
            // Handle post-capture actions
            DispatchQueue.main.async {
                switch openOption {
                case .clipboard:
                    self.copyImageToClipboard(filePath: finalPath)
                    self.showNotification(title: "Scrolling Capture Complete", message: "\(frameCount) frames merged and copied to clipboard")
                    
                case .saveToFile:
                    self.showNotification(title: "Scrolling Capture Complete", message: "\(frameCount) frames merged and saved")
                    
                case .preview:
                    NSWorkspace.shared.open(finalPath)
                    self.showNotification(title: "Scrolling Capture Complete", message: "\(frameCount) frames merged")
                }
            }
        } else {
            print("[ERR] Failed to save merged image")
            showNotification(title: "Error", message: "Could not save merged scrolling capture")
            try? FileManager.default.removeItem(at: sessionFolder)
        }
    }
    
    /// Stacks multiple images vertically into one tall image
    private func stackImagesVertically(_ images: [NSImage]) -> NSImage? {
        guard !images.isEmpty else { return nil }
        
        // Calculate total height and max width
        let width = images.map { $0.size.width }.max() ?? 0
        let totalHeight = images.reduce(0) { $0 + $1.size.height }
        
        let finalSize = NSSize(width: width, height: totalHeight)
        
        // Create a new image to draw into
        let finalImage = NSImage(size: finalSize)
        
        finalImage.lockFocus()
        
        var yOffset: CGFloat = 0
        for image in images {
            let rect = NSRect(x: 0, y: yOffset, width: image.size.width, height: image.size.height)
            image.draw(in: rect)
            yOffset += image.size.height
        }
        
        finalImage.unlockFocus()
        
        return finalImage
    }
    
    /// Saves an NSImage as PNG to the specified path
    private func savePNGImage(_ image: NSImage, to url: URL) -> Bool {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            return false
        }
        
        do {
            try pngData.write(to: url)
            return true
        } catch {
            print("[ERR] Failed to write PNG: \(error)")
            return false
        }
    }
    
    func executeScreenCapture(arguments: [String], completion: @escaping (Bool) -> Void) {
        print("[CAPTURE] Executing screencapture with arguments: \(arguments)")
        
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = arguments
        
        // Capture both stdout and stderr for debugging
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        task.terminationHandler = { process in
            let success = process.terminationStatus == 0
            
            // Read output for debugging
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            if let outputString = String(data: outputData, encoding: .utf8), !outputString.isEmpty {
                print("[CAPTURE] screencapture output: \(outputString)")
            }
            
            if !success {
                if let errorString = String(data: errorData, encoding: .utf8), !errorString.isEmpty {
                    print("[ERR] screencapture error: \(errorString)")
                }
                print("[ERR] screencapture failed with status: \(process.terminationStatus)")
                
                // Status 1 usually means user cancelled (pressed ESC)
                if process.terminationStatus == 1 {
                    print("[INFO] User likely cancelled screenshot (pressed ESC)")
                }
            } else {
                print("[OK] screencapture completed successfully")
                
                // Verify file was created if we're saving to file
                if let filePath = arguments.last, !filePath.starts(with: "-") {
                    let fileURL = URL(fileURLWithPath: filePath)
                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        do {
                            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                            let fileSize = attributes[.size] as? Int64 ?? 0
                            print("[FILE] File created: \(fileURL.path) (Size: \(fileSize) bytes)")
                            
                            // Check if file size is reasonable (not empty)
                            if fileSize == 0 {
                                print("[WARN]  Warning: Screenshot file is empty (0 bytes)")
                            }
                        } catch {
                            print("[FILE] File created but couldn't read attributes: \(fileURL.path)")
                        }
                    } else {
                        print("[WARN]  File was not created at expected path: \(fileURL.path)")
                    }
                }
            }
            
            completion(success)
        }
        
        do {
            try task.run()
            print("[CAPTURE] screencapture task started successfully")
        } catch {
            print("[ERR] Failed to start screencapture task: \(error)")
            completion(false)
        }
    }
    
    private func copyImageToClipboard(filePath: URL) {
        // Add a small delay to ensure file is written
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let image = NSImage(contentsOf: filePath) else {
                print("Failed to load image from file: \(filePath.path)")
                return
            }
            
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            
            // Write both the image and the file path to pasteboard
            let success = pasteboard.writeObjects([image])
            
            if success {
                print("Successfully copied image to clipboard from: \(filePath.path)")
            } else {
                print("Failed to copy image to clipboard")
            }
        }
    }
    
    // MARK: - Recent Screenshots
    func loadRecentScreenshots() -> [URL] {
        let folderURL = getScreenGrabberFolderURL()
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            // Filter for image files and sort by creation date (newest first)
            let imageFiles = fileURLs.filter { url in
                let pathExtension = url.pathExtension.lowercased()
                return ["png", "jpg", "jpeg", "gif", "bmp", "tiff"].contains(pathExtension)
            }
            
            let sortedFiles = imageFiles.sorted { url1, url2 in
                do {
                    let date1 = try url1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                    let date2 = try url2.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                    return date1 > date2
                } catch {
                    return false
                }
            }
            
            return Array(sortedFiles.prefix(10)) // Return up to 10 recent files
        } catch {
            print("[ERR] Failed to load recent screenshots: \(error)")
            return []
        }
    }
    
    // MARK: - Notifications
    func showNotification(title: String, message: String) {
        let center = UNUserNotificationCenter.current()
        
        // Request permission if not already granted
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = message
                content.sound = .default
                
                // Create a trigger to show immediately
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
                
                // Create the request
                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: trigger
                )
                
                // Add the request
                center.add(request) { error in
                    if let error = error {
                        print("Notification error: \(error.localizedDescription)")
                    }
                }
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    func showWelcomeNotification() {
        // Check permissions before showing welcome
        checkAndRequestPermissions { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.showNotification(
                        title: "Screen Grabber Ready!",
                        message: "App running in dock & menu bar. Press ⌘⇧C to capture!"
                    )
                } else {
                    self?.showNotification(
                        title: "Permissions Required",
                        message: "Please grant Screen Recording and Full Disk Access permissions to use ScreenGrabber"
                    )
                }
            }
        }
    }
    
    // MARK: - Manual Testing & Debugging
    func testFullScreenshotProcess() {
        print("[TEST] Starting full screenshot process test...")
        
        // Check permissions first
        checkAndRequestPermissions { [weak self] granted in
            guard granted else {
                print("[ERR] TEST FAILED: Required permissions not granted")
                self?.showNotification(title: "Test Failed", message: "Permissions required for testing")
                return
            }
            
            // Test 1: File system access
            self?.testFileSystemAccess()
            
            // Test 2: Try a simple full screen capture to test the entire flow
            let timestamp = Date()
            let filename = "TEST_Screenshot_\(DateFormatter.screenshotFormatter.string(from: timestamp)).png"
            guard let screenGrabberFolder = self?.getScreenGrabberFolderURL() else {
                print("[ERR] TEST FAILED: Could not get ScreenGrabber folder")
                return
            }
            let filePath = screenGrabberFolder.appendingPathComponent(filename)
            
            print("[TEST] Testing full screen capture to: \(filePath.path)")
            
            // Simple full screen capture without user interaction
            let arguments = ["-i", filePath.path]
            
            self?.executeScreenCapture(arguments: arguments) { success in
                DispatchQueue.main.async {
                    if success {
                        if FileManager.default.fileExists(atPath: filePath.path) {
                            print("[OK] TEST PASSED: Screenshot file created successfully")
                            self?.showNotification(title: "Test Successful", message: "Screenshot saved to \(filename)")
                            
                            // Clean up test file after 5 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                                try? FileManager.default.removeItem(at: filePath)
                                print("[CLEAN] Cleaned up test file")
                            }
                        } else {
                            print("[ERR] TEST FAILED: Screenshot file was not created")
                            self?.showNotification(title: "Test Failed", message: "File was not created")
                        }
                    } else {
                        print("[ERR] TEST FAILED: Screenshot process returned failure")
                        self?.showNotification(title: "Test Failed", message: "Screenshot process failed")
                    }
                }
            }
        }
    }
    
    /// Comprehensive debugging method to check all aspects of the screenshot system
    func diagnoseScreenshotIssues() {
        print("[CHECK] === SCREENSHOT SYSTEM DIAGNOSIS ===")
        
        // 1. Check macOS version and compatibility
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        print("[MACOS] macOS Version: \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)")
        
        // 2. Check app permissions and entitlements
        print("[SEC] Checking app permissions:")
        
        checkAndRequestPermissions { [weak self] allGranted in
            print("   - All permissions granted: \(allGranted)")
            print("   - Screen Recording: \(self?.hasScreenRecordingPermission ?? false)")
            print("   - Full Disk Access: \(self?.hasFullDiskAccess ?? false)")
            
            // 3. Test folder access
            print("[FILE] Testing folder access:")
            let folderURL = self?.getScreenGrabberFolderURL()
            self?.testFileSystemAccess()
            
            // 4. Test screencapture command
            print("[CAPTURE] Testing screencapture command:")
            let testTask = Process()
            testTask.launchPath = "/usr/sbin/screencapture"
            testTask.arguments = ["-h"]
            
            let pipe = Pipe()
            testTask.standardOutput = pipe
            testTask.standardError = pipe
            
            do {
                try testTask.run()
                testTask.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? "No output"
                
                print("   - screencapture exit code: \(testTask.terminationStatus)")
                print("   - screencapture help output length: \(output.count) characters")
                
                if testTask.terminationStatus == 0 {
                    print("   [OK] screencapture command is available")
                } else {
                    print("   [ERR] screencapture command failed")
                }
            } catch {
                print("   [ERR] Could not run screencapture command: \(error)")
            }
            
            // 5. Test actual screenshot creation if permissions are granted
            if allGranted, let folderURL = folderURL {
                print("[SHOT] Testing actual screenshot creation:")
                let testPath = folderURL.appendingPathComponent("DIAGNOSIS_test.png")
                let quickScreenshotArgs = ["-x", "-t", "png", "-R", "0,0,100,100", testPath.path]
                
                let screenshotTask = Process()
                screenshotTask.launchPath = "/usr/sbin/screencapture"
                screenshotTask.arguments = quickScreenshotArgs
                
                screenshotTask.terminationHandler = { process in
                    DispatchQueue.main.async {
                        if process.terminationStatus == 0 {
                            if FileManager.default.fileExists(atPath: testPath.path) {
                                do {
                                    let attributes = try FileManager.default.attributesOfItem(atPath: testPath.path)
                                    let fileSize = attributes[.size] as? Int64 ?? 0
                                    print("   [OK] Test screenshot created successfully (Size: \(fileSize) bytes)")
                                    
                                    // Clean up
                                    try? FileManager.default.removeItem(at: testPath)
                                    
                                    self?.showNotification(title: "Diagnosis Complete", message: "Screenshot system is working properly!")
                                } catch {
                                    print("   [WARN]  Test screenshot created but couldn't read attributes")
                                }
                            } else {
                                print("   [ERR] Test screenshot command succeeded but file not found")
                                self?.showNotification(title: "Diagnosis Issue", message: "Screenshot command runs but files not saved properly")
                            }
                        } else {
                            print("   [ERR] Test screenshot failed with status: \(process.terminationStatus)")
                            self?.showNotification(title: "Diagnosis Failed", message: "Screenshot creation is not working")
                        }
                        
                        print("[CHECK] === DIAGNOSIS COMPLETE ===")
                    }
                }
                
                do {
                    try screenshotTask.run()
                } catch {
                    print("   [ERR] Could not start test screenshot: \(error)")
                    print("[CHECK] === DIAGNOSIS COMPLETE ===")
                }
            } else {
                print("   [WARN]  Skipping screenshot test due to missing permissions")
                print("[CHECK] === DIAGNOSIS COMPLETE ===")
                
                DispatchQueue.main.async {
                    self?.showNotification(title: "Diagnosis Complete", message: "Please grant required permissions and try again")
                }
            }
        }
    }
    
    private func showPermissionDeniedMessage() {
        print("   Go to System Preferences > Security & Privacy > Privacy > Screen Recording")
        print("   and make sure ScreenGrabber is enabled")
        
        // Show notification to guide user
        showNotification(
            title: "Permission Required",
            message: "Please enable Screen Recording permission in System Preferences > Security & Privacy > Privacy > Screen Recording"
        )
    }
    
    /// Saves a screenshot record to the database or handles metadata logging.
    private func saveScreenshotRecord(filePath: URL, timestamp: Date, method: ScreenOption, openOption: OpenOption, modelContext: ModelContext?) {
        // TODO: Implement database persistence if desired, using modelContext and your data model.
        print("[DB] saveScreenshotRecord called with:\n  Path: \(filePath.path)\n  Timestamp: \(timestamp)\n  Method: \(method.displayName)\n  OpenOption: \(openOption.displayName)")
        // This is a placeholder to resolve the build error.
    }
}

// MARK: - DateFormatter Extension
extension DateFormatter {
    static let screenshotFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
}
