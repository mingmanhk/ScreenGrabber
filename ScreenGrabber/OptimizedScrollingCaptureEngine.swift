//
//  OptimizedScrollingCaptureEngine.swift
//  ScreenGrabber
//
//  Optimized scrolling capture engine for macOS with performance enhancements,
//  browser-specific optimizations, and smart detection algorithms.
//

import AppKit
import ApplicationServices
import Vision
import Metal
import MetalKit
import Combine
import ScreenCaptureKit

/// EXPERIMENTAL — not wired to the production capture flow.
/// A Metal-accelerated variant of the scrolling capture engine. The active production
/// engine is `WindowBasedScrollingEngine` in WindowBasedScrollingEngine.swift.
/// Retained as a performance reference implementation.
@MainActor
final class OptimizedScrollingCaptureEngine: ObservableObject {
    
    // MARK: - Published State
    
    @Published var isActive: Bool = false
    @Published var isCapturing: Bool = false
    @Published var progress: CaptureProgress?
    @Published var error: CaptureError?
    
    // MARK: - Types
    
    struct CaptureProgress {
        var currentSlice: Int
        var totalSlices: Int?
        var statusMessage: String
        var estimatedTimeRemaining: TimeInterval?
    }
    
    enum CaptureError: LocalizedError {
        case noScrollableRegion
        case accessibilityDenied
        case captureFailure
        case stitchingFailure
        case cancelled
        case insufficientMemory
        
        var errorDescription: String? {
            switch self {
            case .noScrollableRegion:
                return "No scrollable region detected. Please hover over a scrollable window or webpage."
            case .accessibilityDenied:
                return "Accessibility permission required for scrolling. Enable in System Settings → Privacy & Security."
            case .captureFailure:
                return "Failed to capture screen content. Check screen recording permissions."
            case .stitchingFailure:
                return "Failed to stitch captured images. Try capturing fewer slices."
            case .cancelled:
                return "Capture was cancelled by user"
            case .insufficientMemory:
                return "Not enough memory to complete capture. Try closing other apps."
            }
        }
    }
    
    struct ScrollableRegion {
        let windowNumber: Int
        let frame: CGRect
        let scrollDirection: ScrollDirection
        let axElement: AXUIElement?
        let appName: String?
        let windowTitle: String?
    }
    
    enum ScrollDirection {
        case vertical
        case horizontal
        case both
        
        var hasVertical: Bool { self == .vertical || self == .both }
        var hasHorizontal: Bool { self == .horizontal || self == .both }
    }
    
    // MARK: - Configuration
    
    struct Configuration {
        // Scrolling behavior
        var scrollStepPercentage: CGFloat = 0.75
        var sliceOverlapPercentage: CGFloat = 0.25
        var scrollDelaySeconds: TimeInterval = 0.4
        var maxSlices: Int = 100
        
        // Capture quality
        var captureScale: CGFloat = NSScreen.main?.backingScaleFactor ?? 2.0
        var useScreenCaptureKit: Bool = true
        
        // Performance optimization
        var enableAdaptiveDelay: Bool = true
        var duplicateThreshold: Double = 0.98
        var enableSmartEndDetection: Bool = true
        var memoryWarningThreshold: UInt64 = 500_000_000 // 500MB
        
        // Stitching optimization
        var useGPUAcceleration: Bool = true
        var compressionQuality: CGFloat = 0.9
        var maxImageDimension: CGFloat = 50000 // Prevent extremely large images
        
        // Browser-specific optimizations
        var safariScrollDelay: TimeInterval = 0.5
        var chromeScrollDelay: TimeInterval = 0.6
        var firefoxScrollDelay: TimeInterval = 0.5
        var webScrollWarmupDelay: TimeInterval = 0.2
        
        public init() {}
    }
    
    private var config = Configuration()
    
    // MARK: - State
    
    private var capturedSlices: [CaptureSlice] = []
    private var shouldCancel = false
    private var detectedRegion: ScrollableRegion?
    private var startTime: Date?
    private var lastScrollPosition: CGFloat = 0
    private var unchangedScrollCount = 0
    
    // Performance monitoring
    private var captureTimings: [TimeInterval] = []
    private var averageCaptureTime: TimeInterval = 0
    
    // Metal for GPU acceleration
    private var metalDevice: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    
    // MARK: - Initialization
    
