import SwiftUI
import AppKit
import SwiftData

/// Integration guide: How to add ScrollCaptureManager to your existing screen capture app
///
/// This file shows how to integrate the enhanced scroll capture functionality
/// into your existing ScreenCaptureManager workflow.

// MARK: - Step 1: Add scroll capture trigger to your UI

extension ScreenCaptureManager {
    
    /// Enhanced scrolling capture that uses ScrollCaptureManager
    func performEnhancedScrollingCapture(openOption: OpenOption, modelContext: ModelContext?) {
        print("[SCROLL] Starting enhanced scrolling capture with area selection...")
        
        // Show instruction notification
        showNotification(
            title: "Scroll Capture",
            message: "Select the area you want to capture. The app will automatically scroll and stitch."
        )
        
        // Hide main window temporarily
        if let window = NSApp.keyWindow {
            window.orderOut(nil)
        }
        
        // Small delay for window to hide
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.startAreaSelection { rect in
                // Show window again
                if let window = NSApp.windows.first(where: { $0.title.contains("ScreenGrabber") }) {
                    window.makeKeyAndOrderFront(nil)
                }
                
                guard let captureRect = rect else {
                    self.showNotification(title: "Cancelled", message: "No area selected")
                    return
                }
                
                // Start the enhanced capture
                self.executeEnhancedScrollCapture(
                    in: captureRect,
                    openOption: openOption,
                    modelContext: modelContext
                )
            }
        }
    }
    
    private func startAreaSelection(completion: @escaping (CGRect?) -> Void) {
        let selectionWindow = AreaSelectionOverlay(completion: completion)
        selectionWindow.makeKeyAndOrderFront(nil)
    }
    
    private func executeEnhancedScrollCapture(
        in rect: CGRect,
        openOption: OpenOption,
        modelContext: ModelContext?
    ) {
        let timestamp = Date()
        
        // Create ScrollingCaptureEngine instance
        let scrollEngine = ScrollingCaptureEngine()
        
        // Show capturing notification
        showNotification(
            title: "Capturing",
            message: "Automatically scrolling and capturing the content..."
        )
        
        Task {
            do {
                // Check accessibility permission
                // Note: ScrollingCaptureEngine checks this internally in startCapture()
                
                // Perform the capture
                let finalImage = try await scrollEngine.startCapture()
                
                // Save the result
                await MainActor.run {
                    self.saveScrollCaptureResult(
                        image: finalImage,
                        timestamp: timestamp,
                        openOption: openOption,
                        modelContext: modelContext
                    )
                }
                
            } catch let error as ScrollingCaptureEngine.CaptureError {
                await MainActor.run {
                    let message = error.localizedDescription
                    self.showNotification(title: "Capture Failed", message: message)
                }
            } catch {
                await MainActor.run {
                    self.showNotification(
                        title: "Capture Failed",
                        message: error.localizedDescription
                    )
                }
            }
        }
    }
    
    private func saveScrollCaptureResult(
        image: NSImage,
        timestamp: Date,
        openOption: OpenOption,
        modelContext: ModelContext?
    ) {
        Task { @MainActor in
            guard let capturesFolder = await UnifiedCaptureManager.shared.getCapturesFolderURL() else {
                self.showNotification(title: "Error", message: "Cannot access captures folder")
                return
            }
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let dateString = dateFormatter.string(from: timestamp)
            let filename = "EnhancedScrollCapture_\(dateString).png"
            let finalPath = capturesFolder.appendingPathComponent(filename)

            do {
                // Save the image
                guard let tiffData = image.tiffRepresentation,
                      let bitmapRep = NSBitmapImageRep(data: tiffData),
                      let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
                    self.showNotification(title: "Error", message: "Failed to convert image to PNG")
                    return
                }
                
                try pngData.write(to: finalPath, options: .atomic)
                print("[OK] Enhanced scroll capture saved to: \(finalPath.path)")

                // Get file size
                let attributes = try FileManager.default.attributesOfItem(atPath: finalPath.path)
                let fileSize = attributes[.size] as? Int64 ?? 0

                // Create Screenshot record
                let screenshot = Screenshot(
                    filename: filename,
                    filePath: finalPath.path,
                    captureType: ScreenOption.scrollingCapture.rawValue,
                    width: Int(image.size.width),
                    height: Int(image.size.height),
                    fileSize: fileSize,
                    timestamp: timestamp
                )

                // Save to SwiftData
                if let context = modelContext {
                    context.insert(screenshot)
                    try context.save()
                    
                    // Generate thumbnails asynchronously
                    Task {
                        await screenshot.generateThumbnail()
                        await screenshot.generatePreview()
                        try? context.save()
                    }
                }

                // Show success notification
                self.showNotification(
                    title: "Capture Complete",
                    message: "Saved \(Int(image.size.width))×\(Int(image.size.height)) image"
                )

                // Handle open option
                switch openOption {
                case .clipboard:
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.writeObjects([image])
                case .saveToFile:
                    NSWorkspace.shared.open(finalPath)
                case .editor:
                    // Open in editor if available
                    NSWorkspace.shared.open(finalPath)
                }

                // Notify UI
                NotificationCenter.default.post(
                    name: .screenshotCaptured,
                    object: nil,
                    userInfo: ["path": finalPath.path]
                )
            } catch {
                self.showNotification(title: "Error", message: "Failed to save: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Step 2: Add to your menu or toolbar

extension ScreenCaptureManager {
    
    /// Add this to your menu bar or toolbar
    static func createScrollCaptureMenuItem() -> NSMenuItem {
        let item = NSMenuItem(
            title: "Capture Scrolling Area (Enhanced)",
            action: #selector(triggerEnhancedScrollCapture),
            keyEquivalent: "s"
        )
        item.keyEquivalentModifierMask = [.command, .shift]
        return item
    }
    
    @objc private func triggerEnhancedScrollCapture() {
        performEnhancedScrollingCapture(openOption: .saveToFile, modelContext: nil)
    }
}

// MARK: - Step 3: Add SwiftUI integration

struct EnhancedScrollCaptureButton: View {
    // ScreenCaptureManager is a singleton class, not an ObservableObject.
    // Use the shared instance instead of EnvironmentObject.
    let captureManager = ScreenCaptureManager.shared
    
    @State private var isCapturing = false
    
    var body: some View {
        Button(action: startCapture) {
            Label("Scroll Capture (Enhanced)", systemImage: "arrow.down.doc")
        }
        .help("Select an area and automatically capture its entire scrollable content")
        .disabled(isCapturing)
    }
    
    private func startCapture() {
        isCapturing = true
        captureManager.performEnhancedScrollingCapture(
            openOption: .saveToFile,
            modelContext: nil
        )
        
        // Reset after a delay (capture happens asynchronously)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isCapturing = false
        }
    }
}

// MARK: - Step 4: Settings UI for scroll capture options

// Renamed to avoid conflict with existing ScrollCaptureSettingsView
struct IntegrationScrollCaptureSettingsView: View {
    @AppStorage("scrollCapture.stepOverlap") private var stepOverlap = 50.0
    @AppStorage("scrollCapture.stepDelay") private var stepDelay = 0.3
    @AppStorage("scrollCapture.edgeMatching") private var edgeMatching = true
    @AppStorage("scrollCapture.maxSteps") private var maxSteps = 200.0
    @AppStorage("scrollCapture.autoRequestPermission") private var autoRequestPermission = true
    
    var body: some View {
        Form {
            Section("Capture Quality") {
                Slider(value: $stepOverlap, in: 20...150, step: 5) {
                    Text("Frame Overlap")
                } minimumValueLabel: {
                    Text("20")
                } maximumValueLabel: {
                    Text("150")
                }
                Text("Current: \(Int(stepOverlap)) pixels")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Higher values improve stitching quality but increase capture time")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            Section("Timing") {
                Slider(value: $stepDelay, in: 0.1...1.0, step: 0.1) {
                    Text("Scroll Delay")
                } minimumValueLabel: {
                    Text("0.1s")
                } maximumValueLabel: {
                    Text("1.0s")
                }
                Text("Current: \(String(format: "%.1f", stepDelay))s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Increase for slow-loading or complex pages")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            Section("Advanced") {
                Toggle("Smart Edge Matching", isOn: $edgeMatching)
                Text("Automatically detect and align overlapping regions for seamless stitching")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                
                Slider(value: $maxSteps, in: 50...500, step: 10) {
                    Text("Maximum Frames")
                } minimumValueLabel: {
                    Text("50")
                } maximumValueLabel: {
                    Text("500")
                }
                Text("Current: \(Int(maxSteps)) frames")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Toggle("Auto-request Accessibility Permission", isOn: $autoRequestPermission)
                Text("Automatically prompt for Accessibility permission when starting scroll capture")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            Section("Permissions") {
                PermissionStatusView()
            }
        }
        .formStyle(.grouped)
    }
}

struct PermissionStatusView: View {
    @State private var hasAccessibility = false
    @State private var hasScreenRecording = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PermissionRow(
                title: "Accessibility",
                granted: hasAccessibility,
                icon: "hand.raised.fill",
                description: "Required for precise scroll control"
            ) {
                openAccessibilitySettings()
            }
            
            PermissionRow(
                title: "Screen Recording",
                granted: hasScreenRecording,
                icon: "record.circle",
                description: "Required for capturing screen content"
            ) {
                openScreenRecordingSettings()
            }
            
            Button("Refresh Status") {
                checkPermissions()
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .onAppear {
            checkPermissions()
        }
    }
    
    private func checkPermissions() {
        // Check accessibility permission using ApplicationServices
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        hasAccessibility = AXIsProcessTrustedWithOptions(options)
        
        // Check screen recording permission (simplified check)
        hasScreenRecording = true // Implement actual check based on your existing code
    }
    
    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
    
    private func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
}

struct PermissionRow: View {
    let title: String
    let granted: Bool
    let icon: String
    let description: String
    let action: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(granted ? .green : .orange)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Grant") {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}

// MARK: - Step 5: Area selection overlay (already in ScrollCaptureView.swift)

class AreaSelectionOverlay: NSWindow {
    private var startPoint: NSPoint?
    private let overlayView: SelectionOverlayView
    private let completion: (CGRect?) -> Void
    
    init(completion: @escaping (CGRect?) -> Void) {
        self.completion = completion
        
        // Cover all screens
        let frame = NSScreen.screens.reduce(CGRect.zero) { $0.union($1.frame) }
        self.overlayView = SelectionOverlayView()
        
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
            
            if rect.width > 50 && rect.height > 50 {
                self.completion(rect)
            } else {
                self.completion(nil)
            }
        }
    }
    
    override var canBecomeKey: Bool { true }
}

class SelectionOverlayView: NSView {
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

// MARK: - Preview

#Preview("Settings") {
    IntegrationScrollCaptureSettingsView()
        .frame(width: 500, height: 600)
}

