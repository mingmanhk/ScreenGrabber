//
//  WindowBasedScrollingEngine.swift
//  ScreenGrabber
//
//  Engine for automatic scrolling capture within a selected window
//  Implements state machine: WindowSelection → Capture → Scroll → Stitch → Save
//

import Foundation
import AppKit
import ScreenCaptureKit
import SwiftData
import Combine
import UserNotifications

/// State machine for scrolling capture
enum ScrollingCaptureState {
    case idle
    case selectingWindow
    case capturingSegments(progress: CaptureProgress)
    case stitching
    case saving
    case complete(imageURL: URL)
    case failed(error: Error)
    
    struct CaptureProgress {
        var currentSegment: Int
        var totalSegments: Int?
        var status: String
    }
}

/// Errors that can occur during scrolling capture
enum ScrollingCaptureError: LocalizedError {
    case windowNotAccessible
    case noScrollableContent
    case captureTimedOut
    case stitchingFailed
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .windowNotAccessible:
            return "Unable to access the selected window"
        case .noScrollableContent:
            return "The window does not have scrollable content"
        case .captureTimedOut:
            return "Capture took too long and was cancelled"
        case .stitchingFailed:
            return "Failed to merge captured segments"
        case .saveFailed:
            return "Failed to save the final image"
        }
    }
}

/// CANONICAL scrolling capture engine — this is the one called by ScreenCaptureManager.captureScrolling().
///
/// Architecture note — three scrolling engines exist in this codebase:
/// - `WindowBasedScrollingEngine` (THIS FILE) — **active**, used in production capture flow
/// - `ScrollingCaptureEngine` — earlier rebuild, not wired to ScreenCaptureManager, kept for reference
/// - `OptimizedScrollingCaptureEngine` — Metal-accelerated experiment, not wired to production flow
///
/// When modifying scrolling capture behaviour, edit this file only.
@MainActor
class WindowBasedScrollingEngine: ObservableObject {
    
    @Published var state: ScrollingCaptureState = .idle
    
    private var capturedSegments: [NSImage] = []
    private var selectedWindow: SelectableWindow?
    
    // Configuration
    private let scrollAmount: CGFloat = 300 // Pixels to scroll per step
    private let overlapAmount: CGFloat = 50 // Overlap between segments
    private let maxSegments: Int = 50 // Safety limit
    private let scrollDelay: TimeInterval = 0.3 // Delay between scrolls
    
    // MARK: - Public Interface
    
    /// Starts the scrolling capture workflow with a pre-selected window
    func startScrollingCapture(window: SelectableWindow, modelContext: ModelContext?) async {
        CaptureLogger.log(.scrolling, "Starting window-based scrolling capture", level: .info)

        self.selectedWindow = window
        await self.beginAutomaticScrollCapture(modelContext: modelContext)
    }

    /// Starts the scrolling capture workflow, presenting a window picker to the user
    func startScrollingCapture(modelContext: ModelContext?) async {
        CaptureLogger.log(.scrolling, "Starting window-based scrolling capture (picker flow)", level: .info)
        await transitionToState(.selectingWindow)

        // Fetch available windows and pick the frontmost app window
        let windows = await fetchAvailableWindows()
        guard let firstWindow = windows.first else {
            await transitionToState(.failed(error: ScrollingCaptureError.windowNotAccessible))
            return
        }
        self.selectedWindow = firstWindow
        await self.beginAutomaticScrollCapture(modelContext: modelContext)
    }
    
    /// Cancels the current capture operation
    func cancelCapture() {
        CaptureLogger.log(.scrolling, "Capture cancelled by user", level: .warning)
        
        capturedSegments.removeAll()
        
        Task { @MainActor in
            await self.transitionToState(.idle)
        }
    }
    
    // MARK: - State Machine
    
    private func transitionToState(_ newState: ScrollingCaptureState) async {
        state = newState
        
        switch newState {
        case .idle:
            CaptureLogger.log(.scrolling, "Idle", level: .debug)
        case .selectingWindow:
            CaptureLogger.log(.scrolling, "Waiting for window selection", level: .info)
        case .capturingSegments(let progress):
            CaptureLogger.log(.scrolling, "Capturing segment \(progress.currentSegment)/\(progress.totalSegments ?? 0) - \(progress.status)", level: .debug)
        case .stitching:
            CaptureLogger.log(.scrolling, "Stitching segments together", level: .info)
        case .saving:
            CaptureLogger.log(.scrolling, "Saving final image", level: .info)
        case .complete(let url):
            CaptureLogger.log(.scrolling, "Complete - Saved to: \(url.path)", level: .success)
        case .failed(let error):
            CaptureLogger.log(.scrolling, "Failed: \(error.localizedDescription)", level: .error)
        }
    }
    
    // MARK: - Step 2: Automatic Scroll Capture
    
