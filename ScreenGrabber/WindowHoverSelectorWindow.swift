//
//  WindowHoverSelectorWindow.swift
//  ScreenGrabber
//
//  Snagit-style window capture: transparent full-screen overlay that highlights
//  the window under the mouse cursor. Click to capture, Esc to cancel.
//
//  Architecture follows OptimizedScrollingCaptureOverlay.swift.
//

import AppKit
import SwiftUI
import Combine

// MARK: - ViewModel

@MainActor
final class WindowHoverViewModel: ObservableObject {
    /// CGWindowListCopyWindowInfo bounds (top-left origin) for the highlighted window.
    /// `nil` means no window is under the cursor.
    @Published var highlightBounds: CGRect?
    @Published var windowLabel: String = ""
}

// MARK: - Overlay Window

final class WindowHoverSelectorWindow: NSWindow {

    private let viewModel = WindowHoverViewModel()
    private let availableWindows: [SelectableWindow]
    private var highlightedWindow: SelectableWindow?
    private var mouseTrackingTimer: Timer?

    var onWindowSelected: ((SelectableWindow) -> Void)?
    var onCancelled: (() -> Void)?

    // MARK: Init

    init(availableWindows: [SelectableWindow]) {
        self.availableWindows = availableWindows

        // Cover all attached screens
        let combinedFrame = NSScreen.screens.reduce(CGRect.zero) { $0.union($1.frame) }

        super.init(
            contentRect: combinedFrame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hasShadow = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true

        let overlayView = WindowHoverOverlayView(viewModel: viewModel)
        let hosting = NSHostingView(rootView: overlayView)
        hosting.frame = contentView?.bounds ?? .zero
        hosting.autoresizingMask = [.width, .height]
        contentView = hosting

        startMouseTracking()
    }

    deinit {
        mouseTrackingTimer?.invalidate()
    }

    // MARK: Mouse Tracking

    private func startMouseTracking() {
        mouseTrackingTimer = Timer.scheduledTimer(
            withTimeInterval: 0.033,    // ~30 fps
            repeats: true
        ) { [weak self] _ in
            self?.updateMousePosition()
        }
        if let timer = mouseTrackingTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    private func updateMousePosition() {
        let mouse = NSEvent.mouseLocation

        // NSEvent.mouseLocation is in bottom-left origin coords.
        // CGWindowListCopyWindowInfo uses top-left origin coords.
        // Identify which screen contains the cursor for the Y-flip.
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) })
                  ?? NSScreen.main
        let screenH = screen?.frame.height ?? (NSScreen.main?.frame.height ?? 0)
        let cgPoint = CGPoint(x: mouse.x, y: screenH - mouse.y)

        // WindowPickerService walks the CG window list in z-order (front → back).
        if let info = WindowPickerService.shared.getWindowAtPoint(cgPoint),
           let match = availableWindows.first(where: { $0.id == info.windowID }) {
            if highlightedWindow?.id != match.id {
                highlightedWindow = match
                DispatchQueue.main.async { [weak viewModel = self.viewModel] in
                    viewModel?.highlightBounds = info.bounds
                    viewModel?.windowLabel = match.displayTitle
                }
            }
        } else {
            if highlightedWindow != nil {
                highlightedWindow = nil
                DispatchQueue.main.async { [weak viewModel = self.viewModel] in
                    viewModel?.highlightBounds = nil
                    viewModel?.windowLabel = ""
                }
            }
        }
    }

    // MARK: Events

    override func mouseDown(with event: NSEvent) {
        mouseTrackingTimer?.invalidate()
        mouseTrackingTimer = nil
        if let window = highlightedWindow {
            onWindowSelected?(window)
        } else {
            onCancelled?()
        }
        orderOut(nil)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            mouseTrackingTimer?.invalidate()
            mouseTrackingTimer = nil
            onCancelled?()
            orderOut(nil)
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - SwiftUI Overlay View

struct WindowHoverOverlayView: View {
    @ObservedObject var viewModel: WindowHoverViewModel

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Dim everything
                Color.black.opacity(0.25)
                    .ignoresSafeArea()

                if let b = viewModel.highlightBounds {
                    // Cut the highlighted window out of the dim layer
                    Color.clear
                        .frame(width: b.width, height: b.height)
                        .position(x: b.midX, y: b.midY)
                        .blendMode(.destinationOut)

                    // Accent-colored border
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.accentColor, lineWidth: 3)
                        .frame(width: b.width, height: b.height)
                        .position(x: b.midX, y: b.midY)

                    // App / window name label above the highlight
                    Text(viewModel.windowLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.accentColor))
                        .position(x: b.midX, y: max(b.minY - 22, 22))
                }

                // Dismiss hint at the bottom centre
                Text("Click to capture  •  Esc to cancel")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
                    .position(x: geo.size.width / 2, y: geo.size.height - 40)
            }
        }
        .compositingGroup()   // required for .blendMode(.destinationOut) cut-out
        .ignoresSafeArea()
    }
}
