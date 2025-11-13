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
                text: editorState.currentText,
                onSave: { text in
                    addTextAnnotation(text: text, at: textEditorPosition)
                }
            )
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        if originalImage == nil {
            originalImage = NSImage(contentsOf: imageURL)
        }
    }
    
    private func handleTap(at location: CGPoint) {
        switch editorState.selectedTool {
        case .text:
            textEditorPosition = location
            editorState.currentText = "Enter text"
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
        
        finishDrawing(at: location)
        
        // Reset drawing state
        tempAnnotation = nil
        currentPath = nil
    }
    
    private func startDrawing(at point: CGPoint) {
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
        case .pen, .highlighter, .eraser:
            let path = CGMutablePath()
            path.move(to: point)
            currentPath = path
            annotation.points = [point]
            
        case .line, .arrow:
            annotation.points = [point, point] // Start and end will be the same initially
            
        case .shape, .blur, .spotlight, .callout, .crop:
            annotation.rect = CGRect(origin: point, size: .zero)
            
        default:
            break
        }
        
        tempAnnotation = annotation
    }
    
    private func updateCurrentDrawing(to point: CGPoint) {
        guard var annotation = tempAnnotation else { return }
        
        switch editorState.selectedTool {
        case .pen, .highlighter, .eraser:
            currentPath?.addLine(to: point)
            annotation.points.append(point)
            
        case .line, .arrow:
            if annotation.points.count >= 2 {
                annotation.points[1] = point
            }
            
        case .shape, .blur, .spotlight, .callout, .crop:
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
        case .pen, .highlighter, .eraser:
            return annotation.points.count > 1
            
        case .line, .arrow:
            return annotation.points.count >= 2 && 
                   distance(annotation.points[0], annotation.points[1]) > 5
            
        case .shape, .blur, .spotlight, .callout, .crop:
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
            case .shape, .blur, .spotlight, .callout, .text, .crop:
                return annotation.rect.contains(point)
                
            case .line, .arrow:
                if annotation.points.count >= 2 {
                    return distanceFromPointToLine(point, annotation.points[0], annotation.points[1]) < annotation.lineWidth + 5
                }
                return false
                
            case .pen, .highlighter, .eraser:
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
        annotation.tool = .text
        annotation.text = text
        annotation.color = editorState.currentColor
        annotation.fontSize = editorState.fontSize
        annotation.opacity = editorState.opacity
        annotation.rect = CGRect(origin: location, size: CGSize(width: 200, height: 30))
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
        let stepNumber = editorState.annotations.filter { $0.tool == .step }.count + 1
        
        var annotation = DrawingAnnotation()
        annotation.tool = .step
        annotation.text = "\(stepNumber)"
        annotation.color = editorState.currentColor
        annotation.rect = CGRect(origin: location, size: CGSize(width: 30, height: 30))
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
            }
        }
    }
    
    private func drawAnnotation(context: GraphicsContext, annotation: DrawingAnnotation, in size: CGSize) {
        var context = context
        context.opacity = annotation.opacity
        
        switch annotation.tool {
        case .pen, .highlighter, .eraser:
            if let path = annotation.path {
                let swiftUIPath = Path(path)
                context.stroke(
                    swiftUIPath,
                    with: .color(Color(annotation.color)),
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
            
        case .spotlight:
            drawSpotlight(context: context, annotation: annotation)
            
        case .step:
            drawStep(context: context, annotation: annotation)
            
        case .stamp:
            drawStamp(context: context, annotation: annotation)

        case .callout:
            drawCallout(context: context, annotation: annotation)

        case .fill:
            drawFill(context: context, annotation: annotation)

        case .magnify:
            drawMagnify(context: context, annotation: annotation)

        case .magicWand:
            drawMagicWand(context: context, annotation: annotation)

        case .cutOut:
            drawCutOut(context: context, annotation: annotation)

        default:
            break
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
        case .rectangle, .roundedRectangle:
            path = Path(roundedRect: rect, cornerRadius: annotation.shapeType == .roundedRectangle ? 8 : 0)
        case .ellipse:
            path = Path(ellipseIn: rect)
        default:
            path = Path(rect)
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
        // Create a more realistic blur effect with frosted glass appearance
        var context = context
        context.opacity = 0.9
        context.fill(Path(rect), with: .color(.white.opacity(0.7)))

        // Add checkerboard pattern to indicate blur
        let tileSize: CGFloat = 8
        let tilesX = Int(rect.width / tileSize)
        let tilesY = Int(rect.height / tileSize)

        for x in 0..<tilesX {
            for y in 0..<tilesY {
                if (x + y) % 2 == 0 {
                    let tileRect = CGRect(
                        x: rect.minX + CGFloat(x) * tileSize,
                        y: rect.minY + CGFloat(y) * tileSize,
                        width: tileSize,
                        height: tileSize
                    )
                    context.fill(Path(tileRect), with: .color(.gray.opacity(0.15)))
                }
            }
        }

        context.stroke(Path(rect), with: .color(Color(annotation.color)), lineWidth: 2)
    }

    private func drawSpotlight(context: GraphicsContext, annotation: DrawingAnnotation) {
        let rect = annotation.rect
        // Create spotlight effect with highlighted center
        var context = context

        // Draw outer shadow/darkened area (represented by border)
        context.stroke(Path(ellipseIn: rect), with: .color(Color(annotation.color)), lineWidth: annotation.lineWidth * 2)

        // Draw inner highlight circle
        let innerRect = rect.insetBy(dx: annotation.lineWidth, dy: annotation.lineWidth)
        context.stroke(Path(ellipseIn: innerRect), with: .color(.white.opacity(0.3)), lineWidth: 1)

        // Add center glow
        let centerRect = rect.insetBy(dx: rect.width * 0.3, dy: rect.height * 0.3)
        context.fill(Path(ellipseIn: centerRect), with: .color(.white.opacity(0.1)))
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

    private func drawCallout(context: GraphicsContext, annotation: DrawingAnnotation) {
        let rect = annotation.rect
        // Create speech bubble with pointer
        let bubblePath = Path { path in
            let cornerRadius: CGFloat = 8
            let pointerHeight: CGFloat = 20
            let pointerWidth: CGFloat = 15

            // Main bubble rectangle
            let bubbleRect = CGRect(
                x: rect.minX,
                y: rect.minY,
                width: rect.width,
                height: rect.height - pointerHeight
            )

            // Top-left corner
            path.move(to: CGPoint(x: bubbleRect.minX + cornerRadius, y: bubbleRect.minY))

            // Top edge and top-right corner
            path.addLine(to: CGPoint(x: bubbleRect.maxX - cornerRadius, y: bubbleRect.minY))
            path.addQuadCurve(
                to: CGPoint(x: bubbleRect.maxX, y: bubbleRect.minY + cornerRadius),
                control: CGPoint(x: bubbleRect.maxX, y: bubbleRect.minY)
            )

            // Right edge and bottom-right corner
            path.addLine(to: CGPoint(x: bubbleRect.maxX, y: bubbleRect.maxY - cornerRadius))
            path.addQuadCurve(
                to: CGPoint(x: bubbleRect.maxX - cornerRadius, y: bubbleRect.maxY),
                control: CGPoint(x: bubbleRect.maxX, y: bubbleRect.maxY)
            )

            // Bottom edge with pointer
            let pointerStart = bubbleRect.midX - pointerWidth / 2
            path.addLine(to: CGPoint(x: pointerStart + pointerWidth, y: bubbleRect.maxY))
            path.addLine(to: CGPoint(x: bubbleRect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: pointerStart, y: bubbleRect.maxY))

            // Bottom-left corner
            path.addLine(to: CGPoint(x: bubbleRect.minX + cornerRadius, y: bubbleRect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: bubbleRect.minX, y: bubbleRect.maxY - cornerRadius),
                control: CGPoint(x: bubbleRect.minX, y: bubbleRect.maxY)
            )

            // Left edge and top-left corner
            path.addLine(to: CGPoint(x: bubbleRect.minX, y: bubbleRect.minY + cornerRadius))
            path.addQuadCurve(
                to: CGPoint(x: bubbleRect.minX + cornerRadius, y: bubbleRect.minY),
                control: CGPoint(x: bubbleRect.minX, y: bubbleRect.minY)
            )
        }

        if annotation.isFilled {
            context.fill(bubblePath, with: .color(Color(annotation.color).opacity(0.2)))
        }
        context.stroke(bubblePath, with: .color(Color(annotation.color)), lineWidth: annotation.lineWidth)
    }

    private func drawFill(context: GraphicsContext, annotation: DrawingAnnotation) {
        let rect = annotation.rect
        // Fill bucket shows as a filled rectangle with paint bucket icon representation
        context.fill(Path(rect), with: .color(Color(annotation.color)))

        // Add a subtle pattern to show it's a fill
        let stripePath = Path { path in
            let stripeCount = 5
            let stripeSpacing = rect.height / CGFloat(stripeCount)
            for i in 0..<stripeCount {
                let y = rect.minY + CGFloat(i) * stripeSpacing
                path.move(to: CGPoint(x: rect.minX, y: y))
                path.addLine(to: CGPoint(x: rect.maxX, y: y))
            }
        }
        context.stroke(stripePath, with: .color(.white.opacity(0.2)), lineWidth: 1)
    }

    private func drawMagnify(context: GraphicsContext, annotation: DrawingAnnotation) {
        let rect = annotation.rect
        // Draw magnifying glass
        let glassRect = rect.insetBy(dx: rect.width * 0.1, dy: rect.height * 0.1)
        let handleRect = CGRect(
            x: glassRect.maxX - 10,
            y: glassRect.maxY - 10,
            width: 20,
            height: 20
        )

        // Glass circle
        context.stroke(Path(ellipseIn: glassRect), with: .color(Color(annotation.color)), lineWidth: annotation.lineWidth * 2)
        context.stroke(Path(ellipseIn: glassRect.insetBy(dx: 3, dy: 3)), with: .color(Color(annotation.color)), lineWidth: annotation.lineWidth)

        // Handle
        let handlePath = Path { path in
            path.move(to: CGPoint(x: glassRect.maxX - 5, y: glassRect.maxY - 5))
            path.addLine(to: CGPoint(x: handleRect.maxX, y: handleRect.maxY))
        }
        context.stroke(handlePath, with: .color(Color(annotation.color)), lineWidth: annotation.lineWidth * 2)

        // Add crosshair in center
        let center = CGPoint(x: glassRect.midX, y: glassRect.midY)
        let crosshairSize: CGFloat = 10
        let crosshairPath = Path { path in
            path.move(to: CGPoint(x: center.x - crosshairSize, y: center.y))
            path.addLine(to: CGPoint(x: center.x + crosshairSize, y: center.y))
            path.move(to: CGPoint(x: center.x, y: center.y - crosshairSize))
            path.addLine(to: CGPoint(x: center.x, y: center.y + crosshairSize))
        }
        context.stroke(crosshairPath, with: .color(Color(annotation.color).opacity(0.5)), lineWidth: 1)
    }

    private func drawMagicWand(context: GraphicsContext, annotation: DrawingAnnotation) {
        let rect = annotation.rect
        // Draw magic wand with sparkles for selection

        // Wand stick
        let wandPath = Path { path in
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.3, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.3, y: rect.minY))
        }
        context.stroke(wandPath, with: .color(Color(annotation.color)), lineWidth: annotation.lineWidth)

        // Star at top
        let starSize: CGFloat = min(rect.width, rect.height) * 0.3
        let starRect = CGRect(
            x: rect.maxX - rect.width * 0.3 - starSize / 2,
            y: rect.minY - starSize / 2,
            width: starSize,
            height: starSize
        )
        let starPath = createStarPath(in: starRect)
        context.fill(starPath, with: .color(Color(annotation.color)))
        context.stroke(starPath, with: .color(Color(annotation.color)), lineWidth: 1)

        // Sparkles around selection area
        let sparklePositions = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.midX, y: rect.minY),
            CGPoint(x: rect.midX, y: rect.maxY)
        ]

        for position in sparklePositions {
            let sparklePath = Path { path in
                let size: CGFloat = 4
                path.move(to: CGPoint(x: position.x, y: position.y - size))
                path.addLine(to: CGPoint(x: position.x, y: position.y + size))
                path.move(to: CGPoint(x: position.x - size, y: position.y))
                path.addLine(to: CGPoint(x: position.x + size, y: position.y))
            }
            context.stroke(sparklePath, with: .color(Color(annotation.color)), lineWidth: 2)
        }

        // Selection marquee (dashed border)
        context.stroke(Path(rect), with: .color(Color(annotation.color)), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
    }

    private func drawCutOut(context: GraphicsContext, annotation: DrawingAnnotation) {
        let rect = annotation.rect
        // Draw scissors cutting out a region

        // Draw cut-out area with dashed line
        context.stroke(
            Path(rect),
            with: .color(Color(annotation.color)),
            style: StrokeStyle(lineWidth: annotation.lineWidth, dash: [10, 5])
        )

        // Add corner markers to indicate cut area
        let cornerSize: CGFloat = 15
        let corners = [
            rect.origin,
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY)
        ]

        for corner in corners {
            let cornerPath = Path { path in
                if corner.x == rect.minX && corner.y == rect.minY {
                    // Top-left
                    path.move(to: corner)
                    path.addLine(to: CGPoint(x: corner.x + cornerSize, y: corner.y))
                    path.move(to: corner)
                    path.addLine(to: CGPoint(x: corner.x, y: corner.y + cornerSize))
                } else if corner.x == rect.maxX && corner.y == rect.minY {
                    // Top-right
                    path.move(to: corner)
                    path.addLine(to: CGPoint(x: corner.x - cornerSize, y: corner.y))
                    path.move(to: corner)
                    path.addLine(to: CGPoint(x: corner.x, y: corner.y + cornerSize))
                } else if corner.x == rect.minX && corner.y == rect.maxY {
                    // Bottom-left
                    path.move(to: corner)
                    path.addLine(to: CGPoint(x: corner.x + cornerSize, y: corner.y))
                    path.move(to: corner)
                    path.addLine(to: CGPoint(x: corner.x, y: corner.y - cornerSize))
                } else {
                    // Bottom-right
                    path.move(to: corner)
                    path.addLine(to: CGPoint(x: corner.x - cornerSize, y: corner.y))
                    path.move(to: corner)
                    path.addLine(to: CGPoint(x: corner.x, y: corner.y - cornerSize))
                }
            }
            context.stroke(cornerPath, with: .color(Color(annotation.color)), lineWidth: annotation.lineWidth * 1.5)
        }

        // Draw scissors icon in center
        let scissorsSize: CGFloat = min(rect.width, rect.height) * 0.2
        let scissorsCenter = CGPoint(x: rect.midX, y: rect.midY)
        let scissorsPath = Path { path in
            // Left blade circle
            path.addEllipse(in: CGRect(
                x: scissorsCenter.x - scissorsSize,
                y: scissorsCenter.y - scissorsSize / 2,
                width: scissorsSize * 0.6,
                height: scissorsSize * 0.6
            ))
            // Right blade circle
            path.addEllipse(in: CGRect(
                x: scissorsCenter.x + scissorsSize * 0.4,
                y: scissorsCenter.y - scissorsSize / 2,
                width: scissorsSize * 0.6,
                height: scissorsSize * 0.6
            ))
            // Connecting pivot
            path.move(to: CGPoint(x: scissorsCenter.x - scissorsSize * 0.3, y: scissorsCenter.y))
            path.addLine(to: CGPoint(x: scissorsCenter.x + scissorsSize * 0.3, y: scissorsCenter.y))
        }
        context.stroke(scissorsPath, with: .color(Color(annotation.color)), lineWidth: 2)
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
            case .pen, .highlighter, .eraser:
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
                
            case .shape, .blur, .spotlight, .callout, .crop:
                let rect = CGRect(
                    x: min(dragStart.x, dragCurrent.x),
                    y: min(dragStart.y, dragCurrent.y),
                    width: abs(dragCurrent.x - dragStart.x),
                    height: abs(dragCurrent.y - dragStart.y)
                )
                
                let path: Path
                switch annotation.shapeType {
                case .ellipse:
                    path = Path(ellipseIn: rect)
                default:
                    path = Path(rect)
                }
                
                if annotation.isFilled {
                    context.fill(path, with: .color(Color(annotation.color).opacity(0.3)))
                }
                context.stroke(path, with: .color(Color(annotation.color)), lineWidth: annotation.lineWidth)
                
            default:
                break
            }
        }
    }
}

// MARK: - Text Editor Sheet
struct TextEditorSheet: View {
    @State private var text: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    init(text: String, onSave: @escaping (String) -> Void) {
        self._text = State(initialValue: text)
        self.onSave = onSave
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Text")
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