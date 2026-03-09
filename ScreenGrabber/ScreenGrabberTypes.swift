//
//  ScreenGrabberTypes.swift
//  ScreenGrabber
//
//  Centralized type definitions for ScreenGrabber
//

import Foundation

/// Namespace for all ScreenGrabber shared types
enum ScreenGrabberTypes {
    
    // MARK: - Capture Type
    
    /// Type of screen capture
    enum CaptureType: String, Codable, CaseIterable {
        case area = "area"
        case window = "window"
        case fullscreen = "fullscreen"
        case scrolling = "scrolling"
        
        var displayName: String {
            switch self {
            case .area: return "Area"
            case .window: return "Window"
            case .fullscreen: return "Full Screen"
            case .scrolling: return "Scrolling"
            }
        }
    }
    
    // MARK: - Permission Type
    
    /// Permission types required by the app
    enum PermissionType: String, CaseIterable {
        case screenRecording = "Screen Recording"
        case accessibility = "Accessibility"
        case fileSystem = "File System Access"
        case fullDiskAccess = "Full Disk Access"
        case microphone = "Microphone"
        
        var displayName: String { rawValue }
        
        var systemSettingsURL: String {
            switch self {
            case .screenRecording:
                return "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
            case .accessibility:
                return "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            case .fileSystem:
                return "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders"
            case .fullDiskAccess:
                return "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
            case .microphone:
                return "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
            }
        }
        
        var icon: String {
            switch self {
            case .screenRecording:
                return "rectangle.on.rectangle"
            case .accessibility:
                return "accessibility"
            case .fileSystem:
                return "folder"
            case .fullDiskAccess:
                return "externaldrive.fill"
            case .microphone:
                return "mic.fill"
            }
        }
        
        var description: String {
            switch self {
            case .screenRecording:
                return "Required to capture screenshots and screen recordings"
            case .accessibility:
                return "Required for window selection and smart capture features"
            case .fileSystem:
                return "Required to save screenshots to custom locations"
            case .fullDiskAccess:
                return "Required to access protected folders like Desktop and Documents"
            case .microphone:
                return "Required for screen recordings with audio"
            }
        }
        
        var isOptional: Bool {
            switch self {
            case .screenRecording, .accessibility:
                return false
            case .fileSystem, .fullDiskAccess, .microphone:
                return true
            }
        }
    }
    
    // MARK: - Capture Errors
    
    /// Errors that can occur during capture operations
    enum CaptureError: LocalizedError {
        case permissionDenied(type: PermissionType)
        case folderCreationFailed(underlying: Error?)
        case fileWriteFailed(underlying: Error?)
        case captureKitError(String)
        case userCancelled
        case noScreenAvailable
        case noWindowAvailable
        case historyUpdateFailed(underlying: Error)
        case thumbnailGenerationFailed(underlying: Error?)
        case invalidImageData
        case editorLaunchFailed(underlying: Error?)
        
        var errorDescription: String? {
            switch self {
            case .permissionDenied(let type):
                return "\(type.displayName) permission is required but not granted"
            case .folderCreationFailed(let underlying):
                if let error = underlying {
                    return "Cannot create or access screenshot folder: \(error.localizedDescription)"
                }
                return "Cannot create or access screenshot folder"
            case .fileWriteFailed(let underlying):
                if let error = underlying {
                    return "Cannot save screenshot file: \(error.localizedDescription)"
                }
                return "Cannot save screenshot file"
            case .captureKitError(let message):
                return "Screen capture failed: \(message)"
            case .userCancelled:
                return "Screenshot cancelled"
            case .noScreenAvailable:
                return "No screen available for capture"
            case .noWindowAvailable:
                return "No window selected for capture"
            case .historyUpdateFailed(let underlying):
                return "Screenshot saved but history update failed: \(underlying.localizedDescription)"
            case .thumbnailGenerationFailed:
                return "Screenshot saved but thumbnail generation failed"
            case .invalidImageData:
                return "Invalid screenshot data"
            case .editorLaunchFailed(let underlying):
                if let error = underlying {
                    return "Cannot open screenshot in editor: \(error.localizedDescription)"
                }
                return "Cannot open screenshot in editor"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .permissionDenied(let type):
                switch type {
                case .screenRecording:
                    return "Open System Settings → Privacy & Security → Screen Recording and enable ScreenGrabber"
                case .accessibility:
                    return "Open System Settings → Privacy & Security → Accessibility and enable ScreenGrabber"
                case .fileSystem:
                    return "Ensure the save folder is writable, or choose a different location in Settings"
                case .fullDiskAccess:
                    return "Open System Settings → Privacy & Security → Full Disk Access and enable ScreenGrabber.\n\nNote: You may need to quit and restart the app after granting permission."
                case .microphone:
                    return "Open System Settings → Privacy & Security → Microphone and enable ScreenGrabber"
                }
            case .folderCreationFailed:
                return "Try these solutions:\n• Check if you have write permissions\n• Ensure sufficient disk space\n• Choose a different save location in Settings\n• Try the default location: ~/Pictures/Screen Grabber/"
            case .fileWriteFailed:
                return "Try these solutions:\n• Ensure sufficient disk space\n• Check folder permissions\n• Choose a different save location in Settings"
            case .captureKitError:
                return "Try restarting the app. If the problem persists, restart your Mac."
            case .userCancelled:
                return nil
            case .noScreenAvailable:
                return """
                ScreenGrabber could not detect an active display.
                
                Possible causes:
                • Your Mac is transitioning between display modes
                • Displays are being reconfigured
                • The system is waking from sleep
                • Display connection issues
                
                Please try:
                1. Move your mouse to activate the display
                2. Wait a moment and retry the capture
                3. Check your display connections
                4. Restart ScreenGrabber if the issue persists
                """
            case .noWindowAvailable:
                return "Make sure windows are visible and not minimized. You may need to grant Screen Recording permission in System Settings."
            case .historyUpdateFailed:
                return "The screenshot was saved successfully but could not be added to history. You can find it in your save folder."
            case .thumbnailGenerationFailed:
                return "The screenshot was saved successfully. Thumbnails will be generated later."
            case .invalidImageData:
                return "Try capturing again. If the problem persists, restart the app."
            case .editorLaunchFailed:
                return "The screenshot was saved successfully. You can open it manually from your save folder."
            }
        }
    }
}

