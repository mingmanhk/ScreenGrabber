import SwiftUI
import WebKit
import ApplicationServices
import ScreenCaptureKit

/// Unified Screen Capture Example
/// Demonstrates the redesigned flow for Area, Window, and Full Screen capture
/// with optional scrolling support.
struct WebViewScrollCaptureExample: View {
    // MARK: - State
    @StateObject private var captureEngine = ScrollingCaptureEngine()
    @State private var webView: WKWebView?
    @State private var capturedImage: NSImage?
    
    // UI State
    @State private var selectedMode: CaptureMode = .region
    @State private var isScrollingEnabled: Bool = false
    @State private var isCapturing: Bool = false
    @State private var statusMessage: String = "Ready"
    
    // MARK: - Enums
    
    enum CaptureMode: String, CaseIterable, Identifiable {
        case region = "Select Area"
        case window = "Select Window"
        case screen = "Full Screen"
        
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .region: return "crop"
            case .window: return "macwindow"
            case .screen: return "display"
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar / Controls
            HStack(spacing: 20) {
                Picker("Capture Mode", selection: $selectedMode) {
                    ForEach(CaptureMode.allCases) { mode in
                        Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 350)
                
                Toggle("Scrolling Capture", isOn: $isScrollingEnabled)
                    .toggleStyle(.switch)
                    .help("Auto-scroll to capture full content")
                
                Button(action: startCaptureFlow) {
                    Label("Start Capture", systemImage: "camera.fill")
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCapturing)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Content Area
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                
                if let image = capturedImage {
                    VStack {
                        HStack {
                            Text("Capture Result")
                                .font(.headline)
                            Spacer()
                            Button("Clear") { capturedImage = nil }
                        }
                        .padding([.top, .horizontal])
                        
                        ScrollView {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(nsColor: .textBackgroundColor))
                                .cornerRadius(8)
                        }
                        .padding()
                    }
                } else {
                    // Preview content (WebView) to test capture against
                    VStack {
                        Text("Test Content (Web View) - Try capturing this!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                        
                        WebViewRepresentable(webView: $webView)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(radius: 2)
                            .padding()
                    }
                }
                
                if isCapturing {
                    ZStack {
                        Color.black.opacity(0.3)
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text(statusMessage)
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(.regularMaterial, in: Capsule())
                        }
                    }
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onChange(of: captureEngine.progress) { oldValue, newValue in
            if let progress = newValue {
                self.statusMessage = progress.statusMessage
            }
        }
    }
    
    // MARK: - Logic
    
    private func startCaptureFlow() {
        isCapturing = true
        statusMessage = "Waiting for selection..."
        
        // Hide app window to clear view for capture
        NSApp.hide(nil)
        
        Task {
            // Give time for window to hide
            try? await Task.sleep(nanoseconds: 200_000_000)
            
            // 1. Selection Phase
            guard let selection = await SelectionOverlayManager.shared.select(mode: selectedMode) else {
                print("Selection cancelled")
                await MainActor.run {
                    NSApp.unhide(nil)
                    isCapturing = false
                    statusMessage = "Cancelled"
                }
                return
            }
            
            // 2. Capture Phase
            await MainActor.run {
                statusMessage = isScrollingEnabled ? "Scrolling & Capturing..." : "Capturing..."
            }
            
            do {
                let image: NSImage
                
                if isScrollingEnabled {
                    // Use the new ScrollingCaptureEngine
                    // Detect scrollable region from the selection
                    let scrollDirection: ScrollingCaptureEngine.ScrollDirection = .vertical
                    
                    // Create a scrollable region from the selection
                    let region = ScrollingCaptureEngine.ScrollableRegion(
                        windowNumber: 0, // This would need proper window detection
                        frame: selection,
                        scrollDirection: scrollDirection,
                        axElement: nil
                    )
                    
                    image = try await captureEngine.captureRegion(region, direction: scrollDirection)
                } else {
                    // Static capture fallback
                    image = try await takeStaticCapture(rect: selection)
                }
                
                await MainActor.run {
                    NSApp.unhide(nil)
                    NSApp.activate(ignoringOtherApps: true)
                    self.capturedImage = image
                    self.isCapturing = false
                    self.statusMessage = "Done"
                }
                
            } catch {
                print("Capture Error: \(error.localizedDescription)")
                await MainActor.run {
                    NSApp.unhide(nil)
                    NSApp.activate(ignoringOtherApps: true)
                    self.isCapturing = false
                    self.statusMessage = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    @MainActor
    private func takeStaticCapture(rect: CGRect) async throws -> NSImage {
        // SCScreenshotManager replacement for deprecated CGWindowListCreateImage
        // Requires macOS 14.0+
        
        guard let mainHeight = NSScreen.screens.first?.frame.height else {
            throw ScrollingCaptureEngine.CaptureError.captureFailure
        }
        
        // 1. Convert Cocoa Rect (Bottom-Left) to Quartz Rect (Top-Left)
        let quartzY = mainHeight - (rect.origin.y + rect.height)
        let quartzRect = CGRect(x: rect.origin.x, y: quartzY, width: rect.width, height: rect.height)
        
        // 2. Get shareable content to find displays
        let content = try await SCShareableContent.current
        
        // Find the display that contains the largest portion of this rect
        guard let display = content.displays.max(by: { d1, d2 in
            let area1 = d1.frame.intersection(quartzRect).width * d1.frame.intersection(quartzRect).height
            let area2 = d2.frame.intersection(quartzRect).width * d2.frame.intersection(quartzRect).height
            return area1 < area2
        }) else {
            throw ScrollingCaptureEngine.CaptureError.captureFailure
        }
        
        // 3. Configure Filter & Stream
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        
        // SCStreamConfiguration sourceRect is in the content's coordinate space (Display Local)
        let localOriginX = quartzRect.origin.x - display.frame.origin.x
        let localOriginY = quartzRect.origin.y - display.frame.origin.y
        let localRect = CGRect(x: localOriginX, y: localOriginY, width: quartzRect.width, height: quartzRect.height)
        
        config.sourceRect = localRect
        
        // Calculate output dimensions
        // SCDisplay width is pixels, frame is points.
        let scale = Double(display.width) / display.frame.width
        config.width = Int(localRect.width * scale)
        config.height = Int(localRect.height * scale)
        config.showsCursor = false
        
        // 4. Capture
        let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return NSImage(cgImage: cgImage, size: rect.size)
    }
}

// MARK: - WebView Wrapper

struct WebViewRepresentable: NSViewRepresentable {
    @Binding var webView: WKWebView?
    
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        if let url = URL(string: "https://www.apple.com/mac-pro/") { // Long page for testing
            webView.load(URLRequest(url: url))
        }
        DispatchQueue.main.async { self.webView = webView }
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

// MARK: - Selection Overlay System

@MainActor
final class SelectionOverlayManager {
    static let shared = SelectionOverlayManager()
    
    private var windows: [SelectionWindow] = []
    private var continuation: CheckedContinuation<CGRect?, Never>?
    
    func select(mode: WebViewScrollCaptureExample.CaptureMode) async -> CGRect? {
        // Clear previous
        cleanup()
        
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            
            // Create overlay on every screen
            for screen in NSScreen.screens {
                let window = SelectionWindow(
                    screen: screen,
                    mode: mode,
                    onSelection: { [weak self] rect in
                        self?.finish(with: rect)
                    },
                    onCancel: { [weak self] in
                        self?.finish(with: nil)
                    }
                )
                window.orderFront(nil)
                windows.append(window)
            }
            
            // Activate app to ensure overlays catch events
            // We need the overlay to be key to catch ESC
            NSApp.activate(ignoringOtherApps: true)
            windows.first?.makeKey()
        }
    }
    
    private func finish(with rect: CGRect?) {
        continuation?.resume(returning: rect)
        continuation = nil
        cleanup()
    }
    
    private func cleanup() {
        windows.forEach { $0.close() }
        windows.removeAll()
    }
}

// Custom Window for Selection
class SelectionWindow: NSWindow {
    private let mode: WebViewScrollCaptureExample.CaptureMode
    private let onSelection: (CGRect) -> Void
    private let onCancel: () -> Void
    
    init(screen: NSScreen, 
         mode: WebViewScrollCaptureExample.CaptureMode,
         onSelection: @escaping (CGRect) -> Void,
         onCancel: @escaping () -> Void) {
        
        self.mode = mode
        self.onSelection = onSelection
        self.onCancel = onCancel
        
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        
        // Ensure it sits above mostly everything
        self.level = .screenSaver
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        self.contentView = SelectionView(frame: screen.frame, mode: mode, window: self)
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            onCancel()
        }
    }
    
    func complete(with rect: CGRect) {
        onSelection(rect)
    }
}

// View Handling Mouse Events
class SelectionView: NSView {
    let mode: WebViewScrollCaptureExample.CaptureMode
    weak var overlayWindow: SelectionWindow?
    
    // State
    private var startPoint: NSPoint?
    private var currentRect: NSRect?
    private var hoveredWindowRect: NSRect?
    private var trackingArea: NSTrackingArea?
    
    init(frame: NSRect, mode: WebViewScrollCaptureExample.CaptureMode, window: SelectionWindow) {
        self.mode = mode
        self.overlayWindow = window
        super.init(frame: frame)
        self.wantsLayer = true
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = trackingArea { removeTrackingArea(t) }
        
        let options: NSTrackingArea.Options = [.mouseMoved, .activeAlways, .mouseEnteredAndExited]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        // Dim background (unified for all modes to show "active selection state")
        NSColor.black.withAlphaComponent(0.3).setFill()
        dirtyRect.fill()
        
        if mode == .screen {
            // Draw highlight border for screen
            NSColor.systemBlue.setStroke()
            let path = NSBezierPath(rect: bounds.insetBy(dx: 4, dy: 4))
            path.lineWidth = 8
            path.stroke()
            
            drawLabel("Click to Capture Screen", in: bounds)
        }
        else if mode == .region {
            if let r = currentRect {
                // Clear the selection area (hole punch)
                NSColor.clear.setFill()
                r.fill(using: .copy)
                
                // Border
                NSColor.white.setStroke()
                let path = NSBezierPath(rect: r)
                path.lineWidth = 2
                path.setLineDash([5, 3], count: 2, phase: 0)
                path.stroke()
                
                drawLabel("\(Int(r.width)) × \(Int(r.height))", in: r)
            } else {
                drawLabel("Click and Drag to Select Area", in: bounds)
            }
        }
        else if mode == .window {
            if let r = hoveredWindowRect {
                // Highlight window
                NSColor.systemGreen.withAlphaComponent(0.3).setFill()
                r.fill(using: .sourceOver)
                
                NSColor.systemGreen.setStroke()
                NSBezierPath(rect: r).stroke()
            }
            drawLabel("Click a Window to Select", in: bounds)
        }
    }
    
    private func drawLabel(_ text: String, in rect: NSRect) {
        let str = NSAttributedString(string: text, attributes: [
            .font: NSFont.boldSystemFont(ofSize: 20),
            .foregroundColor: NSColor.white,
            .shadow: NSShadow()
        ])
        let size = str.size()
        let origin = NSPoint(
            x: rect.midX - size.width/2,
            y: rect.midY - size.height/2
        )
        // Ensure label stays on screen
        let clampedOrigin = NSPoint(
            x: max(bounds.minX + 10, min(bounds.maxX - size.width - 10, origin.x)),
            y: max(bounds.minY + 10, min(bounds.maxY - size.height - 10, origin.y))
        )
        str.draw(at: clampedOrigin)
    }
    
    // MARK: - Mouse Events
    
    override func mouseDown(with event: NSEvent) {
        startPoint = event.locationInWindow
        
        if mode == .screen {
            // Capture this entire screen
            // The overlay covers the screen, so 'bounds' is the screen rect in local coords (0,0 based)
            // We need Global Screen Coordinates.
            if let screen = overlayWindow?.screen {
                overlayWindow?.complete(with: screen.frame)
            }
        }
        else if mode == .window {
            if let r = hoveredWindowRect {
                // 'r' is already converted to global Cocoa coordinates in findWindowUnderMouse
                overlayWindow?.complete(with: r)
            }
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard mode == .region, let start = startPoint else { return }
        
        let current = event.locationInWindow
        let minX = min(start.x, current.x)
        let minY = min(start.y, current.y)
        let w = abs(current.x - start.x)
        let h = abs(current.y - start.y)
        
        currentRect = NSRect(x: minX, y: minY, width: w, height: h)
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        if mode == .region, let rect = currentRect, rect.width > 5, rect.height > 5 {
            // Convert local window coordinates to Global Cocoa Screen Coordinates
            let screenFrame = window?.screen?.frame ?? .zero
            let globalRect = NSRect(
                x: screenFrame.minX + rect.minX,
                y: screenFrame.minY + rect.minY,
                width: rect.width,
                height: rect.height
            )
            
            overlayWindow?.complete(with: globalRect)
        } else {
            if mode == .region {
                currentRect = nil
                needsDisplay = true
            }
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        if mode == .window {
            self.hoveredWindowRect = findWindowUnderMouse()
            needsDisplay = true
        }
    }
    
    private func findWindowUnderMouse() -> CGRect? {
        let mouseLoc = NSEvent.mouseLocation // Global Cocoa coordinates (Bottom-Left 0,0)
        
        // CGWindowList returns Quartz coordinates (Top-Left 0,0)
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return nil }
        
        // Helper to convert Quartz Rect to Cocoa Rect
        guard let mainHeight = NSScreen.screens.first?.frame.height else { return nil }
        
        for entry in list {
            if let boundsDict = entry[kCGWindowBounds as String] as? [String: Any],
               let quartzRect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) {
                
                // Convert Quartz Rect to Cocoa Rect for hit testing against mouseLoc
                let cocoaY = mainHeight - (quartzRect.origin.y + quartzRect.height)
                let cocoaRect = CGRect(x: quartzRect.origin.x, y: cocoaY, width: quartzRect.width, height: quartzRect.height)
                
                // Check if mouse is inside
                if cocoaRect.contains(mouseLoc) {
                    // Filter out our own overlay windows if possible, or very large desktop windows
                    // For this simple example, we assume the user is hovering over a "real" window.
                    // Improving this: check kCGWindowOwnerName or kCGWindowLayer
                    if let layer = entry[kCGWindowLayer as String] as? Int, layer == 0 {
                        return cocoaRect
                    }
                }
            }
        }
        return nil
    }
}

// MARK: - Preview

#Preview {
    WebViewScrollCaptureExample()
        .frame(width: 800, height: 700)
}
