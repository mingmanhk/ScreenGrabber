//
//  SCROLLING_CAPTURE_INTEGRATION.swift
//  ScreenGrabber
//
//  Quick reference for integrating window-based scrolling capture
//

/*
 
 ╔════════════════════════════════════════════════════════════════════╗
 ║   WINDOW-BASED SCROLLING CAPTURE - INTEGRATION CHECKLIST          ║
 ╚════════════════════════════════════════════════════════════════════╝
 
 ✅ FILES CREATED:
    1. UnifiedCaptureManager.swift
    2. WindowPickerOverlay.swift
    3. WindowBasedScrollingEngine.swift
    4. ScrollingCaptureProgressView.swift
 
 ✅ FILES MODIFIED:
    1. ScreenCaptureManager.swift - Added new engine integration
 
 ═══════════════════════════════════════════════════════════════════
 
 📋 XCODE PROJECT SETUP
 
 1. Add these files to your Xcode project:
    - Drag them into the project navigator
    - Ensure "Copy items if needed" is checked
    - Add to Screen Grabber target
 
 2. Import required frameworks in target settings:
    - ScreenCaptureKit (required for window detection)
    - SwiftData (required for history)
    - UserNotifications (required for alerts)
 
 3. Update Info.plist with required permission descriptions:
    
    <key>NSScreenCaptureUsageDescription</key>
    <string>Screen Grabber needs screen recording permission to capture windows and create scrolling screenshots.</string>
    
    <key>NSAccessibilityUsageDescription</key>
    <string>Screen Grabber needs accessibility permission to scroll windows automatically during scrolling capture.</string>
 
 ═══════════════════════════════════════════════════════════════════
 
 🔧 HOW TO USE IN YOUR CODE
 
 // Option 1: Via ScreenCaptureManager (Recommended)
 ScreenCaptureManager.shared.captureScreen(
     method: .scrollingCapture,
     openOption: .saved,
     modelContext: yourModelContext
 )
 
 // Option 2: Direct Engine Access
 Task { @MainActor in
     await ScreenCaptureManager.shared.windowBasedScrollingEngine
         .startScrollingCapture(modelContext: yourModelContext)
 }
 
 ═══════════════════════════════════════════════════════════════════
 
 🎯 USER WORKFLOW
 
 1. User selects "Scrolling" capture type
 2. Window picker overlay appears (semi-transparent)
 3. User hovers over available windows (blue highlight)
 4. User clicks desired window
 5. Progress window shows capture status
 6. App automatically:
    - Focuses the window
    - Captures visible content
    - Scrolls down
    - Repeats until bottom
    - Stitches segments together
    - Saves to ~/Pictures/ScreenGrabber/
    - Updates history database
 7. Completion dialog shows with options:
    - Show in Finder
    - Preview
 
 ═══════════════════════════════════════════════════════════════════
 
 🔐 REQUIRED PERMISSIONS
 
 Users must grant these permissions on first use:
 
 1. Screen Recording
    System Settings → Privacy & Security → Screen Recording
    ✅ Screen Grabber
 
 2. Accessibility (for auto-scrolling)
    System Settings → Privacy & Security → Accessibility
    ✅ Screen Grabber
 
 The app will prompt for these automatically.
 
 ═══════════════════════════════════════════════════════════════════
 
 📊 STATE MACHINE OVERVIEW
 
 WindowBasedScrollingEngine maintains state:
 
 .idle
   ↓
 .selectingWindow (shows window picker)
   ↓
 .capturingSegments(progress) (scrolls and captures)
   ↓
 .stitching (merges segments)
   ↓
 .saving (writes to disk + database)
   ↓
 .complete(imageURL) or .failed(error)
 
 Monitor state via @Published property:
 engine.state
 
 ═══════════════════════════════════════════════════════════════════
 
 🧪 TESTING CHECKLIST
 
 Test these scenarios:
 
 ✅ Safari - Long web page
 ✅ Notes - Long document
 ✅ Xcode - Code file with scrolling
 ✅ Finder - List view with many items
 ✅ Short content (no scrolling needed)
 ✅ Cancel during window selection
 ✅ Cancel during capture
 ✅ Window closes during capture (error handling)
 
 ═══════════════════════════════════════════════════════════════════
 
 🐛 DEBUGGING
 
 Enable console logging to see detailed capture flow:
 
 [SCROLL] 🚀 Starting window-based scrolling capture
 [PICKER] 🪟 Found 12 selectable windows
 [PICKER] ✅ Window selected: Safari - Apple
 [SCROLL] 📸 Captured segment 1 - Size: (1200.0, 800.0)
 [SCROLL] 📸 Captured segment 2 - Size: (1200.0, 800.0)
 [SCROLL] 🏁 Reached end of scrollable content
 [SCROLL] ✅ Captured 5 segments total
 [SCROLL] 🧩 Stitching 5 segments...
 [UNIFIED] 🚀 Starting save pipeline for Scrolling capture
 [UNIFIED] ✅ Screenshot saved to database: Scroll_2026-01-10_14-30-45.png
 [SCROLL] ✅ Complete - Saved to: ~/Pictures/ScreenGrabber/Scroll_2026-01-10_14-30-45.png
 
 ═══════════════════════════════════════════════════════════════════
 
 💡 CONFIGURATION OPTIONS
 
 In WindowBasedScrollingEngine.swift, you can adjust:
 
 private let scrollAmount: CGFloat = 300        // Pixels per scroll
 private let overlapAmount: CGFloat = 50        // Overlap between segments
 private let maxSegments: Int = 50              // Safety limit
 private let scrollDelay: TimeInterval = 0.3    // Delay between scrolls
 
 ═══════════════════════════════════════════════════════════════════
 
 🔄 INTEGRATION WITH EXISTING FEATURES
 
 ✅ UnifiedCaptureManager
    - Automatically saves to ~/Pictures/ScreenGrabber/
    - Generates thumbnails
    - Updates SwiftData database
    - Posts notifications for UI updates
 
 ✅ MenuBarContentView
    - Recent captures strip updates automatically
    - Shows scrolling captures with metadata
 
 ✅ Library View
    - Scrolling captures appear in history
    - Filterable by capture type
 
 ✅ Image Editor
    - Scrolling captures can be edited
    - Opens from history or recent captures
 
 ═══════════════════════════════════════════════════════════════════
 
 ⚠️  KNOWN LIMITATIONS
 
 1. Some apps may block programmatic scrolling
    - Workaround: Falls back to Page Down key
 
 2. Windows with complex scroll views (nested scrolling)
    - Captures outer scroll view only
 
 3. Maximum 50 segments per capture
    - Prevents infinite loops on buggy windows
 
 4. Requires macOS 12.3+ for ScreenCaptureKit
    - Earlier versions not supported
 
 ═══════════════════════════════════════════════════════════════════
 
 📚 DOCUMENTATION
 
 Full documentation in:
 - WINDOW_BASED_SCROLLING_GUIDE.md
 
 Related files:
 - UNIFIED_ARCHITECTURE.md
 - CAPTURE_FIXES_DOCUMENTATION.md
 
 ═══════════════════════════════════════════════════════════════════
 
 ✨ FEATURES IMPLEMENTED
 
 ✅ Window picker with hover highlights
 ✅ Automatic window focus
 ✅ Intelligent scrolling (multiple methods)
 ✅ Real-time progress tracking
 ✅ Seamless image stitching
 ✅ Unified save pipeline integration
 ✅ Error handling and recovery
 ✅ User cancellation support
 ✅ macOS design patterns
 ✅ Accessibility support
 
 ═══════════════════════════════════════════════════════════════════
 
 🚀 READY TO USE!
 
 Build and run your app, then:
 1. Select "Scrolling" as capture type
 2. Click on a window
 3. Watch the magic happen! ✨
 
 ═══════════════════════════════════════════════════════════════════
 
 */

