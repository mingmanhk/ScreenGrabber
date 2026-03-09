//
//  FullDiskAccessTrigger.swift
//  ScreenGrabber
//
//  Utility to trigger Full Disk Access prompt and ensure app appears in System Settings
//

import Foundation
import AppKit

/// Helper to trigger Full Disk Access and make app appear in privacy settings
@MainActor
final class FullDiskAccessTrigger {
    
    /// Shared singleton instance
    static let shared = FullDiskAccessTrigger()
    
    private init() {}
    
    // MARK: - Trigger FDA Prompt
    
    /// Attempts to access protected folders to trigger TCC prompt and FDA list entry
    /// This makes ScreenGrabber appear in System Settings → Privacy & Security → Full Disk Access
    func triggerFullDiskAccessPrompt() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        
        // List of protected directories to attempt access
        // Accessing these will cause macOS to add the app to FDA list
        let protectedPaths = [
            // Desktop is most reliable for triggering FDA
            homeDir.appendingPathComponent("Desktop"),
            
            // Documents folder
            homeDir.appendingPathComponent("Documents"),
            
            // Downloads folder
            homeDir.appendingPathComponent("Downloads"),
            
            // Library folder (highly protected)
            homeDir.appendingPathComponent("Library/Safari"),
            homeDir.appendingPathComponent("Library/Mail"),
            homeDir.appendingPathComponent("Library/Messages"),
            
            // Application Support
            homeDir.appendingPathComponent("Library/Application Support/com.apple.sharedfilelist")
        ]
        
        // Attempt to access each protected path
        for path in protectedPaths {
            attemptAccess(to: path)
        }
        
        // Also try to list contents of Desktop (most common trigger)
        attemptListContents(of: homeDir.appendingPathComponent("Desktop"))
        
