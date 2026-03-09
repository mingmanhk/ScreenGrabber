//
//  OnboardingManager.swift
//  ScreenGrabber
//
//  Created by Assistant on 1/17/26.
//

import Foundation
import SwiftUI

/// Manages first-launch onboarding state and completion
@Observable
final class OnboardingManager {
    static let shared = OnboardingManager()
    
    private enum Keys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let hasSeenWelcome = "hasSeenWelcome"
        static let hasSetupPermissions = "hasSetupPermissions"
        static let hasConfiguredSaveLocation = "hasConfiguredSaveLocation"
        static let hasSeenQuickTour = "hasSeenQuickTour"
        static let lastOnboardingVersion = "lastOnboardingVersion"
    }
    
    private let currentOnboardingVersion = "1.0"
    
    // MARK: - State Properties
    
    var hasCompletedOnboarding: Bool {
        get {
            UserDefaults.standard.bool(forKey: Keys.hasCompletedOnboarding) &&
            UserDefaults.standard.string(forKey: Keys.lastOnboardingVersion) == currentOnboardingVersion
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.hasCompletedOnboarding)
            if newValue {
                UserDefaults.standard.set(currentOnboardingVersion, forKey: Keys.lastOnboardingVersion)
            }
        }
    }
    
    var hasSeenWelcome: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.hasSeenWelcome) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.hasSeenWelcome) }
    }
    
    var hasSetupPermissions: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.hasSetupPermissions) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.hasSetupPermissions) }
    }
    
    var hasConfiguredSaveLocation: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.hasConfiguredSaveLocation) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.hasConfiguredSaveLocation) }
    }
    
    var hasSeenQuickTour: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.hasSeenQuickTour) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.hasSeenQuickTour) }
    }
    
    // MARK: - Onboarding Actions
    
    func shouldShowOnboarding() -> Bool {
        return !hasCompletedOnboarding
    }
    
    func markWelcomeComplete() {
        hasSeenWelcome = true
    }
    
    func markPermissionsComplete() {
        hasSetupPermissions = true
    }
    
    func markSaveLocationComplete() {
        hasConfiguredSaveLocation = true
    }
    
    func markQuickTourComplete() {
        hasSeenQuickTour = true
    }
    
    func completeOnboarding() {
        hasSeenWelcome = true
        hasSetupPermissions = true
        hasConfiguredSaveLocation = true
        hasCompletedOnboarding = true
        
        print("[ONBOARDING] ✅ Onboarding completed successfully")
    }
    
    func resetOnboarding() {
        UserDefaults.standard.removeObject(forKey: Keys.hasCompletedOnboarding)
        UserDefaults.standard.removeObject(forKey: Keys.hasSeenWelcome)
        UserDefaults.standard.removeObject(forKey: Keys.hasSetupPermissions)
        UserDefaults.standard.removeObject(forKey: Keys.hasConfiguredSaveLocation)
        UserDefaults.standard.removeObject(forKey: Keys.hasSeenQuickTour)
        UserDefaults.standard.removeObject(forKey: Keys.lastOnboardingVersion)
        
        print("[ONBOARDING] 🔄 Onboarding reset - will show on next launch")
    }
}
