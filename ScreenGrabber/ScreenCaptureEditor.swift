//
//  ScreenCaptureEditor.swift
//  ScreenGrabber
//
//  Modern Screen Capture Editor Window
//  Created by Victor Lam on 1/5/26.
//

import SwiftUI
import AppKit
import Combine
import CoreImage

extension ScreenCaptureManager {
    /// Retrieves OCR text for the given image URL from extended attributes
    func getOCRText(for url: URL) -> String? {
        let xattrName = "com.screengrabber.ocrtext"
        
        guard let data = url.withUnsafeFileSystemRepresentation({ fileSystemPath -> Data? in
            guard let path = fileSystemPath else { return nil }
            
            // Get size of attribute
            let length = getxattr(path, xattrName, nil, 0, 0, 0)
            guard length > 0 else { return nil }
            
            // Read attribute data
            var data = Data(count: length)
            let result = data.withUnsafeMutableBytes { buffer in
                getxattr(path, xattrName, buffer.baseAddress, length, 0, 0)
            }
            
            guard result > 0 else { return nil }
            return data
        }) else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    /// Stores OCR text for the given image URL as an extended attribute
    func setOCRText(_ text: String, for url: URL) {
        let xattrName = "com.screengrabber.ocrtext"
        
        guard let data = text.data(using: .utf8) else { return }
        
        url.withUnsafeFileSystemRepresentation({ fileSystemPath in
            guard let path = fileSystemPath else { return }
            
            _ = data.withUnsafeBytes { buffer in
                setxattr(path, xattrName, buffer.baseAddress, data.count, 0, 0)
            }
        })
    }
    
    func performAutoOCR(for url: URL) {
        guard let image = NSImage(contentsOf: url) else {
            CaptureLogger.log(.debug, "performAutoOCR: failed to load image at \(url.lastPathComponent)", level: .warning)
            return
        }
        Task {
            do {
                if let result = try await OCRManager.shared.extractTextWithConfidence(from: image) {
                    CaptureLogger.log(.debug, "Auto-OCR extracted \(result.text.count) chars (\(Int(result.confidence * 100))% confidence)", level: .info)
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: Notification.Name("ocrTextExtracted"),
                            object: nil,
                            userInfo: ["text": result.text, "url": url]
                        )
                    }
                } else {
                    CaptureLogger.log(.debug, "Auto-OCR: no text found in \(url.lastPathComponent)", level: .info)
                }
            } catch {
                CaptureLogger.log(.debug, "Auto-OCR failed: \(error.localizedDescription)", level: .error)
            }
        }
    }
    
    func savePNGImage(_ image: NSImage, to url: URL) -> Bool {
        guard let tiffData = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData),
              let png = rep.representation(using: .png, properties: [:]) else { return false }
        do { try png.write(to: url); return true } catch { return false }
    }
}

/// Main container for the Screen Capture Editor
/// Presents as a standalone window with full editing capabilities
struct ScreenCaptureEditor: View {
    // MARK: - State Properties
    @StateObject private var editorState = ScreenCaptureEditorState()
    @Environment(\.dismiss) private var dismiss
    
    let imageURL: URL
    @State private var originalImage: NSImage?
    
