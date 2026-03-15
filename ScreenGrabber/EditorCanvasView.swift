//
//  EditorCanvasView.swift
//  ScreenGrabber
//
//  Interactive canvas for drawing annotations
//

import SwiftUI
import Combine
import Combine

struct EditorCanvasView: View {
    let image: NSImage
    @ObservedObject var editorState: EditorStateManager
    let viewMode: ScreenshotEditorView.ViewMode
    
    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var selectedHandle: ResizeHandle?
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    // Base image
                    if viewMode == .original {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else if viewMode == .split {
                        HStack(spacing: 2) {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: image.size.width / 2)
                                .clipped()
                            
                            ZStack {
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                
                                Canvas { context, size in
                                    drawAnnotations(context: context, size: size)
                                }
                            }
                            .frame(width: image.size.width / 2)
                            .clipped()
                        }
                    } else {
                        ZStack {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                            
                            // Annotations layer
                            Canvas { context, size in
                                drawAnnotations(context: context, size: size)
                            }
                            .frame(width: image.size.width, height: image.size.height)
                            
                            // Current drawing layer
                            if let start = dragStart, let current = dragCurrent {
                                Canvas { context, size in
                                    drawCurrentAnnotation(
                                        context: context,
                                        start: start,
                                        current: current
                                    )
                                }
                                .frame(width: image.size.width, height: image.size.height)
                            }
                            
                            // Snap guides
                            if editorState.showSnapGuides {
                                Canvas { context, size in
                                    drawSnapGuides(context: context, size: size)
                                }
                                .frame(width: image.size.width, height: image.size.height)
                            }
                            
                            // Selection handles
                            if let selected = editorState.selectedAnnotation {
                                SelectionHandlesView(
                                    annotation: selected,
                                    onDrag: { handle, translation in
                                        handleResize(annotation: selected, handle: handle, translation: translation)
                                    },
                                    onRotate: { angle in
                                        selected.rotation = angle
                                    }
                                )
                            }
                        }
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleDragChanged(value, in: geometry.size)
                        }
                        .onEnded { value in
                            handleDragEnded(value, in: geometry.size)
                        }
                )
                .onTapGesture { location in
                    handleTap(at: location)
                }
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }
    
    // MARK: - Drawing
    
    private func drawAnnotations(context: GraphicsContext, size: CGSize) {
        for annotation in editorState.annotations {
            var context = context
            context.opacity = annotation.opacity

            // Apply rotation transform around annotation center
            if annotation.rotation != 0.0 {
                let centerX = (annotation.cgStartPoint.x + annotation.cgEndPoint.x) / 2
                let centerY = (annotation.cgStartPoint.y + annotation.cgEndPoint.y) / 2
                let center = CGPoint(x: centerX, y: centerY)
                context.translateBy(x: center.x, y: center.y)
                context.rotate(by: .radians(annotation.rotation))
                context.translateBy(x: -center.x, y: -center.y)
            }
            
            switch annotation.tool {
            case .arrow:
                drawArrow(annotation, in: context)
            case .rectangle:
                drawRectangle(annotation, in: context)
            case .ellipse:
                drawEllipse(annotation, in: context)
            case .line:
                drawLine(annotation, in: context)
            case .text:
                drawText(annotation, in: context)
            case .highlighter:
                drawHighlight(annotation, in: context)
            case .freehand:
                drawFreehand(annotation, in: context)
            default:
                break
            }
            
            // Draw selection border
            if editorState.selectedAnnotation?.id == annotation.id {
                if let bounds = annotation.bounds {
                    context.stroke(
                        Path(bounds.cgRect),
                        with: .color(.blue),
                        style: StrokeStyle(lineWidth: 2, dash: [5, 3])
                    )
                }
            }
        }
    }
    
    private func drawCurrentAnnotation(context: GraphicsContext, start: CGPoint, current: CGPoint) {
        var context = context
        context.opacity = editorState.opacity
        
        let rect = CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
        
        let color = Color(editorState.strokeColor)
        let lineWidth = editorState.lineWidth
        
        switch editorState.selectedTool {
        case .arrow:
            // Draw line
            context.stroke(
                Path { path in
                    path.move(to: start)
                    path.addLine(to: current)
                },
                with: .color(color),
                lineWidth: lineWidth
            )
            
            // Draw arrowhead
            let angle = atan2(current.y - start.y, current.x - start.x)
            let arrowLength: CGFloat = 15
            let arrowAngle: CGFloat = .pi / 6
            
            context.stroke(
                Path { path in
                    path.move(to: current)
                    path.addLine(to: CGPoint(
                        x: current.x - arrowLength * cos(angle - arrowAngle),
                        y: current.y - arrowLength * sin(angle - arrowAngle)
                    ))
                    path.move(to: current)
                    path.addLine(to: CGPoint(
                        x: current.x - arrowLength * cos(angle + arrowAngle),
                        y: current.y - arrowLength * sin(angle + arrowAngle)
                    ))
                },
                with: .color(color),
                lineWidth: lineWidth
            )
            
        case .rectangle:
            if editorState.isFilled, let fillColor = editorState.fillColor {
                context.fill(Path(rect), with: .color(Color(fillColor)))
            }
            context.stroke(Path(rect), with: .color(color), lineWidth: lineWidth)
            
        case .ellipse:
            if editorState.isFilled, let fillColor = editorState.fillColor {
                context.fill(Path(ellipseIn: rect), with: .color(Color(fillColor)))
            }
            context.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: lineWidth)
            
        case .line:
            context.stroke(
                Path { path in
                    path.move(to: start)
                    path.addLine(to: current)
                },
                with: .color(color),
                lineWidth: lineWidth
            )
            
        case .highlight:
            context.fill(Path(rect), with: .color(color.opacity(0.3)))
            
        case .blur:
            context.fill(Path(rect), with: .color(.white.opacity(0.6)))
            context.stroke(Path(rect), with: .color(color), lineWidth: 1)
            
        default:
            break
        }
    }
    
    private func drawSnapGuides(context: GraphicsContext, size: CGSize) {
        for guide in editorState.snapGuides {
            let path: Path
            switch guide.type {
            case .horizontal:
                path = Path { p in
                    p.move(to: CGPoint(x: 0, y: guide.position))
                    p.addLine(to: CGPoint(x: size.width, y: guide.position))
                }
            case .vertical:
                path = Path { p in
                    p.move(to: CGPoint(x: guide.position, y: 0))
                    p.addLine(to: CGPoint(x: guide.position, y: size.height))
                }
            }
            
            context.stroke(
                path,
                with: .color(.blue.opacity(0.5)),
                style: StrokeStyle(lineWidth: 1, dash: [4, 4])
            )
        }
    }
    
    // MARK: - Annotation Drawing Helpers
    
    private func drawArrow(_ annotation: Annotation, in context: GraphicsContext) {
        let start = annotation.cgStartPoint
        let end = annotation.cgEndPoint
        let color = Color(annotation.strokeColor.nsColor)
        
        context.stroke(
            Path { path in
                path.move(to: start)
                path.addLine(to: end)
            },
            with: .color(color),
            lineWidth: annotation.lineWidth
        )
        
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = 15
        let arrowAngle: CGFloat = .pi / 6
        
        context.stroke(
            Path { path in
                path.move(to: end)
                path.addLine(to: CGPoint(
                    x: end.x - arrowLength * cos(angle - arrowAngle),
                    y: end.y - arrowLength * sin(angle - arrowAngle)
                ))
                path.move(to: end)
                path.addLine(to: CGPoint(
                    x: end.x - arrowLength * cos(angle + arrowAngle),
                    y: end.y - arrowLength * sin(angle + arrowAngle)
                ))
            },
            with: .color(color),
            lineWidth: annotation.lineWidth
        )
    }
    
    private func drawRectangle(_ annotation: Annotation, in context: GraphicsContext) {
        let rect = CGRect(
            x: min(annotation.cgStartPoint.x, annotation.cgEndPoint.x),
            y: min(annotation.cgStartPoint.y, annotation.cgEndPoint.y),
            width: abs(annotation.cgEndPoint.x - annotation.cgStartPoint.x),
            height: abs(annotation.cgEndPoint.y - annotation.cgStartPoint.y)
        )
        let color = Color(annotation.strokeColor.nsColor)
        
        if let fillColor = annotation.fillColor {
            context.fill(Path(rect), with: .color(Color(fillColor.nsColor)))
        }
        
        context.stroke(Path(rect), with: .color(color), lineWidth: annotation.lineWidth)
    }
    
    private func drawEllipse(_ annotation: Annotation, in context: GraphicsContext) {
        let rect = CGRect(
            x: min(annotation.cgStartPoint.x, annotation.cgEndPoint.x),
            y: min(annotation.cgStartPoint.y, annotation.cgEndPoint.y),
            width: abs(annotation.cgEndPoint.x - annotation.cgStartPoint.x),
            height: abs(annotation.cgEndPoint.y - annotation.cgStartPoint.y)
        )
        let color = Color(annotation.strokeColor.nsColor)
        
        if let fillColor = annotation.fillColor {
            context.fill(Path(ellipseIn: rect), with: .color(Color(fillColor.nsColor)))
        }
        
        context.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: annotation.lineWidth)
    }
    
    private func drawLine(_ annotation: Annotation, in context: GraphicsContext) {
        let color = Color(annotation.strokeColor.nsColor)
        
        context.stroke(
            Path { path in
                path.move(to: annotation.cgStartPoint)
                path.addLine(to: annotation.cgEndPoint)
            },
            with: .color(color),
            lineWidth: annotation.lineWidth
        )
    }
    
    private func drawText(_ annotation: Annotation, in context: GraphicsContext) {
        guard let text = annotation.text else { return }
        let fontSize = annotation.fontSize
        
        let resolved = context.resolve(
            Text(text)
                .font(.system(size: fontSize))
                .foregroundColor(Color(annotation.strokeColor.nsColor))
        )
        
        context.draw(resolved, at: annotation.cgStartPoint, anchor: .topLeading)
    }
    
    private func drawHighlight(_ annotation: Annotation, in context: GraphicsContext) {
        let rect = CGRect(
            x: min(annotation.cgStartPoint.x, annotation.cgEndPoint.x),
            y: min(annotation.cgStartPoint.y, annotation.cgEndPoint.y),
            width: abs(annotation.cgEndPoint.x - annotation.cgStartPoint.x),
            height: abs(annotation.cgEndPoint.y - annotation.cgStartPoint.y)
        )
        let color = Color(annotation.strokeColor.nsColor)
        
        context.fill(Path(rect), with: .color(color.opacity(0.3)))
    }
    
    private func drawFreehand(_ annotation: Annotation, in context: GraphicsContext) {
        let points = annotation.cgControlPoints
        guard !points.isEmpty else { return }
        let color = Color(annotation.strokeColor.nsColor)
        
        context.stroke(
            Path { path in
                path.move(to: points[0])
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
            },
            with: .color(color),
            style: StrokeStyle(lineWidth: annotation.lineWidth, lineCap: .round, lineJoin: .round)
        )
    }
    
    // MARK: - Gesture Handling
    
    private func handleDragChanged(_ value: DragGesture.Value, in size: CGSize) {
        if dragStart == nil {
            dragStart = editorState.checkSnapping(for: value.startLocation)
        }
        dragCurrent = editorState.checkSnapping(for: value.location)
    }
    
    private func handleDragEnded(_ value: DragGesture.Value, in size: CGSize) {
        guard let start = dragStart, let end = dragCurrent else { return }
        
        // Only create annotation if drag is significant
        guard abs(end.x - start.x) > 5 || abs(end.y - start.y) > 5 else {
            dragStart = nil
            dragCurrent = nil
            editorState.showSnapGuides = false
            return
        }
        
        // Create annotation based on tool using proper Annotation initializer
        let annotation = Annotation(
            toolType: editorState.selectedTool,
            startPoint: start,
            endPoint: end,
            strokeColor: editorState.strokeColor,
            lineWidth: editorState.lineWidth,
            fontSize: 16.0
        )
        
        // Set fill color if applicable
        if let fillColor = editorState.fillColor {
            annotation.fillColor = CodableColor(color: fillColor)
        }
        
        // Set opacity
        annotation.opacity = editorState.opacity
        
        // Set text for text tool
        if editorState.selectedTool == .text {
            annotation.text = "Text"
        }
        
        editorState.addAnnotation(annotation)
        
        dragStart = nil
        dragCurrent = nil
        editorState.showSnapGuides = false
    }
    
    private func handleTap(at location: CGPoint) {
        // Check if tapping on an annotation
        for annotation in editorState.annotations.reversed() {
            if annotation.contains(point: location) {
                editorState.selectedAnnotation = annotation
                return
            }
        }
        
        editorState.selectedAnnotation = nil
    }
    
    private func handleResize(annotation: Annotation, handle: ResizeHandle, translation: CGSize) {
        // Calculate the new rect based on handle and translation
        let currentStart = annotation.cgStartPoint
        let currentEnd = annotation.cgEndPoint
        
        var newStart = currentStart
        var newEnd = currentEnd
        
        // Adjust points based on which handle is being dragged
        switch handle {
        case .topLeft:
            newStart.x += translation.width
            newStart.y += translation.height
        case .topRight:
            newEnd.x += translation.width
            newStart.y += translation.height
        case .bottomLeft:
            newStart.x += translation.width
            newEnd.y += translation.height
        case .bottomRight:
            newEnd.x += translation.width
            newEnd.y += translation.height
        }
        
        // Update the annotation's points
        annotation.startPoint = CodablePoint(point: newStart)
        annotation.endPoint = CodablePoint(point: newEnd)
        _ = annotation.calculateBounds()
        
        editorState.updateAnnotation(annotation)
    }
}

