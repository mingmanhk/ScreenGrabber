import SwiftUI
import AppKit
import SwiftData
import UniformTypeIdentifiers
import Combine
import ScreenCaptureKit

struct ScrollCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedRect: CGRect?
    @State private var isSelectingArea = false
    @State private var capturedImage: NSImage?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isCapturing = false
    @State private var captureProgress: Double = 0.0
    @State private var statusMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("Scrolling Capture")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Select an area to capture. The app will automatically scroll and stitch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Divider()
            
            // Progress
            if isCapturing {
                VStack(spacing: 12) {
                    ProgressView(value: captureProgress) {
                        Text("Capturing...")
                    }
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Button("Cancel") { 
                        isCapturing = false
                        statusMessage = "Cancelled"
                    }
                        .buttonStyle(.bordered).tint(.red)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.1)))
            } else {
                // Action
                Button {
                    initiateCapture()
                } label: {
                    Label("Select Area & Capture", systemImage: "viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            
            // Preview
            if let image = capturedImage {
                VStack {
                    Text("Result: \(Int(image.size.width))×\(Int(image.size.height))")
                    ScrollView {
                        Image(nsImage: image)
                            .resizable().aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 400)
                    }
                    .frame(height: 300)
                    .border(Color.gray.opacity(0.2))
                    
                    HStack {
                        Button("Save") { saveImage(image) }
                        Button("Copy") { NSPasteboard.general.clearContents(); NSPasteboard.general.writeObjects([image]) }
                    }
                }
            }
            Spacer()
        }
        .padding()
        .frame(minWidth: 500, minHeight: 600)
        .alert("Error", isPresented: $showingError) { Button("OK") {} } message: { Text(errorMessage) }
    }
    
    private func initiateCapture() {
        Task {
            await MainActor.run {
                isSelectingArea = true
                NSApp.keyWindow?.orderOut(nil)
            }
            
            // Wait for window to hide
            try? await Task.sleep(nanoseconds: 200_000_000)
            
            await MainActor.run {
                selectScreenArea { rect in
                    // Show window
                    if let win = NSApp.windows.first(where: { $0.title.contains("Scroll") }) {
                        win.makeKeyAndOrderFront(nil)
                    }
                    
                    if let r = rect {
                        startCapture(in: r)
                    } else {
                        isSelectingArea = false
                    }
                }
            }
        }
    }
    
    private func selectScreenArea(completion: @escaping (CGRect?) -> Void) {
        let selectionWindow = ScrollCaptureAreaSelectionWindow(completion: completion)
        selectionWindow.makeKeyAndOrderFront(nil)
    }
    
    private func startCapture(in rect: CGRect) {
        Task {
            do {
                isCapturing = true
                statusMessage = "Detecting scrollable region..."
                captureProgress = 0.1
                
                // Create the optimized scrolling engine
                let scrollingEngine = OptimizedScrollingCaptureEngine()
                
                statusMessage = "Capturing scrolling content..."
                captureProgress = 0.3
                
                // Create a ScrollableRegion from the selected rect
                let region = OptimizedScrollingCaptureEngine.ScrollableRegion(
                    windowNumber: 0,
                    frame: rect,
                    scrollDirection: .vertical,
                    axElement: nil,
                    appName: nil,
                    windowTitle: nil
                )
                
                captureProgress = 0.5
                let image = try await scrollingEngine.captureRegion(region, direction: .vertical)
                
                captureProgress = 1.0
                statusMessage = "Complete!"
                
                await MainActor.run {
                    self.capturedImage = image
                    self.isSelectingArea = false
                    self.isCapturing = false
                }
                
                // Save through unified pipeline
                let metadata = UnifiedCaptureManager.CaptureMetadata(
                    captureType: .scrolling,
                    timestamp: Date(),
                    image: image
                )
                
                await UnifiedCaptureManager.shared.saveCapture(
                    metadata,
                    to: modelContext,
                    copyToClipboard: false
                )
                
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                    self.isSelectingArea = false
                    self.isCapturing = false
                }
            }
        }
    }
    
    private func saveImage(_ image: NSImage) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "Capture.png"
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                if let tiff = image.tiffRepresentation, let bmp = NSBitmapImageRep(data: tiff), let png = bmp.representation(using: .png, properties: [:]) {
                    try? png.write(to: url)
                }
            }
        }
    }
}

