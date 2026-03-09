//
//  PermissionsDebugHelper.swift
//  ScreenGrabber
//
//  Debug utilities for testing permissions
//  Remove or disable in production builds
//

import Foundation
import AppKit
#if canImport(AVFoundation)
import AVFoundation
#endif

#if DEBUG

/// Debug helper for testing and diagnosing permission issues
struct PermissionsDebugHelper {
    
    /// Print comprehensive permission status report
    static func printPermissionStatus() {
        print("\n" + String(repeating: "=", count: 60))
        print("📊 SCREENGRABBER PERMISSION STATUS")
        print(String(repeating: "=", count: 60))
        
        // Screen Recording
        let hasScreenRecording = CGPreflightScreenCaptureAccess()
        print("📹 Screen Recording: \(hasScreenRecording ? "✅ Granted" : "❌ Not Granted")")
        
        // Accessibility
        let hasAccessibility = AXIsProcessTrusted()
        print("♿️ Accessibility: \(hasAccessibility ? "✅ Granted" : "❌ Not Granted")")
        
        // Full Disk Access
        let hasFDA = CapturePermissionsManager.hasFullDiskAccess()
        print("💾 Full Disk Access: \(hasFDA ? "✅ Granted" : "❌ Not Granted")")
        
        // Microphone (if needed)
        #if canImport(AVFoundation)
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let hasMic = micStatus == .authorized
        print("🎤 Microphone: \(hasMic ? "✅ Granted" : "❌ Not Granted (\(micStatus.rawValue))")")
        #endif
        
        print(String(repeating: "=", count: 60))
        
        // Test protected folders
        print("\n📁 FOLDER ACCESS TEST")
        print(String(repeating: "-", count: 60))
        
        testFolderAccess(name: "Pictures", path: "Pictures")
        testFolderAccess(name: "Desktop", path: "Desktop")
        testFolderAccess(name: "Documents", path: "Documents")
        testFolderAccess(name: "Downloads", path: "Downloads")
        testFolderAccess(name: "Library/Safari", path: "Library/Safari")
        
        print(String(repeating: "=", count: 60) + "\n")
    }
    
