//
//  ImageCanvas.swift
//  ScreenGrabber
//
//  Created by Victor Lam on 10/23/25.
//

import SwiftUI
import AppKit

struct ImageCanvas: View {
    let imageURL: URL
    @ObservedObject var editorState: ImageEditorState
    @Binding var originalImage: NSImage?
    
    @State private var dragStart: CGPoint = .zero
    @State private var dragCurrent: CGPoint = .zero
    @State private var isDragging: Bool = false
    @State private var currentPath: CGMutablePath?
    @State private var tempAnnotation: DrawingAnnotation?
    @State private var showingTextEditor: Bool = false
    @State private var textEditorPosition: CGPoint = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.white
                
                if let image = originalImage {
                    // Main image
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(editorState.zoomLevel)
                        .overlay(
                            // Annotation overlay
                            AnnotationOverlay(
                                editorState: editorState,
                                imageSize: image.size,
                                canvasSize: geometry.size
                            )
                        )
                        .overlay(
                            // Drawing overlay for current gesture
                            CurrentDrawingOverlay(
                                editorState: editorState,
                                tempAnnotation: tempAnnotation,
                                dragStart: dragStart,
                                dragCurrent: dragCurrent,
                                isDragging: isDragging,
                                currentPath: currentPath
                            )
                        )
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    handleDragChanged(value)
                                }
                                .onEnded { value in
                                    handleDragEnded(value)
                                }
                        )
                        .onTapGesture { location in
                            handleTap(at: location)
                        }
                } else {
                    // Loading state
                    ProgressView("Loading image...")
                }
            }
        }
        .sheet(isPresented: $showingTextEditor) {
            TextEditorSheet(
                title: editorState.selectedTool == .callout ? "Add Callout" : "Add Text",
                text: editorState.currentText,
                onSave: { text in
                    addTextAnnotation(text: text, at: textEditorPosition)
                }
            )
        }
        .task {
            // Load image if not already loaded
            if originalImage == nil {
                originalImage = NSImage(contentsOf: imageURL)
            }
        }
    }
    
    // Removed redundant loadImage function
    
    private func handleTap(at location: CGPoint) {
        switch editorState.selectedTool {
        case .text, .callout:
            textEditorPosition = location
            editorState.currentText = editorState.selectedTool == .callout ? "Callout text" : "Enter text"
            showingTextEditor = true
            
        case .stamp:
            addStampAnnotation(at: location)
            
        case .step:
            addStepAnnotation(at: location)
            
        default:
            // Check if tapping on existing annotation for selection
            if let annotation = findAnnotationAt(location) {
                editorState.selectedAnnotation = annotation
            }
        }
    }
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        let location = value.location
        
        if !isDragging {
            // Start new drawing
            isDragging = true
            dragStart = location
            startDrawing(at: location)
        }
        
        dragCurrent = location
        updateCurrentDrawing(to: location)
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        let location = value.location

        guard isDragging else { return }
        isDragging = false

        // Small drag (< 5 pt) = treat as tap for point-placement tools
        let dragDist = distance(value.startLocation, location)
        if dragDist < 5 {
            switch editorState.selectedTool {
            case .text, .callout:
                textEditorPosition = location
                editorState.currentText = editorState.selectedTool == .callout ? "Callout text" : "Enter text"
                showingTextEditor = true
                tempAnnotation = nil
                currentPath = nil
                return
            case .stamp:
                addStampAnnotation(at: location)
                tempAnnotation = nil
                currentPath = nil
                return
            case .step:
                addStepAnnotation(at: location)
                tempAnnotation = nil
                currentPath = nil
                return
            default:
                break
            }
        }

        finishDrawing(at: location)
        tempAnnotation = nil
        currentPath = nil
    }
    
    private func startDrawing(at point: CGPoint) {
        // For selection tool, check if we're clicking on an annotation
        if editorState.selectedTool == .selection {
            if let annotation = findAnnotationAt(point) {
                editorState.selectedAnnotation = annotation
            } else {
                editorState.selectedAnnotation = nil
            }
            return
        }
        
        // For move tool, check if we're clicking on an annotation to move it
        if editorState.selectedTool == .pan {
            if let annotation = findAnnotationAt(point) {
                editorState.selectedAnnotation = annotation
                // Store the starting point for moving
                dragStart = point
            }
            return
        }
        
        var annotation = DrawingAnnotation()
        annotation.tool = editorState.selectedTool
        annotation.color = editorState.currentColor
        annotation.lineWidth = editorState.lineWidth
        annotation.opacity = editorState.opacity
        annotation.fontSize = editorState.fontSize
        annotation.shapeType = editorState.selectedShape
        annotation.isFilled = editorState.isShapeFilled
        annotation.blurRadius = editorState.blurRadius
        
        switch editorState.selectedTool {
        case .freehand, .highlighter, .eraser:
            let path = CGMutablePath()
            path.move(to: point)
            currentPath = path
            annotation.points = [point]
            
        case .line, .arrow:
            annotation.points = [point, point] // Start and end will be the same initially
            
        case .shape, .blur, .pixelate, .spotlight, .callout, .crop, .magnify:
            annotation.rect = CGRect(origin: point, size: .zero)

        default:
            break
        }

        tempAnnotation = annotation
    }
    
    private func updateCurrentDrawing(to point: CGPoint) {
        // Handle move tool
        if editorState.selectedTool == .pan, let selectedAnnotation = editorState.selectedAnnotation {
            let deltaX = point.x - dragStart.x
            let deltaY = point.y - dragStart.y
            
            // Update the annotation's position
            if var updatedAnnotation = editorState.annotations.first(where: { $0.id == selectedAnnotation.id }) {
                updatedAnnotation.rect = CGRect(
                    x: updatedAnnotation.rect.origin.x + deltaX,
                    y: updatedAnnotation.rect.origin.y + deltaY,
                    width: updatedAnnotation.rect.width,
                    height: updatedAnnotation.rect.height
                )
                
                // Update points for line/arrow tools
                if !updatedAnnotation.points.isEmpty {
                    updatedAnnotation.points = updatedAnnotation.points.map { oldPoint in
                        CGPoint(x: oldPoint.x + deltaX, y: oldPoint.y + deltaY)
                    }
                }
                
                editorState.updateAnnotation(updatedAnnotation)
                dragStart = point // Update drag start for continuous movement
            }
            return
        }
        
        // For selection tool, don't create new annotations
        if editorState.selectedTool == .selection {
            return
        }
        
        guard var annotation = tempAnnotation else { return }
        
        switch editorState.selectedTool {
        case .freehand, .highlighter, .eraser:
            currentPath?.addLine(to: point)
            annotation.points.append(point)
            
        case .line, .arrow:
            if annotation.points.count >= 2 {
                annotation.points[1] = point
            }
            
        case .shape, .blur, .pixelate, .spotlight, .callout, .crop, .magnify:
            let rect = CGRect(
                x: min(dragStart.x, point.x),
                y: min(dragStart.y, point.y),
                width: abs(point.x - dragStart.x),
                height: abs(point.y - dragStart.y)
            )
            annotation.rect = rect
            
        default:
            break
        }
        
        tempAnnotation = annotation
    }
    
    private func finishDrawing(at point: CGPoint) {
        guard var annotation = tempAnnotation else { return }
        
        annotation.isCompleted = true
        
        // Set the final path for path-based tools
        if let path = currentPath {
            annotation.path = path.copy()
        }
        
        // Only add annotation if it has meaningful content
        if shouldAddAnnotation(annotation) {
            editorState.addAnnotation(annotation)
        }
    }
    
    private func shouldAddAnnotation(_ annotation: DrawingAnnotation) -> Bool {
        switch annotation.tool {
        case .freehand, .highlighter, .eraser:
            return annotation.points.count > 1
            
        case .line, .arrow:
            return annotation.points.count >= 2 && 
                   distance(annotation.points[0], annotation.points[1]) > 5
            
        case .shape, .blur, .pixelate, .spotlight, .callout, .crop, .magnify:
            return annotation.rect.width > 5 && annotation.rect.height > 5
            
        case .text:
            return !annotation.text.isEmpty
            
        default:
            return true
        }
    }
    
    private func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        sqrt(pow(p2.x - p1.x, 2) + pow(p2.y - p1.y, 2))
    }
    
    private func findAnnotationAt(_ point: CGPoint) -> DrawingAnnotation? {
        // Find the topmost annotation that contains this point
        return editorState.annotations.reversed().first { annotation in
            switch annotation.tool {
            case .shape, .blur, .pixelate, .spotlight, .callout, .text, .crop, .magnify:
                return annotation.rect.contains(point)
                
            case .line, .arrow:
                if annotation.points.count >= 2 {
                    return distanceFromPointToLine(point, annotation.points[0], annotation.points[1]) < annotation.lineWidth + 5
                }
                return false
                
            case .freehand, .highlighter, .eraser:
                // Check if point is near any point in the path
                return annotation.points.contains { pathPoint in
                    distance(point, pathPoint) < annotation.lineWidth + 5
                }
                
            default:
                return false
            }
        }
    }
    
    private func distanceFromPointToLine(_ point: CGPoint, _ lineStart: CGPoint, _ lineEnd: CGPoint) -> CGFloat {
        let A = point.x - lineStart.x
        let B = point.y - lineStart.y
        let C = lineEnd.x - lineStart.x
        let D = lineEnd.y - lineStart.y
        
        let dot = A * C + B * D
        let lenSq = C * C + D * D
        
        guard lenSq != 0 else { return distance(point, lineStart) }
        
        var param = dot / lenSq
        param = max(0, min(1, param))
        
        let xx = lineStart.x + param * C
        let yy = lineStart.y + param * D
        
        return distance(point, CGPoint(x: xx, y: yy))
    }
    
    private func addTextAnnotation(text: String, at location: CGPoint) {
        var annotation = DrawingAnnotation()
        annotation.tool = editorState.selectedTool == .callout ? .callout : .text
        annotation.text = text
        annotation.color = editorState.currentColor
        annotation.fontSize = editorState.fontSize
        annotation.opacity = editorState.opacity

        if editorState.selectedTool == .callout {
            // Callout gets a bigger default rect
            let estimatedWidth = max(120, CGFloat(text.count) * annotation.fontSize * 0.65 + 16)
            annotation.rect = CGRect(origin: location, size: CGSize(width: estimatedWidth, height: annotation.fontSize * 2.5))
        } else {
            annotation.rect = CGRect(origin: location, size: CGSize(width: 200, height: 30))
        }
        annotation.isCompleted = true

        editorState.addAnnotation(annotation)
    }
    
    private func addStampAnnotation(at location: CGPoint) {
        var annotation = DrawingAnnotation()
        annotation.tool = .stamp
        annotation.color = editorState.currentColor
        annotation.rect = CGRect(origin: location, size: CGSize(width: 40, height: 40))
        annotation.isCompleted = true
        
        editorState.addAnnotation(annotation)
    }
    
    private func addStepAnnotation(at location: CGPoint) {
        // Find the highest existing step number and increment
        let existingNumbers = editorState.annotations
            .filter { $0.tool == .step }
            .compactMap { Int($0.text) }
        let stepNumber = (existingNumbers.max() ?? 0) + 1

        var annotation = DrawingAnnotation()
        annotation.tool = .step
        annotation.text = "\(stepNumber)"
        annotation.color = editorState.currentColor
        annotation.rect = CGRect(
            x: location.x - 15, y: location.y - 15,
            width: 30, height: 30
        )
        annotation.isCompleted = true

        editorState.addAnnotation(annotation)
    }
}