    // UI State
    @State private var showingExportSheet = false
    @State private var showingRenameSheet = false
    @State private var showingOCRPanel = false
    @State private var showingPropertiesPanel = true
    @State private var showingRecentCaptures = true
    @State private var showingAdjustments = false
    @State private var showingResizeSheet = false

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Top Toolbar
            EditorToolbar(
                editorState: editorState,
                onExport: { showingExportSheet = true },
                onPrint: { printImage() },
                onRename: { showingRenameSheet = true },
                onOCRToggle: { showingOCRPanel.toggle() },
                onPropertiesToggle: { showingPropertiesPanel.toggle() },
                onRecentToggle: { showingRecentCaptures.toggle() },
                onAdjustmentsToggle: { showingAdjustments.toggle() },
                onRotateCW: rotateImageCW,
                onRotateCCW: rotateImageCCW,
                onFlipH: flipImageHorizontal,
                onFlipV: flipImageVertical,
                onResize: { showingResizeSheet = true }
            )
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // Main Content Area
            HStack(spacing: 0) {
                // Left Sidebar - Tools
                EditorToolsSidebar(editorState: editorState)
                    .frame(width: 60)
                    .background(Color(nsColor: .controlBackgroundColor))
                
                Divider()
                
                // Center Canvas
                ZStack {
                    // Checkerboard background for transparency
                    CheckerboardBackground()
                    
                    // Main image canvas with annotations
                    EditorCanvas(
                        imageURL: imageURL,
                        editorState: editorState,
                        originalImage: $originalImage
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Zoom controls overlay (bottom-left)
                    VStack {
                        Spacer()
                        HStack {
                            ZoomControls(editorState: editorState)
                                .padding()
                            Spacer()
                        }
                    }
                }
                
                // Right Panel - Properties, Adjustments & OCR
                if showingPropertiesPanel || showingOCRPanel || showingAdjustments {
                    Divider()

                    EditorRightPanel(
                        editorState: editorState,
                        imageURL: imageURL,
                        showingProperties: showingPropertiesPanel,
                        showingOCR: showingOCRPanel,
                        showingAdjustments: showingAdjustments
                    )
                    .frame(width: 280)
                    .background(Color(nsColor: .controlBackgroundColor))
                }
            }
            
            // Bottom Strip - Recent Captures
            if showingRecentCaptures {
                Divider()
                
                RecentCapturesStrip(
                    currentImageURL: imageURL,
                    onSelectImage: { url in
                        // TODO: Open new editor window with selected image
                        print("Opening image: \(url.lastPathComponent)")
                    }
                )
                .frame(height: 100)
                .background(Color(nsColor: .controlBackgroundColor))
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            loadImage()
            loadOCRText()
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportSheet(
                imageURL: imageURL,
                editorState: editorState
            )
        }
        .sheet(isPresented: $showingRenameSheet) {
            RenameSheet(imageURL: imageURL)
        }
        .sheet(isPresented: $showingResizeSheet) {
            ResizeImageSheet(originalImage: $originalImage)
        }
        // Keyboard shortcuts
        .onDeleteCommand {
            if let selected = editorState.imageEditorState.selectedAnnotation {
                editorState.imageEditorState.removeAnnotation(selected)
            }
        }
        .background(KeyboardShortcutHelper(
            onUndo: { editorState.imageEditorState.undo() },
            onRedo: { editorState.imageEditorState.redo() },
            onSave: { saveAnnotatedImage() },
            onExport: { showingExportSheet = true },
            onPrint: { printImage() }
        ))
    }
    
    // MARK: - Helper Functions
    
    private func loadImage() {
        if let image = NSImage(contentsOf: imageURL) {
            originalImage = image
            print("[EDITOR] Loaded image: \(imageURL.lastPathComponent)")
            print("[EDITOR] Image size: \(Int(image.size.width)) × \(Int(image.size.height))")
        } else {
            print("[EDITOR] Failed to load image from: \(imageURL.path)")
        }
    }
    