    private static func testFolderAccess(name: String, path: String) {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(path)
        
        let exists = FileManager.default.fileExists(atPath: url.path)
        let readable = FileManager.default.isReadableFile(atPath: url.path)
        let writable = FileManager.default.isWritableFile(atPath: url.path)
        
        var status = ""
        if readable && writable {
            status = "✅ Full Access"
        } else if readable {
            status = "📖 Read Only"
        } else if exists {
            status = "🔒 No Access"
        } else {
            status = "❌ Not Found"
        }
        
        print("  \(name.padding(toLength: 20, withPad: " ", startingAt: 0)) \(status)")
        
        // Try to list contents
        if readable {
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: url.path) {
                print("    └─ \(contents.count) items")
            }
        }
    }
    
    /// Test specific folder for write access
    static func testWriteAccess(to folder: URL) {
        print("\n🔬 TESTING WRITE ACCESS: \(folder.path)")
        print(String(repeating: "-", count: 60))
        
        let testFile = folder.appendingPathComponent(".screengrabber_test_\(UUID().uuidString).txt")
        
        do {
            // Try to write
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            print("✅ Write successful: \(testFile.lastPathComponent)")
            
            // Try to read
            let content = try String(contentsOf: testFile, encoding: .utf8)
            print("✅ Read successful: \"\(content)\"")
            
            // Try to delete
            try FileManager.default.removeItem(at: testFile)
            print("✅ Delete successful")
            
            print("✅ FULL ACCESS CONFIRMED")
            
        } catch {
            print("❌ ERROR: \(error.localizedDescription)")
            
            if let nsError = error as NSError? {
                print("   Domain: \(nsError.domain)")
                print("   Code: \(nsError.code)")
                
                switch nsError.code {
                case NSFileWriteNoPermissionError:
                    print("   ⚠️ No write permission - may need Full Disk Access")
                case NSFileWriteVolumeReadOnlyError:
                    print("   ⚠️ Volume is read-only")
                case NSFileWriteOutOfSpaceError:
                    print("   ⚠️ Out of disk space")
                default:
                    print("   ⚠️ Unknown error")
                }
            }
        }
        
        print(String(repeating: "-", count: 60) + "\n")
    }
    
    /// Check if specific path requires Full Disk Access
    static func checkPathRequirements(path: String) {
        let url = URL(fileURLWithPath: path)
        let needsFDA = CapturePermissionsManager.requiresFullDiskAccess(for: url)
        
        print("\n📋 PATH ANALYSIS")
        print(String(repeating: "-", count: 60))
        print("Path: \(path)")
        print("Requires FDA: \(needsFDA ? "⚠️ YES" : "✅ NO")")
        
        if needsFDA {
            let hasFDA = CapturePermissionsManager.hasFullDiskAccess()
            print("FDA Status: \(hasFDA ? "✅ Granted" : "❌ Not Granted")")
            
            if !hasFDA {
                print("\n⚠️ ACTION REQUIRED:")
                print("  1. Open System Settings > Privacy & Security > Full Disk Access")
                print("  2. Add ScreenGrabber and toggle it ON")
                print("  3. Quit and restart ScreenGrabber")
            }
        }
        
        print(String(repeating: "-", count: 60) + "\n")
    }
    
    /// Open System Settings to specific permission
    static func openPermissionSettings(_ type: ScreenGrabberTypes.PermissionType) {
        print("🔗 Opening System Settings for: \(type.displayName)")
        CapturePermissionsManager.openSystemSettings(for: type)
    }
    
    /// Reset UserDefaults (for testing onboarding)
    static func resetOnboarding() {
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            print("🔄 Onboarding reset - restart app to see onboarding again")
        }
    }
    
    /// Test folder creation at various locations
    static func testFolderCreation() {
        print("\n🧪 FOLDER CREATION TEST")
        print(String(repeating: "=", count: 60))
        
        let testLocations = [
            ("Pictures", "~/Pictures/Screen Grabber Test"),
            ("Desktop", "~/Desktop/Screen Grabber Test"),
            ("Documents", "~/Documents/Screen Grabber Test"),
            ("Downloads", "~/Downloads/Screen Grabber Test"),
        ]
        
        for (name, pathString) in testLocations {
            let path = NSString(string: pathString).expandingTildeInPath
            let url = URL(fileURLWithPath: path)
            
            print("\nTesting: \(name)")
            print("  Path: \(path)")
            
            Task {
                let result = await CapturePermissionsManager.shared
                    .ensureCaptureFolderExists(at: url)
                
                await MainActor.run {
                    switch result {
                    case .success(let createdURL):
                        print("  ✅ Success: \(createdURL.path)")
                        
                        // Clean up test folder
                        try? FileManager.default.removeItem(at: createdURL)
                        print("  🧹 Cleaned up test folder")
                        
                    case .failure(let error):
                        print("  ❌ Failed: \(error.localizedDescription)")
                        
                        if case .permissionDenied(let type) = error {
                            print("  ⚠️ Permission required: \(type.displayName)")
                        }
                    }
                }
            }
        }
        
        print(String(repeating: "=", count: 60) + "\n")
    }
    
    /// Check app signature and entitlements
    static func checkAppSignature() {
        guard let bundlePath = Bundle.main.bundlePath as String? else {
            print("❌ Could not get bundle path")
            return
        }
        
        print("\n🔐 CODE SIGNATURE VERIFICATION")
        print(String(repeating: "=", count: 60))
        print("Bundle: \(bundlePath)")
        
        // Check code signature
        let task = Process()
        task.launchPath = "/usr/bin/codesign"
        task.arguments = ["-dvvv", bundlePath]
        
        let pipe = Pipe()
        task.standardError = pipe
        task.standardOutput = pipe
        
        task.launch()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            print(output)
        }
        
        print(String(repeating: "=", count: 60) + "\n")
    }
    
    /// Generate full diagnostic report
    static func generateDiagnosticReport() {
        print("\n")
        print(String(repeating: "🔍", count: 30))
        print("SCREENGRABBER DIAGNOSTIC REPORT")
        print(String(repeating: "🔍", count: 30))
        print("\nGenerated: \(Date())")
        
        // App info
        print("\n📱 APP INFORMATION")
        print(String(repeating: "-", count: 60))
        print("Bundle ID: \(Bundle.main.bundleIdentifier ?? "Unknown")")
        print("Version: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")")
        print("Build: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown")")
        
        // System info
        print("\n💻 SYSTEM INFORMATION")
        print(String(repeating: "-", count: 60))
        let os = ProcessInfo.processInfo.operatingSystemVersion
        print("macOS: \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)")
        print("User: \(NSUserName())")
        print("Home: \(NSHomeDirectory())")
        
        // Permissions
        printPermissionStatus()
        
        // Save location
        print("\n💾 SAVE LOCATION")
        print(String(repeating: "-", count: 60))
        Task { @MainActor in
            let saveURL = SettingsModel.shared.effectiveSaveURL
            print("Current: \(saveURL.path)")
            let needsFDA = CapturePermissionsManager.requiresFullDiskAccess(for: saveURL)
            print("Requires FDA: \(needsFDA ? "⚠️ YES" : "✅ NO")")
        }
        
        print("\n" + String(repeating: "🔍", count: 30))
        print("END OF DIAGNOSTIC REPORT")
        print(String(repeating: "🔍", count: 30) + "\n")
    }
}

