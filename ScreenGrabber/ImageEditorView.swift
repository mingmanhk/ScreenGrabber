//
//  ImageEditorView.swift
//  ScreenGrabber
//
//  Created by Victor Lam on 10/23/25.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ImageEditorView: View {
    let imageURL: URL
    @StateObject private var editorState = ImageEditorState()
    @State private var originalImage: NSImage?
    @State private var showingSaveDialog = false
    @State private var showingExportDialog = false
    @State private var showingDiscardAlert = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Main Content
            HStack(spacing: 0) {
                // Left Sidebar - Tools Panel
                VStack(spacing: 0) {
                    // Sidebar Header
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.purple.opacity(0.15))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "pencil.tip.crop.circle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.purple)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Editor Tools")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Text("\(editorState.annotations.count) annotations")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()
                    
                    // Tool Categories - Scrollable
                    ScrollView {
                        VStack(spacing: 16) {
                            // Selection & Basic Tools
                            ToolCategorySection(title: "Selection & Basic", tools: [
                                .selection, .move, .crop, .magnify
                            ], editorState: editorState)
                            
                            // Drawing Tools
                            ToolCategorySection(title: "Drawing", tools: [
                                .pen, .line, .arrow, .highlighter
                            ], editorState: editorState)
                            
                            // Shapes & Text
                            ToolCategorySection(title: "Shapes & Text", tools: [
                                .shape, .text, .callout, .stamp, .step
                            ], editorState: editorState)
                            
                            // Effects & Editing
                            ToolCategorySection(title: "Effects", tools: [
                                .blur, .spotlight, .fill, .eraser
                            ], editorState: editorState)
                            
                            // Advanced Tools
                            ToolCategorySection(title: "Advanced", tools: [
                                .magicWand, .cutOut
                            ], editorState: editorState)
                        }
                        .padding()
                    }
                    
                    Divider()
                    
                    // Tool Properties Panel - Collapsible
                    VStack(spacing: 0) {
                        // Properties Header
                        HStack {
                            Label("Properties", systemImage: "slider.horizontal.3")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                        
                        // Properties Content
                        ToolPropertiesPanel(editorState: editorState)
                            .frame(height: 180)
                    }
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                }
                .frame(width: 280)
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Main Editor Canvas Area
                VStack(spacing: 0) {
                    // Top Toolbar - Enhanced Design
                    HStack(spacing: 16) {
                        // Left Section - File Info
                        HStack(spacing: 10) {
                            Image(systemName: "photo")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(imageURL.lastPathComponent)
                                    .font(.system(size: 13, weight: .semibold))
                                    .lineLimit(1)
                                
                                if let image = originalImage {
                                    Text("\(Int(image.size.width)) × \(Int(image.size.height)) px")
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: 200, alignment: .leading)
                        
                        Spacer()
                        
                        // Center Section - Action Buttons
                        HStack(spacing: 12) {
                            // Undo/Redo Group
                            HStack(spacing: 6) {
                                Button(action: editorState.undo) {
                                    Image(systemName: "arrow.uturn.backward")
                                        .font(.system(size: 14, weight: .medium))
                                        .frame(width: 32, height: 32)
                                        .background(editorState.canUndo ? Color.accentColor.opacity(0.1) : Color.clear)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                .disabled(!editorState.canUndo)
                                .keyboardShortcut("z", modifiers: .command)
                                .help("Undo (⌘Z)")
                                
                                Button(action: editorState.redo) {
                                    Image(systemName: "arrow.uturn.forward")
                                        .font(.system(size: 14, weight: .medium))
                                        .frame(width: 32, height: 32)
                                        .background(editorState.canRedo ? Color.accentColor.opacity(0.1) : Color.clear)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                .disabled(!editorState.canRedo)
                                .keyboardShortcut("z", modifiers: [.command, .shift])
                                .help("Redo (⌘⇧Z)")
                            }
                            .padding(4)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(10)
                            
                            Divider()
                                .frame(height: 24)
                            
                            // Zoom Controls Group
                            HStack(spacing: 6) {
                                Button(action: { editorState.zoomLevel = max(0.25, editorState.zoomLevel - 0.25) }) {
                                    Image(systemName: "minus.magnifyingglass")
                                        .font(.system(size: 14, weight: .medium))
                                        .frame(width: 32, height: 32)
                                        .background(Color.accentColor.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                .help("Zoom Out")
                                
                                Button(action: { editorState.zoomLevel = 1.0 }) {
                                    Text("\(Int(editorState.zoomLevel * 100))%")
                                        .font(.system(size: 12, weight: .semibold))
                                        .frame(width: 56, height: 32)
                                        .background(Color.accentColor.opacity(0.15))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                .help("Reset Zoom (100%)")
                                
                                Button(action: { editorState.zoomLevel = min(4.0, editorState.zoomLevel + 0.25) }) {
                                    Image(systemName: "plus.magnifyingglass")
                                        .font(.system(size: 14, weight: .medium))
                                        .frame(width: 32, height: 32)
                                        .background(Color.accentColor.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                .help("Zoom In")
                            }
                            .padding(4)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(10)
                            
                            Divider()
                                .frame(height: 24)
                            
                            // Save Actions
                            HStack(spacing: 8) {
                                Button(action: saveImage) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 14, weight: .semibold))
                                        Text("Save")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.green, Color.green.opacity(0.85)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .cornerRadius(8)
                                    .shadow(color: Color.green.opacity(0.3), radius: 4, x: 0, y: 2)
                                }
                                .buttonStyle(ScaleButtonStyle())
                                .keyboardShortcut("s", modifiers: .command)
                                .help("Save Changes (⌘S)")
                                
                                Button(action: { showingExportDialog = true }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 14, weight: .semibold))
                                        Text("Export")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.blue, Color.blue.opacity(0.85)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .cornerRadius(8)
                                    .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                                }
                                .buttonStyle(ScaleButtonStyle())
                                .keyboardShortcut("e", modifiers: [.command, .shift])
                                .help("Export As... (⌘⇧E)")
                            }
                        }
                        
                        Spacer()
                        
                        // Right Section - Close Button
                        Button(action: handleClose) {
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.red)
                            }
                        }
                        .buttonStyle(.plain)
                        .help("Close Editor (ESC)")
                        .keyboardShortcut(.escape)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(
                        VisualEffectBlur(material: .headerView, blendingMode: .withinWindow)
                    )
                    
                    Divider()
                    
                    // Canvas Area with Checkered Background
                    ZStack {
                        // Checkered background pattern
                        GeometryReader { geometry in
                            Canvas { context, size in
                                let squareSize: CGFloat = 20
                                let cols = Int(ceil(size.width / squareSize))
                                let rows = Int(ceil(size.height / squareSize))
                                
                                for row in 0..<rows {
                                    for col in 0..<cols {
                                        if (row + col) % 2 == 0 {
                                            let rect = CGRect(
                                                x: CGFloat(col) * squareSize,
                                                y: CGFloat(row) * squareSize,
                                                width: squareSize,
                                                height: squareSize
                                            )
                                            context.fill(Path(rect), with: .color(.gray.opacity(0.1)))
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Image Canvas
                        ImageCanvas(
                            imageURL: imageURL,
                            editorState: editorState,
                            originalImage: $originalImage
                        )
                    }
                    .clipped()
                }
            }
        }
        .frame(minWidth: 1200, minHeight: 800)
        .onAppear {
            loadImage()
        }
        .sheet(isPresented: $showingExportDialog) {
            ExportDialog(imageURL: imageURL, editorState: editorState)
        }
        .alert("Unsaved Changes", isPresented: $showingDiscardAlert) {
            Button("Discard", role: .destructive) {
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                saveImage()
                dismiss()
            }
        } message: {
            Text("You have unsaved changes. Would you like to save them before closing?")
        }
    }
    
    private func handleClose() {
        if editorState.isModified {
            showingDiscardAlert = true
        } else {
            dismiss()
        }
    }
    
    private func loadImage() {
        originalImage = NSImage(contentsOf: imageURL)
    }
    
    private func saveImage() {
        // Save the edited image back to the original location
        guard let image = originalImage else { return }
        
        // Apply all annotations to the image
        let editedImage = applyAnnotationsToImage(image, annotations: editorState.annotations)
        
        // Save to file
        if let data = editedImage.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: data),
           let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            
            do {
                try pngData.write(to: imageURL)
                editorState.isModified = false
                
                // Show success notification
                ScreenCaptureManager.shared.showWelcomeNotification()
            } catch {
                print("Failed to save edited image: \(error)")
            }
        }
    }
    
    private func applyAnnotationsToImage(_ image: NSImage, annotations: [DrawingAnnotation]) -> NSImage {
        let size = image.size
        let editedImage = NSImage(size: size)
        
        editedImage.lockFocus()
        
        // Draw original image
        image.draw(at: .zero, from: NSRect(origin: .zero, size: size), operation: .sourceOver, fraction: 1.0)
        
        // Draw annotations
        let context = NSGraphicsContext.current?.cgContext
        
        for annotation in annotations where annotation.isCompleted {
            context?.saveGState()
            
            // Set common properties
            context?.setStrokeColor(annotation.color.cgColor)
            context?.setFillColor(annotation.color.cgColor)
            context?.setLineWidth(annotation.lineWidth)
            context?.setAlpha(annotation.opacity)
            
            switch annotation.tool {
            case .pen, .highlighter:
                if let path = annotation.path {
                    context?.addPath(path)
                    if annotation.tool == .highlighter {
                        context?.setBlendMode(.multiply)
                    }
                    context?.strokePath()
                }
                
            case .line:
                if annotation.points.count >= 2 {
                    let start = annotation.points[0]
                    let end = annotation.points[1]
                    context?.move(to: start)
                    context?.addLine(to: end)
                    context?.strokePath()
                }
                
            case .arrow:
                if annotation.points.count >= 2 {
                    drawArrow(context: context, from: annotation.points[0], to: annotation.points[1], annotation: annotation)
                }
                
            case .shape:
                drawShape(context: context, annotation: annotation)
                
            case .text:
                drawText(annotation: annotation, in: NSRect(origin: .zero, size: size))
                
            case .blur:
                applyBlur(context: context, annotation: annotation, imageSize: size)
                
            case .spotlight:
                applySpotlight(context: context, annotation: annotation, imageSize: size)
                
            default:
                break
            }
            
            context?.restoreGState()
        }
        
        editedImage.unlockFocus()
        return editedImage
    }
    
    // MARK: - Drawing Methods
    
    private func drawArrow(context: CGContext?, from start: CGPoint, to end: CGPoint, annotation: DrawingAnnotation) {
        guard let context = context else { return }
        
        // Draw line
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()
        
        // Draw arrowhead
        if annotation.hasArrowHead {
            let angle = atan2(end.y - start.y, end.x - start.x)
            let arrowLength: CGFloat = 15
            let arrowAngle: CGFloat = .pi / 6
            
            let arrowPoint1 = CGPoint(
                x: end.x - arrowLength * cos(angle - arrowAngle),
                y: end.y - arrowLength * sin(angle - arrowAngle)
            )
            
            let arrowPoint2 = CGPoint(
                x: end.x - arrowLength * cos(angle + arrowAngle),
                y: end.y - arrowLength * sin(angle + arrowAngle)
            )
            
            context.move(to: end)
            context.addLine(to: arrowPoint1)
            context.move(to: end)
            context.addLine(to: arrowPoint2)
            context.strokePath()
        }
    }
    
    private func drawShape(context: CGContext?, annotation: DrawingAnnotation) {
        guard let context = context else { return }
        
        let rect = annotation.rect
        
        switch annotation.shapeType {
        case .rectangle:
            if annotation.isFilled {
                context.fill(rect)
            } else {
                context.stroke(rect)
            }
            
        case .ellipse:
            if annotation.isFilled {
                context.fillEllipse(in: rect)
            } else {
                context.strokeEllipse(in: rect)
            }
            
        case .roundedRectangle:
            let cornerRadius = min(rect.width, rect.height) * 0.1
            let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
            context.addPath(path)
            if annotation.isFilled {
                context.fillPath()
            } else {
                context.strokePath()
            }
            
        default:
            // Simple rectangle fallback
            if annotation.isFilled {
                context.fill(rect)
            } else {
                context.stroke(rect)
            }
        }
    }
    
    private func drawText(annotation: DrawingAnnotation, in bounds: NSRect) {
        let font = NSFont.systemFont(ofSize: annotation.fontSize, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: annotation.color
        ]
        
        let attributedString = NSAttributedString(string: annotation.text, attributes: attributes)
        attributedString.draw(at: annotation.rect.origin)
    }
    
    private func applyBlur(context: CGContext?, annotation: DrawingAnnotation, imageSize: NSSize) {
        // This would require Core Image filters for proper implementation
        // For now, draw a semi-transparent overlay
        guard let context = context else { return }
        
        context.setFillColor(NSColor.white.withAlphaComponent(0.6).cgColor)
        context.fill(annotation.rect)
    }
    
    private func applySpotlight(context: CGContext?, annotation: DrawingAnnotation, imageSize: NSSize) {
        guard let context = context else { return }
        
        // Create a mask that darkens everything except the spotlight area
        context.setFillColor(NSColor.black.withAlphaComponent(0.6).cgColor)
        context.fill(CGRect(origin: .zero, size: imageSize))
        
        // Clear the spotlight area
        context.setBlendMode(.destinationOut)
        context.fillEllipse(in: annotation.rect)
        context.setBlendMode(.normal)
    }
}

// MARK: - Tool Category Section
struct ToolCategorySection: View {
    let title: String
    let tools: [EditorTool]
    @ObservedObject var editorState: ImageEditorState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Category Header
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.accentColor.opacity(0.3))
                    .frame(width: 4, height: 4)
                
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            .padding(.horizontal, 4)
            
            // Tools Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 10) {
                ForEach(tools, id: \.self) { tool in
                    EditorToolButton(tool: tool, editorState: editorState)
                }
            }
        }
    }
}

