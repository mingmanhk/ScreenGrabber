//
//  ScrollingCaptureEngine.swift
//  ScreenGrabber
//
//  Complete rebuild of scrolling capture feature based on specification.
//  This replaces all previous scrolling capture implementations.
//

import AppKit
import ApplicationServices
import Vision
import Combine
import ScreenCaptureKit

/// LEGACY — not wired to the production capture flow.
/// The active scrolling engine is `WindowBasedScrollingEngine`, which is called by
/// `ScreenCaptureManager.captureScrolling()`. This class predates that implementation
/// and is retained for reference only.
@MainActor
final class ScrollingCaptureEngine: ObservableObject {
    
    // MARK: - Published State
    
    @Published var isActive: Bool = false
    @Published var isCapturing: Bool = false
    @Published var progress: CaptureProgress?
    @Published var error: CaptureError?
    
    // MARK: - Types
    
    struct CaptureProgress: Equatable {
        var currentSlice: Int
        var totalSlices: Int?
        var statusMessage: String
    }
    
    enum CaptureError: LocalizedError {
        case noScrollableRegion
        case accessibilityDenied
        case captureFailure
        case stitchingFailure
        case cancelled
        
        var errorDescription: String? {
            switch self {
            case .noScrollableRegion:
                return "No scrollable region detected"
            case .accessibilityDenied:
                return "Accessibility permission required for scrolling"
            case .captureFailure:
                return "Failed to capture screen content"
            case .stitchingFailure:
                return "Failed to stitch captured images"
            case .cancelled:
                return "Capture was cancelled by user"
            }
        }
    }
    
    struct ScrollableRegion {
        let windowNumber: Int
        let frame: CGRect
        let scrollDirection: ScrollDirection
        let axElement: AXUIElement?
    }
    
    enum ScrollDirection {
        case vertical
        case horizontal
        case both
        
        var hasVertical: Bool {
            self == .vertical || self == .both
        }
        
        var hasHorizontal: Bool {
            self == .horizontal || self == .both
        }
    }
    
    // MARK: - Configuration
    
    struct Configuration {
        var scrollStepPercentage: CGFloat = 0.75 // Scroll 75% of viewport height/width
        var sliceOverlapPercentage: CGFloat = 0.25 // 25% overlap for stitching
        var scrollDelaySeconds: TimeInterval = 0.3
        var maxSlices: Int = 100
        var captureScale: CGFloat = 2.0 // Retina scale
    }
    
    private var config = Configuration()
    
    // MARK: - State
    
    private var capturedSlices: [NSImage] = []
    private var shouldCancel = false
    private var detectedRegion: ScrollableRegion?
    
    // MARK: - Public API
    
    /// Start the scrolling capture workflow
    func startCapture() async throws -> NSImage {
        isActive = true
        isCapturing = false
        shouldCancel = false
        capturedSlices = []
        error = nil
        
        // Step 1: Check accessibility permission
        guard checkAccessibilityPermission() else {
            error = .accessibilityDenied
            throw CaptureError.accessibilityDenied
        }
        
        // Step 2: Wait for user to hover and select a scrollable region
        // This will be handled by the overlay UI
        // For now, return a placeholder
        
        // This method will be called after user selects a region
        let finalImage = NSImage(size: NSSize(width: 800, height: 600))
        
        isActive = false
        return finalImage
    }
    
    /// Cancel active capture
    func cancel() {
        shouldCancel = true
        isCapturing = false
        isActive = false
        error = .cancelled
    }
    
    /// Detect scrollable region at mouse position
    func detectScrollableRegion(at point: NSPoint) -> ScrollableRegion? {
        // Get window under cursor
        guard let windowInfo = getWindowInfo(at: point) else {
            return nil
        }
        
        // Check if window is scrollable
        let scrollDirection = detectScrollDirection(for: windowInfo)
        
        guard scrollDirection != nil else {
            return nil
        }
        
        return ScrollableRegion(
            windowNumber: windowInfo.windowNumber,
            frame: windowInfo.frame,
            scrollDirection: scrollDirection ?? .vertical,
            axElement: windowInfo.axElement
        )
    }
    
    /// Execute scrolling capture on a selected region
    func captureRegion(_ region: ScrollableRegion, direction: ScrollDirection) async throws -> NSImage {
        isCapturing = true
        capturedSlices = []
        shouldCancel = false
        
        progress = CaptureProgress(
            currentSlice: 0,
            totalSlices: nil,
            statusMessage: "Starting capture..."
        )
        
        // Execute based on direction
        switch direction {
        case .vertical:
            try await captureVerticalScroll(region: region)
        case .horizontal:
            try await captureHorizontalScroll(region: region)
        case .both:
            // For now, default to vertical. Can be enhanced later
            try await captureVerticalScroll(region: region)
        }
        
        // Stitch all slices
        progress?.statusMessage = "Stitching images..."
        guard let stitchedImage = stitchImages(capturedSlices, direction: direction) else {
            throw CaptureError.stitchingFailure
        }
        
        isCapturing = false
        isActive = false
        
        return stitchedImage
    }
    
