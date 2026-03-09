//
//  OnboardingModel.swift
//  ScreenGrabber
//
//  Created on 01/17/26.
//  Manages onboarding state and flow
//

import Foundation
import SwiftUI

/// Manages the onboarding experience for first-time users
@Observable
final class OnboardingModel {
    static let shared = OnboardingModel()
    
    // MARK: - Keys
    private enum Keys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let hasSeenPermissionsGuide = "hasSeenPermissionsGuide"
        static let hasConfiguredSaveLocation = "hasConfiguredSaveLocation"
        static let hasSeenQuickTour = "hasSeenQuickTour"
        static let onboardingVersion = "onboardingVersion"
    }
    
    // MARK: - Current Version
    private let currentOnboardingVersion = 1
    
    // MARK: - State
    var shouldShowOnboarding: Bool {
        !hasCompletedOnboarding || needsOnboardingUpdate
    }
    
    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.hasCompletedOnboarding) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.hasCompletedOnboarding) }
    }
    
    var hasSeenPermissionsGuide: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.hasSeenPermissionsGuide) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.hasSeenPermissionsGuide) }
    }
    
    var hasConfiguredSaveLocation: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.hasConfiguredSaveLocation) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.hasConfiguredSaveLocation) }
    }
    
    var hasSeenQuickTour: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.hasSeenQuickTour) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.hasSeenQuickTour) }
    }
    
    private var onboardingVersion: Int {
        get { UserDefaults.standard.integer(forKey: Keys.onboardingVersion) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.onboardingVersion) }
    }
    
    private var needsOnboardingUpdate: Bool {
        onboardingVersion < currentOnboardingVersion
    }
    
    // MARK: - Permissions Status
    var screenRecordingPermissionGranted: Bool {
        CGPreflightScreenCaptureAccess()
    }
    
    var accessibilityPermissionGranted: Bool {
        AXIsProcessTrusted()
    }
    
    var fullDiskAccessGranted: Bool {
        CapturePermissionsManager.hasFullDiskAccess()
    }
    
    var allRequiredPermissionsGranted: Bool {
        screenRecordingPermissionGranted && accessibilityPermissionGranted
    }
    
    var allPermissionsGranted: Bool {
        screenRecordingPermissionGranted && accessibilityPermissionGranted && fullDiskAccessGranted
    }
    
    // MARK: - Actions
    
    /// Mark onboarding as complete
    func completeOnboarding() {
        hasCompletedOnboarding = true
        onboardingVersion = currentOnboardingVersion
        print("[ONBOARDING] ✅ Onboarding completed (version \(currentOnboardingVersion))")
    }
    
    /// Reset onboarding (for testing or major updates)
    func resetOnboarding() {
        hasCompletedOnboarding = false
        hasSeenPermissionsGuide = false
        hasConfiguredSaveLocation = false
        hasSeenQuickTour = false
        onboardingVersion = 0
        print("[ONBOARDING] ⚠️ Onboarding reset")
    }
    
    /// Request screen recording permission
    func requestScreenRecordingPermission() {
        CGRequestScreenCaptureAccess()
    }
    
    /// Request accessibility permission
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    /// Request Full Disk Access
    func requestFullDiskAccessPermission() {
        Task { @MainActor in
            CapturePermissionsManager.triggerFullDiskAccessPrompt()
        }
    }
    
    /// Open System Settings to specific permission pane
    func openSystemSettings(for permission: PermissionType) {
        switch permission {
        case .screenRecording:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        case .accessibility:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        case .fullDiskAccess:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    // MARK: - Types
    
    enum PermissionType {
        case screenRecording
        case accessibility
        case fullDiskAccess
    }
}

// MARK: - Onboarding Step

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case permissions = 1
    case saveLocation = 2
    case quickTour = 3
    case complete = 4
    
    var title: String {
        switch self {
        case .welcome: return "Welcome to Screen Grabber"
        case .permissions: return "Set Up Permissions"
        case .saveLocation: return "Choose Save Location"
        case .quickTour: return "Quick Tour"
        case .complete: return "You're All Set!"
        }
    }
    
    var subtitle: String {
        switch self {
        case .welcome:
            return "Capture, edit, and share screenshots with ease"
        case .permissions:
            return "Grant necessary permissions for full functionality"
        case .saveLocation:
            return "Choose where your captures are saved"
        case .quickTour:
            return "Learn the basics in 60 seconds"
        case .complete:
            return "Start capturing amazing screenshots"
        }
    }
    
    var icon: String {
        switch self {
        case .welcome: return "hand.wave.fill"
        case .permissions: return "lock.shield.fill"
        case .saveLocation: return "folder.fill"
        case .quickTour: return "lightbulb.fill"
        case .complete: return "checkmark.circle.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .welcome: return .orange
        case .permissions: return .blue
        case .saveLocation: return .purple
        case .quickTour: return .yellow
        case .complete: return .green
        }
    }
}
