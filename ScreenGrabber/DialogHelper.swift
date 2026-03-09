//
//  DialogHelper.swift
//  ScreenGrabber
//
//  Created on 01/17/26.
//  macOS-native dialogs with action-oriented button labels
//

import SwiftUI
import AppKit

/// Helper for creating macOS-native dialogs with proper button labels
enum DialogHelper {
    
    // MARK: - Confirmation Dialogs
    
    /// Show a confirmation dialog with action-oriented buttons
    @MainActor
    static func showConfirmation(
        title: String,
        message: String,
        confirmTitle: String = "Continue",
        confirmStyle: NSAlert.Style = .informational,
        showCancel: Bool = true,
        cancelTitle: String = "Cancel"
    ) async -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = confirmStyle
        
        alert.addButton(withTitle: confirmTitle)
        if showCancel {
            alert.addButton(withTitle: cancelTitle)
        }
        
        let response = alert.runModal()
        return response == .alertFirstButtonReturn
    }
    
    // MARK: - Delete/Destructive Actions
    
    /// Show a destructive action confirmation
    @MainActor
    static func showDestructiveConfirmation(
        title: String,
        message: String,
        actionTitle: String = "Delete",
        cancelTitle: String = "Cancel"
    ) async -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        
        alert.addButton(withTitle: cancelTitle)
        alert.addButton(withTitle: actionTitle)
        
        let response = alert.runModal()
        return response == .alertSecondButtonReturn
    }
    
    // MARK: - Save Dialogs
    
    /// Show "Save Changes" dialog
    @MainActor
    static func showSaveChanges(
        documentName: String? = nil
    ) async -> SaveChangesResult {
        let alert = NSAlert()
        
        if let name = documentName {
            alert.messageText = "Do you want to save changes to \"\(name)\"?"
        } else {
            alert.messageText = "Do you want to save your changes?"
        }
        
        alert.informativeText = "Your changes will be lost if you don't save them."
        alert.alertStyle = .warning
        
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Don't Save")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            return .save
        case .alertSecondButtonReturn:
            return .cancel
        case .alertThirdButtonReturn:
            return .dontSave
        default:
            return .cancel
        }
    }
    
    enum SaveChangesResult {
        case save
        case dontSave
        case cancel
    }
    
    // MARK: - Permission Dialogs
    
    /// Show permission required dialog
    @MainActor
    static func showPermissionRequired(
        permission: String,
        reason: String
    ) async -> Bool {
        let alert = NSAlert()
        alert.messageText = "\(permission) Permission Required"
        alert.informativeText = reason
        alert.alertStyle = .warning
        
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Not Now")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // Open System Settings
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
                NSWorkspace.shared.open(url)
            }
            return true
        }
        
        return false
    }
    
    // MARK: - Error Dialogs
    
    /// Show an error dialog with optional recovery action
    @MainActor
    static func showError(
        title: String,
        message: String,
        recoveryAction: RecoveryAction? = nil
    ) async -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        
        alert.addButton(withTitle: "OK")
        
        if let recovery = recoveryAction {
            alert.addButton(withTitle: recovery.title)
        }
        
        let response = alert.runModal()
        
        if response == .alertSecondButtonReturn, let recovery = recoveryAction {
            recovery.action()
            return true
        }
        
        return false
    }
    
    struct RecoveryAction {
        let title: String
        let action: () -> Void
    }
    
    // MARK: - Choice Dialogs
    
    /// Show a dialog with multiple choices
    @MainActor
    static func showChoice(
        title: String,
        message: String,
        choices: [String],
        style: NSAlert.Style = .informational
    ) async -> Int? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        
        for choice in choices {
            alert.addButton(withTitle: choice)
        }
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            return 0
        case .alertSecondButtonReturn:
            return 1
        case .alertThirdButtonReturn:
            return 2
        default:
            return nil
        }
    }
    
    // MARK: - Specific Use Cases
    
    /// Confirm quit while operation in progress
    @MainActor
    static func confirmQuitDuringOperation() async -> Bool {
        await showConfirmation(
            title: "Are you sure you want to quit?",
            message: "A capture operation is currently in progress. If you quit now, it will be canceled.",
            confirmTitle: "Quit Anyway",
            confirmStyle: .warning,
            cancelTitle: "Continue Capture"
        )
    }
    
    /// Confirm delete captured screenshot
    @MainActor
    static func confirmDeleteScreenshot(filename: String) async -> Bool {
        await showDestructiveConfirmation(
            title: "Delete \"\(filename)\"?",
            message: "This screenshot will be moved to the Trash. You can restore it from the Trash if needed.",
            actionTitle: "Move to Trash"
        )
    }
    
    /// Confirm overwrite existing file
    @MainActor
    static func confirmOverwrite(filename: String) async -> OverwriteResult {
        let alert = NSAlert()
        alert.messageText = "\"\(filename)\" already exists."
        alert.informativeText = "Do you want to replace it with the new version?"
        alert.alertStyle = .warning
        
        alert.addButton(withTitle: "Replace")
        alert.addButton(withTitle: "Keep Both")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            return .replace
        case .alertSecondButtonReturn:
            return .keepBoth
        case .alertThirdButtonReturn:
            return .cancel
        default:
            return .cancel
        }
    }
    
    enum OverwriteResult {
        case replace
        case keepBoth
        case cancel
    }
    
    /// Show folder permission error
    @MainActor
    static func showFolderPermissionError(path: String) async {
        let alert = NSAlert()
        alert.messageText = "Cannot Save to This Location"
        alert.informativeText = "Screen Grabber doesn't have permission to save files to \"\(path)\". Please choose a different location in Settings."
        alert.alertStyle = .critical
        
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Open Settings")
        
        let response = alert.runModal()
        
        if response == .alertSecondButtonReturn {
            NotificationCenter.default.post(name: .requestSettingsOpen, object: nil)
        }
    }
    
    /// Show disk space warning
    @MainActor
    static func showDiskSpaceWarning(availableSpace: String) async -> Bool {
        await showConfirmation(
            title: "Low Disk Space",
            message: "Your disk has only \(availableSpace) of free space available. Screen Grabber may not be able to save screenshots or recordings.",
            confirmTitle: "Continue Anyway",
            confirmStyle: .warning,
            cancelTitle: "Free Up Space"
        )
    }
    
    /// Show first launch permissions guide
    @MainActor
    static func showFirstLaunchPermissions() async -> Bool {
        let alert = NSAlert()
        alert.messageText = "Welcome to Screen Grabber"
        alert.informativeText = """
        To capture screenshots and recordings, Screen Grabber needs permission to record your screen.
        
        Click "Grant Permission" to open System Settings and enable Screen Recording access.
        """
        alert.alertStyle = .informational
        
        alert.addButton(withTitle: "Grant Permission")
        alert.addButton(withTitle: "Later")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
            return true
        }
        
        return false
    }
}