    private func beginAutomaticScrollCapture(modelContext: ModelContext?) async {
        guard let window = selectedWindow else {
            await transitionToState(.failed(error: ScrollingCaptureError.windowNotAccessible))
            return
        }
        
        CaptureLogger.log(.scrolling, "Selected window: \(window.displayTitle)", level: .info)
        CaptureLogger.log(.scrolling, "Window frame: \(window.frame)", level: .debug)
        
        capturedSegments.removeAll()
        
        // Start capture progress
        await transitionToState(.capturingSegments(
            progress: .init(currentSegment: 0, totalSegments: nil, status: "Initializing...")
        ))
        
        do {
            // Focus the window
            try await focusWindow(window)
            
            // Capture segments
            try await captureAllSegments(window: window)
            
            // Stitch segments
            await transitionToState(.stitching)
            let finalImage = try await stitchSegments()
            
            // Save using unified pipeline
            await transitionToState(.saving)
            guard let url = await saveCapture(image: finalImage, modelContext: modelContext) else {
                throw ScrollingCaptureError.saveFailed
            }
            
            await transitionToState(.complete(imageURL: url))
            
        } catch {
            await transitionToState(.failed(error: error))
            showErrorNotification(error)
        }
    }
    
    // MARK: - Window Focus & Accessibility
    
