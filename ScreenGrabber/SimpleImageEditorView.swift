//
//  SimpleImageEditorView.swift
//  ScreenGrabber
//
//  Created by Victor Lam on 10/23/25.
//

import SwiftUI
import AppKit

struct SimpleImageEditorView: View {
    let imageURL: URL
    @State private var image: NSImage?
    @State private var selectedTool: String = "arrow"
    @State private var selectedColor: Color = .red
    @State private var lineWidth: CGFloat = 3.0
    @State private var annotations: [SimpleAnnotation] = []
    @State private var currentPath: [CGPoint] = []
    @State private var isDragging: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                // Drawing tools
                HStack(spacing: 12) {
                    ToolButton(tool: "arrow", icon: "arrow.up.right", isSelected: selectedTool == "arrow") {
                        selectedTool = "arrow"
                    }
                    
                    ToolButton(tool: "pen", icon: "pencil", isSelected: selectedTool == "pen") {
                        selectedTool = "pen"
                    }
                    
                    ToolButton(tool: "rectangle", icon: "rectangle", isSelected: selectedTool == "rectangle") {
                        selectedTool = "rectangle"
                    }
                    
                    ToolButton(tool: "circle", icon: "circle", isSelected: selectedTool == "circle") {
                        selectedTool = "circle"
                    }
                    
                    ToolButton(tool: "text", icon: "textformat", isSelected: selectedTool == "text") {
                        selectedTool = "text"
                    }
                    
                    Divider()
                    
                    // Color picker
                    ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                        .frame(width: 30, height: 30)
                    
                    // Line width
                    VStack {
                        Text("Width")
                            .font(.caption)
                        Slider(value: $lineWidth, in: 1...10)
                            .frame(width: 100)
                    }
                }
                
                Spacer()
                
