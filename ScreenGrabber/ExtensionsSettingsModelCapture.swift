//
//  SettingsModel+Capture.swift
//  ScreenGrabber
//
//  Extensions to SettingsModel for capture state tracking
//

import Foundation
import AppKit

extension SettingsModel {
    // MARK: - Last Used Capture Settings (for retry functionality)
    
    private static let lastCaptureMethodKey = "lastUsedCaptureMethod"
    private static let lastOpenOptionKey = "lastUsedOpenOption"
    
    var lastUsedCaptureMethod: ScreenOption? {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: Self.lastCaptureMethodKey) else {
                return nil
            }
            return ScreenOption(rawValue: rawValue)
        }
        set {
            if let method = newValue {
                UserDefaults.standard.set(method.rawValue, forKey: Self.lastCaptureMethodKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.lastCaptureMethodKey)
            }
        }
    }
    
    var lastUsedOpenOption: OpenOption? {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: Self.lastOpenOptionKey) else {
                return nil
            }
            return OpenOption(rawValue: rawValue)
        }
        set {
            if let option = newValue {
                UserDefaults.standard.set(option.rawValue, forKey: Self.lastOpenOptionKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.lastOpenOptionKey)
            }
        }
    }
    

}

// MARK: - Notification Names

extension Notification.Name {
    static let settingsDidChange = Notification.Name("settingsDidChange")
}



// MARK: - ModelContainer Shared Instance

import SwiftData

extension ModelContainer {
    /// Shared model container for the app
    /// This provides a centralized container for retry operations
    static var shared: ModelContainer = {
        do {
            let schema = Schema([
                Screenshot.self,
                Annotation.self
            ])
            
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            
            let container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
            
            print("[DATABASE] ✅ Shared ModelContainer initialized")
            return container
            
        } catch {
            fatalError("[DATABASE] ❌ Failed to create ModelContainer: \(error)")
        }
    }()
}
