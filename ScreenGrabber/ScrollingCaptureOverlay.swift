//
//  ScrollingCaptureOverlay.swift (DEPRECATED)
//  ScreenGrabber
//
//  ⚠️ This file is DEPRECATED and replaced by ScrollingCaptureOverlayWindow.swift
//  It is kept only for temporary backwards compatibility.
//

import SwiftUI
import AppKit

/// DEPRECATED: Use ScrollingCaptureOverlayWindow instead
@available(*, deprecated, message: "Use ScrollingCaptureOverlayWindow instead")
class ScrollingCaptureOverlay: NSWindow {
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 140),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        print("[DEPRECATED] ScrollingCaptureOverlay - Use ScrollingCaptureOverlayWindow instead")
    }
    
    func updateProgress(current: Int, total: Int?, status: String) {
        print("[DEPRECATED] updateProgress called - Use ScrollingCaptureEngine instead")
    }
    
    func showCancellable(onCancel: @escaping () -> Void) {
        print("[DEPRECATED] showCancellable called - Use ScrollingCaptureEngine instead")
    }
    
    func dismiss(completion: (() -> Void)? = nil) {
        print("[DEPRECATED] dismiss called")
        completion?()
    }
}

// MARK: - Deprecated Progress View
@available(*, deprecated)
struct ScrollingProgressView: View {
    var currentFrame: Int = 0
    var estimatedTotal: Int? = nil
    var status: String = "Preparing..."
    var onCancel: (() -> Void)? = nil
    
    var body: some View {
        VStack {
            Text("DEPRECATED: Use ScrollingCaptureEngine")
                .font(.caption)
                .foregroundColor(.red)
        }
        .padding()
    }
}



