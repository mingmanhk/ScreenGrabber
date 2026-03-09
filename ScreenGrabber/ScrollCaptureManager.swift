//
//  ScrollCaptureManager.swift (DEPRECATED)
//  ScreenGrabber
//
//  ⚠️ This file is DEPRECATED and replaced by ScrollingCaptureEngine.swift
//  It is kept only for temporary backwards compatibility.
//  All new code should use ScrollingCaptureEngine instead.
//

import AppKit
import ApplicationServices
import Combine

/// DEPRECATED: Use ScrollingCaptureEngine instead
@available(*, deprecated, message: "Use ScrollingCaptureEngine instead")
public final class ScrollCaptureManager: ObservableObject {
    
    // MARK: - Deprecated Types (kept for compatibility)
    
    @available(*, deprecated, message: "Configuration is now in ScrollingCaptureEngine.Configuration")
    public struct Options {
        var stepOverlap: CGFloat = 50
        var stepDelay: TimeInterval = 0.3
        var maxSteps: Int = 200
        var captureScale: CGFloat = NSScreen.main?.backingScaleFactor ?? 2.0
        var edgeMatchingEnabled: Bool = true
        var maxTraversalDepth: Int = 30
        
        public init() {}
        
        // Removed duplicate fromAppStorage() - it is defined in ScrollCaptureSettingsView.swift extension
    }

    @available(*, deprecated, message: "Use ScrollingCaptureEngine.CaptureError instead")
    public enum CaptureError: Error, LocalizedError {
        case noScreen
        case captureFailed
        case stitchingFailed
        case unableToScroll
        case cancelled
        case accessibilityPermissionDenied
        case invalidCaptureArea
        
        public var errorDescription: String? {
            switch self {
            case .noScreen: return "No screen found for capture area"
            case .captureFailed: return "Failed to capture screen content"
            case .stitchingFailed: return "Failed to stitch captured frames"
            case .unableToScroll: return "Unable to scroll the selected area"
            case .cancelled: return "Capture was cancelled"
            case .accessibilityPermissionDenied: return "Accessibility permission is required"
            case .invalidCaptureArea: return "Invalid capture area selected"
            }
        }
    }

    @available(*, deprecated)
    public enum CaptureMode {
        case region
        case entireScreen
    }

    // MARK: - Properties
    
    private let options: Options
    @Published public var hasAccessibilityPermission: Bool = false
    @Published public var isCapturing: Bool = false
    @Published public var captureProgress: Double = 0.0
    @Published public var statusMessage: String = ""

    // MARK: - Initializer
    
    public init(options: Options = Options()) {
        self.options = options
        self.hasAccessibilityPermission = Self.checkAccessibilityPermissionStatic()
    }
    
    // MARK: - Public API (Deprecated stubs)
    
    @available(*, deprecated, message: "Use ScrollingCaptureEngine.cancel() instead")
    public func cancelCapture() {
        print("[DEPRECATED] ScrollCaptureManager.cancelCapture() - Use ScrollingCaptureEngine instead")
    }
    
    public func ensureAccessibilityPermission() async {
        // Placeholder for async permission check
        self.hasAccessibilityPermission = Self.checkAccessibilityPermissionStatic()
    }
    
    public func checkAccessibilityPermission() -> Bool {
        return Self.checkAccessibilityPermissionStatic()
    }
    
    private static func checkAccessibilityPermissionStatic() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    public func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
    
    @available(*, deprecated)
    @MainActor
    public func startCapture(in globalRect: CGRect, mode: CaptureMode = .region) async throws -> NSImage {
        print("[DEPRECATED] ScrollCaptureManager.startCapture() - Use ScrollingCaptureEngine instead")
        throw CaptureError.cancelled
    }
    
    // Singleton for backwards compatibility
    public static let shared = ScrollCaptureManager()
}