    // MARK: - Private Methods - Permission
    
    private func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
    
    // MARK: - Private Methods - Detection
    
    private struct WindowInfo {
        let windowNumber: Int
        let frame: CGRect
        let ownerPID: pid_t
        let axElement: AXUIElement?
    }
    
    private func getWindowInfo(at point: NSPoint) -> WindowInfo? {
        let screenPoint = CGPoint(x: point.x, y: point.y)
        
        // Get window list
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        
        // Find window at point
        for windowDict in windowList {
            guard let bounds = windowDict[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = bounds["X"],
                  let y = bounds["Y"],
                  let width = bounds["Width"],
                  let height = bounds["Height"],
                  let windowNumber = windowDict[kCGWindowNumber as String] as? Int,
                  let ownerPID = windowDict[kCGWindowOwnerPID as String] as? pid_t else {
                continue
            }
            
            let windowFrame = CGRect(x: x, y: y, width: width, height: height)
            
            if windowFrame.contains(screenPoint) {
                let axApp = AXUIElementCreateApplication(ownerPID)
                
                return WindowInfo(
                    windowNumber: windowNumber,
                    frame: windowFrame,
                    ownerPID: ownerPID,
                    axElement: axApp
                )
            }
        }
        
        return nil
    }
    
    private func detectScrollDirection(for windowInfo: WindowInfo) -> ScrollDirection? {
        // Try accessibility API first
        if let direction = detectScrollDirectionViaAX(windowInfo.axElement) {
            return direction
        }
        
        // Fallback: assume vertical scroll for most windows
        // This is a heuristic - can be improved with more detection logic
        return .vertical
    }
    
    private func detectScrollDirectionViaAX(_ axElement: AXUIElement?) -> ScrollDirection? {
        guard let element = axElement else {
            return nil
        }
        
        // Look for scroll areas in the window
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value)
        
        if result == .success, let role = value as? String, role == "AXScrollArea" {
            // Found scroll area - for now assume vertical
            return .vertical
        }
        
        return nil
    }
    
    // MARK: - Private Methods - Capture
    
    private func captureVerticalScroll(region: ScrollableRegion) async throws {
        let viewportHeight = region.frame.height
        let scrollStep = viewportHeight * config.scrollStepPercentage
        
        var sliceCount = 0
        var noChangeCount = 0
        let maxNoChange = 3 // Stop if content doesn't change 3 times
        
        while sliceCount < config.maxSlices && !shouldCancel {
            // Capture current viewport
            guard let slice = await captureRect(region.frame) else {
                throw CaptureError.captureFailure
            }
            
            // Check if this slice is different from previous
            if let previousSlice = capturedSlices.last,
               imagesAreIdentical(slice, previousSlice) {
                noChangeCount += 1
                if noChangeCount >= maxNoChange {
                    print("[SCROLL] No changes detected, stopping capture")
                    break
                }
            } else {
                noChangeCount = 0
            }
            
            capturedSlices.append(slice)
            sliceCount += 1
            
            progress = CaptureProgress(
                currentSlice: sliceCount,
                totalSlices: nil,
                statusMessage: "Capturing slice \(sliceCount)..."
            )
            
            // Scroll down
            let scrollSuccess = await scrollWindow(
                region: region,
                direction: .vertical,
                amount: scrollStep
            )
            
            if !scrollSuccess {
                print("[SCROLL] Scroll failed, assuming end of content")
                break
            }
            
            // Wait for content to settle
            try await Task.sleep(nanoseconds: UInt64(config.scrollDelaySeconds * 1_000_000_000))
        }
        
        if shouldCancel {
            throw CaptureError.cancelled
        }
    }
    
    private func captureHorizontalScroll(region: ScrollableRegion) async throws {
        let viewportWidth = region.frame.width
        let scrollStep = viewportWidth * config.scrollStepPercentage
        
        var sliceCount = 0
        var noChangeCount = 0
        let maxNoChange = 3
        
        while sliceCount < config.maxSlices && !shouldCancel {
            guard let slice = await captureRect(region.frame) else {
                throw CaptureError.captureFailure
            }
            
            if let previousSlice = capturedSlices.last,
               imagesAreIdentical(slice, previousSlice) {
                noChangeCount += 1
                if noChangeCount >= maxNoChange {
                    break
                }
            } else {
                noChangeCount = 0
            }
            
            capturedSlices.append(slice)
            sliceCount += 1
            
            progress = CaptureProgress(
                currentSlice: sliceCount,
                totalSlices: nil,
                statusMessage: "Capturing slice \(sliceCount)..."
            )
            
            let scrollSuccess = await scrollWindow(
                region: region,
                direction: .horizontal,
                amount: scrollStep
            )
            
            if !scrollSuccess {
                break
            }
            
            try await Task.sleep(nanoseconds: UInt64(config.scrollDelaySeconds * 1_000_000_000))
        }
        
        if shouldCancel {
            throw CaptureError.cancelled
        }
    }
    
