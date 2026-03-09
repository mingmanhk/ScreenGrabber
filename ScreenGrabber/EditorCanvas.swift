//
//  EditorCanvas.swift
//  ScreenGrabber
//
//  Main canvas for image display and annotation
//  Created by Victor Lam on 1/5/26.
//

import SwiftUI
import AppKit
import Combine

/// Main canvas that displays the image with zoom, pan, and annotation support
struct EditorCanvas: View {
    let imageURL: URL
    @ObservedObject var editorState: ScreenCaptureEditorState
    @Binding var originalImage: NSImage?

    // Pan & Zoom state
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @GestureState private var dragOffset: CGSize = .zero

    // Grid overlay
    @State private var showGrid: Bool = false

    /// The image shown on canvas — original with adjustments applied.
    @State private var displayImage: NSImage?

    /// The first completed crop annotation, if any
    private var pendingCropAnnotation: DrawingAnnotation? {
        editorState.imageEditorState.annotations.first { $0.tool == .crop && $0.isCompleted }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main scrollable canvas
                ScrollView([.horizontal, .vertical]) {
                    ZStack {
                        // Grid overlay (if enabled)
                        if editorState.showGrid {
                            GridOverlay()
                        }

                        // Main image with annotations
                        if let image = displayImage ?? originalImage {
                            ImageCanvas(
                                imageURL: imageURL,
                                editorState: editorState.imageEditorState,
                                originalImage: Binding(
                                    get: { displayImage ?? originalImage },
                                    set: { _ in } // display image is derived; writes are no-ops
                                )
                            )
                            .frame(
                                width: image.size.width * editorState.imageEditorState.zoomLevel,
                                height: image.size.height * editorState.imageEditorState.zoomLevel
                            )
                        } else {
                            // Loading state
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                Text("Loading image...")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(
                        minWidth: geometry.size.width,
                        minHeight: geometry.size.height
                    )
                }

                // Ruler overlays (if enabled)
                if editorState.showRulers {
                    VStack {
                        HorizontalRuler()
                            .frame(height: 20)
                        Spacer()
                    }

                    HStack {
                        VerticalRuler()
                            .frame(width: 20)
                        Spacer()
                    }
                }

                // Crop confirmation bar
                if let crop = pendingCropAnnotation {
                    VStack {
                        Spacer()
                        HStack(spacing: 12) {
                            Button("Cancel") {
                                editorState.imageEditorState.removeAnnotation(crop)
                                editorState.selectTool(.selection)
                            }
                            .keyboardShortcut(.cancelAction)

                            let sizeLabel = sizeLabel(for: crop.rect, zoom: editorState.imageEditorState.zoomLevel)
                            Text(sizeLabel)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.secondary)

                            Button("Apply Crop") {
                                applyCrop(annotation: crop)
                                editorState.imageEditorState.removeAnnotation(crop)
                                editorState.selectTool(.selection)
                            }
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut(.defaultAction)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                        .padding(.bottom, 16)
                    }
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    let newZoom = editorState.imageEditorState.zoomLevel * value
                    editorState.imageEditorState.zoomLevel = min(max(newZoom, 0.25), 4.0)
                }
        )
        .onChange(of: originalImage) { _, newImage in
            reapplyAdjustments(to: newImage)
        }
        .onChange(of: editorState.adjustments) { _, _ in
            reapplyAdjustments(to: originalImage)
        }
        .onAppear {
            reapplyAdjustments(to: originalImage)
        }
    }

    private func reapplyAdjustments(to image: NSImage?) {
        guard let image else { displayImage = nil; return }
        if editorState.adjustments.isDefault {
            displayImage = image
            return
        }
        displayImage = editorState.adjustments.applied(to: image) ?? image
    }

    /// Apply crop: convert canvas-space rect → CGImage pixel rect, then crop.
    private func applyCrop(annotation: DrawingAnnotation) {
        guard let image = originalImage,
              let cgIn = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }

        let z = editorState.imageEditorState.zoomLevel
        let r = annotation.rect

        // Canvas coords → image pixel coords (both have (0,0) top-left)
        let pixRect = CGRect(
            x: r.origin.x / z,
            y: r.origin.y / z,
            width: r.width / z,
            height: r.height / z
        ).intersection(CGRect(origin: .zero, size: image.size))

        guard pixRect.width > 1, pixRect.height > 1,
              let cropped = cgIn.cropping(to: pixRect) else { return }

        let newImage = NSImage(cgImage: cropped, size: pixRect.size)
        originalImage = newImage
        reapplyAdjustments(to: newImage)
    }