// MARK: - Editor Tool Button
struct EditorToolButton: View {
    let tool: EditorTool
    @ObservedObject var editorState: ImageEditorState
    @State private var isHovering = false
    
    var body: some View {
        Button(action: { 
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                editorState.selectedTool = tool
            }
        }) {
            VStack(spacing: 6) {
                ZStack {
                    // Icon Background
                    if editorState.selectedTool == tool {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentColor.opacity(0.2), Color.accentColor.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                    } else if isHovering {
                        Circle()
                            .fill(Color.accentColor.opacity(0.08))
                            .frame(width: 36, height: 36)
                    }
                    
                    Image(systemName: tool.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(
                            editorState.selectedTool == tool 
                                ? Color.accentColor 
                                : (isHovering ? Color.accentColor.opacity(0.8) : Color.primary)
                        )
                }
                .frame(height: 40)
                
                Text(tool.displayName)
                    .font(.system(size: 10, weight: editorState.selectedTool == tool ? .semibold : .medium))
                    .foregroundStyle(editorState.selectedTool == tool ? Color.accentColor : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 68)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        editorState.selectedTool == tool 
                            ? Color.accentColor.opacity(0.12)
                            : (isHovering ? Color.primary.opacity(0.05) : Color.clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        editorState.selectedTool == tool 
                            ? Color.accentColor.opacity(0.4)
                            : Color.clear,
                        lineWidth: 2
                    )
            )
            .shadow(
                color: editorState.selectedTool == tool 
                    ? Color.accentColor.opacity(0.15) 
                    : Color.clear,
                radius: 6,
                x: 0,
                y: 2
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .help(tool.displayName)
    }
}

// MARK: - Export Dialog
struct ExportDialog: View {
    let imageURL: URL
    @ObservedObject var editorState: ImageEditorState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat: ImageFormat = .png
    @State private var jpegQuality: Double = 0.8
    @State private var exportSize: ExportSize = .original
    
    enum ImageFormat: String, CaseIterable {
        case png = "png"
        case jpeg = "jpeg"
        case tiff = "tiff"
        case gif = "gif"
        
        var displayName: String {
            switch self {
            case .png: return "PNG"
            case .jpeg: return "JPEG"
            case .tiff: return "TIFF"
            case .gif: return "GIF"
            }
        }
        
        var icon: String {
            switch self {
            case .png: return "photo"
            case .jpeg: return "photo.fill"
            case .tiff: return "doc.text.image"
            case .gif: return "photo.stack"
            }
        }
    }
    
    enum ExportSize: String, CaseIterable {
        case original = "original"
        case half = "half"
        case double = "double"
        case custom = "custom"
        
        var displayName: String {
            switch self {
            case .original: return "Original"
            case .half: return "50%"
            case .double: return "200%"
            case .custom: return "Custom"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Export Image")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Choose format and size options")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(24)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Format Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Label("File Format", systemImage: "doc.badge.gearshape")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                            ForEach(ImageFormat.allCases, id: \.self) { format in
                                Button(action: { selectedFormat = format }) {
                                    VStack(spacing: 8) {
                                        Image(systemName: format.icon)
                                            .font(.system(size: 24, weight: .medium))
                                            .foregroundStyle(
                                                selectedFormat == format ? Color.accentColor : .secondary
                                            )
                                        
                                        Text(format.displayName)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(
                                                selectedFormat == format ? Color.accentColor : .primary
                                            )
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(
                                                selectedFormat == format 
                                                    ? Color.accentColor.opacity(0.12) 
                                                    : Color.clear
                                            )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(
                                                selectedFormat == format 
                                                    ? Color.accentColor 
                                                    : Color.secondary.opacity(0.3),
                                                lineWidth: selectedFormat == format ? 2 : 1
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        // JPEG Quality Slider
                        if selectedFormat == .jpeg {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                    
                                    Text("Quality: \(Int(jpegQuality * 100))%")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                
                                Slider(value: $jpegQuality, in: 0.1...1.0)
                                    .tint(Color.accentColor)
                                
                                HStack {
                                    Text("Smaller")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("Better")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.accentColor.opacity(0.05))
                            )
                        }
                    }
                    
                    // Size Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Export Size", systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                            ForEach(ExportSize.allCases, id: \.self) { size in
                                Button(action: { exportSize = size }) {
                                    VStack(spacing: 6) {
                                        Text(size.displayName)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(
                                                exportSize == size ? Color.accentColor : .primary
                                            )
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(
                                                exportSize == size 
                                                    ? Color.accentColor.opacity(0.12) 
                                                    : Color.clear
                                            )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(
                                                exportSize == size 
                                                    ? Color.accentColor 
                                                    : Color.secondary.opacity(0.3),
                                                lineWidth: exportSize == size ? 2 : 1
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(24)
            }
            
            Divider()
            
            // Footer Actions
            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.secondary.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                
                Button(action: { 
                    exportImage()
                    dismiss()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Export")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(10)
                    .shadow(color: Color.blue.opacity(0.3), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(ScaleButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        }
        .frame(width: 560, height: 520)
    }
    
    private func exportImage() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType.png, UTType.jpeg, UTType.tiff, UTType.gif]
        savePanel.nameFieldStringValue = imageURL.deletingPathExtension().lastPathComponent + "_edited"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                // Export logic would go here
                print("Exporting to: \(url)")
            }
        }
    }
}