// MARK: - Annotation Overlay
struct AnnotationOverlay: View {
    @ObservedObject var editorState: ImageEditorState
    let imageSize: NSSize
    let canvasSize: CGSize
    
    var body: some View {
        Canvas { context, size in
            for annotation in editorState.annotations where annotation.isCompleted {
                drawAnnotation(context: context, annotation: annotation, in: size)
                
                // Draw selection handles if this annotation is selected
                if let selected = editorState.selectedAnnotation,
                   selected.id == annotation.id {
                    drawSelectionHandles(context: context, for: annotation)
                }
            }
        }
    }
    
    private func drawSelectionHandles(context: GraphicsContext, for annotation: DrawingAnnotation) {
        let rect = annotation.rect
        let handleSize: CGFloat = 8
        let handles = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.midX, y: rect.minY),
            CGPoint(x: rect.midX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.midY),
            CGPoint(x: rect.maxX, y: rect.midY)
        ]
        
        // Draw selection border
        let borderPath = Path(rect)
        context.stroke(borderPath, with: .color(.blue), style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
        
        // Draw handles
        for handle in handles {
            let handleRect = CGRect(
                x: handle.x - handleSize / 2,
                y: handle.y - handleSize / 2,
                width: handleSize,
                height: handleSize
            )
            context.fill(Path(ellipseIn: handleRect), with: .color(.white))
            context.stroke(Path(ellipseIn: handleRect), with: .color(.blue), lineWidth: 2)
        }
    }
    
    private func drawAnnotation(context: GraphicsContext, annotation: DrawingAnnotation, in size: CGSize) {
        var context = context
        context.opacity = annotation.opacity
        
        switch annotation.tool {
        case .freehand:
            if let path = annotation.path {
                context.stroke(
                    Path(path),
                    with: .color(Color(annotation.color)),
                    lineWidth: annotation.lineWidth
                )
            }

        case .highlighter:
            if let path = annotation.path {
                context.opacity = 0.4
                context.stroke(
                    Path(path),
                    with: .color(Color(annotation.color)),
                    lineWidth: max(annotation.lineWidth, 20)
                )
            }

        case .eraser:
            if let path = annotation.path {
                context.blendMode = .clear
                context.opacity = 1.0
                context.stroke(
                    Path(path),
                    with: .color(.white),
                    lineWidth: annotation.lineWidth
                )
            }

        case .line:
            if annotation.points.count >= 2 {
                let path = Path { p in
                    p.move(to: annotation.points[0])
                    p.addLine(to: annotation.points[1])
                }
                context.stroke(
                    path,
                    with: .color(Color(annotation.color)),
                    lineWidth: annotation.lineWidth
                )
            }
            
        case .arrow:
            drawArrow(context: context, annotation: annotation)
            
        case .shape:
            drawShape(context: context, annotation: annotation)
            
        case .text:
            drawText(context: context, annotation: annotation)
            
        case .blur:
            drawBlur(context: context, annotation: annotation)

        case .pixelate:
            drawPixelate(context: context, annotation: annotation)
            
        case .callout:
            drawCallout(context: context, annotation: annotation)

        case .spotlight:
            drawSpotlight(context: context, annotation: annotation)
            
        case .step:
            drawStep(context: context, annotation: annotation)
            
        case .stamp:
            drawStamp(context: context, annotation: annotation)

        case .magnify:
            drawMagnify(context: context, annotation: annotation)

        case .crop:
            drawCrop(context: context, annotation: annotation)

        default:
            break
        }
    }
    
    private func drawCrop(context: GraphicsContext, annotation: DrawingAnnotation) {
        let rect = annotation.rect
        // Draw dashed border for crop area
        context.stroke(
            Path(rect),
            with: .color(Color(annotation.color)),
            style: StrokeStyle(lineWidth: 2, dash: [8, 4])
        )
        
        // Draw corner handles
        let handleSize: CGFloat = 10
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY)
        ]
        
        for corner in corners {
            let handleRect = CGRect(
                x: corner.x - handleSize / 2,
                y: corner.y - handleSize / 2,
                width: handleSize,
                height: handleSize
            )
            context.fill(Path(handleRect), with: .color(.white))
            context.stroke(Path(handleRect), with: .color(Color(annotation.color)), lineWidth: 2)
        }
    }
    
    private func drawArrow(context: GraphicsContext, annotation: DrawingAnnotation) {
        guard annotation.points.count >= 2 else { return }
        
        let start = annotation.points[0]
        let end = annotation.points[1]
        
        // Draw line
        let path = Path { p in
            p.move(to: start)
            p.addLine(to: end)
        }
        context.stroke(path, with: .color(Color(annotation.color)), lineWidth: annotation.lineWidth)
        
        // Draw arrowhead
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = 15
        let arrowAngle: CGFloat = .pi / 6
        
        let arrowPath = Path { p in
            p.move(to: end)
            p.addLine(to: CGPoint(
                x: end.x - arrowLength * cos(angle - arrowAngle),
                y: end.y - arrowLength * sin(angle - arrowAngle)
            ))
            p.move(to: end)
            p.addLine(to: CGPoint(
                x: end.x - arrowLength * cos(angle + arrowAngle),
                y: end.y - arrowLength * sin(angle + arrowAngle)
            ))
        }
        context.stroke(arrowPath, with: .color(Color(annotation.color)), lineWidth: annotation.lineWidth)
    }
    
    private func drawShape(context: GraphicsContext, annotation: DrawingAnnotation) {
        let rect = annotation.rect
        let path: Path

        switch annotation.shapeType {
        case .rectangle:
            path = Path(rect)
        case .roundedRectangle:
            path = Path(roundedRect: rect, cornerRadius: 8)
        case .ellipse:
            path = Path(ellipseIn: rect)
        case .triangle:
            path = createTrianglePath(in: rect)
        case .star:
            path = createStarPath(in: rect)
        case .polygon:
            path = createPolygonPath(in: rect, sides: 6)
        }

        if annotation.isFilled {
            context.fill(path, with: .color(Color(annotation.color)))
        } else {
            context.stroke(path, with: .color(Color(annotation.color)), lineWidth: annotation.lineWidth)
        }
    }
    
    private func drawText(context: GraphicsContext, annotation: DrawingAnnotation) {
        let text = Text(annotation.text)
            .font(.system(size: annotation.fontSize))
            .foregroundColor(Color(annotation.color))
        
        context.draw(text, at: annotation.rect.origin, anchor: .topLeading)
    }
    
    private func drawBlur(context: GraphicsContext, annotation: DrawingAnnotation) {
        let rect = annotation.rect
        // Solid gray overlay that actually covers content; blurRadius adjusts density
        let intensity = min(0.6 + annotation.blurRadius / 30.0, 0.92)
        context.fill(Path(rect), with: .color(Color.gray.opacity(intensity)))
        context.stroke(Path(rect), with: .color(Color.gray.opacity(0.7)), lineWidth: 1.5)
    }

    private func drawPixelate(context: GraphicsContext, annotation: DrawingAnnotation) {
        let rect = annotation.rect
        // Render as a grid of solid color tiles to suggest pixelation
        let tileSize: CGFloat = max(4, annotation.blurRadius / 5)
        let cols = max(1, Int(rect.width / tileSize))
        let rows = max(1, Int(rect.height / tileSize))
        let actualTileW = rect.width / CGFloat(cols)
        let actualTileH = rect.height / CGFloat(rows)

        // Checkerboard of two grays to indicate pixelation area
        for row in 0..<rows {
            for col in 0..<cols {
                let tileRect = CGRect(
                    x: rect.minX + CGFloat(col) * actualTileW,
                    y: rect.minY + CGFloat(row) * actualTileH,
                    width: actualTileW,
                    height: actualTileH
                )
                let isEven = (row + col) % 2 == 0
                context.fill(
                    Path(tileRect),
                    with: .color(isEven ? Color.gray.opacity(0.5) : Color.gray.opacity(0.3))
                )
            }
        }
        // Border
        context.stroke(Path(rect), with: .color(Color(annotation.color)), lineWidth: 1.5)
    }
    
    private func drawSpotlight(context: GraphicsContext, annotation: DrawingAnnotation) {
        let rect = annotation.rect
        context.stroke(Path(ellipseIn: rect), with: .color(Color(annotation.color)), lineWidth: annotation.lineWidth)
    }

    private func drawCallout(context: GraphicsContext, annotation: DrawingAnnotation) {
        let rect = annotation.rect
        guard rect.width > 4, rect.height > 4 else { return }

        // Speech bubble: rounded rect body + triangular tail at bottom-left
        let cornerRadius: CGFloat = min(10, rect.width * 0.15)
        let tailW: CGFloat = min(16, rect.width * 0.2)
        let tailH: CGFloat = min(12, rect.height * 0.3)
        let tailX = rect.minX + cornerRadius * 1.5

        let bubble = Path { p in
            // Start at top-left, going clockwise
            p.move(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
            p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + cornerRadius),
                           control: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
            p.addQuadCurve(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY),
                           control: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: tailX + tailW, y: rect.maxY))
            // Tail
            p.addLine(to: CGPoint(x: tailX, y: rect.maxY + tailH))
            p.addLine(to: CGPoint(x: tailX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
            p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - cornerRadius),
                           control: CGPoint(x: rect.minX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
            p.addQuadCurve(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY),
                           control: CGPoint(x: rect.minX, y: rect.minY))
            p.closeSubpath()
        }

        let color = Color(annotation.color)
        context.fill(bubble, with: .color(color.opacity(0.15)))
        context.stroke(bubble, with: .color(color), lineWidth: annotation.lineWidth)

        // Draw annotation text if any
        if !annotation.text.isEmpty {
            let label = Text(annotation.text)
                .font(.system(size: annotation.fontSize))
                .foregroundColor(color)
            context.draw(label,
                         at: CGPoint(x: rect.minX + 8, y: rect.midY),
                         anchor: .leading)
        }
    }
    
    private func drawStep(context: GraphicsContext, annotation: DrawingAnnotation) {
        let rect = annotation.rect
        let circlePath = Path(ellipseIn: rect)
        
        context.fill(circlePath, with: .color(Color(annotation.color)))
        context.stroke(circlePath, with: .color(Color(annotation.color)), lineWidth: 2)
        
        let text = Text(annotation.text)
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
        
        context.draw(text, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)
    }
    
    private func drawStamp(context: GraphicsContext, annotation: DrawingAnnotation) {
        let rect = annotation.rect
        let starPath = createStarPath(in: rect)
        
        context.fill(starPath, with: .color(Color(annotation.color)))
        context.stroke(starPath, with: .color(Color(annotation.color)), lineWidth: 1)
    }
    
    private func drawMagnify(context: GraphicsContext, annotation: DrawingAnnotation) {
        let rect = annotation.rect
        let color = Color(annotation.color)
        // Draw the lens circle
        context.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: annotation.lineWidth + 1)
        // Draw the handle from bottom-right of ellipse outward
        let handleStart = CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.maxY - rect.height * 0.12)
        let handleEnd   = CGPoint(x: rect.maxX + rect.width * 0.18, y: rect.maxY + rect.height * 0.18)
        let handle = Path { p in
            p.move(to: handleStart)
            p.addLine(to: handleEnd)
        }
        context.stroke(handle, with: .color(color), lineWidth: annotation.lineWidth + 2)
        // Draw "+" crosshair inside the circle
        let cx = rect.midX, cy = rect.midY, arm = min(rect.width, rect.height) * 0.18
        let crosshair = Path { p in
            p.move(to: CGPoint(x: cx - arm, y: cy)); p.addLine(to: CGPoint(x: cx + arm, y: cy))
            p.move(to: CGPoint(x: cx, y: cy - arm)); p.addLine(to: CGPoint(x: cx, y: cy + arm))
        }
        context.stroke(crosshair, with: .color(color.opacity(0.6)), lineWidth: 1.5)
    }

    private func createTrianglePath(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }

    private func createPolygonPath(in rect: CGRect, sides: Int) -> Path {
        Path { p in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = min(rect.width, rect.height) / 2
            for i in 0..<sides {
                let angle = CGFloat(i) * 2 * .pi / CGFloat(sides) - .pi / 2
                let pt = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
        }
    }

    private func createStarPath(in rect: CGRect) -> Path {
        Path { path in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = min(rect.width, rect.height) / 2
            let innerRadius = radius * 0.5
            
            for i in 0..<10 {
                let angle = CGFloat(i) * .pi / 5
                let r = i % 2 == 0 ? radius : innerRadius
                let x = center.x + r * cos(angle - .pi / 2)
                let y = center.y + r * sin(angle - .pi / 2)
                
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.closeSubpath()
        }
    }
}

// MARK: - Current Drawing Overlay
struct CurrentDrawingOverlay: View {
    @ObservedObject var editorState: ImageEditorState
    let tempAnnotation: DrawingAnnotation?
    let dragStart: CGPoint
    let dragCurrent: CGPoint
    let isDragging: Bool
    let currentPath: CGMutablePath?
    
    var body: some View {
        Canvas { context, size in
            guard isDragging, let annotation = tempAnnotation else { return }
            
            context.opacity = annotation.opacity
            
            switch editorState.selectedTool {
            case .freehand, .highlighter, .eraser:
                if let path = currentPath {
                    let swiftUIPath = Path(path)
                    context.stroke(
                        swiftUIPath,
                        with: .color(Color(annotation.color)),
                        lineWidth: annotation.lineWidth
                    )
                }
                
            case .line:
                let path = Path { p in
                    p.move(to: dragStart)
                    p.addLine(to: dragCurrent)
                }
                context.stroke(
                    path,
                    with: .color(Color(annotation.color)),
                    lineWidth: annotation.lineWidth
                )
                
            case .arrow:
                // Draw line
                let path = Path { p in
                    p.move(to: dragStart)
                    p.addLine(to: dragCurrent)
                }
                context.stroke(path, with: .color(Color(annotation.color)), lineWidth: annotation.lineWidth)
                
                // Draw preview arrowhead
                let angle = atan2(dragCurrent.y - dragStart.y, dragCurrent.x - dragStart.x)
                let arrowLength: CGFloat = 15
                let arrowAngle: CGFloat = .pi / 6
                
                let arrowPath = Path { p in
                    p.move(to: dragCurrent)
                    p.addLine(to: CGPoint(
                        x: dragCurrent.x - arrowLength * cos(angle - arrowAngle),
                        y: dragCurrent.y - arrowLength * sin(angle - arrowAngle)
                    ))
                    p.move(to: dragCurrent)
                    p.addLine(to: CGPoint(
                        x: dragCurrent.x - arrowLength * cos(angle + arrowAngle),
                        y: dragCurrent.y - arrowLength * sin(angle + arrowAngle)
                    ))
                }
                context.stroke(arrowPath, with: .color(Color(annotation.color)), lineWidth: annotation.lineWidth)
                
            case .shape, .blur, .pixelate, .spotlight, .callout, .crop, .magnify:
                let rect = CGRect(
                    x: min(dragStart.x, dragCurrent.x),
                    y: min(dragStart.y, dragCurrent.y),
                    width: abs(dragCurrent.x - dragStart.x),
                    height: abs(dragCurrent.y - dragStart.y)
                )

                let path: Path
                if editorState.selectedTool == .magnify {
                    path = Path(ellipseIn: rect)
                } else {
                    switch annotation.shapeType {
                    case .ellipse:
                        path = Path(ellipseIn: rect)
                    case .triangle:
                        path = Path { p in
                            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
                            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                            p.closeSubpath()
                        }
                    case .star:
                        let center = CGPoint(x: rect.midX, y: rect.midY)
                        let radius = min(rect.width, rect.height) / 2
                        let innerRadius = radius * 0.5
                        path = Path { p in
                            for i in 0..<10 {
                                let angle = CGFloat(i) * .pi / 5
                                let r = i % 2 == 0 ? radius : innerRadius
                                let pt = CGPoint(x: center.x + r * cos(angle - .pi / 2),
                                                 y: center.y + r * sin(angle - .pi / 2))
                                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                            }
                            p.closeSubpath()
                        }
                    case .polygon:
                        let center = CGPoint(x: rect.midX, y: rect.midY)
                        let radius = min(rect.width, rect.height) / 2
                        path = Path { p in
                            for i in 0..<6 {
                                let angle = CGFloat(i) * 2 * .pi / 6 - .pi / 2
                                let pt = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
                                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                            }
                            p.closeSubpath()
                        }
                    default:
                        path = Path(rect)
                    }
                }
                
                // Special styling for pixelate tool
                if editorState.selectedTool == .pixelate {
                    let tileSize: CGFloat = 8
                    let cols = max(1, Int(rect.width / tileSize))
                    let rows = max(1, Int(rect.height / tileSize))
                    let tw = rect.width / CGFloat(cols)
                    let th = rect.height / CGFloat(rows)
                    for row in 0..<rows {
                        for col in 0..<cols {
                            let tile = CGRect(x: rect.minX + CGFloat(col)*tw,
                                              y: rect.minY + CGFloat(row)*th,
                                              width: tw, height: th)
                            let isEven = (row + col) % 2 == 0
                            context.fill(Path(tile), with: .color(isEven ? Color.gray.opacity(0.45) : Color.gray.opacity(0.25)))
                        }
                    }
                    context.stroke(path, with: .color(.white), lineWidth: 1.5)
                }
                // Special styling for crop tool
                else if editorState.selectedTool == .crop {
                    // Draw semi-transparent overlay outside crop area
                    context.opacity = 0.5
                    context.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: size.height)), with: .color(.black.opacity(0.5)))
                    
                    // Draw crop area with border
                    context.opacity = 1.0
                    context.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                    
                    // Draw crop guidelines (rule of thirds)
                    let thirdWidth = rect.width / 3
                    let thirdHeight = rect.height / 3
                    
                    let guidelines = Path { p in
                        // Vertical lines
                        p.move(to: CGPoint(x: rect.minX + thirdWidth, y: rect.minY))
                        p.addLine(to: CGPoint(x: rect.minX + thirdWidth, y: rect.maxY))
                        p.move(to: CGPoint(x: rect.minX + 2 * thirdWidth, y: rect.minY))
                        p.addLine(to: CGPoint(x: rect.minX + 2 * thirdWidth, y: rect.maxY))
                        
                        // Horizontal lines
                        p.move(to: CGPoint(x: rect.minX, y: rect.minY + thirdHeight))
                        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + thirdHeight))
                        p.move(to: CGPoint(x: rect.minX, y: rect.minY + 2 * thirdHeight))
                        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + 2 * thirdHeight))
                    }
                    context.stroke(guidelines, with: .color(.white.opacity(0.5)), lineWidth: 1)
                } else if editorState.selectedTool == .magnify {
                    context.stroke(path, with: .color(Color(annotation.color)), lineWidth: annotation.lineWidth + 1)
                    // preview handle
                    let hs = CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.maxY - rect.height * 0.12)
                    let he = CGPoint(x: rect.maxX + rect.width * 0.18, y: rect.maxY + rect.height * 0.18)
                    let handle = Path { p in p.move(to: hs); p.addLine(to: he) }
                    context.stroke(handle, with: .color(Color(annotation.color)), lineWidth: annotation.lineWidth + 2)
                } else if annotation.isFilled {
                    context.fill(path, with: .color(Color(annotation.color).opacity(0.3)))
                    context.stroke(path, with: .color(Color(annotation.color)), lineWidth: annotation.lineWidth)
                } else {
                    context.stroke(path, with: .color(Color(annotation.color)), lineWidth: annotation.lineWidth)
                }
                
            default:
                break
            }
        }
    }
}

// MARK: - Text Editor Sheet
struct TextEditorSheet: View {
    var title: String = "Add Text"
    @State private var text: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    init(title: String = "Add Text", text: String, onSave: @escaping (String) -> Void) {
        self.title = title
        self._text = State(initialValue: text)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            
            TextField("Enter text", text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Add") {
                    onSave(text)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(text.isEmpty)
            }
        }
        .padding()
        .frame(width: 300, height: 150)
    }
}