// MARK: - Selection Handles

enum ResizeHandle: CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight
}

struct SelectionHandlesView: View {
    let annotation: Annotation
    let onDrag: (ResizeHandle, CGSize) -> Void
    var onRotate: ((Double) -> Void)? = nil

    @State private var rotateStart: CGPoint? = nil
    @State private var rotateStartAngle: Double = 0
    
    var body: some View {
        let rect = CGRect(
            x: min(annotation.cgStartPoint.x, annotation.cgEndPoint.x),
            y: min(annotation.cgStartPoint.y, annotation.cgEndPoint.y),
            width: abs(annotation.cgEndPoint.x - annotation.cgStartPoint.x),
            height: abs(annotation.cgEndPoint.y - annotation.cgStartPoint.y)
        )
        let center = CGPoint(x: rect.midX, y: rect.midY)
        
        ZStack {
            // Resize handles
            ForEach(ResizeHandle.allCases, id: \.self) { handle in
                Circle()
                    .fill(Color.white)
                    .stroke(Color.blue, lineWidth: 2)
                    .frame(width: 12, height: 12)
                    .position(handlePosition(for: handle, in: rect))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                onDrag(handle, value.translation)
                            }
                    )
            }

            // Rotation handle — circle above the top edge
            let rotHandlePos = CGPoint(x: rect.midX, y: rect.minY - 28)
            ZStack {
                // Connector line
                Path { p in
                    p.move(to: CGPoint(x: rect.midX, y: rect.minY))
                    p.addLine(to: rotHandlePos)
                }
                .stroke(Color.blue, lineWidth: 1)
                
                // Handle knob
                Circle()
                    .fill(Color.white)
                    .stroke(Color.blue, lineWidth: 2)
                    .frame(width: 12, height: 12)
                    .position(rotHandlePos)
                    .gesture(
                        DragGesture(minimumDistance: 2)
                            .onChanged { value in
                                if rotateStart == nil {
                                    rotateStart = value.startLocation
                                    rotateStartAngle = annotation.rotation
                                }
                                let dx = value.location.x - center.x
                                let dy = value.location.y - center.y
                                let angle = atan2(dy, dx)
                                let startDx = rotHandlePos.x - center.x
                                let startDy = rotHandlePos.y - center.y
                                let startAngle = atan2(startDy, startDx)
                                let delta = angle - startAngle
                                onRotate?(rotateStartAngle + Double(delta))
                            }
                            .onEnded { _ in rotateStart = nil }
                    )
                    .help("Drag to rotate")
            }
        }
    }
    
    private func handlePosition(for handle: ResizeHandle, in rect: CGRect) -> CGPoint {
        switch handle {
        case .topLeft: return CGPoint(x: rect.minX, y: rect.minY)
        case .topRight: return CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeft: return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomRight: return CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }
}

#Preview {
    EditorCanvasView(
        image: NSImage(systemSymbolName: "photo", accessibilityDescription: nil)!,
        editorState: EditorStateManager(),
        viewMode: .annotated
    )
    .frame(width: 800, height: 600)
}
