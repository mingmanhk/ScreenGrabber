//
//  ScrollingCaptureOverlayWindow.swift
//  ScreenGrabber
//
//  Full-screen overlay for scrolling capture mode showing highlights and direction arrows.
//

import AppKit
import SwiftUI

/// Full-screen transparent window that shows scrollable region highlights and direction arrows
class ScrollingCaptureOverlayWindow: NSWindow {
    
    private var hostingView: NSHostingView<ScrollingCaptureOverlayView>?
    private let engine: ScrollingCaptureEngine
    private var mouseTrackingTimer: Timer?
    private var onCaptureComplete: ((NSImage) -> Void)?
    private var onCancel: (() -> Void)?
    
    init(engine: ScrollingCaptureEngine) {
        self.engine = engine
        
        // Get main screen frame
        let screenFrame = NSScreen.main?.frame ?? .zero
        
        // Create borderless, transparent window
        super.init(
            contentRect: screenFrame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .screenSaver // Above everything
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.ignoresMouseEvents = false
        self.hasShadow = false
        
        setupContent()
        startMouseTracking()
    }
    
    private func setupContent() {
        let overlayView = ScrollingCaptureOverlayView(
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
        
        self.contentView = hostingView
    }
    
    private func startMouseTracking() {
        // Track mouse position to detect scrollable regions
        mouseTrackingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateMousePosition()
        }
    }
    
    private func updateMousePosition() {
        guard let screen = NSScreen.main else { return }
        
        let mouseLocation = NSEvent.mouseLocation
        
        // Convert to screen coordinates (flip Y)
        let screenHeight = screen.frame.height
        let screenPoint = NSPoint(
            x: mouseLocation.x,
            y: screenHeight - mouseLocation.y
        )
        
        // Detect scrollable region at this point
        if let region = engine.detectScrollableRegion(at: screenPoint) {
            // Update UI to show highlight
            updateHighlight(region: region)
        } else {
            clearHighlight()
        }
    }
    
    private func updateHighlight(region: ScrollingCaptureEngine.ScrollableRegion) {
        // Update SwiftUI view state
        if let hostingView = hostingView {
            hostingView.rootView = ScrollingCaptureOverlayView(
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
    }
    
    private func clearHighlight() {
        if let hostingView = hostingView {
            hostingView.rootView = ScrollingCaptureOverlayView(
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
    }
    
    private func startCapture(region: ScrollingCaptureEngine.ScrollableRegion, direction: ScrollingCaptureEngine.ScrollDirection) {
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
        // ESC to cancel
        if event.keyCode == 53 { // ESC
            cancelCapture()
        }
    }
    
    func show(onComplete: @escaping (NSImage) -> Void, onCancel: @escaping () -> Void) {
        self.onCaptureComplete = onComplete
        self.onCancel = onCancel
        
        makeKeyAndOrderFront(nil)
        
        // Show cursor as crosshair
        NSCursor.crosshair.set()
    }
    
    override func close() {
        mouseTrackingTimer?.invalidate()
        NSCursor.arrow.set()
        super.close()
    }
}

// MARK: - SwiftUI Overlay View

struct ScrollingCaptureOverlayView: View {
    
    @ObservedObject var engine: ScrollingCaptureEngine
    var highlightedRegion: ScrollingCaptureEngine.ScrollableRegion?
    var onArrowClick: (ScrollingCaptureEngine.ScrollableRegion, ScrollingCaptureEngine.ScrollDirection) -> Void
    var onCancel: () -> Void
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.1)
                .ignoresSafeArea()
            
            // Highlighted region outline
            if let region = highlightedRegion {
                RegionHighlight(region: region, onArrowClick: onArrowClick)
            }
            
            // Instructions at top
            VStack {
                if !engine.isCapturing {
                    InstructionsPanel()
                        .padding(.top, 40)
                }
                
                Spacer()
            }
            
            // Progress indicator during capture
            if engine.isCapturing, let progress = engine.progress {
                ProgressOverlay(progress: progress, onCancel: {
                    engine.cancel()
                    onCancel()
                })
            }
            
            // Cancel button (always visible)
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
                                .foregroundColor(.white.opacity(0.7))
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
            }
        }
    }
}

// MARK: - Region Highlight

struct RegionHighlight: View {
    let region: ScrollingCaptureEngine.ScrollableRegion
    let onArrowClick: (ScrollingCaptureEngine.ScrollableRegion, ScrollingCaptureEngine.ScrollDirection) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            // Convert CGRect to SwiftUI coordinates
            let frame = convertFrame(region.frame, in: geometry.size)
            