    private func captureRect(_ rect: CGRect) async -> NSImage? {
        // Use ScreenCaptureKit (available from macOS 12.3+)
        guard #available(macOS 12.3, *) else {
            print("ScreenCaptureKit requires macOS 12.3 or later")
            return nil
        }
        
        do {
            let content = try await SCShareableContent.current
            guard let display = content.displays.first else { return nil }
            
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.sourceRect = rect
            config.width = Int(rect.width * 2) // Retina scale
            config.height = Int(rect.height * 2)
            config.showsCursor = false
            
            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            return NSImage(cgImage: cgImage, size: rect.size)
        } catch {
            print("SCKit capture failed: \(error)")
            return nil
        }
    }
    
    private func scrollWindow(region: ScrollableRegion, direction: ScrollDirection, amount: CGFloat) async -> Bool {
        // Use CGEvent to simulate scroll wheel
        let scrollAmount = direction.hasVertical ? -Int32(amount / 10) : 0
        let horizontalAmount = direction.hasHorizontal ? -Int32(amount / 10) : 0
        
        // Create scroll event at window center
        let centerX = region.frame.midX
        let centerY = region.frame.midY
        
        guard let scrollEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: scrollAmount,
            wheel2: horizontalAmount,
            wheel3: 0
        ) else {
            return false
        }
        
        scrollEvent.location = CGPoint(x: centerX, y: centerY)
        scrollEvent.post(tap: .cghidEventTap)
        
        return true
    }
    
    private func imagesAreIdentical(_ image1: NSImage, _ image2: NSImage) -> Bool {
        // Quick size check
        guard image1.size == image2.size else {
            return false
        }
        
        // Compare image data
        guard let data1 = image1.tiffRepresentation,
              let data2 = image2.tiffRepresentation else {
            return false
        }
        
        return data1 == data2
    }
    
    // MARK: - Private Methods - Stitching
    
    private func stitchImages(_ images: [NSImage], direction: ScrollDirection) -> NSImage? {
        guard !images.isEmpty else {
            return nil
        }
        
        if images.count == 1 {
            return images[0]
        }
        
        if direction.hasVertical {
            return stitchVertically(images)
        } else {
            return stitchHorizontally(images)
        }
    }
    
    private func stitchVertically(_ images: [NSImage]) -> NSImage? {
        guard let firstImage = images.first else {
            return nil
        }
        
        let width = firstImage.size.width
        let overlapHeight = firstImage.size.height * config.sliceOverlapPercentage
        
        // Calculate total height
        var totalHeight: CGFloat = firstImage.size.height
        for i in 1..<images.count {
            totalHeight += images[i].size.height - overlapHeight
        }
        
        // Create final image
        let finalSize = NSSize(width: width, height: totalHeight)
        let finalImage = NSImage(size: finalSize)
        
        finalImage.lockFocus()
        
        var currentY: CGFloat = 0
        
        for (index, image) in images.enumerated() {
            let sourceRect = NSRect(origin: .zero, size: image.size)
            var destRect = NSRect(
                x: 0,
                y: totalHeight - currentY - image.size.height,
                width: width,
                height: image.size.height
            )
            
            // Apply overlap offset for non-first images
            if index > 0 {
                destRect.origin.y += overlapHeight
            }
            
            image.draw(in: destRect, from: sourceRect, operation: .copy, fraction: 1.0)
            
            currentY += image.size.height - overlapHeight
        }
        
        finalImage.unlockFocus()
        
        return finalImage
    }
    
    private func stitchHorizontally(_ images: [NSImage]) -> NSImage? {
        guard let firstImage = images.first else {
            return nil
        }
        
        let height = firstImage.size.height
        let overlapWidth = firstImage.size.width * config.sliceOverlapPercentage
        
        var totalWidth: CGFloat = firstImage.size.width
        for i in 1..<images.count {
            totalWidth += images[i].size.width - overlapWidth
        }
        
        let finalSize = NSSize(width: totalWidth, height: height)
        let finalImage = NSImage(size: finalSize)
        
        finalImage.lockFocus()
        
        var currentX: CGFloat = 0
        
        for (index, image) in images.enumerated() {
            let sourceRect = NSRect(origin: .zero, size: image.size)
            var destRect = NSRect(
                x: currentX,
                y: 0,
                width: image.size.width,
                height: height
            )
            
            if index > 0 {
                destRect.origin.x -= overlapWidth
            }
            
            image.draw(in: destRect, from: sourceRect, operation: .copy, fraction: 1.0)
            
            currentX += image.size.width - overlapWidth
        }
        
        finalImage.unlockFocus()
        
        return finalImage
    }
}