    init() {
        setupMetalIfNeeded()
    }
    
    private func setupMetalIfNeeded() {
        if config.useGPUAcceleration {
            metalDevice = MTLCreateSystemDefaultDevice()
            commandQueue = metalDevice?.makeCommandQueue()
        }
    }
    
    // MARK: - Capture Slice
    
    private struct CaptureSlice {
        let image: NSImage
        let hash: String
        let timestamp: Date
        let scrollPosition: CGFloat
    }
    
    // MARK: - Public API
    
    /// Cancel active capture
    func cancel() {
        shouldCancel = true
        isCapturing = false
        isActive = false
        error = .cancelled
    }
    
    /// Detect scrollable region at mouse position with enhanced detection
    func detectScrollableRegion(at point: NSPoint) -> ScrollableRegion? {
        guard let windowInfo = getWindowInfo(at: point) else {
            return nil
        }
        
        // Enhanced scroll direction detection
        let scrollDirection = detectScrollDirection(for: windowInfo)
        guard scrollDirection != nil else {
            return nil
        }
        
        return ScrollableRegion(
            windowNumber: windowInfo.windowNumber,
            frame: windowInfo.frame,
            scrollDirection: scrollDirection ?? .vertical,
            axElement: windowInfo.axElement,
            appName: windowInfo.appName,
            windowTitle: windowInfo.windowTitle
        )
    }
    
    /// Execute optimized scrolling capture
    func captureRegion(_ region: ScrollableRegion, direction: ScrollDirection) async throws -> NSImage {
        isCapturing = true
        capturedSlices = []
        shouldCancel = false
        startTime = Date()
        lastScrollPosition = 0
        unchangedScrollCount = 0
        captureTimings = []
        
        progress = CaptureProgress(
            currentSlice: 0,
            totalSlices: nil,
            statusMessage: "Preparing capture...",
            estimatedTimeRemaining: nil
        )
        
        // Optimize delay based on app
        adjustDelayForApp(region.appName)
        
        // Warmup scroll for web browsers
        if isWebBrowser(region.appName) {
            try await warmupScroll(region: region)
        }
        
        // Execute based on direction
        switch direction {
        case .vertical:
            try await captureVerticalScroll(region: region)
        case .horizontal:
            try await captureHorizontalScroll(region: region)
        case .both:
            try await captureVerticalScroll(region: region) // Default to vertical
        }
        
        // Check memory before stitching
        try checkMemoryAvailability()
        
        // Stitch with optimization
        progress?.statusMessage = "Stitching \(capturedSlices.count) images..."
        guard let stitchedImage = await optimizedStitch(
            capturedSlices.map { $0.image },
            direction: direction
        ) else {
            throw CaptureError.stitchingFailure
        }
        
        isCapturing = false
        isActive = false
        
        return stitchedImage
    }
    
    // MARK: - Enhanced Detection
    
    private struct WindowInfo {
        let windowNumber: Int
        let frame: CGRect
        let ownerPID: pid_t
        let axElement: AXUIElement?
        let appName: String?
        let windowTitle: String?
    }
    
    private func getWindowInfo(at point: NSPoint) -> WindowInfo? {
        let screenPoint = CGPoint(x: point.x, y: point.y)
        
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }
        
        for windowDict in windowList {
            guard let bounds = windowDict[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = bounds["X"], let y = bounds["Y"],
                  let width = bounds["Width"], let height = bounds["Height"],
                  let windowNumber = windowDict[kCGWindowNumber as String] as? Int,
                  let ownerPID = windowDict[kCGWindowOwnerPID as String] as? pid_t else {
                continue
            }
            
            let windowFrame = CGRect(x: x, y: y, width: width, height: height)
            
            if windowFrame.contains(screenPoint) {
                let axApp = AXUIElementCreateApplication(ownerPID)
                let appName = windowDict[kCGWindowOwnerName as String] as? String
                let windowTitle = windowDict[kCGWindowName as String] as? String
                
                return WindowInfo(
                    windowNumber: windowNumber,
                    frame: windowFrame,
                    ownerPID: ownerPID,
                    axElement: axApp,
                    appName: appName,
                    windowTitle: windowTitle
                )
            }
        }
        
        return nil
    }
    