            ZStack {
                // Highlight border
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.orange, lineWidth: 4)
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
                    .shadow(color: .orange.opacity(0.5), radius: 10)
                
                // Direction arrows
                if region.scrollDirection.hasVertical {
                    VerticalArrowButton(region: region, onTap: onArrowClick)
                        .position(x: frame.midX, y: frame.midY)
                }
                
                if region.scrollDirection.hasHorizontal {
                    HorizontalArrowButton(region: region, onTap: onArrowClick)
                        .position(x: frame.midX, y: frame.midY)
                }
            }
        }
    }
    
    private func convertFrame(_ cgFrame: CGRect, in size: CGSize) -> CGRect {
        // CGRect is in screen coordinates, convert to SwiftUI coordinates
        return CGRect(
            x: cgFrame.origin.x,
            y: size.height - cgFrame.origin.y - cgFrame.height,
            width: cgFrame.width,
            height: cgFrame.height
        )
    }
}

// MARK: - Arrow Buttons

struct VerticalArrowButton: View {
    let region: ScrollingCaptureEngine.ScrollableRegion
    let onTap: (ScrollingCaptureEngine.ScrollableRegion, ScrollingCaptureEngine.ScrollDirection) -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            onTap(region, .vertical)
        }) {
            VStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                Text("Scroll Down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.7))
                    )
            }
            .scaleEffect(isHovered ? 1.1 : 1.0)
            .animation(.spring(response: 0.3), value: isHovered)
            .shadow(color: .blue.opacity(0.5), radius: isHovered ? 20 : 10)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct HorizontalArrowButton: View {
    let region: ScrollingCaptureEngine.ScrollableRegion
    let onTap: (ScrollingCaptureEngine.ScrollableRegion, ScrollingCaptureEngine.ScrollDirection) -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            onTap(region, .horizontal)
        }) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Scroll Right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.7))
                    )
            }
            .scaleEffect(isHovered ? 1.1 : 1.0)
            .animation(.spring(response: 0.3), value: isHovered)
            .shadow(color: .purple.opacity(0.5), radius: isHovered ? 20 : 10)
        }
        .buttonStyle(.plain)
        .offset(x: 120) // Offset to the right to avoid overlap
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Instructions Panel

struct InstructionsPanel: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                
                Text("Hover over a scrollable window or browser")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Text("Click the arrow to start automatic scrolling capture")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.8))
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        )
    }
}

// MARK: - Progress Overlay

struct ProgressOverlay: View {
    let progress: ScrollingCaptureEngine.CaptureProgress
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Progress info
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.blue)
                
                Text(progress.statusMessage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    Text("Slice:")
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(progress.currentSlice)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.blue)
                    
                    if let total = progress.totalSlices {
                        Text("/ \(total)")
                            .foregroundColor(.white.opacity(0.7))
                    }
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
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.85))
                .shadow(color: .black.opacity(0.5), radius: 30, y: 15)
        )
    }
}

// MARK: - Preview

#Preview {
    ScrollingCaptureOverlayView(
        engine: ScrollingCaptureEngine(),
        highlightedRegion: nil,
        onArrowClick: { _, _ in },
        onCancel: { }
    )
}