// MARK: - Preview Helper

#Preview("Dialog Examples") {
    struct DialogPreview: View {
        var body: some View {
            ScrollView {
                VStack(spacing: 16) {
                    Group {
                        Text("Confirmation Dialogs")
                            .font(.headline)
                        
                        Button("Show Basic Confirmation") {
                            Task {
                                let result = await DialogHelper.showConfirmation(
                                    title: "Confirm Action",
                                    message: "Are you sure you want to continue?",
                                    confirmTitle: "Continue"
                                )
                                print("Result: \(result)")
                            }
                        }
                        
                        Button("Show Destructive Confirmation") {
                            Task {
                                let result = await DialogHelper.confirmDeleteScreenshot(
                                    filename: "Screenshot 2026-01-17 at 10.30.45.png"
                                )
                                print("Delete: \(result)")
                            }
                        }
                    }
                    
                    Divider()
                    
                    Group {
                        Text("Save Dialogs")
                            .font(.headline)
                        
                        Button("Show Save Changes") {
                            Task {
                                let result = await DialogHelper.showSaveChanges(
                                    documentName: "My Screenshot"
                                )
                                print("Save result: \(result)")
                            }
                        }
                        
                        Button("Show Overwrite Confirmation") {
                            Task {
                                let result = await DialogHelper.confirmOverwrite(
                                    filename: "screenshot.png"
                                )
                                print("Overwrite: \(result)")
                            }
                        }
                    }
                    
                    Divider()
                    
                    Group {
                        Text("Permission Dialogs")
                            .font(.headline)
                        
                        Button("Show Permission Required") {
                            Task {
                                let result = await DialogHelper.showPermissionRequired(
                                    permission: "Screen Recording",
                                    reason: "Screen Grabber needs Screen Recording permission to capture screenshots and recordings."
                                )
                                print("Permission: \(result)")
                            }
                        }
                        
                        Button("Show First Launch") {
                            Task {
                                let result = await DialogHelper.showFirstLaunchPermissions()
                                print("First launch: \(result)")
                            }
                        }
                    }
                    
                    Divider()
                    
                    Group {
                        Text("Error Dialogs")
                            .font(.headline)
                        
                        Button("Show Error") {
                            Task {
                                await DialogHelper.showError(
                                    title: "Save Failed",
                                    message: "Unable to save the screenshot to disk. Please check your disk space and try again."
                                )
                            }
                        }
                        
                        Button("Show Error with Recovery") {
                            Task {
                                await DialogHelper.showError(
                                    title: "Save Failed",
                                    message: "Unable to save to the selected location.",
                                    recoveryAction: .init(
                                        title: "Choose Different Location"
                                    ) {
                                        print("Recovery action triggered")
                                    }
                                )
                            }
                        }
                        
                        Button("Show Folder Permission Error") {
                            Task {
                                await DialogHelper.showFolderPermissionError(
                                    path: "~/Documents/Screenshots"
                                )
                            }
                        }
                    }
                    
                    Divider()
                    
                    Group {
                        Text("Special Cases")
                            .font(.headline)
                        
                        Button("Confirm Quit During Operation") {
                            Task {
                                let result = await DialogHelper.confirmQuitDuringOperation()
                                print("Quit: \(result)")
                            }
                        }
                        
                        Button("Show Disk Space Warning") {
                            Task {
                                let result = await DialogHelper.showDiskSpaceWarning(
                                    availableSpace: "500 MB"
                                )
                                print("Continue: \(result)")
                            }
                        }
                    }
                }
                .padding(20)
            }
            .frame(width: 400, height: 600)
        }
    }
    
    return DialogPreview()
}