    private func loadOCRText() {
        // Attempt to load OCR text from extended attributes
        if let ocrText = ScreenCaptureManager.shared.getOCRText(for: imageURL) {
            editorState.ocrText = ocrText
            print("[EDITOR] Loaded OCR text: \(ocrText.count) characters")
        } else {
            print("[EDITOR] No OCR text found, triggering scan...")
            // Trigger OCR if not already available
            ScreenCaptureManager.shared.performAutoOCR(for: imageURL)
            
            // Listen for OCR completion
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("screenshotOCRCompleted"),
                object: nil,
                queue: .main
            ) { [weak editorState] notification in
                if let url = notification.userInfo?["url"] as? URL,
                   url == imageURL,
                   let text = notification.userInfo?["text"] as? String,
                   let state = editorState {
                    DispatchQueue.main.async {
                        state.ocrText = text
                    }
                }
            }
        }
    }
    
    private func saveAnnotatedImage() {
        guard let originalImage = originalImage else { return }
        
        // Create a new image with annotations rendered
        let annotatedImage = renderImageWithAnnotations(originalImage)
        
        // Save to the same URL
        if ScreenCaptureManager.shared.savePNGImage(annotatedImage, to: imageURL) {
            editorState.imageEditorState.isModified = false
            print("[EDITOR] Saved annotated image")
            
            // Show success notification
            ScreenCaptureManager.shared.showNotification(
                title: "Saved",
                message: "Your edits have been saved"
            )
        } else {
            print("[EDITOR] Failed to save annotated image")
        }
    }
    
    private func printImage() {
        guard let image = originalImage else { return }

        let imageView = NSImageView(frame: NSRect(origin: .zero, size: image.size))
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyDown

        let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .fit
        printInfo.isHorizontallyCentered = true
        printInfo.isVerticallyCentered = true

        let op = NSPrintOperation(view: imageView, printInfo: printInfo)
        op.showsPrintPanel = true
        op.showsProgressPanel = true
        op.run()
    }

    // MARK: - Image Transforms

    private func rotateImageCW() {
        guard let image = originalImage,
              let cgIn = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        applyTransform(CGAffineTransform(rotationAngle: -.pi / 2), to: image, cgIn: cgIn)
    }

    private func rotateImageCCW() {
        guard let image = originalImage,
              let cgIn = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        applyTransform(CGAffineTransform(rotationAngle: .pi / 2), to: image, cgIn: cgIn)
    }

    private func flipImageHorizontal() {
        guard let image = originalImage,
              let cgIn = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let t = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: CGFloat(cgIn.width), ty: 0)
        applyTransform(t, to: image, cgIn: cgIn)
    }

    private func flipImageVertical() {
        guard let image = originalImage,
              let cgIn = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let t = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(cgIn.height))
        applyTransform(t, to: image, cgIn: cgIn)
    }

    private func applyTransform(_ transform: CGAffineTransform, to image: NSImage, cgIn: CGImage) {
        var ci = CIImage(cgImage: cgIn).transformed(by: transform)
        let origin = ci.extent.origin
        if origin.x != 0 || origin.y != 0 {
            ci = ci.transformed(by: CGAffineTransform(translationX: -origin.x, y: -origin.y))
        }
        let extent = ci.extent
        let ciCtx = CIContext()
        guard let cgOut = ciCtx.createCGImage(ci, from: extent) else { return }
        let scale = cgIn.width > 0 ? image.size.width / CGFloat(cgIn.width) : 1
        originalImage = NSImage(
            cgImage: cgOut,
            size: NSSize(width: extent.width * scale, height: extent.height * scale)
        )
    }

    private func renderImageWithAnnotations(_ baseImage: NSImage) -> NSImage {
        let finalImage = NSImage(size: baseImage.size)
        
        finalImage.lockFocus()
        
        // Draw base image
        baseImage.draw(
            in: NSRect(origin: .zero, size: baseImage.size),
            from: .zero,
            operation: .copy,
            fraction: 1.0
        )
        
        // TODO: Render all annotations on top
        // This would involve converting SwiftUI Canvas drawing to NSImage drawing
        
        finalImage.unlockFocus()
        
        return finalImage
    }
}

// MARK: - Editor State Manager
// NOTE: ScreenCaptureEditorState is now defined in ScreenCaptureEditorState.swift
// This file uses that centralized definition

// MARK: - Keyboard Shortcut Helper
struct KeyboardShortcutHelper: View {
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onSave: () -> Void
    let onExport: () -> Void
    let onPrint: () -> Void

    var body: some View {
        ZStack {
            // Undo: Cmd+Z
            Button("") { onUndo() }
                .keyboardShortcut("z", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)

            // Redo: Cmd+Shift+Z
            Button("") { onRedo() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .opacity(0)
                .frame(width: 0, height: 0)

            // Save: Cmd+S
            Button("") { onSave() }
                .keyboardShortcut("s", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)

            // Export: Cmd+E
            Button("") { onExport() }
                .keyboardShortcut("e", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)

            // Print: Cmd+P
            Button("") { onPrint() }
                .keyboardShortcut("p", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
        }
        .frame(width: 0, height: 0)
    }
}

// MARK: - Checkerboard Background
struct CheckerboardBackground: View {
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let checkSize: CGFloat = 20
                let cols = Int(size.width / checkSize) + 1
                let rows = Int(size.height / checkSize) + 1
                
                for row in 0..<rows {
                    for col in 0..<cols {
                        let isEven = (row + col) % 2 == 0
                        let rect = CGRect(
                            x: CGFloat(col) * checkSize,
                            y: CGFloat(row) * checkSize,
                            width: checkSize,
                            height: checkSize
                        )
                        
                        context.fill(
                            Path(rect),
                            with: .color(isEven ? .white : Color(white: 0.9))
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Window Creation Helper
extension ScreenCaptureEditor {
    /// Opens a new editor window for the given image URL
    static func open(imageURL: URL) {
        let editorView = ScreenCaptureEditor(imageURL: imageURL)
        
        let hostingController = NSHostingController(rootView: editorView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Screen Capture Editor - \(imageURL.lastPathComponent)"
        window.setContentSize(NSSize(width: 1200, height: 800))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.center()
        window.makeKeyAndOrderFront(nil)
        
        // Set window appearance
        window.titlebarAppearsTransparent = false
        window.toolbar = NSToolbar(identifier: "EditorToolbar")
        
        print("[EDITOR] Opened editor window for: \(imageURL.lastPathComponent)")
    }
}
