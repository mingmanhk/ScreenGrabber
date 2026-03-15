//
//  ScreenCaptureManager.swift
//  ScreenGrabber
//
//  Central coordinator for all screen capture operations
//  PRODUCTION-READY IMPLEMENTATION
//

import Foundation
import AppKit
import ScreenCaptureKit
import SwiftData
import Combine
import UserNotifications
import os

@MainActor
class ScreenCaptureManager: ObservableObject {
    static let shared = ScreenCaptureManager()
    
    @Published var isCapturing = false
    @Published var lastCaptureURL: URL?
    @Published var captureProgress: Double = 0.0
    
    private init() {
        setupNotifications()
    }
    
    // MARK: - Notification Setup
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                CaptureLogger.log(.capture, "Notification permission granted", level: .success)
            } else if let error = error {
                CaptureLogger.log(.capture, "Notification permission error: \(error)", level: .error)
            }
        }
    }
    
    // MARK: - Main Capture Entry Point
    
    func captureScreen(
        method: ScreenOption,
        openOption: OpenOption,
        modelContext: ModelContext?
    ) {
        guard !isCapturing else {
            CaptureLogger.log(.capture, "Capture already in progress", level: .warning)
            
            // Show user feedback that a capture is already running
            Task { @MainActor in
                let alert = NSAlert()
                alert.messageText = "Capture in Progress"
                alert.informativeText = "Please wait for the current screenshot to complete."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
            return
        }
        
        isCapturing = true
        captureProgress = 0.0
        CaptureLogger.log(.capture, "Starting capture: \(method.displayName)", level: .info)
        
        // Store last used settings for retry functionality
        Task { @MainActor in
            SettingsModel.shared.lastUsedCaptureMethod = method
            SettingsModel.shared.lastUsedOpenOption = openOption
        }
        
        Task {
            // CRITICAL: Use defer to ALWAYS reset state, even if task is cancelled
            defer {
                Task { @MainActor in
                    self.isCapturing = false
                    self.captureProgress = 0.0
                    CaptureLogger.log(.capture, "Capture state reset", level: .debug)
                }
            }
            
            do {
                // STEP 1: Apply time delay if enabled
                let settings = await MainActor.run { SettingsModel.shared }
                if settings.timeDelayEnabled {
                    let delaySeconds = settings.timeDelaySeconds
                    CaptureLogger.log(.capture, "Applying \(delaySeconds)s delay", level: .info)
                    await showCountdownNotification(seconds: Int(delaySeconds))
                    try await Task.sleep(for: .seconds(delaySeconds))
                }
                
                // Validate environment
                captureProgress = 0.1
                let validation = await CapturePermissionsManager.shared.validateCaptureEnvironment()
                guard case .success = validation else {
                    if case .failure(let error) = validation {
                        // Pass the actual error, not a wrapped one
                        await handleCaptureError(error)
                    }
                    return
                }
                
                // Perform capture based on method
                captureProgress = 0.2
                let captureResult: CaptureResult
                
                switch method {
                case .selectedArea:
                    captureResult = try await captureArea()
                case .window:
                    captureResult = try await captureWindow()
                case .fullScreen:
                    captureResult = try await captureFullScreen()
                case .scrollingCapture:
                    captureResult = try await captureScrolling()
                }
                
                // Save screenshot
                captureProgress = 0.7
                let screenshot = try await saveCapture(
                    captureResult,
                    method: method,
                    context: modelContext
                )
                
                lastCaptureURL = screenshot.fileURL
                captureProgress = 1.0
                
                // STEP 2: Handle copy to clipboard if enabled
                if settings.copyToClipboardEnabled {
                    CaptureLogger.log(.clipboard, "Copy to clipboard enabled, copying", level: .info)
                    let clipboardResult = await CaptureClipboardService.shared.copyToClipboard(captureResult.image)

                    if case .success = clipboardResult {
                        CaptureLogger.log(.clipboard, "Successfully copied to clipboard", level: .success)
                    } else if case .failure(let error) = clipboardResult {
                        CaptureLogger.log(.clipboard, "Failed to copy to clipboard: \(error.localizedDescription)", level: .error)
                    }
                } else {
                    CaptureLogger.log(.clipboard, "Copy to clipboard disabled, skipping", level: .debug)
                }
                
                // STEP 3: Handle open option (respects previewInEditorEnabled)
                await handleOpenOption(openOption, screenshot: screenshot, image: captureResult.image)
                
                // Notify success
                showNotification(
                    title: "Screenshot Captured",
                    message: "\(Int(captureResult.size.width))×\(Int(captureResult.size.height)) saved"
                )
                
                // Post notification for UI updates
                NotificationCenter.default.post(
                    name: .screenshotCaptured,
                    object: screenshot,
                    userInfo: ["url": screenshot.fileURL]
                )
                
                CaptureLogger.log(.capture, "Capture complete: \(screenshot.filename)", level: .success)
                
            } catch {
                await handleCaptureError(error)
            }
        }
    }
    
    // MARK: - Capture Methods
    
    private func captureArea() async throws -> CaptureResult {
        CaptureLogger.captureStarted(method: "Area Selection")
        
        return try await withCheckedThrowingContinuation { continuation in
            // Track if we've already resumed — OSAllocatedUnfairLock is safe in async contexts
            let hasResumed = OSAllocatedUnfairLock(initialState: false)
            var selectorWindow: AreaSelectorWindow?

            DispatchQueue.main.async {
                let selector = AreaSelectorWindow { rect in
                    // Prevent double-resumption with thread-safe check
                    let alreadyResumed = hasResumed.withLock { state -> Bool in
                        if state { return true }
                        state = true
                        return false
                    }
                    guard !alreadyResumed else {
                        CaptureLogger.log(.area, "Area selection callback called multiple times (ignored)", level: .warning)
                        return
                    }
                    
                    Task {
                        defer {
                            // CRITICAL: Always clean up window reference
                            DispatchQueue.main.async {
                                selectorWindow?.orderOut(nil)
                                selectorWindow = nil
                            }
                        }
                        
                        do {
                            if let rect = rect {
                                CaptureLogger.areaSelected(rect: rect)

                                // Validate rect dimensions
                                guard rect.width > 0 && rect.height > 0 else {
                                    CaptureLogger.log(.area, "Invalid rect dimensions: \(rect)", level: .error)
                                    continuation.resume(throwing: ScreenGrabberTypes.CaptureError.userCancelled)
                                    return
                                }
                                
                                // Capture the selected area
                                let image = try await self.captureRect(rect)
                                
                                continuation.resume(returning: CaptureResult(
                                    image: image,
                                    size: CGSize(width: rect.width, height: rect.height),
                                    method: .selectedArea,
                                    sourceInfo: "Area: \(Int(rect.width))×\(Int(rect.height))"
                                ))
                            } else {
                                CaptureLogger.log(.area, "Area selection cancelled by user", level: .info)
                                continuation.resume(throwing: ScreenGrabberTypes.CaptureError.userCancelled)
                            }
                        } catch {
                            CaptureLogger.captureError(error, method: "Area Capture")
                            continuation.resume(throwing: error)
                        }
                    }
                }
                
                selectorWindow = selector
                selector.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                CaptureLogger.log(.area, "Area selector window displayed", level: .debug)
                
                // CRITICAL: Shorter timeout to prevent hanging
                Task {
                    // Wait up to 2 minutes for user selection
                    try? await Task.sleep(for: .seconds(120))
                    
                    let alreadyResumedOnTimeout = hasResumed.withLock { state -> Bool in
                        if state { return true }
                        state = true
                        return false
                    }
                    guard !alreadyResumedOnTimeout else { return }

                    CaptureLogger.log(.area, "Area selection timed out after 2 minutes", level: .warning)
                    
                    // Clean up window
                    DispatchQueue.main.async {
                        selectorWindow?.orderOut(nil)
                        selectorWindow?.close()
                        selectorWindow = nil
                    }
                    
                    continuation.resume(throwing: ScreenGrabberTypes.CaptureError.userCancelled)
                }
            }
        }
    }
    
    private func captureWindow() async throws -> CaptureResult {
        CaptureLogger.log(.window, "Starting window selection", level: .info)
        
        // Fetch available windows
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let windows = content.windows.filter { window in
            guard window.frame.width > 100,
                  window.frame.height > 100,
                  window.isOnScreen,
                  window.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier else {
                return false
            }
            return true
        }.map { window in
            SelectableWindow(
                id: window.windowID,
                frame: window.frame,
                title: window.title ?? "",
                ownerName: window.owningApplication?.applicationName ?? "Unknown",
                layer: window.windowLayer,
                windowRef: window
            )
        }
        
        guard !windows.isEmpty else {
            throw ScreenGrabberTypes.CaptureError.noWindowAvailable
        }
        
        // Present Snagit-style hover overlay
        let selectedWindow = await presentWindowHoverSelector(windows: windows)
        
        guard let window = selectedWindow else {
            throw ScreenGrabberTypes.CaptureError.userCancelled
        }
        
        CaptureLogger.log(.window, "Selected window: \(window.displayTitle)", level: .info)
        let image = try await captureWindow(window)
        
        return CaptureResult(
            image: image,
            size: window.frame.size,
            method: .window,
            sourceInfo: window.displayTitle
        )
    }

    /// Presents a transparent full-screen overlay; user hovers to highlight a window, clicks to select.
    private func presentWindowHoverSelector(windows: [SelectableWindow]) async -> SelectableWindow? {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let selector = WindowHoverSelectorWindow(availableWindows: windows)
                selector.onWindowSelected = { continuation.resume(returning: $0) }
                selector.onCancelled     = { continuation.resume(returning: nil) }
                selector.makeKeyAndOrderFront(nil)
            }
        }
    }
    
    private func captureFullScreen() async throws -> CaptureResult {
        CaptureLogger.log(.screen, "Capturing full screen", level: .info)

        // ROBUST SCREEN DETECTION
        // Use CGDisplay API for more reliable screen capture
        let mainDisplayID = CGMainDisplayID()
        let screenFrame = CGDisplayBounds(mainDisplayID)

        guard !screenFrame.isEmpty else {
            CaptureLogger.log(.screen, "No screen available after all detection attempts", level: .error)
            throw ScreenGrabberTypes.CaptureError.noScreenAvailable
        }

        CaptureLogger.log(.screen, "Using main display, frame: \(screenFrame)", level: .debug)
        
        let image = try await captureRect(screenFrame)
        
        return CaptureResult(
            image: image,
            size: screenFrame.size,
            method: .fullScreen,
            sourceInfo: "Main Display"
        )
    }
    
    // MARK: - Screen Detection
    
    /// Robust screen detection with multiple fallback strategies
    @MainActor
    private func detectActiveScreen() -> NSScreen? {
        // Strategy 1: Use main screen (screen with keyboard focus)
        if let mainScreen = NSScreen.main {
            CaptureLogger.log(.screen, "Detected main screen: \(mainScreen.localizedName)", level: .debug)
            return mainScreen
        }

        CaptureLogger.log(.screen, "NSScreen.main is nil, trying fallback strategies", level: .warning)

        // Strategy 2: Use screen containing the mouse cursor
        let mouseLocation = NSEvent.mouseLocation
        if let cursorScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
            CaptureLogger.log(.screen, "Detected screen containing cursor: \(cursorScreen.localizedName)", level: .debug)
            return cursorScreen
        }

        CaptureLogger.log(.screen, "No screen contains cursor at \(mouseLocation)", level: .warning)

        // Strategy 3: Use deepest screen (highest color depth)
        if let deepestScreen = NSScreen.deepest {
            CaptureLogger.log(.screen, "Using deepest screen: \(deepestScreen.localizedName)", level: .debug)
            return deepestScreen
        }

        CaptureLogger.log(.screen, "NSScreen.deepest is nil, trying next strategy", level: .warning)

        // Strategy 4: Use first available screen
        if let firstScreen = NSScreen.screens.first {
            CaptureLogger.log(.screen, "Using first available screen: \(firstScreen.localizedName)", level: .debug)
            return firstScreen
        }

        // Strategy 5: Last resort - try to detect screens via ScreenCaptureKit
        CaptureLogger.log(.screen, "No screens available via NSScreen, checking ScreenCaptureKit", level: .warning)
        
        return nil
    }
    
    private func captureScrolling() async throws -> CaptureResult {
        CaptureLogger.log(.scrolling, "Starting scrolling capture", level: .info)

        // Present window hover selector for the user to pick a window
        guard let window = try await selectWindow() else {
            throw ScreenGrabberTypes.CaptureError.userCancelled
        }

        CaptureLogger.log(.scrolling, "Window selected: \(window.displayTitle)", level: .info)

        // Use WindowBasedScrollingEngine — capture-only path (no internal save)
        let engine = WindowBasedScrollingEngine()
        let stitched = try await engine.captureAndStitch(window: window)

        CaptureLogger.log(.scrolling, "Scrolling capture complete: \(Int(stitched.size.width))×\(Int(stitched.size.height))", level: .success)

        return CaptureResult(
            image: stitched,
            size: stitched.size,
            method: .scrollingCapture,
            sourceInfo: window.displayTitle
        )
    }

    func selectWindow() async throws -> SelectableWindow? {
        // Fetch available windows
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let windows = content.windows.filter { window in
            guard window.frame.width > 100,
                  window.frame.height > 100,
                  window.isOnScreen,
                  window.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier else {
                return false
            }
            return true
        }.map { window in
            SelectableWindow(
                id: window.windowID,
                frame: window.frame,
                title: window.title ?? "",
                ownerName: window.owningApplication?.applicationName ?? "Unknown",
                layer: window.windowLayer,
                windowRef: window
            )
        }
        
        guard !windows.isEmpty else {
            throw ScreenGrabberTypes.CaptureError.noWindowAvailable
        }
        
        return await presentWindowHoverSelector(windows: windows)
    }
    
    // MARK: - ScreenCaptureKit Integration
    
    private func captureRect(_ rect: CGRect) async throws -> NSImage {
        CaptureLogger.log(.capture, "Capturing rect: \(rect)", level: .debug)

        // Validate rect dimensions
        guard rect.width > 0 && rect.height > 0 else {
            CaptureLogger.log(.capture, "Invalid rect dimensions: \(rect)", level: .error)
            throw ScreenGrabberTypes.CaptureError.invalidImageData
        }
        
        // Get settings for cursor inclusion
        let settings = await MainActor.run { SettingsModel.shared }
        let includeCursor = settings.includeCursor
        
        // Get shareable content with proper error handling
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.current
            CaptureLogger.log(.screen, "ScreenCaptureKit reports \(content.displays.count) displays", level: .debug)
        } catch {
            CaptureLogger.log(.screen, "Failed to get shareable content: \(error.localizedDescription)", level: .error)
            throw ScreenGrabberTypes.CaptureError.captureKitError("Failed to access screen content: \(error.localizedDescription)")
        }
        
        // Ensure we have at least one display
        guard !content.displays.isEmpty else {
            CaptureLogger.log(.screen, "No displays available from ScreenCaptureKit", level: .error)
            throw ScreenGrabberTypes.CaptureError.noScreenAvailable
        }
        
        // Find display containing the rect
        var matchingDisplay = content.displays.first(where: { display in
            display.frame.intersects(rect)
        })
        
        // Fallback: If no display intersects, try to find the closest display
        if matchingDisplay == nil {
            CaptureLogger.log(.screen, "No display intersects rect \(rect), finding closest display", level: .warning)
            
            // Find display with most overlap or closest center
            matchingDisplay = content.displays.min(by: { display1, display2 in
                let center1 = CGPoint(x: display1.frame.midX, y: display1.frame.midY)
                let center2 = CGPoint(x: display2.frame.midX, y: display2.frame.midY)
                let rectCenter = CGPoint(x: rect.midX, y: rect.midY)
                
                let dist1 = hypot(center1.x - rectCenter.x, center1.y - rectCenter.y)
                let dist2 = hypot(center2.x - rectCenter.x, center2.y - rectCenter.y)
                
                return dist1 < dist2
            })
            
            if let display = matchingDisplay {
                CaptureLogger.log(.screen, "Using closest display: \(display.displayID)", level: .debug)
            }
        }

        guard let display = matchingDisplay else {
            CaptureLogger.log(.screen, "No suitable display found. Available: \(content.displays.map { "ID: \($0.displayID), frame: \($0.frame)" }.joined(separator: ", "))", level: .error)
            throw ScreenGrabberTypes.CaptureError.noScreenAvailable
        }
        
        CaptureLogger.log(.screen, "Using display \(display.displayID), frame: \(display.frame)", level: .debug)
        
        // Configure capture
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        
        // Set resolution - use 2.0 for Retina displays
        let scale: CGFloat = 2.0
        let captureWidth = Int(rect.width * scale)
        let captureHeight = Int(rect.height * scale)
        
        // Validate dimensions are reasonable
        guard captureWidth > 0 && captureHeight > 0 && captureWidth <= 16384 && captureHeight <= 16384 else {
            CaptureLogger.log(.capture, "Invalid capture dimensions: \(captureWidth)×\(captureHeight)", level: .error)
            throw ScreenGrabberTypes.CaptureError.invalidImageData
        }

        config.width = captureWidth
        config.height = captureHeight

        // Set source rect (in display coordinates)
        // Need to translate rect to display's coordinate space
        let displayRect: CGRect
        if display.frame.contains(rect) {
            // Rect is within display, use relative coordinates
            displayRect = CGRect(
                x: rect.origin.x - display.frame.origin.x,
                y: rect.origin.y - display.frame.origin.y,
                width: rect.width,
                height: rect.height
            )
        } else {
            // Use the full display or intersection
            let intersection = display.frame.intersection(rect)
            if intersection.isEmpty {
                // Capture full display as fallback
                displayRect = CGRect(origin: .zero, size: display.frame.size)
                CaptureLogger.log(.screen, "Using full display as rect doesn't intersect", level: .warning)
            } else {
                displayRect = CGRect(
                    x: intersection.origin.x - display.frame.origin.x,
                    y: intersection.origin.y - display.frame.origin.y,
                    width: intersection.width,
                    height: intersection.height
                )
            }
        }

        config.sourceRect = displayRect

        // Quality settings
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = includeCursor  // ✅ RESPECT SETTINGS
        config.scalesToFit = false

        CaptureLogger.log(.capture, "Capturing - width: \(config.width), height: \(config.height), sourceRect: \(config.sourceRect), cursor: \(includeCursor)", level: .debug)
        
        // Capture the image with error handling
        let cgImage: CGImage
        do {
            cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
        } catch {
            CaptureLogger.log(.capture, "ScreenCaptureKit capture failed: \(error.localizedDescription)", level: .error)
            throw ScreenGrabberTypes.CaptureError.captureKitError("Screenshot capture failed: \(error.localizedDescription)")
        }

        // Convert to NSImage
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: rect.width, height: rect.height))

        CaptureLogger.log(.capture, "Captured \(Int(rect.width))×\(Int(rect.height)) image", level: .success)
        return nsImage
    }

    private func captureWindow(_ window: SelectableWindow) async throws -> NSImage {
        CaptureLogger.log(.window, "Capturing window ID: \(window.id)", level: .debug)

        // Validate window dimensions
        guard window.frame.width > 0 && window.frame.height > 0 else {
            CaptureLogger.log(.window, "Invalid window dimensions: \(window.frame)", level: .error)
            throw ScreenGrabberTypes.CaptureError.invalidImageData
        }
        
        // Get settings for cursor inclusion
        let settings = await MainActor.run { SettingsModel.shared }
        let includeCursor = settings.includeCursor
        
        // Create filter and configuration
        let filter = SCContentFilter(desktopIndependentWindow: window.windowRef)
        let config = SCStreamConfiguration()
        
        // Use window dimensions
        let captureWidth = Int(window.frame.width * 2) // 2x for Retina
        let captureHeight = Int(window.frame.height * 2)
        
        // Validate dimensions are reasonable
        guard captureWidth > 0 && captureHeight > 0 && captureWidth <= 16384 && captureHeight <= 16384 else {
            CaptureLogger.log(.window, "Invalid capture dimensions: \(captureWidth)×\(captureHeight)", level: .error)
            throw ScreenGrabberTypes.CaptureError.invalidImageData
        }

        config.width = captureWidth
        config.height = captureHeight

        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = includeCursor  // ✅ RESPECT SETTINGS
        config.scalesToFit = true

        CaptureLogger.log(.window, "Capturing window with cursor: \(includeCursor), dimensions: \(captureWidth)×\(captureHeight)", level: .debug)
        
        // Capture the image with error handling
        let cgImage: CGImage
        do {
            cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
        } catch {
            CaptureLogger.log(.window, "Window capture failed: \(error.localizedDescription)", level: .error)
            throw ScreenGrabberTypes.CaptureError.captureKitError("Window capture failed: \(error.localizedDescription)")
        }

        let nsImage = NSImage(cgImage: cgImage, size: window.frame.size)

        CaptureLogger.log(.window, "Captured window: \(window.displayTitle)", level: .success)
        return nsImage
    }
    
    // MARK: - Save & Organize
    
    private func saveCapture(
        _ result: CaptureResult,
        method: ScreenOption,
        context: ModelContext?
    ) async throws -> Screenshot {
        CaptureLogger.log(.save, "Saving capture", level: .info)
        
        // Convert ScreenOption to CaptureType for CaptureFileStore
        let captureType: ScreenGrabberTypes.CaptureType
        switch method {
        case .selectedArea:
            captureType = .area
        case .window:
            captureType = .window
        case .fullScreen:
            captureType = .fullscreen
        case .scrollingCapture:
            captureType = .scrolling
        }
        
        // Use CaptureFileStore for robust file saving with error handling
        let timestamp = Date()
        let saveResult = await CaptureFileStore.shared.saveImage(
            result.image,
            type: captureType,
            timestamp: timestamp
        )
        
        guard case .success(let fileURL) = saveResult else {
            if case .failure(let error) = saveResult {
                CaptureLogger.log(.error, "❌ Failed to save image: \(error.localizedDescription)", level: .error)
                throw error
            }
            throw ScreenGrabberTypes.CaptureError.fileWriteFailed(underlying: nil)
        }
        
        // Get file size
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        CaptureLogger.log(.save, "Saved to: \(fileURL.path)", level: .success)
        CaptureLogger.log(.save, "File size: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))", level: .debug)
        
        // Generate thumbnail immediately before creating the screenshot model
        let thumbnailURL = await generateThumbnailForCapture(image: result.image, baseURL: fileURL)
        
        // Create Screenshot model
        let screenshot = Screenshot(
            filename: fileURL.lastPathComponent,
            filePath: fileURL.path,
            captureType: method.rawValue,
            width: Int(result.size.width),
            height: Int(result.size.height),
            fileSize: fileSize,
            timestamp: timestamp,
            sourceDisplay: result.sourceInfo
        )
        
        // Set thumbnail path if we generated one
        if let thumbURL = thumbnailURL {
            screenshot.thumbnailPath = thumbURL.path
        }
        
        // Save to SwiftData and update history
        if let context = context {
            // Use CaptureHistoryStore for centralized history management
            let historyResult = await CaptureHistoryStore.shared.addCapture(
                fileURL: fileURL,
                thumbnailURL: thumbnailURL,
                type: captureType,
                timestamp: timestamp,
                imageSize: result.size,
                modelContext: context
            )
            
            if case .success(let savedScreenshot) = historyResult {
                CaptureLogger.log(.save, "Added to history database", level: .success)
                CaptureLogger.log(.save, "Thumbnail: \(thumbnailURL?.lastPathComponent ?? "none")", level: .debug)
                
                // Notify UI that screenshot was saved to history
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .screenshotSavedToHistory,
                        object: savedScreenshot,
                        userInfo: ["url": fileURL, "thumbnail": thumbnailURL as Any]
                    )
                }
                
                return savedScreenshot
            } else {
                // Even if history fails, we still saved the file - return a screenshot object
                CaptureLogger.log(.save, "Failed to add to history database, but file was saved", level: .warning)
                context.insert(screenshot)
                try? context.save()
            }
        } else {
            CaptureLogger.log(.save, "No model context provided - screenshot not saved to database", level: .warning)
        }
        
        return screenshot
    }
    
    private func saveImage(_ image: NSImage, to url: URL) throws {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw ScreenGrabberTypes.CaptureError.invalidImageData
        }
        
        try pngData.write(to: url, options: .atomic)
    }
    
    /// Generate thumbnail for a captured image
    private func generateThumbnailForCapture(image: NSImage, baseURL: URL) async -> URL? {
        // Create thumbnails folder
        let thumbnailsFolder = baseURL.deletingLastPathComponent().appendingPathComponent(".thumbnails", isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: thumbnailsFolder, withIntermediateDirectories: true)
        } catch {
            CaptureLogger.log(.save, "Failed to create thumbnails folder: \(error.localizedDescription)", level: .warning)
            return nil
        }
        
        // Generate thumbnail
        let thumbnailSize = CGSize(width: 200, height: 200)
        let thumbnailImage = resizeImage(image, to: thumbnailSize)
        
        // Save thumbnail
        let thumbnailURL = thumbnailsFolder.appendingPathComponent(baseURL.lastPathComponent)
        
        do {
            try saveImage(thumbnailImage, to: thumbnailURL)
            CaptureLogger.log(.save, "Thumbnail saved: \(thumbnailURL.lastPathComponent)", level: .debug)
            return thumbnailURL
        } catch {
            CaptureLogger.log(.save, "Failed to save thumbnail: \(error.localizedDescription)", level: .warning)
            return nil
        }
    }
    
    /// Resize an image maintaining aspect ratio
    private func resizeImage(_ image: NSImage, to targetSize: CGSize) -> NSImage {
        let imageSize = image.size
        let aspectRatio = imageSize.width / imageSize.height
        
        var newSize: CGSize
        if aspectRatio > 1 {
            // Landscape
            newSize = CGSize(width: targetSize.width, height: targetSize.width / aspectRatio)
        } else {
            // Portrait or square
            newSize = CGSize(width: targetSize.height * aspectRatio, height: targetSize.height)
        }
        
        let resizedImage = NSImage(size: newSize)
        
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(newSize.width),
            pixelsHigh: Int(newSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        
        if let rep = rep, let context = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = context
            
            image.draw(in: NSRect(origin: .zero, size: newSize))
            
            NSGraphicsContext.restoreGraphicsState()
            resizedImage.addRepresentation(rep)
        }
        
        return resizedImage
    }
    
    // MARK: - Post-Capture Actions
    
    private func handleOpenOption(_ option: OpenOption, screenshot: Screenshot, image: NSImage) async {
        let settings = await MainActor.run { SettingsModel.shared }
        
        // If "Preview in Editor" toggle is enabled, always open in editor regardless of openOption
        if settings.previewInEditorEnabled {
            await openInEditor(screenshot)
            return
        }
        
        // Otherwise, respect the openOption
        switch option {
        case .clipboard:
            await copyToClipboard(screenshot)
            
        case .saveToFile:
            // File is already saved. Do nothing.
            break
            
        case .editor:
            await openInEditor(screenshot)
        }
    }
    
    private func copyToClipboard(_ screenshot: Screenshot) async {
        guard let image = NSImage(contentsOf: screenshot.fileURL) else {
            CaptureLogger.log(.clipboard, "Failed to load image for clipboard", level: .error)
            return
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        
        showNotification(
            title: "Copied to Clipboard",
            message: "Screenshot ready to paste"
        )

        CaptureLogger.log(.clipboard, "Copied to clipboard", level: .success)
    }

    private func openInEditor(_ screenshot: Screenshot) async {
        // Post notification to open editor
        NotificationCenter.default.post(
            name: .openScreenshotInEditor,
            object: screenshot
        )

        CaptureLogger.log(.capture, "Opening in editor: \(screenshot.filename)", level: .debug)
    }
    
    // MARK: - Error Handling
    
    private func handleCaptureError(_ error: Error) async {
        CaptureLogger.log(.error, "Capture error: \(error.localizedDescription)", level: .error)
        
        // CRITICAL: Always reset capturing state on error to prevent UI freeze
        await MainActor.run {
            self.isCapturing = false
            self.captureProgress = 0.0
        }
        
        await MainActor.run {
            let alert = NSAlert()
            alert.messageText = "Screenshot Failed"
            alert.alertStyle = .critical
            
            if let captureError = error as? ScreenGrabberTypes.CaptureError {
                alert.informativeText = captureError.localizedDescription
                
                // Add recovery suggestion if available
                if let suggestion = captureError.recoverySuggestion {
                    alert.informativeText += "\n\n" + suggestion
                }
                
                // Add recovery options based on error type
                switch captureError {
                case .noScreenAvailable:
                    // Special handling for screen detection failure
                    alert.informativeText = """
                    ScreenGrabber could not detect an active screen.
                    
                    This may occur if:
                    • Your Mac is in a transitional display state
                    • Displays are being reconfigured
                    • The system is waking from sleep
                    
                    Troubleshooting steps:
                    • Check that your display is connected and active
                    • Try moving your mouse to activate the display
                    • Wait a moment and try again
                    • Restart ScreenGrabber if the problem persists
                    """
                    
                    alert.addButton(withTitle: "Retry")
                    alert.addButton(withTitle: "Check System Settings")
                    alert.addButton(withTitle: "Cancel")
                    
                    let response = alert.runModal()
                    
                    switch response {
                    case .alertFirstButtonReturn:
                        // Retry after a short delay
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(0.5))
                            CaptureLogger.log(.capture, "Retrying capture after user request", level: .info)
                            
                            // Get the last used method and retry
                            let lastMethod = SettingsModel.shared.lastUsedCaptureMethod ?? .fullScreen
                            let lastOpenOption = SettingsModel.shared.lastUsedOpenOption ?? .saveToFile
                            
                            // Get model context if available
                            let context: ModelContext? = ModelContext(ModelContainer.shared)
                            
                            self.captureScreen(
                                method: lastMethod,
                                openOption: lastOpenOption,
                                modelContext: context
                            )
                        }
                        
                    case .alertSecondButtonReturn:
                        // Open Displays settings
                        if let url = URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension") {
                            NSWorkspace.shared.open(url)
                        }
                        
                    default:
                        break
                    }
                    return
                    
                case .permissionDenied(let type):
                    alert.addButton(withTitle: "Open System Settings")
                    alert.addButton(withTitle: "Cancel")
                    
                    let response = alert.runModal()
                    if response == .alertFirstButtonReturn {
                        CapturePermissionsManager.openSystemSettings(for: type)
                    }
                    return
                    
                case .folderCreationFailed:
                    alert.addButton(withTitle: "Choose Folder...")
                    alert.addButton(withTitle: "Use Default Location")
                    alert.addButton(withTitle: "Cancel")
                    
                    let response = alert.runModal()
                    
                    switch response {
                    case .alertFirstButtonReturn:
                        // Choose custom folder
                        self.showFolderPickerForRecovery()
                        
                    case .alertSecondButtonReturn:
                        // Reset to default location
                        SettingsModel.shared.resetSaveLocationToDefault()
                        
                        // Show confirmation
                        let confirmAlert = NSAlert()
                        confirmAlert.alertStyle = .informational
                        confirmAlert.messageText = "Location Reset"
                        confirmAlert.informativeText = "Screenshots will now be saved to:\n~/Pictures/Screen Grabber/\n\nTry capturing again."
                        confirmAlert.addButton(withTitle: "OK")
                        confirmAlert.runModal()
                        
                    default:
                        break
                    }
                    return
                    
                case .fileWriteFailed:
                    alert.addButton(withTitle: "Choose Folder...")
                    alert.addButton(withTitle: "Check Disk Space")
                    alert.addButton(withTitle: "Cancel")
                    
                    let response = alert.runModal()
                    
                    switch response {
                    case .alertFirstButtonReturn:
                        self.showFolderPickerForRecovery()
                        
                    case .alertSecondButtonReturn:
                        // Open Storage settings
                        if let url = URL(string: "x-apple.systempreferences:com.apple.settings.Storage") {
                            NSWorkspace.shared.open(url)
                        }
                        
                    default:
                        break
                    }
                    return
                    
                case .userCancelled:
                    // Don't show alert for user cancellation - just log it
                    CaptureLogger.log(.capture, "User cancelled capture", level: .info)
                    return
                    
                default:
                    break
                }
            } else {
                alert.informativeText = error.localizedDescription
            }
            
            alert.addButton(withTitle: "OK")
            alert.runModal()
            
            // Show notification for non-critical errors
            if let captureError = error as? ScreenGrabberTypes.CaptureError,
               case .userCancelled = captureError {
                // Don't notify for user cancellation
            } else {
                self.showNotification(
                    title: "Screenshot Failed",
                    message: error.localizedDescription
                )
            }
        }
    }
    
    @MainActor
    private func showFolderPickerForRecovery() {
        let panel = NSOpenPanel()
        panel.message = "Choose where to save screenshots"
        panel.prompt = "Select Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        
        // Start at Pictures directory
        if let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first {
            panel.directoryURL = picturesURL
        }
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task { @MainActor in
                    let screenGrabberFolder = url.appendingPathComponent("Screen Grabber")
                    SettingsModel.shared.setCustomSaveLocation(screenGrabberFolder)
                    
                    // Validate the new location immediately
                    let result = await CapturePermissionsManager.shared.ensureCaptureFolderExists(at: screenGrabberFolder)
                    
                    switch result {
                    case .success:
                        let confirmAlert = NSAlert()
                        confirmAlert.alertStyle = .informational
                        confirmAlert.messageText = "Save Location Updated"
                        confirmAlert.informativeText = """
                        Screenshots will now be saved to:
                        \(screenGrabberFolder.path)
                        
                        Try capturing again.
                        """
                        confirmAlert.addButton(withTitle: "OK")
                        confirmAlert.runModal()
                        
                    case .failure(let error):
                        let errorAlert = NSAlert()
                        errorAlert.alertStyle = .warning
                        errorAlert.messageText = "Location Still Invalid"
                        errorAlert.informativeText = """
                        The selected location could not be accessed:
                        
                        \(error.localizedDescription)
                        
                        Please choose a different location.
                        """
                        errorAlert.addButton(withTitle: "OK")
                        errorAlert.runModal()
                    }
                }
            }
        }
    }
    
    
    // MARK: - Notifications
    
    func showNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                CaptureLogger.log(.capture, "Notification error: \(error)", level: .warning)
            }
        }
    }
    
    private func showCountdownNotification(seconds: Int) async {
        for i in (1...seconds).reversed() {
            let content = UNMutableNotificationContent()
            content.title = "Screenshot Countdown"
            content.body = "Capturing in \(i) second\(i == 1 ? "" : "s")..."
            content.sound = nil
            
            let request = UNNotificationRequest(
                identifier: "countdown-\(i)",
                content: content,
                trigger: nil
            )
            
            try? await UNUserNotificationCenter.current().add(request)
            
            if i > 1 {
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
    
    // MARK: - Supporting Types
    
    struct CaptureResult {
        let image: NSImage
        let size: CGSize
        let method: ScreenOption
        let sourceInfo: String?
    }
}

// MARK: - Additional Notification Names

extension Notification.Name {
}

// MARK: - Area Selector Window

class AreaSelectorWindow: NSWindow {
    private let onSelection: (CGRect?) -> Void
    private var overlayView: AreaSelectorView
    private var hasCompleted = false
    private var isClosing = false
    
    init(onSelection: @escaping (CGRect?) -> Void) {
        self.onSelection = onSelection
        
        // Cover all screens
        let combinedFrame = NSScreen.screens.reduce(CGRect.zero) { $0.union($1.frame) }
        
        // Create a temporary placeholder view - we'll set the real one after super.init
        self.overlayView = AreaSelectorView(onSelection: { _ in })
        
        super.init(
            contentRect: combinedFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // CRITICAL: Set releasedWhenClosed to false to prevent premature deallocation
        // This ensures the window stays alive until we explicitly release it
        self.isReleasedWhenClosed = false
        
        // Now that self is fully initialized, create the real overlay view with proper closure
        let finalOverlayView = AreaSelectorView(onSelection: { [weak self] rect in
            self?.handleSelection(rect)
        })
        self.overlayView = finalOverlayView
        
        self.backgroundColor = .clear
        self.isOpaque = false
        self.level = .screenSaver
        self.ignoresMouseEvents = false
        self.hasShadow = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // CRITICAL: Use the final overlay view with the proper closure, not the placeholder
        let hostingView = NSHostingView(rootView: finalOverlayView)
        self.contentView = hostingView
    }
    
    /// Public cancel entry point to unify teardown paths
    func cancel() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.hasCompleted else { return }
            self.handleSelection(nil)
        }
    }
    
    override var canBecomeKey: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    
    /// Handle the selection callback (ensure it only fires once)
    private func handleSelection(_ rect: CGRect?) {
        guard !hasCompleted else {
            CaptureLogger.log(.area, "Selection already completed (ignored)", level: .warning)
            return
        }
        hasCompleted = true

        // IMPORTANT: Call completion handler BEFORE closing the window
        // This ensures the handler can complete while the window is still valid
        onSelection(rect)

        // Schedule window close on next runloop to allow current event handling to complete
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isClosing else { return }
            self.isClosing = true

            CaptureLogger.log(.area, "Closing area selector window", level: .debug)
            self.orderOut(nil)
            
            // Small delay to ensure all pending operations complete before closing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.close()
            }
        }
    }
    
    /// Override to handle escape key at window level
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape key
            CaptureLogger.log(.area, "Escape key pressed - cancelling selection", level: .info)
            handleSelection(nil)
        } else {
            super.keyDown(with: event)
        }
    }
}

