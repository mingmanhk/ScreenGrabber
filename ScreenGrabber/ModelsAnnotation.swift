//
//  Annotation.swift
//  ScreenGrabber
//
//  Complete SwiftData model for screenshot annotations
//  PRODUCTION-READY IMPLEMENTATION
//

import Foundation
import SwiftData
import AppKit

// MARK: - Editor Tool Definition
// EditorTool is now defined in EditorModels.swift to avoid ambiguity
// This file uses the centralized definition

// MARK: - Codable Geometry Types
// CodablePoint, CodableRect, CodableColor, and CodableSize are now defined in CodableGeometry.swift
// This file uses those centralized definitions

// MARK: - Annotation Model

@Model
final class Annotation {
    // MARK: - Identity
    var id: UUID
    var timestamp: Date
    
    // MARK: - Tool & Style
    var toolType: String  // EditorTool.rawValue
    var strokeColor: CodableColor
    var fillColor: CodableColor?
    var lineWidth: Double
    var fontSize: Double
    var opacity: Double
    
    // MARK: - Geometry
    var startPoint: CodablePoint
    var endPoint: CodablePoint
    var controlPoints: [CodablePoint]  // For bezier curves and freehand
    var bounds: CodableRect?  // Cached bounds for hit-testing
    
    // MARK: - Content
    var text: String?
    var stepNumber: Int?
    
    // MARK: - Visual Properties
    var layer: Int  // Z-order for overlapping annotations
    var isHidden: Bool
    var isLocked: Bool
    var rotation: Double  // radians, 0 = no rotation
    var shadowEnabled: Bool
    var shadowBlur: Double
    
    // MARK: - Relationship
    var screenshot: Screenshot?
    
    // MARK: - Initialization
    @MainActor
    init(
        toolType: EditorTool,
        startPoint: CGPoint,
        endPoint: CGPoint,
        strokeColor: NSColor = .red,
        lineWidth: Double = 2.0,
        fontSize: Double = 16.0
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.toolType = toolType.rawValue
        self.strokeColor = CodableColor(color: strokeColor)
        self.startPoint = CodablePoint(point: startPoint)
        self.endPoint = CodablePoint(point: endPoint)
        self.lineWidth = lineWidth
        self.fontSize = fontSize
        self.opacity = 1.0
        self.controlPoints = []
        self.layer = 0
        self.isHidden = false
        self.isLocked = false
        self.rotation = 0.0
        self.shadowEnabled = false
        self.shadowBlur = 4.0
    }
    
    // MARK: - Conversion
    var tool: EditorTool {
        EditorTool(rawValue: toolType) ?? .selection
    }
    
    @MainActor
    var nsStrokeColor: NSColor {
        strokeColor.nsColor.withAlphaComponent(opacity)
    }
    
    @MainActor
    var nsFillColor: NSColor? {
        fillColor?.nsColor.withAlphaComponent(opacity * 0.3)
    }
    
    var cgStartPoint: CGPoint {
        startPoint.cgPoint
    }
    
    var cgEndPoint: CGPoint {
        endPoint.cgPoint
    }
    
    var cgControlPoints: [CGPoint] {
        controlPoints.map { $0.cgPoint }
    }
    
    // MARK: - Bounds Calculation
    func calculateBounds() -> CGRect {
        var minX = min(cgStartPoint.x, cgEndPoint.x)
        var minY = min(cgStartPoint.y, cgEndPoint.y)
        var maxX = max(cgStartPoint.x, cgEndPoint.x)
        var maxY = max(cgStartPoint.y, cgEndPoint.y)
        
        // Include control points
        for point in cgControlPoints {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }
        
        // Add padding for line width
        let padding = lineWidth / 2 + 5
        
        let rect = CGRect(
            x: minX - padding,
            y: minY - padding,
            width: (maxX - minX) + (padding * 2),
            height: (maxY - minY) + (padding * 2)
        )
        
        self.bounds = CodableRect(rect: rect)
        return rect
    }
    
    // MARK: - Hit Testing
    func contains(point: CGPoint, tolerance: Double = 10.0) -> Bool {
        // First check bounds
        guard let bounds = bounds else {
            return calculateBounds().contains(point)
        }
        
        let boundsRect = bounds.cgRect
        let expandedBounds = boundsRect.insetBy(dx: -tolerance, dy: -tolerance)
        
        if !expandedBounds.contains(point) {
            return false
        }
        
        // Detailed hit test based on tool type
        switch tool {
        case .line, .arrow:
            return distanceToLine(from: cgStartPoint, to: cgEndPoint, point: point) < tolerance
            
        case .rectangle, .shape:
            let rect = calculateShapeRect()
            let expandedRect = rect.insetBy(dx: -tolerance, dy: -tolerance)
            let shrunkRect = rect.insetBy(dx: tolerance, dy: tolerance)
            
            // Hit if on edge (not inside)
            return expandedRect.contains(point) && !shrunkRect.contains(point)
            
        case .ellipse:
            let rect = calculateShapeRect()
            return distanceToEllipse(rect: rect, point: point) < tolerance
            
        case .text:
            return boundsRect.contains(point)
            
        case .freehand:
            // Check distance to any line segment
            for i in 0..<cgControlPoints.count - 1 {
                let start = cgControlPoints[i]
                let end = cgControlPoints[i + 1]
                if distanceToLine(from: start, to: end, point: point) < tolerance {
                    return true
                }
            }
            return false
            
        default:
            return boundsRect.contains(point)
        }
    }
    
