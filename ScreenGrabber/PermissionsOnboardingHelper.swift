//
//  PermissionsOnboardingHelper.swift
//  ScreenGrabber
//
//  Comprehensive permissions onboarding and guidance
//  Helps users understand and grant required permissions
//

import Foundation
import AppKit
import SwiftUI

/// Helper for onboarding users through macOS permissions
@MainActor
final class PermissionsOnboardingHelper {
    
    static let shared = PermissionsOnboardingHelper()
    
    private init() {}
    
    // MARK: - Permission Checks
    
    /// Check screen recording permission using CGPreflightScreenCaptureAccess
    private func checkScreenRecordingPermission() -> Bool {
        // Use the same approach as CapturePermissionsManager
        if let fn = dlsym(nil, "CGPreflightScreenCaptureAccess") {
            typealias Fn = @convention(c) () -> Bool
            let check = unsafeBitCast(fn, to: Fn.self)
            return check()
        }
        // Fallback: assume granted (actual capture will fail if not)
        return true
    }
    
    // MARK: - Permission Status
    
    /// Check all required permissions and return status
    func checkAllPermissions() -> PermissionStatus {
        var status = PermissionStatus()
        
        // Screen Recording - check via CGPreflightScreenCaptureAccess or assume granted
        // Since we can't access the private method, we'll attempt a different approach
        status.screenRecording = checkScreenRecordingPermission()
        
        // Full Disk Access
        status.fullDiskAccess = CapturePermissionsManager.hasFullDiskAccess()
        
        // Files & Folders (check common locations)
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        status.desktopAccess = CapturePermissionsManager.hasFolderAccess(
            for: homeDir.appendingPathComponent("Desktop")
        )
        status.documentsAccess = CapturePermissionsManager.hasFolderAccess(
            for: homeDir.appendingPathComponent("Documents")
        )
        status.downloadsAccess = CapturePermissionsManager.hasFolderAccess(
            for: homeDir.appendingPathComponent("Downloads")
        )
        
        // Pictures folder (usually doesn't require permission)
        status.picturesAccess = CapturePermissionsManager.hasFolderAccess(
            for: homeDir.appendingPathComponent("Pictures")
        )
        
        return status
    }
    
    /// Show comprehensive permissions onboarding
    func showPermissionsOnboarding() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Welcome to ScreenGrabber!"
        alert.icon = NSImage(systemSymbolName: "rectangle.on.rectangle.badge.gearshape", accessibilityDescription: nil)
        
        alert.informativeText = """
        ScreenGrabber needs a few permissions to work properly.
        
        📸 Required Permissions:
        
        • Screen Recording
          → Allows ScreenGrabber to capture your screen
          → Required for all screenshots and recordings
        
        📁 Optional Permissions (recommended):
        
        • Files & Folders Access
          → Allows saving to Desktop, Documents, Downloads
          → Not required if you save to Pictures folder
        
        💡 Tip: ScreenGrabber works great with just the Pictures folder!
        
        The default save location is:
        ~/Pictures/Screen Grabber/
        
        This location does NOT require any special permissions.
        
        Would you like to:
        • Continue with Pictures folder (recommended)
        • Set up Desktop/Documents access
        • Review all permissions
        """
        
        alert.addButton(withTitle: "Use Pictures Folder (Easy)")
        alert.addButton(withTitle: "Set Up Folder Access")
        alert.addButton(withTitle: "Review Permissions")
        alert.addButton(withTitle: "Skip for Now")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            // Use default Pictures location
            usePicturesFolder()
            
        case .alertSecondButtonReturn:
            // Show folder selection and permissions guide
            showFolderAccessSetup()
            
        case .alertThirdButtonReturn:
            // Show detailed permissions review
            showDetailedPermissionsReview()
            
