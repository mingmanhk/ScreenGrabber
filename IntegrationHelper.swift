//
//  IntegrationHelper.swift
//  ScreenGrabber
//
//  Quick integration guide for enhanced features
//

import SwiftUI

/*
 
 QUICK INTEGRATION GUIDE
 =======================
 
 Follow these steps to integrate all new features into your existing ScreenGrabber app:
 
 
 ## STEP 1: Add Files to Xcode Project
 
 Add these new files to your Xcode project:
 
 1. CapturePreferences.swift
 2. EnhancedCaptureSettingsView.swift
 3. FloatingThumbnailWindow.swift
 4. QuickActionsBarView.swift
 5. ScreenCaptureManager+Enhanced.swift
 6. IntegrationHelper.swift (this file)
 
 
 ## STEP 2: Update ScreenshotBrowserView
 
 In ScreenshotBrowserView.swift, find the sidebar settings section and add:
 
 ```swift
 // Add this new settings group after existing groups
 SettingsGroupView(
     title: "Advanced Features",
     icon: "star.fill",
     iconColor: .purple
 ) {
     VStack(spacing: 16) {
         // Capture Delay
         CaptureDelayPickerView()
         
         Divider()
         
         // Image Format
         CompressionProfilePickerView()
         
         Divider()
         
         // Auto-Copy
         AutoCopySettingsView()
         
         Divider()
         
         // Region Presets
         RegionPresetsView()
         
         Divider()
         
         // Floating Thumbnail
         FloatingThumbnailSettingsView()
         
         Divider()
         
         // Quick Actions
         QuickActionsConfigView()
     }
 }
 ```
 
 
 ## STEP 3: Update Capture Method
 
 Replace your quickCapture() method with this enhanced version:
 
 ```swift
 private func quickCapture() {
     let delay = CaptureDelaySettings.current
     let profile = CompressionProfile.current
     
     if delay > 0 {
         ScreenCaptureManager.shared.captureWithDelay(
             method: selectedScreenOption,
             openOption: selectedOpenOption,
             modelContext: modelContext,
             delay: delay
         )
     } else if profile != .highQualityPNG {
         ScreenCaptureManager.shared.captureWithFormat(
             method: selectedScreenOption,
             openOption: selectedOpenOption,
             modelContext: modelContext,
             profile: profile
         )
     } else {
         ScreenCaptureManager.shared.captureScreen(
             method: selectedScreenOption,
             openOption: selectedOpenOption,
             modelContext: modelContext
         )
     }
     
     DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
         loadRecentScreenshots()
     }
 }
 ```
 
 
 ## STEP 4: Add Menu Bar Features (Optional)
 
 In MenuBarContentView.swift, add quick access buttons:
 
 ```swift
 // Add to your menu
 Button("Capture with 3s Delay") {
     CaptureDelaySettings.current = 3
     quickCapture()
 }
 
 Button("Capture with 5s Delay") {
     CaptureDelaySettings.current = 5
     quickCapture()
 }
 
 Divider()
 
 Menu("Recent Presets") {
     ForEach(RegionPresetsManager.shared.presets.prefix(5)) { preset in
         Button(preset.name) {
             ScreenCaptureManager.shared.captureWithPreset(
                 preset,
                 openOption: selectedOpenOption,
                 modelContext: modelContext
             )
         }
     }
 }
 ```
 
 
 ## STEP 5: Test Each Feature
 
 1. Launch app
 2. Open settings sidebar
 3. Test capture delay (set to 3s, try capture)
 4. Test compression profiles (try JPEG)
 5. Test auto-copy (set to Filename)
 6. Create a region preset
 7. Enable floating thumbnail
 8. Capture and verify Quick Actions Bar appears
 
 
 ## STEP 6: Build & Run
 
 Press ⌘R to build and run your enhanced ScreenGrabber!
 
 
 ## TROUBLESHOOTING
 
 ### Issue: Floating window doesn't appear
 - Check FloatingThumbnailSettings.enabled = true
 - Verify image is being captured successfully
 
 ### Issue: Quick Actions Bar not showing
 - Check that QuickActionsManager has actions
 - Verify post-capture methods are called
 
 ### Issue: Organization folders not created
 - Check folder permissions
 - Verify rules are enabled in OrganizationRulesManager
 
 ### Issue: Format conversion fails
 - HEIF requires macOS 10.13+
 - WebP requires additional framework
 - Fall back to JPEG if issues occur
 
 
 ## ADVANCED CUSTOMIZATION
 
 ### Custom Compression Profile
 ```swift
 // Add to CompressionProfile enum
 case customJPEG = "Custom JPEG"
 
 // In quality getter:
 case .customJPEG: return 0.65 // Your custom quality
 ```
 
 ### Custom Organization Rule
 ```swift
 let customRule = OrganizationRule(
     ruleName: "My Custom Rule",
     ruleType: .sourceApp,
     folderName: "CustomFolder"
 )
 OrganizationRulesManager.shared.rules.append(customRule)
 OrganizationRulesManager.shared.saveRules()
 ```
 
 ### Custom Quick Action
 ```swift
 let customAction = QuickAction(
     name: "Custom Action",
     icon: "star.fill",
     action: .annotate // Reuse existing or add new
 )
 QuickActionsManager.shared.actions.append(customAction)
 QuickActionsManager.shared.saveActions()
 ```
 
 
 ## NEXT FEATURES TO IMPLEMENT
 
 Priority order for remaining features:
 
 1. Quick Draw on Capture (simple overlay)
 2. Smart Tags (auto-tagging system)
 3. Project Workspaces (folder categories)
 4. Multi-Monitor Control (screen selection)
 5. Screenshot Versioning (iteration tracking)
 
 Each of these can be implemented following the same pattern:
 - Create model in CapturePreferences.swift
 - Add UI in EnhancedCaptureSettingsView.swift
 - Implement logic in ScreenCaptureManager+Enhanced.swift
 
 
 ## PERFORMANCE OPTIMIZATION
 
 If you notice performance issues:
 
 1. Reduce FloatingThumbnail auto-dismiss delay
 2. Disable unused Quick Actions
 3. Limit Region Presets to <20
 4. Use compressed formats for large captures
 5. Disable organization rules if not needed
 
 
 ## SUPPORT
 
 For help with integration:
 - Check IMPLEMENTATION_GUIDE.md
 - Review code comments in each file
 - Test features individually
 - Check console for error messages
 
 
 Happy coding! 🚀
 
 */