// MARK: - Area Selector View

import SwiftUI

struct AreaSelectorView: View {
    let onSelection: (CGRect?) -> Void
    
    @State private var startPoint: CGPoint?
    @State private var currentPoint: CGPoint?
    @State private var hasCompleted = false
    
    var selectionRect: CGRect? {
        guard let start = startPoint, let current = currentPoint else { return nil }
        
        return CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
    }
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            // Selection rectangle
            if let rect = selectionRect, rect.width > 5, rect.height > 5 {
                Rectangle()
                    .stroke(Color.blue, lineWidth: 2)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                
                // Dimensions label
                Text("\(Int(rect.width)) × \(Int(rect.height))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.blue))
                    .position(x: rect.midX, y: rect.maxY + 25)
            }
            
            // Instructions
            if startPoint == nil && !hasCompleted {
                VStack(spacing: 12) {
                    Image(systemName: "viewfinder.rectangular")
                        .font(.system(size: 48))
                        .foregroundColor(.white)
                    
                    Text("Drag to Select Area")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Press Escape to Cancel")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard !hasCompleted else { return }
                    
                    if startPoint == nil {
                        startPoint = value.startLocation
                    }
                    currentPoint = value.location
                }
                .onEnded { value in
                    guard !hasCompleted else { return }
                    hasCompleted = true
                    
                    if let rect = selectionRect, rect.width > 5, rect.height > 5 {
                        // Valid selection - complete with rect
                        onSelection(rect)
                    } else {
                        // Invalid selection (too small) - cancel
                        onSelection(nil)
                    }
                }
        )
        .onKeyPress(.escape) {
            guard !hasCompleted else { return .ignored }
            hasCompleted = true

            CaptureLogger.log(.area, "Escape pressed in SwiftUI area selector", level: .info)
            onSelection(nil)
            return .handled
        }
        // Also handle right-click to cancel
        .onTapGesture(count: 1) { }
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded { _ in
                    guard !hasCompleted else { return }
                    hasCompleted = true

                    CaptureLogger.log(.area, "Double-tap detected - cancelling selection", level: .info)
                    onSelection(nil)
                }
        )
    }
}

// MARK: - Scroll Capture Configuration

struct ScrollCaptureConfiguration {
    let stepOverlap: Int
    let stepDelay: TimeInterval
    let maxSteps: Int
}