        default:
            break
        }
    }
    
    // MARK: - Folder Setup
    
    private func usePicturesFolder() {
        let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures")
        let screenGrabberFolder = picturesURL.appendingPathComponent("Screen Grabber")
        
        // Clear any custom location
        SettingsModel.shared.customSaveLocationPath = nil
        
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "All Set! ✅"
        alert.informativeText = """
        ScreenGrabber will save screenshots to:
        \(screenGrabberFolder.path)
        
        This location:
        • Does NOT require special permissions
        • Works immediately
        • Is organized and easy to find
        
        You can change this later in Settings.
        
        Ready to take your first screenshot?
        """
        alert.addButton(withTitle: "Start Using ScreenGrabber")
        alert.addButton(withTitle: "Open Settings")
        alert.runModal()
    }
    
    private func showFolderAccessSetup() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Set Up Folder Access"
        
        alert.informativeText = """
        Where would you like to save screenshots?
        
        📁 Desktop
        • Quick access from your desktop
        • Requires Files & Folders permission
        • Clutters desktop if you take many screenshots
        
        📄 Documents
        • Organized with other documents
        • Requires Files & Folders permission
        • Good for archiving
        
        💾 Downloads
        • Familiar location
        • Requires Files & Folders permission
        • May get cleaned up automatically
        
        🖼️ Pictures (Recommended)
        • Perfect for screenshots
        • NO permissions required
        • Default for most apps
        
        Choose where to save:
        """
        
        alert.addButton(withTitle: "Desktop")
        alert.addButton(withTitle: "Documents")
        alert.addButton(withTitle: "Downloads")
        alert.addButton(withTitle: "Pictures (Recommended)")
        alert.addButton(withTitle: "Custom Location...")
        
        let response = alert.runModal()
        
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        var selectedURL: URL?
        var requiresPermission = false
        
        // NSAlert supports .alertFirstButtonReturn, .alertSecondButtonReturn, .alertThirdButtonReturn
        // For 4+ buttons, we need to check the raw value: 1000, 1001, 1002, 1003, 1004...
        switch response.rawValue {
        case NSApplication.ModalResponse.alertFirstButtonReturn.rawValue: // 1000 - Desktop
            selectedURL = homeDir.appendingPathComponent("Desktop/Screen Grabber")
            requiresPermission = true
            
        case NSApplication.ModalResponse.alertSecondButtonReturn.rawValue: // 1001 - Documents
            selectedURL = homeDir.appendingPathComponent("Documents/Screen Grabber")
            requiresPermission = true
            
        case NSApplication.ModalResponse.alertThirdButtonReturn.rawValue: // 1002 - Downloads
            selectedURL = homeDir.appendingPathComponent("Downloads/Screen Grabber")
            requiresPermission = true
            
        case 1003: // Pictures (4th button)
            selectedURL = homeDir.appendingPathComponent("Pictures/Screen Grabber")
            requiresPermission = false
            
        default: // 1004+ - Custom location
            // Custom location - show picker
            showCustomFolderPicker()
            return
        }
        
        if let url = selectedURL {
            setupFolder(at: url, requiresPermission: requiresPermission)
        }
    }
    
    private func setupFolder(at url: URL, requiresPermission: Bool) {
        if requiresPermission {
            // Show permissions guide
            let folderName = CapturePermissionsManager.folderDisplayName(for: url)
            showPermissionsGuide(for: url, folderName: folderName)
        } else {
            // Just set the location
            SettingsModel.shared.setCustomSaveLocation(url)
            
            Task {
                let result = await CapturePermissionsManager.shared.ensureCaptureFolderExists(at: url)
                
                await MainActor.run {
                    if case .success = result {
                        let alert = NSAlert()
                        alert.alertStyle = .informational
                        alert.messageText = "Folder Set Up! ✅"
                        alert.informativeText = """
                        Screenshots will be saved to:
                        \(url.path)
                        
                        You're ready to start capturing!
                        """
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                }
            }
        }
    }
    
    private func showPermissionsGuide(for url: URL, folderName: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Permission Required: \(folderName)"
        alert.icon = NSImage(systemSymbolName: "folder.badge.questionmark", accessibilityDescription: nil)
        
        alert.informativeText = """
        To save screenshots to your \(folderName) folder, you'll need to grant Files & Folders permission.
        
        🔐 Why is this needed?
        
        macOS protects your \(folderName) folder from unauthorized access. When you grant permission, ScreenGrabber will appear in:
        
        System Settings → Privacy & Security → Files and Folders
        
        📋 What happens next:
        
        1. We'll try to access the \(folderName) folder
        2. macOS may prompt for permission
        3. Grant permission when asked
        4. ScreenGrabber will appear in System Settings
        
        🔧 If the prompt doesn't appear:
        
        • We'll show you how to enable it manually
        • You can always choose a different location
        • Pictures folder doesn't require permission
        
        Ready to proceed?
        """
        
        alert.addButton(withTitle: "Grant Permission")
        alert.addButton(withTitle: "Use Pictures Instead")
        alert.addButton(withTitle: "Choose Different Folder")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            // Try to access the folder and trigger permission
            attemptFolderAccess(url: url, folderName: folderName)
            
        case .alertSecondButtonReturn:
            usePicturesFolder()
            
        case .alertThirdButtonReturn:
            showCustomFolderPicker()
            
        default:
            break
        }
    }
    
    private func attemptFolderAccess(url: URL, folderName: String) {
        // Set the custom location
        SettingsModel.shared.setCustomSaveLocation(url)
        
        // Trigger permission prompt
        CapturePermissionsManager.triggerFilesFoldersPermissionPrompt(for: url)
        
        // Check if we have access
        Task {
            let result = await CapturePermissionsManager.shared.ensureCaptureFolderExists(at: url)
            
            await MainActor.run {
                switch result {
                case .success:
                    let alert = NSAlert()
                    alert.alertStyle = .informational
                    alert.messageText = "Success! ✅"
                    alert.informativeText = """
                    ScreenGrabber can now access your \(folderName) folder.
                    
                    Screenshots will be saved to:
                    \(url.path)
                    
                    You can verify this in:
                    System Settings → Privacy & Security → Files and Folders
                    
                    You're all set!
                    """
                    alert.addButton(withTitle: "Start Using ScreenGrabber")
                    alert.addButton(withTitle: "Open System Settings")
                    
                    if alert.runModal() == .alertSecondButtonReturn {
                        CapturePermissionsManager.openSystemSettings(for: .fileSystem)
                    }
                    
                case .failure(.permissionDenied):
                    // Permission was denied - show guidance
                    showPermissionDeniedGuidance(folderName: folderName)
                    
                case .failure(let error):
                    let alert = NSAlert()
                    alert.alertStyle = .warning
                    alert.messageText = "Could Not Access Folder"
                    alert.informativeText = """
                    Error: \(error.localizedDescription)
                    
                    \(error.recoverySuggestion ?? "Please try a different location.")
                    """
                    alert.addButton(withTitle: "Choose Different Folder")
                    alert.addButton(withTitle: "Cancel")
                    
                    if alert.runModal() == .alertFirstButtonReturn {
                        showCustomFolderPicker()
                    }
                }
            }
        }
    }
    
    private func showPermissionDeniedGuidance(folderName: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Permission Needed"
        
        alert.informativeText = """
        ScreenGrabber needs your permission to access the \(folderName) folder.
        
        ℹ️ What to do:
        
        1. Click "Open System Settings" below
        2. Navigate to Privacy & Security → Files and Folders
        3. Find "ScreenGrabber" in the list
        4. Enable "\(folderName)" access
        
        If ScreenGrabber is NOT in the list:
        • The app may not be properly sandboxed
        • Try choosing a different save location
        • Use Pictures folder (no permission needed)
        
        Alternative: Choose a different save location
        """
        
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Use Pictures Folder")
        alert.addButton(withTitle: "Choose Different Folder")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            CapturePermissionsManager.openSystemSettings(for: .fileSystem)
            
        case .alertSecondButtonReturn:
            usePicturesFolder()
            
        case .alertThirdButtonReturn:
            showCustomFolderPicker()
            
        default:
            break
        }
    }
    
    private func showCustomFolderPicker() {
        let panel = NSOpenPanel()
        panel.message = "Choose where to save screenshots"
        panel.prompt = "Select Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        
        // Start at Pictures
        panel.directoryURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let screenGrabberFolder = url.appendingPathComponent("Screen Grabber")
                let requiresPermission = CapturePermissionsManager.requiresFilesFoldersPermission(for: screenGrabberFolder)
                self.setupFolder(at: screenGrabberFolder, requiresPermission: requiresPermission)
            }
        }
    }
    
    // MARK: - Detailed Permissions Review
    
    private func showDetailedPermissionsReview() {
        let status = checkAllPermissions()
        
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Permissions Status"
        alert.icon = NSImage(systemSymbolName: "checkmark.shield", accessibilityDescription: nil)
        
        var infoText = """
        Current Permission Status:
        
        📸 Screen Recording: \(status.screenRecording ? "✅ Granted" : "❌ Not Granted")
        Required for taking screenshots
        
        🔐 Full Disk Access: \(status.fullDiskAccess ? "✅ Granted" : "❌ Not Granted")
        Only needed for protected Library folders
        
        📁 Files & Folders Access:
        """
        
        infoText += "\n  • Desktop: \(status.desktopAccess ? "✅" : "❌")"
        infoText += "\n  • Documents: \(status.documentsAccess ? "✅" : "❌")"
        infoText += "\n  • Downloads: \(status.downloadsAccess ? "✅" : "❌")"
        infoText += "\n  • Pictures: \(status.picturesAccess ? "✅" : "❌")"
        
        infoText += "\n\n💡 Recommendations:\n"
        
        if !status.screenRecording {
            infoText += "\n⚠️ Screen Recording is REQUIRED"
            infoText += "\n   Enable in System Settings → Privacy & Security"
        }
        
        if !status.picturesAccess {
            infoText += "\n⚠️ Pictures folder access failed"
            infoText += "\n   This is unusual and may indicate a sandbox issue"
        }
        
        if status.picturesAccess && (!status.desktopAccess && !status.documentsAccess) {
            infoText += "\n✅ Use Pictures folder (recommended)"
            infoText += "\n   No special permissions needed!"
        }
        
        alert.informativeText = infoText
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Continue Setup")
        alert.addButton(withTitle: "Close")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            CapturePermissionsManager.openSystemSettings(for: .screenRecording)
        } else if response == .alertSecondButtonReturn {
            showFolderAccessSetup()
        }
    }
}

// MARK: - Permission Status Model

struct PermissionStatus {
    var screenRecording = false
    var fullDiskAccess = false
    var desktopAccess = false
    var documentsAccess = false
    var downloadsAccess = false
    var picturesAccess = false
    
    var hasRequiredPermissions: Bool {
        screenRecording
    }
    
    var hasAllFolderAccess: Bool {
        desktopAccess && documentsAccess && downloadsAccess
    }
    
    var hasAnySaveLocation: Bool {
        picturesAccess || desktopAccess || documentsAccess || downloadsAccess
    }
}
