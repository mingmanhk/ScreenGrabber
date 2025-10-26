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
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            // Toolbar/Sidebar
            VStack(spacing: 0) {
                // Tool Categories
                ScrollView {
                    LazyVStack(spacing: 12) {
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
                
                // Tool Properties Panel
                ToolPropertiesPanel(editorState: editorState)
                    .frame(height: 200)
                    .padding()
            }
            .frame(width: 280)
            .background(Color(NSColor.controlBackgroundColor))
            
            // Main Editor Canvas
            VStack(spacing: 0) {
                // Top toolbar
                HStack {
                    // File actions
                    HStack(spacing: 8) {
                        Button(action: saveImage) {
                            Label("Save", systemImage: "square.and.arrow.down")
                        }
                        .keyboardShortcut("s", modifiers: .command)
                        
                        Button(action: { showingExportDialog = true }) {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                        .keyboardShortcut("e", modifiers: [.command, .shift])
                        
                        Divider()
                        
                        Button(action: editorState.undo) {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        .disabled(!editorState.canUndo)
                        .keyboardShortcut("z", modifiers: .command)
                        
                        Button(action: editorState.redo) {
                            Image(systemName: "arrow.uturn.forward")
                        }
                        .disabled(!editorState.canRedo)
                        .keyboardShortcut("z", modifiers: [.command, .shift])
                    }
                    
                    Spacer()
                    
                    // Zoom controls
                    HStack(spacing: 8) {
                        Button(action: { editorState.zoomLevel = max(0.25, editorState.zoomLevel - 0.25) }) {
                            Image(systemName: "minus.magnifyingglass")
                        }
                        
                        Text("\(Int(editorState.zoomLevel * 100))%")
                            .font(.caption)
                            .frame(width: 50)
                        
                        Button(action: { editorState.zoomLevel = min(4.0, editorState.zoomLevel + 0.25) }) {
                            Image(systemName: "plus.magnifyingglass")
                        }
                        
                        Button(action: { editorState.zoomLevel = 1.0 }) {
                            Text("100%")
                                .font(.caption)
                        }
                    }
                    
                    Spacer()
                    
                    // Close button
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Canvas
                ImageCanvas(
                    imageURL: imageURL,
                    editorState: editorState,
                    originalImage: $originalImage
                )
                .clipped()
            }
        }
        .navigationTitle("Image Editor - \(imageURL.lastPathComponent)")
        .onAppear {
            loadImage()
        }
        .sheet(isPresented: $showingExportDialog) {
            ExportDialog(imageURL: imageURL, editorState: editorState)
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
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
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
    
    var body: some View {
        Button(action: { editorState.selectedTool = tool }) {
            VStack(spacing: 4) {
                Image(systemName: tool.icon)
                    .font(.title3)
                    .foregroundColor(editorState.selectedTool == tool ? .white : .accentColor)
                
                Text(tool.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(editorState.selectedTool == tool ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(editorState.selectedTool == tool ? Color.accentColor : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: editorState.selectedTool == tool ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
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
    }
    
    enum ExportSize: String, CaseIterable {
        case original = "original"
        case half = "half"
        case double = "double"
        case custom = "custom"
        
        var displayName: String {
            switch self {
            case .original: return "Original Size"
            case .half: return "50%"
            case .double: return "200%"
            case .custom: return "Custom"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Export Image")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Format:")
                    .font(.headline)
                
                Picker("Format", selection: $selectedFormat) {
                    ForEach(ImageFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                
                if selectedFormat == .jpeg {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("JPEG Quality: \(Int(jpegQuality * 100))%")
                            .font(.subheadline)
                        
                        Slider(value: $jpegQuality, in: 0.1...1.0)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Size:")
                    .font(.headline)
                
                Picker("Size", selection: $exportSize) {
                    ForEach(ExportSize.allCases, id: \.self) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Export") {
                    exportImage()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400, height: 300)
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