// MARK: - SwiftUI Integration

#if canImport(SwiftUI)
import SwiftUI

/// Debug view for testing permissions
struct PermissionsDebugView: View {
    @State private var fdaStatus = CapturePermissionsManager.hasFullDiskAccess()
    @State private var screenRecordingStatus = CGPreflightScreenCaptureAccess()
    @State private var accessibilityStatus = AXIsProcessTrusted()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Permissions Debug")
                .font(.title)
                .fontWeight(.bold)
            
            // Status
            GroupBox("Current Status") {
                VStack(alignment: .leading, spacing: 8) {
                    StatusRow(title: "Screen Recording", granted: screenRecordingStatus)
                    StatusRow(title: "Accessibility", granted: accessibilityStatus)
                    StatusRow(title: "Full Disk Access", granted: fdaStatus)
                }
                .padding()
            }
            
            // Actions
            GroupBox("Actions") {
                VStack(spacing: 12) {
                    Button("Print Status Report") {
                        PermissionsDebugHelper.printPermissionStatus()
                    }
                    
                    Button("Test Desktop Access") {
                        let desktop = FileManager.default.homeDirectoryForCurrentUser
                            .appendingPathComponent("Desktop/Screen Grabber Test")
                        PermissionsDebugHelper.testWriteAccess(to: desktop)
                    }
                    
                    Button("Generate Full Report") {
                        PermissionsDebugHelper.generateDiagnosticReport()
                    }
                    
                    Button("Open FDA Settings") {
                        PermissionsDebugHelper.openPermissionSettings(.fullDiskAccess)
                    }
                    
                    Button("Reset Onboarding") {
                        PermissionsDebugHelper.resetOnboarding()
                    }
                    
                    Button("Refresh Status") {
                        refreshStatus()
                    }
                }
                .padding()
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 400, height: 500)
    }
    
    private func refreshStatus() {
        fdaStatus = CapturePermissionsManager.hasFullDiskAccess()
        screenRecordingStatus = CGPreflightScreenCaptureAccess()
        accessibilityStatus = AXIsProcessTrusted()
    }
}

struct StatusRow: View {
    let title: String
    let granted: Bool
    
    var body: some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(granted ? .green : .red)
            Text(title)
            Spacer()
            Text(granted ? "Granted" : "Not Granted")
                .foregroundStyle(.secondary)
        }
    }
}

#endif

#endif

// MARK: - Usage Examples

/*
 
 // In your app startup or settings view:
 
 #if DEBUG
 
 // Print full diagnostic report
 PermissionsDebugHelper.generateDiagnosticReport()
 
 // Check specific folder
 PermissionsDebugHelper.checkPathRequirements(
     path: "/Users/yourname/Desktop/Screen Grabber"
 )
 
 // Test write access
 let desktop = FileManager.default.homeDirectoryForCurrentUser
     .appendingPathComponent("Desktop")
 PermissionsDebugHelper.testWriteAccess(to: desktop)
 
 // Open debug view (SwiftUI)
 Button("Debug Permissions") {
     let window = NSWindow(
         contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
         styleMask: [.titled, .closable, .miniaturizable],
         backing: .buffered,
         defer: false
     )
     window.contentView = NSHostingView(rootView: PermissionsDebugView())
     window.center()
     window.makeKeyAndOrderFront(nil)
 }
 
 #endif
 
 */