        // Show user guidance
        showFDAGuidance()
    }
    
    /// Attempt to access a protected path (this triggers TCC)
    private func attemptAccess(to url: URL) {
        // Try to check if file exists (triggers TCC prompt)
        _ = FileManager.default.fileExists(atPath: url.path)
        
        // Try to check if it's readable
        _ = FileManager.default.isReadableFile(atPath: url.path)
        
        // Try to get attributes
        _ = try? FileManager.default.attributesOfItem(atPath: url.path)
    }
    
    /// Attempt to list contents of a directory (reliable FDA trigger)
    private func attemptListContents(of url: URL) {
        do {
            // This is the most reliable way to trigger FDA prompt
            _ = try FileManager.default.contentsOfDirectory(atPath: url.path)
        } catch {
            // Expected to fail if FDA not granted - this is what triggers the TCC entry
            CaptureLogger.log(.permissions, "FDA trigger attempt for \(url.path): \(error.localizedDescription)", level: .debug)
        }
        
        // Also try shallow enumeration
        let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.nameKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        )
        _ = enumerator?.nextObject()
    }
    
    // MARK: - User Guidance
    
    /// Shows comprehensive FDA setup guidance
    func showFDAGuidance() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Full Disk Access Setup"
        alert.icon = NSImage(systemSymbolName: "externaldrive.fill", accessibilityDescription: nil)
        
        alert.informativeText = """
        ScreenGrabber needs Full Disk Access to save screenshots to protected folders like Desktop and Documents.
        
        📍 How to Enable:
        
        1. Click "Open System Settings" below
        2. Click the 🔒 lock icon (bottom left) and authenticate
        3. Scroll to find "ScreenGrabber" in the list
           • If you don't see it, try saving a screenshot first, then check again
           • Or click the + button and manually add ScreenGrabber.app
        4. Toggle the switch to ON (✓)
        5. Quit and restart ScreenGrabber
        
        💡 Note: ScreenGrabber has just attempted to access protected folders. It should now appear in the Full Disk Access list.
        
        ⚠️ Important: If you don't want to enable Full Disk Access, you can:
        • Choose Pictures folder instead (no FDA required)
        • Select a custom folder outside Desktop/Documents
        • Use an external drive or custom location
        """
        
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Show Me How (Step-by-Step)")
        alert.addButton(withTitle: "Choose Different Folder")
        alert.addButton(withTitle: "Not Now")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            openFDASettings()
            showFollowUpInstructions()
            
        case .alertSecondButtonReturn:
            showStepByStepGuide()
            
        case .alertThirdButtonReturn:
            showFolderPicker()
            
        default:
            break
        }
    }
    
    /// Opens System Settings to Full Disk Access panel
    func openFDASettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Shows follow-up instructions after opening settings
    private func showFollowUpInstructions() {
        // Delay to give user time to see System Settings open
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = "In System Settings..."
            alert.informativeText = """
            You should now see the Full Disk Access panel.
            
            ✓ What to do:
            
            1. Look for "ScreenGrabber" in the list
               - It may be at the top or bottom
               - Scroll if you don't see it immediately
            
            2. If ScreenGrabber IS in the list:
               → Toggle the switch to ON
               → Quit and restart ScreenGrabber
               → You're done! ✅
            
            3. If ScreenGrabber is NOT in the list:
               → Click the + button (bottom of list)
               → Navigate to Applications folder
               → Select ScreenGrabber.app
               → Toggle the switch to ON
               → Quit and restart ScreenGrabber
            
            4. Still don't see it?
               → Try saving a screenshot to Desktop first
               → Then check System Settings again
               → Or click "Show Troubleshooting" below
            
            Remember: You MUST quit and restart ScreenGrabber after enabling FDA for it to take effect!
            """
            
            alert.addButton(withTitle: "Got It")
            alert.addButton(withTitle: "Show Troubleshooting")
            
            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
                self?.showTroubleshooting()
            }
        }
    }
    
    /// Shows detailed step-by-step visual guide
    private func showStepByStepGuide() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Step-by-Step Guide: Enable Full Disk Access"
        
        alert.informativeText = """
        Follow these steps carefully:
        
        STEP 1: Open System Settings
        ────────────────────────────
        • Click the Apple menu () → System Settings
        • Or click "Open Settings" below
        
        STEP 2: Navigate to Privacy & Security
        ────────────────────────────────────
        • Click "Privacy & Security" in the sidebar
        • Scroll down to "Full Disk Access"
        • Click on "Full Disk Access"
        
        STEP 3: Unlock Settings
        ─────────────────────
        • Click the 🔒 lock icon (bottom left corner)
        • Enter your administrator password
        • The lock should change to 🔓
        
        STEP 4: Find ScreenGrabber
        ───────────────────────
        • Look in the list for "ScreenGrabber"
        • It might be in alphabetical order
        • Scroll through the list carefully
        
        STEP 5A: If ScreenGrabber is in the list
        ──────────────────────────────────────
        • Click the toggle switch next to ScreenGrabber
        • It should turn blue (ON)
        • Skip to Step 6
        
        STEP 5B: If ScreenGrabber is NOT in the list
        ──────────────────────────────────────────
        • Click the + (plus) button below the list
        • A file picker will open
        • Navigate to: Applications folder
        • Find and select "ScreenGrabber.app"
        • Click "Open"
        • ScreenGrabber will now appear in the list
        • Toggle the switch to ON
        
        STEP 6: Restart ScreenGrabber
        ──────────────────────────
        • Quit ScreenGrabber completely (⌘Q)
        • Launch ScreenGrabber again
        • Full Disk Access is now active! ✅
        
        TROUBLESHOOTING:
        • If the + button is grayed out, make sure you unlocked (Step 3)
        • If ScreenGrabber doesn't appear after adding, restart your Mac
        • If you get "Operation not permitted", you need to restart the app
        """
        
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "I'll Do This Later")
        
        if alert.runModal() == .alertFirstButtonReturn {
            openFDASettings()
        }
    }
    
    /// Shows troubleshooting options
    private func showTroubleshooting() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Troubleshooting Full Disk Access"
        
        alert.informativeText = """
        Common issues and solutions:
        
        ❓ PROBLEM: ScreenGrabber not in FDA list
        
        Solution 1: Trigger FDA Detection
        • Try to save a screenshot to Desktop
        • This forces macOS to recognize the app
        • Check System Settings again after
        
        Solution 2: Manual Addition
        • Open System Settings → Full Disk Access
        • Click + button
        • Navigate to /Applications
        • Select ScreenGrabber.app
        • If ScreenGrabber.app is in a different location, go there instead
        
        Solution 3: Reset TCC Database
        • Open Terminal
        • Run: tccutil reset SystemPolicyAllFiles
        • Try accessing Desktop folder again
        • Check System Settings
        
        ❓ PROBLEM: FDA enabled but access still denied
        
        Solution: Restart Required
        • Full Disk Access requires app restart
        • Quit ScreenGrabber completely (⌘Q)
        • Don't just close windows - fully quit
        • Launch ScreenGrabber again
        
        ❓ PROBLEM: + button is grayed out
        
        Solution: Unlock Settings
        • Click the 🔒 lock icon (bottom left)
        • Enter your password
        • Lock must be unlocked to make changes
        
        ❓ PROBLEM: Don't want to enable FDA
        
        Solution: Use Different Folder
        • Choose Pictures folder (no FDA needed)
        • Use Documents/Custom location
        • Or an external drive
        • Click "Choose Folder" below
        
        ❓ PROBLEM: App crashes or weird behavior
        
        Solution: Clean Install
        • Completely quit ScreenGrabber
        • Delete app from Applications
        • Empty Trash
        • Download fresh copy
        • Reinstall and try again
        
        Still having issues? Click "Get More Help" below.
        """
        
        alert.addButton(withTitle: "Try Saving to Desktop Now")
        alert.addButton(withTitle: "Choose Different Folder")
        alert.addButton(withTitle: "Open Terminal Instructions")
        alert.addButton(withTitle: "Close")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            testDesktopAccess()
            
        case .alertSecondButtonReturn:
            showFolderPicker()
            
        case .alertThirdButtonReturn:
            showTerminalInstructions()
            
        default:
            break
        }
    }
    
    /// Test access to Desktop folder
    private func testDesktopAccess() {
        Task {
            let desktop = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Desktop/Screen Grabber Test")
            
            let result = await CapturePermissionsManager.shared
                .ensureCaptureFolderExists(at: desktop)
            
            await MainActor.run {
                let alert = NSAlert()
                
                switch result {
                case .success(let url):
                    alert.alertStyle = .informational
                    alert.messageText = "Success! ✅"
                    alert.informativeText = """
                    ScreenGrabber can now access the Desktop folder.
                    
                    Test folder created at:
                    \(url.path)
                    
                    Full Disk Access is working correctly!
                    
                    ScreenGrabber should now appear in System Settings → Privacy & Security → Full Disk Access.
                    """
                    
                case .failure(.permissionDenied(type: .fullDiskAccess)):
                    alert.alertStyle = .critical
                    alert.messageText = "Full Disk Access Required"
                    alert.informativeText = """
                    ScreenGrabber cannot access the Desktop folder.
                    
                    This confirms that Full Disk Access is not enabled.
                    
                    ScreenGrabber should now appear in System Settings.
                    Please enable it and restart the app.
                    """
                    
                case .failure(let error):
                    alert.alertStyle = .warning
                    alert.messageText = "Access Failed"
                    alert.informativeText = """
                    Could not access Desktop folder.
                    
                    Error: \(error.localizedDescription)
                    
                    \(error.recoverySuggestion ?? "Try choosing a different save location.")
                    """
                }
                
                alert.addButton(withTitle: "OK")
                if case .failure = result {
                    alert.addButton(withTitle: "Open System Settings")
                }
                
                if alert.runModal() == .alertSecondButtonReturn {
                    openFDASettings()
                }
            }
        }
    }
    
    /// Shows folder picker for alternative location
    private func showFolderPicker() {
        let panel = NSOpenPanel()
        panel.message = "Choose where to save screenshots"
        panel.prompt = "Select Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        
        // Start at Pictures directory (doesn't require FDA)
        panel.directoryURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task { @MainActor in
                    let screenGrabberFolder = url.appendingPathComponent("Screen Grabber")
                    SettingsModel.shared.setCustomSaveLocation(screenGrabberFolder)
                    
                    let result = await CapturePermissionsManager.shared
                        .ensureCaptureFolderExists(at: screenGrabberFolder)
                    
                    let alert = NSAlert()
                    if case .success = result {
                        alert.alertStyle = .informational
                        alert.messageText = "Save Location Updated"
                        alert.informativeText = """
                        Screenshots will now be saved to:
                        \(screenGrabberFolder.path)
                        
                        This location does not require Full Disk Access.
                        """
                    } else {
                        alert.alertStyle = .warning
                        alert.messageText = "Location Not Accessible"
                        alert.informativeText = "The selected location could not be accessed. Please choose a different folder."
                    }
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }
    
    /// Shows Terminal reset instructions
    private func showTerminalInstructions() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Reset TCC Database (Advanced)"
        
        alert.informativeText = """
        This will reset all Full Disk Access permissions.
        
        Steps:
        
        1. Open Terminal application
           (Applications → Utilities → Terminal)
        
        2. Copy and paste this command:
        
           tccutil reset SystemPolicyAllFiles
        
        3. Press Return/Enter
        
        4. You may see a confirmation message
        
        5. All Full Disk Access permissions are now reset
        
        6. Try accessing Desktop folder in ScreenGrabber again
        
        7. Check System Settings → Full Disk Access
        
        WARNING: This will remove FDA permissions for ALL apps.
        You'll need to re-enable FDA for any app that needs it.
        
        Only do this if you've tried everything else!
        """
        
        alert.addButton(withTitle: "Copy Command")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("tccutil reset SystemPolicyAllFiles", forType: .string)
            
            let confirm = NSAlert()
            confirm.messageText = "Command Copied!"
            confirm.informativeText = "The command has been copied to your clipboard. Paste it into Terminal and press Return."
            confirm.addButton(withTitle: "OK")
            confirm.runModal()
        }
    }
    
    // MARK: - Quick Actions
    
    /// One-click action to attempt FDA trigger and open settings
    func quickSetup() {
        // First, try to trigger FDA
        triggerFullDiskAccessPrompt()
        
        // Small delay to let TCC process
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.openFDASettings()
        }
    }
    
    /// Check if FDA is needed for current save location
    func checkCurrentSaveLocation() -> Bool {
        let saveURL = SettingsModel.shared.effectiveSaveURL
        return CapturePermissionsManager.requiresFullDiskAccess(for: saveURL)
    }
    
    /// Show appropriate guidance based on current save location
    func showSmartGuidance() {
        if checkCurrentSaveLocation() {
            if !CapturePermissionsManager.hasFullDiskAccess() {
                triggerFullDiskAccessPrompt()
            }
        } else {
            let alert = NSAlert()
            alert.messageText = "Full Disk Access Not Required"
            alert.informativeText = """
            Your current save location:
            \(SettingsModel.shared.effectiveSaveURL.path)
            
            This location does not require Full Disk Access.
            ScreenGrabber should work without any additional permissions.
            
            Full Disk Access is only needed if you want to save to:
            • Desktop
            • Documents
            • Downloads
            • Certain Library folders
            """
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}