    private func distanceToLine(from start: CGPoint, to end: CGPoint, point: CGPoint) -> Double {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        
        if lengthSquared == 0 {
            return hypot(point.x - start.x, point.y - start.y)
        }
        
        let t = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
        let projX = start.x + t * dx
        let projY = start.y + t * dy
        
        return hypot(point.x - projX, point.y - projY)
    }
    
    private func distanceToEllipse(rect: CGRect, point: CGPoint) -> Double {
        let centerX = rect.midX
        let centerY = rect.midY
        let radiusX = rect.width / 2
        let radiusY = rect.height / 2
        
        let dx = point.x - centerX
        let dy = point.y - centerY
        
        let normalizedDist = sqrt((dx * dx) / (radiusX * radiusX) + (dy * dy) / (radiusY * radiusY))
        
        return abs(normalizedDist - 1) * min(radiusX, radiusY)
    }
    
    private func calculateShapeRect() -> CGRect {
        CGRect(
            x: min(cgStartPoint.x, cgEndPoint.x),
            y: min(cgStartPoint.y, cgEndPoint.y),
            width: abs(cgEndPoint.x - cgStartPoint.x),
            height: abs(cgEndPoint.y - cgStartPoint.y)
        )
    }
    
    // MARK: - Rendering
    func path() -> NSBezierPath {
        let path = NSBezierPath()
        
        switch tool {
        case .line, .arrow:
            path.move(to: cgStartPoint)
            path.line(to: cgEndPoint)
            
        case .rectangle, .shape:
            let rect = calculateShapeRect()
            path.appendRect(rect)
            
        case .ellipse:
            let rect = calculateShapeRect()
            path.appendOval(in: rect)
            
        case .freehand:
            if !cgControlPoints.isEmpty {
                path.move(to: cgControlPoints[0])
                for point in cgControlPoints.dropFirst() {
                    path.line(to: point)
                }
            }
            
        case .highlighter:
            if !cgControlPoints.isEmpty {
                path.move(to: cgControlPoints[0])
                for point in cgControlPoints.dropFirst() {
                    path.line(to: point)
                }
            }
            
        default:
            break
        }
        
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        
        return path
    }
    
    // MARK: - Manipulation
    func translate(by offset: CGPoint) {
        startPoint = CodablePoint(point: CGPoint(
            x: cgStartPoint.x + offset.x,
            y: cgStartPoint.y + offset.y
        ))
        
        endPoint = CodablePoint(point: CGPoint(
            x: cgEndPoint.x + offset.x,
            y: cgEndPoint.y + offset.y
        ))
        
        controlPoints = cgControlPoints.map { point in
            CodablePoint(point: CGPoint(
                x: point.x + offset.x,
                y: point.y + offset.y
            ))
        }
        
        _ = calculateBounds()
    }
    
    func scale(by factor: CGFloat, around anchor: CGPoint) {
        let scalePoint = { (point: CGPoint) -> CGPoint in
            CGPoint(
                x: anchor.x + (point.x - anchor.x) * factor,
                y: anchor.y + (point.y - anchor.y) * factor
            )
        }
        
        startPoint = CodablePoint(point: scalePoint(cgStartPoint))
        endPoint = CodablePoint(point: scalePoint(cgEndPoint))
        controlPoints = cgControlPoints.map { CodablePoint(point: scalePoint($0)) }
        
        lineWidth *= Double(factor)
        
        _ = calculateBounds()
    }
    
    func rotate(by angle: CGFloat, around anchor: CGPoint) {
        let rotatePoint = { (point: CGPoint) -> CGPoint in
            let dx = point.x - anchor.x
            let dy = point.y - anchor.y
            let cos = cos(angle)
            let sin = sin(angle)
            
            return CGPoint(
                x: anchor.x + dx * cos - dy * sin,
                y: anchor.y + dx * sin + dy * cos
            )
        }
        
        startPoint = CodablePoint(point: rotatePoint(cgStartPoint))
        endPoint = CodablePoint(point: rotatePoint(cgEndPoint))
        controlPoints = cgControlPoints.map { CodablePoint(point: rotatePoint($0)) }
        
        _ = calculateBounds()
    }
}

// MARK: - Equatable
extension Annotation: Equatable {
    static func == (lhs: Annotation, rhs: Annotation) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Compatibility Extensions for Legacy Code
extension Annotation {
    /// Compatibility wrapper for geometry property
    var geometry: AnnotationGeometry {
        get {
            AnnotationGeometry(
                rect: bounds ?? CodableRect(rect: calculateBounds()),
                points: controlPoints
            )
        }
    }
    
    /// Compatibility wrapper for style property
    var style: AnnotationStyle {
        get {
            AnnotationStyle(
                strokeColor: strokeColor,
                fillColor: fillColor,
                lineWidth: lineWidth,
                isFilled: fillColor != nil
            )
        }
    }
    
    /// Compatibility wrapper for content property  
    var content: AnnotationContent {
        get {
            AnnotationContent(
                text: text,
                fontSize: fontSize,
                stepNumber: stepNumber
            )
        }
    }
}

/// Compatibility structure for annotation geometry
struct AnnotationGeometry {
    var rect: CodableRect
    var points: [CodablePoint]
}

/// Compatibility structure for annotation style
struct AnnotationStyle {
    var strokeColor: CodableColor
    var fillColor: CodableColor?
    var lineWidth: Double
    var isFilled: Bool
}

/// Compatibility structure for annotation content
struct AnnotationContent {
    var text: String?
    var fontSize: Double
    var stepNumber: Int?
}


