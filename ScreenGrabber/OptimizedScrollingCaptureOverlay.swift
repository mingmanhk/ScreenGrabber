//
//  OptimizedScrollingCaptureOverlay.swift
//  ScreenGrabber
//
//  Optimized full-screen overlay for scrolling capture with smooth animations,
//  reduced CPU usage, and better responsiveness on macOS.
//

import AppKit
import SwiftUI
import Combine

/// High-performance full-screen overlay for scrolling capture
class OptimizedScrollingCaptureOverlay: NSWindow {
    
    private var hostingView: NSHostingView<OptimizedOverlayContentView>?
    private let engine: OptimizedScrollingCaptureEngine
    private var mouseTrackingTimer: Timer?
    private var onCaptureComplete: ((NSImage) -> Void)?
    private var onCancel: (() -> Void)?
    
    // Performance optimization
    private var lastDetectionPoint: NSPoint = .zero
    private var detectionThrottle: TimeInterval = 0.05 // 20 FPS for detection
    private var lastDetectionTime: Date = Date()
    
    // Cached region to avoid flicker
    private var cachedRegion: OptimizedScrollingCaptureEngine.ScrollableRegion?
    
    init(engine: OptimizedScrollingCaptureEngine) {
        self.engine = engine
        
        let screenFrame = NSScreen.main?.frame ?? .zero
        
        super.init(
            contentRect: screenFrame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Window properties for performance
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .screenSaver
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.ignoresMouseEvents = false
        self.hasShadow = false
        self.acceptsMouseMovedEvents = true
        
        // Performance: Disable window server compositing where possible
        self.isMovableByWindowBackground = false
        
        setupContent()
        startMouseTracking()
    }
    
    private func setupContent() {
        let overlayView = OptimizedOverlayContentView(
            engine: engine,
            onArrowClick: { [weak self] region, direction in
                self?.startCapture(region: region, direction: direction)
            },
            onCancel: { [weak self] in
                self?.cancelCapture()
            }
        )
        
        hostingView = NSHostingView(rootView: overlayView)
        hostingView?.frame = self.contentView?.bounds ?? .zero
        hostingView?.autoresizingMask = [.width, .height]
        
        // Performance: Reduce SwiftUI update frequency
        hostingView?.wantsLayer = true
        hostingView?.layer?.drawsAsynchronously = true
        
        self.contentView = hostingView
    }
    
    private func startMouseTracking() {
        // Use timer with throttling for better performance
        mouseTrackingTimer = Timer.scheduledTimer(
            withTimeInterval: detectionThrottle,
            repeats: true
        ) { [weak self] _ in
            guard let self = self else { return }
            self.updateMousePositionThrottled()
        }
        
        // Run on common modes to keep tracking during scroll
        if let timer = mouseTrackingTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    private func updateMousePositionThrottled() {
        let now = Date()
        guard now.timeIntervalSince(lastDetectionTime) >= detectionThrottle else {
            return
        }
        lastDetectionTime = now
        
        guard let screen = NSScreen.main else { return }
        
        let mouseLocation = NSEvent.mouseLocation
        
        // Skip if mouse hasn't moved significantly
        let distance = hypot(
            mouseLocation.x - lastDetectionPoint.x,
            mouseLocation.y - lastDetectionPoint.y
        )
        
        if distance < 5 && cachedRegion != nil {
            return // Use cached region
        }
        
        lastDetectionPoint = mouseLocation
        
        // Convert to screen coordinates
        let screenHeight = screen.frame.height
        let screenPoint = NSPoint(
            x: mouseLocation.x,
            y: screenHeight - mouseLocation.y
        )
        
        // Detect scrollable region
        if let region = engine.detectScrollableRegion(at: screenPoint) {
            if cachedRegion?.windowNumber != region.windowNumber {
                cachedRegion = region
                updateHighlight(region: region)
            }
        } else {
            if cachedRegion != nil {
                cachedRegion = nil
                clearHighlight()
            }
        }
    }
    
    private func updateHighlight(region: OptimizedScrollingCaptureEngine.ScrollableRegion) {
        guard let hostingView = hostingView else { return }
        
        hostingView.rootView = OptimizedOverlayContentView(
            engine: engine,
            highlightedRegion: region,
            onArrowClick: { [weak self] region, direction in
                self?.startCapture(region: region, direction: direction)
            },
            onCancel: { [weak self] in
                self?.cancelCapture()
            }
        )
    }
    
    private func clearHighlight() {
        guard let hostingView = hostingView else { return }
        
        hostingView.rootView = OptimizedOverlayContentView(
            engine: engine,
            highlightedRegion: nil,
            onArrowClick: { [weak self] region, direction in
                self?.startCapture(region: region, direction: direction)
            },
            onCancel: { [weak self] in
                self?.cancelCapture()
            }
        )
    }
    
    private func startCapture(
        region: OptimizedScrollingCaptureEngine.ScrollableRegion,
        direction: OptimizedScrollingCaptureEngine.ScrollDirection
    ) {
        mouseTrackingTimer?.invalidate()
        
        Task {
            do {
                let result = try await engine.captureRegion(region, direction: direction)
                
                await MainActor.run {
                    self.onCaptureComplete?(result)
                    self.close()
                }
            } catch {
                print("[ERROR] Scrolling capture failed: \(error)")
                await MainActor.run {
                    self.onCancel?()
                    self.close()
                }
            }
        }
    }
    
    private func cancelCapture() {
        mouseTrackingTimer?.invalidate()
        engine.cancel()
        onCancel?()
        close()
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            cancelCapture()
        }
    }
    
    func show(onComplete: @escaping (NSImage) -> Void, onCancel: @escaping () -> Void) {
        self.onCaptureComplete = onComplete
        self.onCancel = onCancel
        
        makeKeyAndOrderFront(nil)
        NSCursor.crosshair.set()
    }
    
    override func close() {
        mouseTrackingTimer?.invalidate()
        mouseTrackingTimer = nil
        
        // Clear strong references
        hostingView = nil
        cachedRegion = nil
        onCaptureComplete = nil
        onCancel = nil
        
        NSCursor.arrow.set()
        super.close()
    }
    
    deinit {
        mouseTrackingTimer?.invalidate()
        print("[OVERLAY] OptimizedScrollingCaptureOverlay deallocated")
    }
}

// MARK: - Optimized SwiftUI Content

struct OptimizedOverlayContentView: View {
    
