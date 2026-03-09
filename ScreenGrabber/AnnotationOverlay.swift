//
//  AnnotationOverlay.swift
//  ScreenGrabber
//
//  Created by Screen Grabber Team on 11/28/25.
//
//  This file has been updated to be the single source of truth for annotation logic,
//  resolving conflicts with duplicate code in other files.
//

import SwiftUI
import AppKit

/// A model representing a single annotation drawn by the user.
struct OverlayAnnotation: Identifiable, Equatable {
    let id: UUID = UUID()
    let tool: EditorTool
    var startPoint: CGPoint
    var endPoint: CGPoint
    var color: NSColor
    var lineWidth: CGFloat
    
    static func == (lhs: OverlayAnnotation, rhs: OverlayAnnotation) -> Bool {
        return lhs.id == rhs.id &&
               lhs.tool == rhs.tool &&
               lhs.startPoint == rhs.startPoint &&
               lhs.endPoint == rhs.endPoint &&
               lhs.lineWidth == rhs.lineWidth
    }
}

// MARK: - Annotation Overlay
/// A view that overlays an image canvas to handle drawing and displaying annotations.
struct EditorAnnotationOverlay: View {
    let tool: EditorTool
    let scale: CGFloat
    let annotationColor: NSColor
    let lineWidth: CGFloat
    
    @State private var annotations: [OverlayAnnotation] = []
    @State private var currentAnnotation: OverlayAnnotation?
    
    private var shouldAllowDrawing: Bool {
        tool == .arrow || tool == .shape || tool == .line
    }
    
    var body: some View {
        ZStack {
            // Drawn Annotations
            ForEach(annotations) { annotation in
                OverlayAnnotationShape(annotation: annotation)
                    .stroke(Color(nsColor: annotation.color), lineWidth: annotation.lineWidth / scale)
            }
            
            // Current Annotation being drawn
            if let current = currentAnnotation {
                OverlayAnnotationShape(annotation: current)
                    .stroke(Color.blue.opacity(0.6), lineWidth: current.lineWidth / scale)
            }
            
            // Transparent layer to catch drag gestures
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleDrag(value)
                        }
                        .onEnded { value in
                            handleDragEnd(value)
                        }
                )
        }
        // Disable interaction when not using an annotation tool
        .allowsHitTesting(shouldAllowDrawing)
    }
    
    /// Handles the start and continuation of a drag gesture to draw an annotation.
    private func handleDrag(_ value: DragGesture.Value) {
        guard shouldAllowDrawing else { return }
        
        let point = value.location
        
        if currentAnnotation == nil {
            // Start a new annotation
            currentAnnotation = OverlayAnnotation(
                tool: tool,
                startPoint: point,
                endPoint: point,
                color: annotationColor,
                lineWidth: lineWidth
            )
        } else {
            // Update the end point of the current annotation
            currentAnnotation?.endPoint = point
        }
    }
    
    /// Finalizes the current annotation when the drag gesture ends.
    private func handleDragEnd(_ value: DragGesture.Value) {
        if let current = currentAnnotation {
            // Add the completed annotation to the array
            annotations.append(current)
            // Reset for the next one
            currentAnnotation = nil
        }
    }
}

// MARK: - Annotation Shape Renderer
/// A `Shape` that can render different types of annotations based on their properties.
struct OverlayAnnotationShape: Shape {
    let annotation: OverlayAnnotation
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch annotation.tool {
        case .shape:
            let rect = CGRect(
                x: min(annotation.startPoint.x, annotation.endPoint.x),
                y: min(annotation.startPoint.y, annotation.endPoint.y),
                width: abs(annotation.endPoint.x - annotation.startPoint.x),
                height: abs(annotation.endPoint.y - annotation.startPoint.y)
            )
            path.addRect(rect)
        case .arrow:
            path.move(to: annotation.startPoint)
            path.addLine(to: annotation.endPoint)
            // TODO: Add arrowhead rendering if desired
        default:
            break
        }
        return path
    }
}