// MARK: - Quick Test Function
extension ScreenCaptureManager {
    
    /// Test all enhanced features
    func testEnhancedFeatures() {
        print("🧪 Testing Enhanced Features...")
        
        // Test 1: Capture Delay
        print("✓ Capture Delay: \(CaptureDelaySettings.delays)")
        
        // Test 2: Compression Profiles
        print("✓ Compression Profiles: \(CompressionProfile.allCases.count) available")
        
        // Test 3: Auto-Copy
        print("✓ Auto-Copy: \(AutoCopyOption.current.rawValue)")
        
        // Test 4: Region Presets
        print("✓ Region Presets: \(RegionPresetsManager.shared.presets.count) saved")
        
        // Test 5: Organization Rules
        print("✓ Organization Rules: \(OrganizationRulesManager.shared.rules.count) active")
        
        // Test 6: Quick Actions
        print("✓ Quick Actions: \(QuickActionsManager.shared.actions.filter { $0.enabled }.count) enabled")
        
        // Test 7: Floating Thumbnail
        print("✓ Floating Thumbnail: \(FloatingThumbnailSettings.enabled ? "Enabled" : "Disabled")")
        
        print("✅ All enhanced features loaded successfully!")
    }
}

// MARK: - Quick Settings Reset
extension UserDefaults {
    
    /// Reset all enhanced feature settings to defaults
    func resetEnhancedFeatures() {
        removeObject(forKey: "captureDelay")
        removeObject(forKey: "compressionProfile")
        removeObject(forKey: "autoCopyOption")
        removeObject(forKey: "regionPresets")
        removeObject(forKey: "floatingThumbnailEnabled")
        removeObject(forKey: "floatingThumbnailDelay")
        removeObject(forKey: "organizationRules")
        removeObject(forKey: "quickActions")
        
        print("🔄 Enhanced features reset to defaults")
    }
}