    @ObservedObject var engine: OptimizedScrollingCaptureEngine
    var highlightedRegion: OptimizedScrollingCaptureEngine.ScrollableRegion?
    var onArrowClick: (OptimizedScrollingCaptureEngine.ScrollableRegion, OptimizedScrollingCaptureEngine.ScrollDirection) -> Void
    var onCancel: () -> Void
    
    var body: some View {
        ZStack {
            // Minimal background (only when capturing)
            if engine.isCapturing {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
            }
            
            // Highlighted region with arrows
            if let region = highlightedRegion, !engine.isCapturing {
                OptimizedRegionHighlight(
                    region: region,
                    onArrowClick: onArrowClick
                )
            }
            
            // Instructions (only show when not capturing)
            if !engine.isCapturing && highlightedRegion == nil {
                VStack {
                    OptimizedInstructionsPanel()
                        .padding(.top, 40)
                    Spacer()
                }
                .transition(.opacity)
            }
            
            // Progress overlay
            if engine.isCapturing, let progress = engine.progress {
                OptimizedProgressOverlay(
                    progress: progress,
                    onCancel: {
                        engine.cancel()
                        onCancel()
                    }
                )
                .transition(.scale.combined(with: .opacity))
            }
            
            // Cancel button
            if !engine.isCapturing {
                VStack {
                    Spacer()
                    
                    Button(action: onCancel) {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                            Text("Cancel")
                                .fontWeight(.semibold)
                            Text("(ESC)")
                                .font(.caption)
                                .opacity(0.7)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.red.opacity(0.9))
                                .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 40)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: engine.isCapturing)
        .animation(.easeInOut(duration: 0.2), value: highlightedRegion?.windowNumber)
    }
}

// MARK: - Optimized Region Highlight

struct OptimizedRegionHighlight: View {
    let region: OptimizedScrollingCaptureEngine.ScrollableRegion
    let onArrowClick: (OptimizedScrollingCaptureEngine.ScrollableRegion, OptimizedScrollingCaptureEngine.ScrollDirection) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            let frame = convertFrame(region.frame, in: geometry.size)
            