// MARK: - Area Selection UI

private class ScrollCaptureAreaSelectionWindow: NSWindow {
    private var startPoint: NSPoint?
    private let overlayView: ScrollCaptureOverlayView
    private let completion: (CGRect?) -> Void
    
    init(completion: @escaping (CGRect?) -> Void) {
        self.completion = completion
        
        // Cover all screens
        var frame = CGRect.zero
        for screen in NSScreen.screens {
            frame = frame.union(screen.frame)
        }
        
        self.overlayView = ScrollCaptureOverlayView()
        
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.backgroundColor = .clear
        self.isOpaque = false
        self.level = .screenSaver
        self.ignoresMouseEvents = false
        self.contentView = overlayView
        
        setupMouseHandlers()
    }
    
    private func setupMouseHandlers() {
        overlayView.onMouseDown = { [weak self] point in
            self?.startPoint = point
            self?.overlayView.selectionRect = CGRect(origin: point, size: .zero)
        }
        
        overlayView.onMouseDragged = { [weak self] point in
            guard let start = self?.startPoint else { return }
            let rect = CGRect(
                x: min(start.x, point.x),
                y: min(start.y, point.y),
                width: abs(point.x - start.x),
                height: abs(point.y - start.y)
            )
            self?.overlayView.selectionRect = rect
        }
        
        overlayView.onMouseUp = { [weak self] point in
            guard let self = self, let start = self.startPoint else {
                self?.close()
                self?.completion(nil)
                return
            }
            
            let rect = CGRect(
                x: min(start.x, point.x),
                y: min(start.y, point.y),
                width: abs(point.x - start.x),
                height: abs(point.y - start.y)
            )
            
            self.close()
            
            if rect.width > 20 && rect.height > 20 {
                self.completion(rect)
            } else {
                self.completion(nil)
            }
        }
    }
    
    override var canBecomeKey: Bool { true }
}

private class ScrollCaptureOverlayView: NSView {
    var selectionRect: CGRect = .zero {
        didSet { needsDisplay = true }
    }
    
    var onMouseDown: ((NSPoint) -> Void)?
    var onMouseDragged: ((NSPoint) -> Void)?
    var onMouseUp: ((NSPoint) -> Void)?
    
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.3).setFill()
        bounds.fill()
        
        if selectionRect.width > 0 && selectionRect.height > 0 {
            NSColor.clear.setFill()
            selectionRect.fill(using: .copy)
            
            NSColor.systemBlue.setStroke()
            let path = NSBezierPath(rect: selectionRect)
            path.lineWidth = 2
            path.stroke()
            
            // Draw dimensions
            let text = "\(Int(selectionRect.width)) × \(Int(selectionRect.height))"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: NSColor.white
            ]
            
            let textSize = (text as NSString).size(withAttributes: attrs)
            let labelRect = CGRect(
                x: selectionRect.midX - textSize.width / 2,
                y: selectionRect.maxY + 10,
                width: textSize.width + 16,
                height: textSize.height + 8
            )
            
            NSColor.systemBlue.setFill()
            NSBezierPath(roundedRect: labelRect, xRadius: 4, yRadius: 4).fill()
            
            (text as NSString).draw(
                in: CGRect(
                    x: labelRect.origin.x + 8,
                    y: labelRect.origin.y + 4,
                    width: textSize.width,
                    height: textSize.height
                ),
                withAttributes: attrs
            )
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        onMouseDown?(convert(event.locationInWindow, from: nil))
    }
    
    override func mouseDragged(with event: NSEvent) {
        onMouseDragged?(convert(event.locationInWindow, from: nil))
    }
    
    override func mouseUp(with event: NSEvent) {
        onMouseUp?(convert(event.locationInWindow, from: nil))
    }
}