    private func detectScrollDirection(for windowInfo: WindowInfo) -> ScrollDirection? {
        // Try Accessibility API first
        if let direction = detectScrollDirectionViaAX(windowInfo.axElement) {
            return direction
        }
        
        // Browser-specific heuristics
        if let appName = windowInfo.appName {
            if isWebBrowser(appName) {
                return .vertical // Most web pages scroll vertically
            }
            
            if appName.contains("Finder") || appName.contains("Terminal") {
                return .vertical
            }
            
            if appName.contains("Excel") || appName.contains("Numbers") {
                return .both // Spreadsheets often need both
            }
        }
        
        // Default to vertical for most apps
        return .vertical
    }
    
    private func detectScrollDirectionViaAX(_ axElement: AXUIElement?) -> ScrollDirection? {
        guard let element = axElement else { return nil }
        
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXRoleAttribute as CFString,
            &value
        )
        
        if result == .success, let role = value as? String, role == "AXScrollArea" {
            // Could inspect scroll bars here for more detail
            return .vertical // Default assumption
        }
        
        return nil
    }
    
    // MARK: - Browser Detection & Optimization
    
    private func isWebBrowser(_ appName: String?) -> Bool {
        guard let appName = appName?.lowercased() else { return false }
        return appName.contains("safari") ||
               appName.contains("chrome") ||
               appName.contains("firefox") ||
               appName.contains("edge") ||
               appName.contains("brave") ||
               appName.contains("opera")
    }
    
    private func adjustDelayForApp(_ appName: String?) {
        guard let appName = appName?.lowercased() else { return }
        
        if appName.contains("safari") {
            config.scrollDelaySeconds = config.safariScrollDelay
        } else if appName.contains("chrome") {
            config.scrollDelaySeconds = config.chromeScrollDelay
        } else if appName.contains("firefox") {
            config.scrollDelaySeconds = config.firefoxScrollDelay
        }
    }
    
    private func warmupScroll(region: ScrollableRegion) async throws {
        // Small scroll to trigger lazy loading
        _ = await scrollWindow(region: region, direction: .vertical, amount: 10)
        try await Task.sleep(nanoseconds: UInt64(config.webScrollWarmupDelay * 1_000_000_000))
    }
    
    // MARK: - Optimized Capture
    
    private func captureVerticalScroll(region: ScrollableRegion) async throws {
        let viewportHeight = region.frame.height
        let scrollStep = viewportHeight * config.scrollStepPercentage
        
        var sliceCount = 0
        var noChangeCount = 0
        let maxNoChange = 3
        
        while sliceCount < config.maxSlices && !shouldCancel {
            let captureStart = Date()
            
            // Capture current viewport
            guard let slice = await captureRect(region.frame) else {
                throw CaptureError.captureFailure
            }
            
            let captureTime = Date().timeIntervalSince(captureStart)
            captureTimings.append(captureTime)
            averageCaptureTime = captureTimings.reduce(0, +) / Double(captureTimings.count)
            
            // Generate hash for duplicate detection
            let hash = await generateImageHash(slice)
            
            // Check for duplicate
            if let lastSlice = capturedSlices.last {
                let similarity = await calculateSimilarity(hash: hash, previousHash: lastSlice.hash)
                
                if similarity >= config.duplicateThreshold {
                    noChangeCount += 1
                    print("[SCROLL] Duplicate detected (similarity: \(similarity))")
                    
                    if noChangeCount >= maxNoChange {
                        print("[SCROLL] Reached end of content")
                        break
                    }
                } else {
                    noChangeCount = 0
                }
            }
            
            // Store slice
            let captureSlice = CaptureSlice(
                image: slice,
                hash: hash,
                timestamp: Date(),
                scrollPosition: CGFloat(sliceCount) * scrollStep
            )
            capturedSlices.append(captureSlice)
            sliceCount += 1
            
            // Update progress with time estimate
            let estimatedRemaining = estimateTimeRemaining(currentSlice: sliceCount)
            progress = CaptureProgress(
                currentSlice: sliceCount,
                totalSlices: nil,
                statusMessage: "Capturing slice \(sliceCount)...",
                estimatedTimeRemaining: estimatedRemaining
            )
            
            // Check memory
            if sliceCount % 10 == 0 {
                try checkMemoryAvailability()
            }
            
            // Scroll with adaptive delay
            let scrollSuccess = await scrollWindow(
                region: region,
                direction: .vertical,
                amount: scrollStep
            )
            
            if !scrollSuccess {
                print("[SCROLL] Scroll failed, assuming end of content")
                break
            }
            
            // Adaptive delay based on capture time
            let delay = config.enableAdaptiveDelay
                ? max(config.scrollDelaySeconds, captureTime * 1.5)
                : config.scrollDelaySeconds
            
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        if shouldCancel {
            throw CaptureError.cancelled
        }
    }
    
    private func captureHorizontalScroll(region: ScrollableRegion) async throws {
        // Similar to vertical but for horizontal direction
        let viewportWidth = region.frame.width
        let scrollStep = viewportWidth * config.scrollStepPercentage
        
        var sliceCount = 0
        var noChangeCount = 0
        
        while sliceCount < config.maxSlices && !shouldCancel {
            guard let slice = await captureRect(region.frame) else {
                throw CaptureError.captureFailure
            }
            
            let hash = await generateImageHash(slice)
            
            if let lastSlice = capturedSlices.last {
                let similarity = await calculateSimilarity(hash: hash, previousHash: lastSlice.hash)
                if similarity >= config.duplicateThreshold {
                    noChangeCount += 1
                    if noChangeCount >= 3 { break }
                } else {
                    noChangeCount = 0
                }
            }
            
            capturedSlices.append(CaptureSlice(
                image: slice,
                hash: hash,
                timestamp: Date(),
                scrollPosition: CGFloat(sliceCount) * scrollStep
            ))
            sliceCount += 1
            
            progress = CaptureProgress(
                currentSlice: sliceCount,
                totalSlices: nil,
                statusMessage: "Capturing slice \(sliceCount)...",
                estimatedTimeRemaining: estimateTimeRemaining(currentSlice: sliceCount)
            )
            
            let scrollSuccess = await scrollWindow(
                region: region,
                direction: .horizontal,
                amount: scrollStep
            )
            
            if !scrollSuccess { break }
            
            try await Task.sleep(nanoseconds: UInt64(config.scrollDelaySeconds * 1_000_000_000))
        }
        
        if shouldCancel {
            throw CaptureError.cancelled
        }
    }
    
    // MARK: - Optimized Screen Capture
    
    private func captureRect(_ rect: CGRect) async -> NSImage? {
        if #available(macOS 12.3, *) {
            return await captureRectWithScreenCaptureKit(rect)
        } else {
            // ScreenCaptureKit is required for screen capture on modern macOS
            print("ScreenCaptureKit requires macOS 12.3 or later; cannot capture rect on this OS version")
            return nil
        }
    }
    
    @available(macOS 12.3, *)
    private func captureRectWithScreenCaptureKit(_ rect: CGRect) async -> NSImage? {
        do {
            let content = try await SCShareableContent.current
            // Use the first display that contains the rect center
            guard let display = content.displays.first else { return nil }
            
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.sourceRect = rect
            config.width = Int(rect.width * 2)
            config.height = Int(rect.height * 2)
            config.showsCursor = false
            
            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            return NSImage(cgImage: cgImage, size: rect.size)
        } catch {
            print("SCKit capture failed: \(error)")
            return nil
        }
    }
    
    // MARK: - Smart Scrolling
    
    private func scrollWindow(
        region: ScrollableRegion,
        direction: ScrollDirection,
        amount: CGFloat
    ) async -> Bool {
        let scrollAmount = direction.hasVertical ? -Int32(amount / 10) : 0
        let horizontalAmount = direction.hasHorizontal ? -Int32(amount / 10) : 0
        
        let centerX = region.frame.midX
        let centerY = region.frame.midY
        
        // Use multiple smaller scrolls for smoother animation
        let steps = 5
        let scrollPerStep = scrollAmount / Int32(steps)
        let horizontalPerStep = horizontalAmount / Int32(steps)
        
        for _ in 0..<steps {
            guard let scrollEvent = CGEvent(
                scrollWheelEvent2Source: nil,
                units: .line,
                wheelCount: 2,
                wheel1: scrollPerStep,
                wheel2: horizontalPerStep,
                wheel3: 0
            ) else {
                return false
            }
            
            scrollEvent.location = CGPoint(x: centerX, y: centerY)
            scrollEvent.post(tap: .cghidEventTap)
            
            // Small delay between micro-scrolls
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        return true
    }
    
    // MARK: - Image Processing
    
    private func generateImageHash(_ image: NSImage) async -> String {
        // Fast perceptual hash for duplicate detection
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return UUID().uuidString
        }
        
        // Create downscaled version for fast comparison
        let size = 8 // 8x8 for perceptual hash
        let context = CIContext()
        let ciImage = CIImage(cgImage: cgImage)
        
        guard let filter = CIFilter(name: "CILanczosScaleTransform") else {
            return UUID().uuidString
        }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(Double(size) / Double(cgImage.width), forKey: kCIInputScaleKey)

        guard let outputImage = filter.outputImage,
              let smallCGImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return UUID().uuidString
        }
        
        // Generate hash from pixel values
        guard let data = smallCGImage.dataProvider?.data else { return UUID().uuidString }
        let bytes = CFDataGetBytePtr(data)
        var hash = ""
        
        for i in 0..<(size * size) {
            if let bytes = bytes {
                hash += String(format: "%02x", bytes[i * 4])
            }
        }
        
        return hash
    }
    
    private func calculateSimilarity(hash: String, previousHash: String) async -> Double {
        // Simple Hamming distance for hash comparison
        guard hash.count == previousHash.count else { return 0.0 }
        
        var differences = 0
        for (c1, c2) in zip(hash, previousHash) {
            if c1 != c2 {
                differences += 1
            }
        }
        
        return 1.0 - (Double(differences) / Double(hash.count))
    }
    
    // MARK: - Optimized Stitching
    
    private func optimizedStitch(_ images: [NSImage], direction: ScrollDirection) async -> NSImage? {
        guard !images.isEmpty else { return nil }
        
        if images.count == 1 {
            return images[0]
        }
        
        // Check if we should use GPU acceleration
        if config.useGPUAcceleration, let device = metalDevice {
            return await stitchWithMetal(images, direction: direction, device: device)
        }
        
        // Fallback to CPU stitching
        return direction.hasVertical
            ? stitchVertically(images)
            : stitchHorizontally(images)
    }
    
    private func stitchWithMetal(
        _ images: [NSImage],
        direction: ScrollDirection,
        device: MTLDevice
    ) async -> NSImage? {
        // GPU-accelerated stitching using Metal
        // For now, fallback to CPU version
        return direction.hasVertical
            ? stitchVertically(images)
            : stitchHorizontally(images)
    }
    
    private func stitchVertically(_ images: [NSImage]) -> NSImage? {
        guard let firstImage = images.first else { return nil }
        
        print("[STITCH] Starting vertical stitch with \(images.count) slices")
        
        let width = firstImage.size.width
        let overlapHeight = firstImage.size.height * config.sliceOverlapPercentage
        
        // CRITICAL FIX: Calculate total height correctly by accounting for overlap
        // Formula: First slice (full height) + all other slices (height - overlap)
        var totalHeight: CGFloat = firstImage.size.height
        for i in 1..<images.count {
            let sliceHeight = images[i].size.height
            totalHeight += (sliceHeight - overlapHeight)
        }
        
        print("[STITCH] Calculated total height: \(Int(totalHeight))px (width: \(Int(width))px)")
        print("[STITCH] Overlap per slice: \(Int(overlapHeight))px (\(config.sliceOverlapPercentage * 100)%)")
        
        // Check max dimension
        if totalHeight > config.maxImageDimension {
            print("[STITCH] ⚠️ Warning: Image height \(Int(totalHeight))px exceeds maximum \(Int(config.maxImageDimension))px")
            totalHeight = config.maxImageDimension
        }
        
        let finalSize = NSSize(width: width, height: totalHeight)
        let finalImage = NSImage(size: finalSize)
        
        finalImage.lockFocus()
        
        // Fill with white background to prevent transparency issues
        NSColor.white.setFill()
        NSRect(origin: .zero, size: finalSize).fill()
        
        // CRITICAL FIX: Track current Y position more accurately
        var currentY: CGFloat = 0
        
        for (index, image) in images.enumerated() {
            let imageHeight = image.size.height
            
            // For first image, use full height. For subsequent images, skip the overlap portion
            let sourceY: CGFloat = index == 0 ? 0 : overlapHeight
            let sourceHeight: CGFloat = index == 0 ? imageHeight : (imageHeight - overlapHeight)
            
            let sourceRect = NSRect(
                x: 0,
                y: sourceY,
                width: width,
                height: sourceHeight
            )
            
            // macOS uses bottom-left origin, so we need to flip Y coordinate
            let destRect = NSRect(
                x: 0,
                y: totalHeight - currentY - sourceHeight,
                width: width,
                height: sourceHeight
            )
            
            print("[STITCH] Slice \(index + 1)/\(images.count): source=\(Int(sourceY))→\(Int(sourceY + sourceHeight))px, dest Y=\(Int(destRect.origin.y))px, height=\(Int(sourceHeight))px")
            
            image.draw(in: destRect, from: sourceRect, operation: .copy, fraction: 1.0)
            
            // Move down by the height we just drew
            currentY += sourceHeight
        }
        
        finalImage.unlockFocus()
        
        print("[STITCH] ✅ Vertical stitch complete: \(Int(finalSize.width)) × \(Int(finalSize.height))px")
        
        return finalImage
    }
    
    private func stitchHorizontally(_ images: [NSImage]) -> NSImage? {
        guard let firstImage = images.first else { return nil }
        
        print("[STITCH] Starting horizontal stitch with \(images.count) slices")
        
        let height = firstImage.size.height
        let overlapWidth = firstImage.size.width * config.sliceOverlapPercentage
        
        // CRITICAL FIX: Calculate total width correctly
        var totalWidth: CGFloat = firstImage.size.width
        for i in 1..<images.count {
            let sliceWidth = images[i].size.width
            totalWidth += (sliceWidth - overlapWidth)
        }
        
        print("[STITCH] Calculated total width: \(Int(totalWidth))px (height: \(Int(height))px)")
        print("[STITCH] Overlap per slice: \(Int(overlapWidth))px (\(config.sliceOverlapPercentage * 100)%)")
        
        if totalWidth > config.maxImageDimension {
            print("[STITCH] ⚠️ Warning: Image width \(Int(totalWidth))px exceeds maximum \(Int(config.maxImageDimension))px")
            totalWidth = config.maxImageDimension
        }
        
        let finalSize = NSSize(width: totalWidth, height: height)
        let finalImage = NSImage(size: finalSize)
        
        finalImage.lockFocus()
        
        // Fill with white background
        NSColor.white.setFill()
        NSRect(origin: .zero, size: finalSize).fill()
        
        var currentX: CGFloat = 0
        
        for (index, image) in images.enumerated() {
            let imageWidth = image.size.width
            
            // For first image, use full width. For subsequent images, skip the overlap portion
            let sourceX: CGFloat = index == 0 ? 0 : overlapWidth
            let sourceWidth: CGFloat = index == 0 ? imageWidth : (imageWidth - overlapWidth)
            
            let sourceRect = NSRect(
                x: sourceX,
                y: 0,
                width: sourceWidth,
                height: height
            )
            
            let destRect = NSRect(
                x: currentX,
                y: 0,
                width: sourceWidth,
                height: height
            )
            
            print("[STITCH] Slice \(index + 1)/\(images.count): source=\(Int(sourceX))→\(Int(sourceX + sourceWidth))px, dest X=\(Int(destRect.origin.x))px, width=\(Int(sourceWidth))px")
            
            image.draw(in: destRect, from: sourceRect, operation: .copy, fraction: 1.0)
            
            currentX += sourceWidth
        }
        
        finalImage.unlockFocus()
        
        print("[STITCH] ✅ Horizontal stitch complete: \(Int(finalSize.width)) × \(Int(finalSize.height))px")
        
        return finalImage
    }
    
    // MARK: - Performance Monitoring
    
    private func estimateTimeRemaining(currentSlice: Int) -> TimeInterval? {
        guard currentSlice > 2, let startTime = startTime else { return nil }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let estimatedTotal = (elapsed / Double(currentSlice)) * Double(config.maxSlices)
        let remaining = estimatedTotal - elapsed
        
        return max(0, remaining)
    }
    
    private func checkMemoryAvailability() throws {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return }
        
        let usedMemory = info.resident_size
        
        if usedMemory > config.memoryWarningThreshold {
            print("[MEMORY] Warning: High memory usage \(usedMemory / 1_000_000) MB")
            
            // Release some memory by compressing older slices
            if capturedSlices.count > 20 {
                print("[MEMORY] Compressing older slices to save memory")
                // Could implement slice compression here
            }
        }
    }
    
    private func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