    private func focusWindow(_ window: SelectableWindow) async throws {
        // Bring the window's application to front
        if let app = NSRunningApplication
            .runningApplications(withBundleIdentifier: window.windowRef.owningApplication?.bundleIdentifier ?? "")
            .first {
            
            // Modern approach for macOS 14+
            if #available(macOS 14.0, *) {
                app.activate()
            } else {
                app.activate(options: .activateIgnoringOtherApps)
            }
            
            // Wait for activation
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            
            CaptureLogger.log(.scrolling, "Window focused: \(window.displayTitle)", level: .debug)
        }
    }
    
    // MARK: - Segment Capture Loop
    
    private func captureAllSegments(window: SelectableWindow) async throws {
        var segmentIndex = 0
        var hasMoreContent = true
        
        while hasMoreContent && segmentIndex < maxSegments {
            segmentIndex += 1
            
            await transitionToState(.capturingSegments(
                progress: .init(
                    currentSegment: segmentIndex,
                    totalSegments: nil,
                    status: "Capturing segment \(segmentIndex)..."
                )
            ))
            
            // Capture current visible area
            if let segment = try await captureWindowSegment(window: window) {
                capturedSegments.append(segment)
                CaptureLogger.log(.scrolling, "Captured segment \(segmentIndex) - Size: \(segment.size)", level: .debug)
            } else {
                throw ScrollingCaptureError.captureTimedOut
            }
            
            // Check if we can scroll further
            let currentScrollPosition = try await getScrollPosition(window: window)
            
            // Scroll down
            let scrolled = try await scrollWindow(window: window, amount: scrollAmount)
            
            if !scrolled {
                CaptureLogger.log(.scrolling, "Reached end of scrollable content", level: .info)
                hasMoreContent = false
                break
            }
            
            // Wait for scroll to complete
            try await Task.sleep(nanoseconds: UInt64(scrollDelay * 1_000_000_000))
            
            // Check if scroll position actually changed
            let newScrollPosition = try await getScrollPosition(window: window)
            if abs(newScrollPosition - currentScrollPosition) < 10 {
                CaptureLogger.log(.scrolling, "Scroll position unchanged, reached bottom", level: .info)
                hasMoreContent = false
            }
        }
        
        CaptureLogger.log(.scrolling, "Captured \(capturedSegments.count) segments total", level: .success)
        
        if capturedSegments.isEmpty {
            throw ScrollingCaptureError.noScrollableContent
        }
    }
    
    // MARK: - Window Capture
    
    private func captureWindowSegment(window: SelectableWindow) async throws -> NSImage? {
        // Use ScreenCaptureKit to capture the specific window
        let filter = SCContentFilter(desktopIndependentWindow: window.windowRef)
        let config = SCStreamConfiguration()
        
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.scalesToFit = false
        config.showsCursor = false
        
        do {
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
            
            return NSImage(cgImage: image, size: window.frame.size)
            
        } catch {
            CaptureLogger.log(.scrolling, "Capture error: \(error.localizedDescription)", level: .warning)
            return nil
        }
    }
    
    // MARK: - Scrolling via Accessibility & Events
    
    /// Scrolls the window using multiple methods
    private func scrollWindow(window: SelectableWindow, amount: CGFloat) async throws -> Bool {
        // Method 1: Try scroll wheel event
        let scrolled = try await scrollViaScrollWheel(window: window, amount: amount)
        
        if scrolled {
            return true
        }
        
        // Method 2: Try Page Down key
        return try await scrollViaKeyPress(window: window)
    }
    
    /// Scrolls using scroll wheel events
    private func scrollViaScrollWheel(window: SelectableWindow, amount: CGFloat) async throws -> Bool {
        let windowCenter = CGPoint(
            x: window.frame.midX,
            y: window.frame.midY
        )
        
        // Create scroll event
        let scrollEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 1,
            wheel1: Int32(-amount), // Negative = scroll down
            wheel2: 0,
            wheel3: 0
        )
        
        scrollEvent?.location = windowCenter
        scrollEvent?.post(tap: .cghidEventTap)
        
        return true
    }
    
    /// Scrolls using Page Down key press
    private func scrollViaKeyPress(window: SelectableWindow) async throws -> Bool {
        // Send Page Down key event
        let keyDownEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: 0x79, // Page Down key code
            keyDown: true
        )
        
        let keyUpEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: 0x79,
            keyDown: false
        )
        
        keyDownEvent?.post(tap: .cghidEventTap)
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05s
        keyUpEvent?.post(tap: .cghidEventTap)
        
        return true
    }
    
    /// Gets the current scroll position (best effort)
    private func getScrollPosition(window: SelectableWindow) async throws -> CGFloat {
        // This is a simplified version - in production, you'd use Accessibility API
        // to query the actual scroll position from the window's scroll view
        
        // For now, we'll estimate based on captured segments
        return CGFloat(capturedSegments.count) * scrollAmount
    }
    
    // MARK: - Step 3: Image Stitching
    
    private func stitchSegments() async throws -> NSImage {
        guard !capturedSegments.isEmpty else {
            throw ScrollingCaptureError.stitchingFailed
        }
        
        if capturedSegments.count == 1 {
            return capturedSegments[0]
        }
        
        CaptureLogger.log(.scrolling, "Stitching \(capturedSegments.count) segments", level: .info)
        
        // Calculate dimensions
        let width = capturedSegments[0].size.width
        let overlap = overlapAmount
        
        // Total height = first segment + (remaining segments - overlap each)
        var totalHeight: CGFloat = capturedSegments[0].size.height
        for i in 1..<capturedSegments.count {
            totalHeight += capturedSegments[i].size.height - overlap
        }
        
        CaptureLogger.log(.scrolling, "Final size: \(Int(width)) x \(Int(totalHeight))", level: .debug)
        
        // Create final image
        let finalImage = NSImage(size: NSSize(width: width, height: totalHeight))
        
        finalImage.lockFocus()
        
        var currentY: CGFloat = 0
        
        for (index, segment) in capturedSegments.enumerated() {
            let segmentHeight = segment.size.height
            
            // Skip overlapping portion for non-first segments
            let sourceY: CGFloat = index == 0 ? 0 : overlap
            let sourceHeight: CGFloat = index == 0 ? segmentHeight : (segmentHeight - overlap)
            
            let sourceRect = NSRect(
                x: 0,
                y: sourceY,
                width: width,
                height: sourceHeight
            )
            
            // Draw only non-overlapping content
            let destRect = NSRect(
                x: 0,
                y: totalHeight - currentY - sourceHeight,
                width: width,
                height: sourceHeight
            )
            
            segment.draw(
                in: destRect,
                from: sourceRect,
                operation: .copy,
                fraction: 1.0
            )
            
            currentY += sourceHeight
        }
        
        finalImage.unlockFocus()
        
        CaptureLogger.log(.scrolling, "Stitching complete", level: .success)
        
        return finalImage
    }
    
    // MARK: - Step 4: Save via Unified Pipeline
    
    private func saveCapture(image: NSImage, modelContext: ModelContext?) async -> URL? {
        let metadata = UnifiedCaptureManager.CaptureMetadata(
            captureType: .scrolling,
            timestamp: Date(),
            image: image
        )
        
        return await UnifiedCaptureManager.shared.saveCapture(
            metadata,
            to: modelContext,
            copyToClipboard: false
        )
    }
    
    // MARK: - Notifications
    
    /// Fetches available on-screen windows via ScreenCaptureKit
    private func fetchAvailableWindows() async -> [SelectableWindow] {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return content.windows.compactMap { scWindow -> SelectableWindow? in
                guard let app = scWindow.owningApplication,
                      scWindow.frame.width > 100,
                      scWindow.frame.height > 100 else { return nil }
                return SelectableWindow(
                    id: scWindow.windowID,
                    frame: scWindow.frame,
                    title: scWindow.title ?? "",
                    ownerName: app.applicationName,
                    layer: Int(scWindow.windowLayer),
                    windowRef: scWindow
                )
            }
        } catch {
            CaptureLogger.log(.scrolling, "Failed to fetch windows: \(error.localizedDescription)", level: .error)
            return []
        }
    }

    private func showErrorNotification(_ error: Error) {
        let content = UNMutableNotificationContent()
        content.title = "Scrolling Capture Failed"
        content.body = error.localizedDescription
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}

