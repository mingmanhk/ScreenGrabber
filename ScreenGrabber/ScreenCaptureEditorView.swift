//
//  ScreenCaptureEditorView.swift
//  ScreenGrabber
//
//  Thin container that prevents Swift metadata crashes on sheet presentation.
//  (Same pattern as ImageEditorContainer — see its header comment for rationale.)
//

import SwiftUI
import CoreImage

/// Thin container for ScreenCaptureEditorView that prevents Swift metadata crashes
/// by providing a stable initialization context for sheet presentations.
struct ScreenCaptureEditorView: View {
    let fileURL: URL

    var body: some View {
        _ScreenCaptureEditorContent(fileURL: fileURL)
    }
}

// MARK: - Editor Content (all state & layout lives here)

/// Private inner view that owns all editor state and layout.
/// Kept separate from the outer container to avoid Swift generic-metadata
/// stack overflows when the view is instantiated inside a sheet closure.
private struct _ScreenCaptureEditorContent: View {
    let fileURL: URL

    @StateObject private var editorState = ScreenCaptureEditorState()

    @State private var originalImage: NSImage?
    @State private var showProperties = true
    @State private var showAdjustments = false
    @State private var showOCR = false
    @State private var showExportSheet = false
    @State private var showRenameSheet = false
    @State private var showResizeSheet = false

    var body: some View {
        VStack(spacing: 0) {
            EditorToolbar(
                editorState: editorState,
                onExport: { showExportSheet = true },
                onPrint: performPrint,
                onRename: { showRenameSheet = true },
                onOCRToggle: { showOCR.toggle() },
                onPropertiesToggle: { showProperties.toggle() },
                onRecentToggle: {},
                onAdjustmentsToggle: { showAdjustments.toggle() },
                onRotateCW: rotateImageCW,
                onRotateCCW: rotateImageCCW,
                onFlipH: flipImageHorizontal,
                onFlipV: flipImageVertical,
                onResize: { showResizeSheet = true }
            )
            Divider()
            HStack(spacing: 0) {
                EditorToolsSidebar(editorState: editorState)
                    .frame(width: 60)
                Divider()
                EditorCanvas(
                    imageURL: fileURL,
                    editorState: editorState,
                    originalImage: $originalImage
                )
                if showProperties || showOCR || showAdjustments {
                    Divider()
                    EditorRightPanel(
                        editorState: editorState,
                        imageURL: fileURL,
                        showingProperties: showProperties,
                        showingOCR: showOCR,
                        showingAdjustments: showAdjustments
                    )
                    .frame(width: 280)
                }
            }
        }
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(imageURL: fileURL, editorState: editorState)
        }
        .sheet(isPresented: $showRenameSheet) {
            RenameSheet(imageURL: fileURL)
        }
        .sheet(isPresented: $showResizeSheet) {
            ResizeImageSheet(originalImage: $originalImage)
        }
        .onAppear {
            originalImage = NSImage(contentsOf: fileURL)
        }
    }

    private func performPrint() {
        guard let image = originalImage else { return }
        let iv = NSImageView()
        iv.image = image
        NSPrintOperation(view: iv).run()
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
}