            ZStack {
                // Animated highlight border
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [.orange, .orange.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
                    .shadow(color: .orange.opacity(0.6), radius: 12)
                
                // Direction arrows
                if region.scrollDirection.hasVertical {
                    OptimizedVerticalArrow(region: region, onTap: onArrowClick)
                        .position(x: frame.midX, y: frame.midY)
                }
                
                if region.scrollDirection.hasHorizontal {
                    OptimizedHorizontalArrow(region: region, onTap: onArrowClick)
                        .position(x: frame.midX + 120, y: frame.midY)
                }
                
                // App name label
                if let appName = region.appName {
                    Text(appName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.7))
                        )
                        .position(x: frame.midX, y: frame.minY - 20)
                }
            }
        }
    }
    
    private func convertFrame(_ cgFrame: CGRect, in size: CGSize) -> CGRect {
        return CGRect(
            x: cgFrame.origin.x,
            y: size.height - cgFrame.origin.y - cgFrame.height,
            width: cgFrame.width,
            height: cgFrame.height
        )
    }
}

// MARK: - Optimized Arrow Buttons

struct OptimizedVerticalArrow: View {
    let region: OptimizedScrollingCaptureEngine.ScrollableRegion
    let onTap: (OptimizedScrollingCaptureEngine.ScrollableRegion, OptimizedScrollingCaptureEngine.ScrollDirection) -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: { onTap(region, .vertical) }) {
            VStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 54, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .blue.opacity(0.5), radius: isHovered ? 20 : 10)
                
                Text("Scroll Down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
            .scaleEffect(isHovered ? 1.15 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct OptimizedHorizontalArrow: View {
    let region: OptimizedScrollingCaptureEngine.ScrollableRegion
    let onTap: (OptimizedScrollingCaptureEngine.ScrollableRegion, OptimizedScrollingCaptureEngine.ScrollDirection) -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: { onTap(region, .horizontal) }) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 54, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .purple.opacity(0.5), radius: isHovered ? 20 : 10)
                
                Text("Scroll Right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
            .scaleEffect(isHovered ? 1.15 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Optimized Instructions Panel

struct OptimizedInstructionsPanel: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Hover over a scrollable window")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Text("Click the arrow to capture entire scrolling content")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        )
    }
}

// MARK: - Optimized Progress Overlay

struct OptimizedProgressOverlay: View {
    let progress: OptimizedScrollingCaptureEngine.CaptureProgress
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Animated capture icon
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 8)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .rotationEffect(.degrees(Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 2) * 180))
                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: Date())
                
                Image(systemName: "camera.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
            }
            
            // Progress info
            VStack(spacing: 12) {
                Text(progress.statusMessage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    Text("Slice:")
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(progress.currentSlice)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.blue)
                    
                    if let total = progress.totalSlices {
                        Text("/ \(total)")
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                // Time remaining estimate
                if let timeRemaining = progress.estimatedTimeRemaining {
                    Text("~\(Int(timeRemaining))s remaining")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            // Cancel button
            Button(action: onCancel) {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                    Text("Cancel Capture")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.red.opacity(0.9))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.5), radius: 40, y: 20)
        )
    }
}

// MARK: - Preview

#Preview {
    OptimizedOverlayContentView(
        engine: OptimizedScrollingCaptureEngine(),
        highlightedRegion: nil,
        onArrowClick: { _, _ in },
        onCancel: { }
    )
}