                // Actions
                HStack(spacing: 8) {
                    Button("Clear All") {
                        annotations.removeAll()
                    }
                    .disabled(annotations.isEmpty)
                    
                    Button("Save") {
                        saveImage()
                    }
                    
                    Button("Close") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Canvas
            ZStack {
                Color.white
                
                if let image = image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .overlay(
                            // Annotations overlay
                            Canvas { context, size in
                                for annotation in annotations {
                                    drawAnnotation(context: context, annotation: annotation)
                                }
                            }
                        )
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    handleDrag(value)
                                }
                                .onEnded { value in
                                    finishDrawing()
                                }
                        )
                } else {
                    ProgressView("Loading image...")
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        image = NSImage(contentsOf: imageURL)
    }
    
    private func handleDrag(_ value: DragGesture.Value) {
        let location = value.location
        
        if !isDragging {
            isDragging = true
            currentPath = [value.startLocation]
        }
        
        currentPath.append(location)
    }
    
    private func finishDrawing() {
        guard isDragging, !currentPath.isEmpty else { return }
        
        var annotation = SimpleAnnotation()
        annotation.tool = selectedTool
        annotation.color = NSColor(selectedColor)
        annotation.lineWidth = lineWidth
        annotation.points = currentPath
        
        if currentPath.count >= 2 {
            let start = currentPath.first!
            let end = currentPath.last!
            annotation.startPoint = start
            annotation.endPoint = end
            annotation.rect = CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            )
        }
        
        annotations.append(annotation)
        
        currentPath.removeAll()
        isDragging = false
    }
    
    private func drawAnnotation(context: GraphicsContext, annotation: SimpleAnnotation) {
        let color = Color(annotation.color)
        
        switch annotation.tool {
        case "pen":
            if annotation.points.count > 1 {
                var path = Path()
                path.move(to: annotation.points[0])
                for point in annotation.points.dropFirst() {
                    path.addLine(to: point)
                }
                context.stroke(path, with: .color(color), lineWidth: annotation.lineWidth)
            }
            
        case "arrow":
            if let start = annotation.startPoint, let end = annotation.endPoint {
                // Draw line
                var path = Path()
                path.move(to: start)
                path.addLine(to: end)
                context.stroke(path, with: .color(color), lineWidth: annotation.lineWidth)
                
                // Draw arrowhead
                let angle = atan2(end.y - start.y, end.x - start.x)
                let arrowLength: CGFloat = 15
                let arrowAngle: CGFloat = .pi / 6
                
                var arrowPath = Path()
                arrowPath.move(to: end)
                arrowPath.addLine(to: CGPoint(
                    x: end.x - arrowLength * cos(angle - arrowAngle),
                    y: end.y - arrowLength * sin(angle - arrowAngle)
                ))
                arrowPath.move(to: end)
                arrowPath.addLine(to: CGPoint(
                    x: end.x - arrowLength * cos(angle + arrowAngle),
                    y: end.y - arrowLength * sin(angle + arrowAngle)
                ))
                context.stroke(arrowPath, with: .color(color), lineWidth: annotation.lineWidth)
            }
            
        case "rectangle":
            let path = Path(annotation.rect)
            context.stroke(path, with: .color(color), lineWidth: annotation.lineWidth)
            
        case "circle":
            let path = Path(ellipseIn: annotation.rect)
            context.stroke(path, with: .color(color), lineWidth: annotation.lineWidth)
            
        default:
            break
        }
    }
    
    private func saveImage() {
        guard let originalImage = image else { return }
        
        // Create a new image with annotations
        let size = originalImage.size
        let annotatedImage = NSImage(size: size)
        
        annotatedImage.lockFocus()
        
        // Draw original image
        originalImage.draw(at: .zero, from: NSRect(origin: .zero, size: size), operation: .sourceOver, fraction: 1.0)
        
        // Draw annotations using Core Graphics
        guard let context = NSGraphicsContext.current?.cgContext else {
            annotatedImage.unlockFocus()
            return
        }
        
        for annotation in annotations {
            context.setStrokeColor(annotation.color.cgColor)
            context.setLineWidth(annotation.lineWidth)
            
            switch annotation.tool {
            case "pen":
                if annotation.points.count > 1 {
                    context.move(to: annotation.points[0])
                    for point in annotation.points.dropFirst() {
                        context.addLine(to: point)
                    }
                    context.strokePath()
                }
                
            case "arrow":
                if let start = annotation.startPoint, let end = annotation.endPoint {
                    // Draw line
                    context.move(to: start)
                    context.addLine(to: end)
                    context.strokePath()
                    
                    // Draw arrowhead
                    let angle = atan2(end.y - start.y, end.x - start.x)
                    let arrowLength: CGFloat = 15
                    let arrowAngle: CGFloat = .pi / 6
                    
                    context.move(to: end)
                    context.addLine(to: CGPoint(
                        x: end.x - arrowLength * cos(angle - arrowAngle),
                        y: end.y - arrowLength * sin(angle - arrowAngle)
                    ))
                    context.move(to: end)
                    context.addLine(to: CGPoint(
                        x: end.x - arrowLength * cos(angle + arrowAngle),
                        y: end.y - arrowLength * sin(angle + arrowAngle)
                    ))
                    context.strokePath()
                }
                
            case "rectangle":
                context.stroke(annotation.rect)
                
            case "circle":
                context.strokeEllipse(in: annotation.rect)
                
            default:
                break
            }
        }
        
        annotatedImage.unlockFocus()
        
        // Save to file
        if let data = annotatedImage.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: data),
           let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            
            do {
                try pngData.write(to: imageURL)
                
                // Show success notification
                ScreenCaptureManager.shared.showWelcomeNotification()
            } catch {
                print("Failed to save edited image: \(error)")
            }
        }
    }
}

struct ToolButton: View {
    let tool: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isSelected ? .white : .accentColor)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor, lineWidth: isSelected ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct SimpleAnnotation {
    var tool: String = ""
    var points: [CGPoint] = []
    var startPoint: CGPoint?
    var endPoint: CGPoint?
    var rect: CGRect = .zero
    var color: NSColor = .red
    var lineWidth: CGFloat = 3.0
}

#Preview {
    SimpleImageEditorView(imageURL: URL(fileURLWithPath: "/tmp/test.png"))
}