// MARK: - Example Usage

#if DEBUG

import SwiftUI
import SwiftData

struct ScrollingCaptureExample {
    
    /// Example 1: Trigger from menu bar
    func triggerFromMenuBar(modelContext: ModelContext) {
        ScreenCaptureManager.shared.captureScreen(
            method: .scrollingCapture,
            openOption: .saveToFile,
            modelContext: modelContext
        )
    }
    
    /// Example 2: Trigger from global hotkey
    func setupGlobalHotkey() {
        _ = GlobalHotkeyManager.shared.registerHotkey("⌘⇧S") {
            let context = ModelContext(ScreenGrabberApp.sharedModelContainer)
            ScreenCaptureManager.shared.captureScreen(
                method: .scrollingCapture,
                openOption: .saveToFile,
                modelContext: context
            )
        }
    }
    
    /// Example 3: Direct engine access with state observation
    @MainActor
    func directEngineAccess(modelContext: ModelContext) async {
        // Create an instance of the engine
        let engine = WindowBasedScrollingEngine()
        
        // Observe state changes
        print("Current state: \(engine.state)")
        
        // Start capture
        // Option A: Let the engine present the window picker to select a window
        await engine.startScrollingCapture(modelContext: modelContext)
        
        // Option B: If you already have a SelectableWindow from your own picker,
        // you can pass it directly. Replace 'preselectedWindow' with your actual value.
        // Commented out to keep this example compiling without extra types in scope.
        // if let preselectedWindow: SelectableWindow = nil {
        //     await engine.startScrollingCapture(window: preselectedWindow, modelContext: modelContext)
        // } else {
        //     print("[SCROLL] No preselected window available; used picker flow instead.")
        // }
        
        // Handle completion
        switch engine.state {
        case .complete(let url):
            print("✅ Saved to: \(url.path)")
        case .failed(let error):
            print("❌ Error: \(error.localizedDescription)")
        default:
            break
        }
    }
    
    /// Example 4: Show progress UI
    func showProgressUI() -> some View {
        // Create an instance of the engine
        let engine = WindowBasedScrollingEngine()
        
        return ScrollingCaptureProgressView(
            engine: engine,
            onCancel: {
                engine.cancelCapture()
            }
        )
    }
}

#endif