    private func sizeLabel(for rect: CGRect, zoom: CGFloat) -> String {
        let w = Int(rect.width / zoom)
        let h = Int(rect.height / zoom)
        return "\(w) × \(h) px"
    }
}

// MARK: - Grid Overlay
struct GridOverlay: View {
    let gridSpacing: CGFloat = 50
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let cols = Int(size.width / gridSpacing) + 1
                let rows = Int(size.height / gridSpacing) + 1
                
                // Vertical lines
                for col in 0...cols {
                    let x = CGFloat(col) * gridSpacing
                    let path = Path { p in
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    context.stroke(
                        path,
                        with: .color(.gray.opacity(0.2)),
                        lineWidth: 1
                    )
                }
                
                // Horizontal lines
                for row in 0...rows {
                    let y = CGFloat(row) * gridSpacing
                    let path = Path { p in
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(
                        path,
                        with: .color(.gray.opacity(0.2)),
                        lineWidth: 1
                    )
                }
            }
        }
    }
}

// MARK: - Ruler Components
struct HorizontalRuler: View {
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Background
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(Color(nsColor: .controlBackgroundColor))
                )
                
                // Tick marks every 50 points
                let tickSpacing: CGFloat = 50
                let ticks = Int(size.width / tickSpacing) + 1
                
                for i in 0...ticks {
                    let x = CGFloat(i) * tickSpacing
                    let tickHeight: CGFloat = (i % 2 == 0) ? 8 : 4
                    
                    let path = Path { p in
                        p.move(to: CGPoint(x: x, y: size.height))
                        p.addLine(to: CGPoint(x: x, y: size.height - tickHeight))
                    }
                    
                    context.stroke(path, with: .color(.secondary), lineWidth: 1)
                    
                    // Label every other tick
                    if i % 2 == 0 {
                        let text = Text("\(Int(x))")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                        context.draw(text, at: CGPoint(x: x + 2, y: 2), anchor: .topLeading)
                    }
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct VerticalRuler: View {
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Background
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(Color(nsColor: .controlBackgroundColor))
                )
                
                // Tick marks every 50 points
                let tickSpacing: CGFloat = 50
                let ticks = Int(size.height / tickSpacing) + 1
                
                for i in 0...ticks {
                    let y = CGFloat(i) * tickSpacing
                    let tickWidth: CGFloat = (i % 2 == 0) ? 8 : 4
                    
                    let path = Path { p in
                        p.move(to: CGPoint(x: size.width, y: y))
                        p.addLine(to: CGPoint(x: size.width - tickWidth, y: y))
                    }
                    
                    context.stroke(path, with: .color(.secondary), lineWidth: 1)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Image Info Overlay
struct ImageInfoOverlay: View {
    let image: NSImage
    let zoom: CGFloat
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Size: \(Int(image.size.width)) × \(Int(image.size.height))")
                    Text("Zoom: \(Int(zoom * 100))%")
                    Text("Format: PNG")
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(8)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                .padding()
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview
struct EditorCanvas_Previews: PreviewProvider {
    static var previews: some View {
        EditorCanvas(
            imageURL: URL(fileURLWithPath: "/tmp/test.png"),
            editorState: ScreenCaptureEditorState(),
            originalImage: .constant(nil)
        )
        .frame(width: 800, height: 600)
    }
}
