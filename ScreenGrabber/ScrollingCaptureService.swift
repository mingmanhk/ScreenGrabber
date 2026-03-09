//
//  ScrollingCaptureService.swift
//  ScreenGrabber
//
//  Handles automatic scrolling capture
//

import Foundation
import AppKit
import ApplicationServices
import ScreenCaptureKit

actor ScrollingCaptureService {
    static let shared = ScrollingCaptureService()
    
    private var isCancelled = false
    private var segments: [NSImage] = []
    private var state: CaptureState = .idle
    
    enum CaptureState {
        case idle
        case selectingWindow
        case capturing
        case stitching
        case complete
        case failed
    }
    
    enum CaptureError: LocalizedError {
        case userCancelled
        case windowSelectionFailed
        case captureFailure
        case stitchingFailure
        case noSegmentsCaptured
        case unknown(error: Error)
        
        var errorDescription: String? {
            switch self {
            case .userCancelled:
                return "Capture was cancelled by user"
            case .windowSelectionFailed:
                return "Failed to select window"
            case .captureFailure:
                return "Failed to capture window content"
            case .stitchingFailure:
                return "Failed to stitch captured segments"
            case .noSegmentsCaptured:
                return "No segments were captured"
            case .unknown(let error):
                return "An unexpected error occurred: \(error.localizedDescription)"
            }
        }
    }
    
    private init() {}
    
    func performScrollingCapture() async -> Result<NSImage, CaptureError> {
        isCancelled = false
        segments = []
        state = .selectingWindow
        
        // Get window selection from user
        guard let windowInfo = await selectWindow() else {
            return .failure(.userCancelled)
        }
        
        state = .capturing
        
        // Capture segments while scrolling
        let captureResult = await captureSegments(window: windowInfo)
        guard case .success(let images) = captureResult else {
            if case .failure(let error) = captureResult {
                return .failure(error)
            }
            return .failure(.captureFailure)
        }
        
        state = .stitching
        
        // Stitch segments together
        guard let stitchedImage = stitchImages(images) else {
            return .failure(.stitchingFailure)
        }
        
        state = .complete
        return .success(stitchedImage)
    }
    
    func cancel() {
        isCancelled = true
    }
    
    // MARK: - Window Selection
    
    private func selectWindow() async -> WindowInfo? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                // Show instructions
                let alert = NSAlert()
                alert.messageText = "Select Window to Capture"
                alert.informativeText = "Click on the window you want to scroll and capture.\n\nMake sure the window is scrollable and visible."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Continue")
                alert.addButton(withTitle: "Cancel")
                
                let response = alert.runModal()
                guard response == .alertFirstButtonReturn else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Wait for user to click on a window
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    guard let mouseLocation = NSEvent.mouseLocation as CGPoint?,
                          let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    // Find window at mouse location
                    for windowInfo in windowList {
                        guard let bounds = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                              let x = bounds["X"],
                              let y = bounds["Y"],
                              let width = bounds["Width"],
                              let height = bounds["Height"],
                              let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID else {
                            continue
                        }
                        
                        let windowRect = CGRect(x: x, y: y, width: width, height: height)
                        if windowRect.contains(mouseLocation) {
                            let info = WindowInfo(
                                windowID: windowID,
                                frame: windowRect,
                                name: windowInfo[kCGWindowName as String] as? String
                            )
                            continuation.resume(returning: info)
                            return
                        }
                    }
                    
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    // MARK: - Segment Capture
    
    private func captureSegments(window: WindowInfo) async -> Result<[NSImage], CaptureError> {
        var capturedSegments: [NSImage] = []
        var previousImage: NSImage?
        var scrollAttempts = 0
        let maxScrolls = 50 // Safety limit
        let scrollAmount: CGFloat = window.frame.height * 0.8 // 80% overlap
        
        while scrollAttempts < maxScrolls && !isCancelled {
            // Capture current view
            guard let segment = captureWindow(windowID: window.windowID, frame: window.frame) else {
                if scrollAttempts == 0 {
                    return .failure(.captureFailure)
                }
                break
            }
            
            // Check if we've reached the bottom (image is same as previous)
            if let previous = previousImage, imagesAreSimilar(segment, previous, threshold: 0.95) {
                break
            }
            
            capturedSegments.append(segment)
            previousImage = segment
            
            // Scroll down
            await scrollWindow(by: scrollAmount)
            
            // Wait for scroll to complete
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            scrollAttempts += 1
        }
        
        guard !capturedSegments.isEmpty else {
            return .failure(.noSegmentsCaptured)
        }
        
        return .success(capturedSegments)
    }
    
    private func captureWindow(windowID: CGWindowID, frame: CGRect) -> NSImage? {
        // Use ScreenCaptureKit instead of deprecated CGWindowListCreateImage
        let semaphore = DispatchSemaphore(value: 0)
        var capturedImage: NSImage?
        
        Task {
            capturedImage = await captureWindowWithScreenCaptureKit(windowID: windowID, frame: frame)
            semaphore.signal()
        }
        
        semaphore.wait()
        return capturedImage
    }
    
    private func captureWindowWithScreenCaptureKit(windowID: CGWindowID, frame: CGRect) async -> NSImage? {
        do {
            // Get available content
            let content = try await SCShareableContent.current
            
            // Find the window with the matching windowID
            guard let window = content.windows.first(where: { $0.windowID == windowID }) else {
                print("Window not found with ID: \(windowID)")
                return nil
            }
            
            // Create content filter for just this window
            let filter = SCContentFilter(desktopIndependentWindow: window)
            
            // Configure the capture
            let config = SCStreamConfiguration()
            config.width = Int(frame.width * 2) // Retina scale
            config.height = Int(frame.height * 2)
            config.showsCursor = false
            
            // Capture the image
            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            return await NSImage(cgImage: cgImage, size: frame.size)
        } catch {
            print("ScreenCaptureKit capture failed: \(error)")
            return nil
        }
    }
    
    private func scrollWindow(by amount: CGFloat) async {
        await MainActor.run {
            // Simulate scroll wheel event
            guard let event = CGEvent(
                scrollWheelEvent2Source: nil,
                units: .pixel,
                wheelCount: 1,
                wheel1: Int32(-amount),
                wheel2: 0,
                wheel3: 0
            ) else {
                return
            }
            
            event.post(tap: .cghidEventTap)
        }
    }
    
    // MARK: - Image Stitching
    
    private func stitchImages(_ images: [NSImage]) -> NSImage? {
        guard !images.isEmpty else { return nil }
        guard images.count > 1 else { return images.first }
        
        let width = images[0].size.width
        let overlapHeight = images[0].size.height * 0.2 // 20% overlap
        
        // Calculate total height
        var totalHeight: CGFloat = images[0].size.height
        for i in 1..<images.count {
            totalHeight += images[i].size.height - overlapHeight
        }
        
        // Create final image
        let finalSize = NSSize(width: width, height: totalHeight)
        let finalImage = NSImage(size: finalSize)
        
        finalImage.lockFocus()
        
        var yOffset: CGFloat = 0
        for (index, image) in images.enumerated() {
            let rect = NSRect(
                x: 0,
                y: totalHeight - yOffset - image.size.height,
                width: width,
                height: image.size.height
            )
            
            image.draw(
                in: rect,
                from: NSRect(origin: .zero, size: image.size),
                operation: .sourceOver,
                fraction: 1.0
            )
            
            yOffset += image.size.height - (index < images.count - 1 ? overlapHeight : 0)
        }
        
        finalImage.unlockFocus()
        
        return finalImage
    }
    
    private func imagesAreSimilar(_ image1: NSImage, _ image2: NSImage, threshold: Double) -> Bool {
        // Simple comparison - could be improved with perceptual hashing
        guard image1.size == image2.size else { return false }
        
        // For now, assume images are similar if they're the same size
        // In production, implement proper image comparison
        return false
    }
    
    // MARK: - Window Info
    
    struct WindowInfo {
        let windowID: CGWindowID
        let frame: CGRect
        let name: String?
    }
}
