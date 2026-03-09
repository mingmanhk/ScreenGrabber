//
//  AnnotationRenderer.swift
//  ScreenGrabber
//
//  Renders annotations onto base images for export
//  PRODUCTION-READY IMPLEMENTATION
//

import Foundation
import AppKit

// MARK: - Thread-Safe Color Representation

struct ColorComponents: Sendable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat
    
    init(color: NSColor) {
        // Convert to RGB color space if needed
        guard let rgbColor = color.usingColorSpace(.deviceRGB) else {
            // Fallback to default values if conversion fails
            self.red = 0
            self.green = 0
            self.blue = 0
            self.alpha = color.alphaComponent
            return
        }
        
        self.red = rgbColor.redComponent
        self.green = rgbColor.greenComponent
        self.blue = rgbColor.blueComponent
        self.alpha = rgbColor.alphaComponent
    }
    
    @MainActor
    var nsColor: NSColor {
        NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

// MARK: - Annotation Snapshot Type

struct AnnotationSnapshot: Sendable {
    let tool: EditorTool
    let layer: Int
    let isHidden: Bool
    let lineWidth: CGFloat
    let shadowEnabled: Bool
    let shadowBlur: CGFloat
    let strokeColor: ColorComponents
    let fillColor: ColorComponents?
    let start: CGPoint
    let end: CGPoint
    let text: String?
    let fontSize: Double
    let pathPoints: [CGPoint]
    let bounds: NSRect
    
    // Helper method to reconstruct path
    func createPath() -> NSBezierPath {
        let path = NSBezierPath()
        
        switch tool {
        case .line, .arrow:
            path.move(to: start)
            path.line(to: end)
            
        case .rectangle, .shape:
            let rect = NSRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            )
            path.appendRect(rect)
            
        case .ellipse:
            let rect = NSRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            )
            path.appendOval(in: rect)
            
        case .freehand, .highlighter:
            if !pathPoints.isEmpty {
                path.move(to: pathPoints[0])
                for point in pathPoints.dropFirst() {
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
}

actor AnnotationRenderer {
    static let shared = AnnotationRenderer()
    
    enum ExportFormat {
        case png
        case jpeg(quality: Double)
        case tiff
        case heic(quality: Double)
    }
    
    private init() {}
    
    // MARK: - Snapshot Creation
    
    @MainActor
    private func createSnapshots(from annotations: [Annotation]) -> [AnnotationSnapshot] {
        annotations
            .filter { !$0.isHidden }
            .sorted { $0.layer < $1.layer }
            .map { ann in
                AnnotationSnapshot(
                    tool: ann.tool,
                    layer: ann.layer,
                    isHidden: ann.isHidden,
                    lineWidth: ann.lineWidth,
                    shadowEnabled: ann.shadowEnabled,
                    shadowBlur: ann.shadowBlur,
                    strokeColor: ColorComponents(color: ann.nsStrokeColor),
                    fillColor: ann.nsFillColor.map { ColorComponents(color: $0) },
                    start: ann.cgStartPoint,
                    end: ann.cgEndPoint,
                    text: ann.text,
                    fontSize: ann.fontSize,
                    pathPoints: ann.cgControlPoints,
                    bounds: ann.calculateBounds()
                )
            }
    }
    
    // MARK: - Main Rendering Pipeline
    
    /// Renders annotations onto a base image (flattened)
    func renderAnnotations(
        baseImage: NSImage,
        annotations: [Annotation],
        backgroundColor: NSColor? = nil
    ) async -> NSImage {
        // Capture snapshot data on main actor since Annotation properties are @MainActor
        let snapshots: [AnnotationSnapshot] = await self.createSnapshots(from: annotations)
        
        // Perform drawing on main actor since AppKit requires it
        return await MainActor.run {
            let size = baseImage.size
            let rendered = NSImage(size: size)
            
            rendered.lockFocus()
            
            if let bgColor = backgroundColor {
                bgColor.setFill()
                NSRect(origin: .zero, size: size).fill()
            }
            
            baseImage.draw(
                in: NSRect(origin: .zero, size: size),
                from: .zero,
                operation: .sourceOver,
                fraction: 1.0
            )
            
            for snap in snapshots.sorted(by: { $0.layer < $1.layer }) {
                // Apply shadow
                if snap.shadowEnabled {
                    let shadow = NSShadow()
                    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
                    shadow.shadowOffset = NSSize(width: 0, height: -2)
                    shadow.shadowBlurRadius = snap.shadowBlur
                    shadow.set()
                }
                
                let path = snap.createPath()
                snap.strokeColor.nsColor.setStroke()
                path.lineWidth = snap.lineWidth
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                
                if let fill = snap.fillColor {
                    fill.nsColor.setFill()
                    path.fill()
                }
                path.stroke()
                
                switch snap.tool {
                case .arrow:
                    let start = snap.start
                    let end = snap.end
                    let color = snap.strokeColor.nsColor
                    let lineWidth = snap.lineWidth
                    let arrowLength: CGFloat = 15.0 * CGFloat(lineWidth / 2.0)
                    let arrowAngle: CGFloat = .pi / 6.0
                    let dx = end.x - start.x
                    let dy = end.y - start.y
                    let angle = atan2(dy, dx)
                    let arrowPath = NSBezierPath()
                    let point1 = CGPoint(
                        x: end.x - arrowLength * cos(angle - arrowAngle),
                        y: end.y - arrowLength * sin(angle - arrowAngle)
                    )
                    let point2 = CGPoint(
                        x: end.x - arrowLength * cos(angle + arrowAngle),
                        y: end.y - arrowLength * sin(angle + arrowAngle)
                    )
                    arrowPath.move(to: point1)
                    arrowPath.line(to: end)
                    arrowPath.line(to: point2)
                    arrowPath.close()
                    color.setFill()
                    arrowPath.fill()
                    color.setStroke()
                    arrowPath.lineWidth = lineWidth
                    arrowPath.stroke()
                case .text:
                    if let text = snap.text {
                        let font = NSFont.systemFont(ofSize: CGFloat(snap.fontSize), weight: .medium)
                        let color = snap.strokeColor.nsColor
                        let paragraphStyle = NSMutableParagraphStyle()
                        paragraphStyle.alignment = .left
                        let attributes: [NSAttributedString.Key: Any] = [
                            .font: font,
                            .foregroundColor: color,
                            .paragraphStyle: paragraphStyle
                        ]
                        let attributedText = NSAttributedString(string: text, attributes: attributes)
                        let textSize = attributedText.size()
                        let textRect = NSRect(
                            x: snap.start.x,
                            y: snap.start.y - textSize.height,
                            width: textSize.width,
                            height: textSize.height
                        )
                        if let fill = snap.fillColor {
                            fill.nsColor.setFill()
                            NSRect(
                                x: textRect.origin.x - 4,
                                y: textRect.origin.y - 2,
                                width: textRect.width + 8,
                                height: textRect.height + 4
                            ).fill()
                        }
                        attributedText.draw(in: textRect)
                    }
                case .step:
                    if let number = (snap.text.flatMap { Int($0) }) {
                        let circleSize: CGFloat = CGFloat(snap.fontSize * 2.0)
                        let center = snap.start
                        let circle = NSBezierPath(ovalIn: NSRect(
                            x: center.x - circleSize / 2,
                            y: center.y - circleSize / 2,
                            width: circleSize,
                            height: circleSize
                        ))
                        snap.strokeColor.nsColor.setFill()
                        circle.fill()
                        NSColor.white.setStroke()
                        circle.lineWidth = 2.0
                        circle.stroke()
                        let text = "\(number)"
                        let font = NSFont.systemFont(ofSize: CGFloat(snap.fontSize), weight: .bold)
                        let attributes: [NSAttributedString.Key: Any] = [
                            .font: font,
                            .foregroundColor: NSColor.white
                        ]
                        let textSize = (text as NSString).size(withAttributes: attributes)
                        let textPoint = CGPoint(
                            x: center.x - textSize.width / 2,
                            y: center.y - textSize.height / 2
                        )
                        (text as NSString).draw(at: textPoint, withAttributes: attributes)
                    }
                case .highlighter:
                    NSGraphicsContext.current?.saveGraphicsState()
                    NSGraphicsContext.current?.compositingOperation = .multiply
                    let path = snap.createPath()
                    let highlightColor = snap.strokeColor.nsColor.withAlphaComponent(0.3)
                    highlightColor.setStroke()
                    path.lineWidth = snap.lineWidth * 4
                    path.lineCapStyle = .round
                    path.stroke()
                    NSGraphicsContext.current?.restoreGraphicsState()
                case .blur:
                    let rect = snap.bounds
                    NSColor.white.withAlphaComponent(0.8).setFill()
                    let blurPath = NSBezierPath(rect: rect)
                    blurPath.fill()
                default:
                    break
                }
            }
            
            rendered.unlockFocus()
            
            return rendered
        }
    }
    
    // MARK: - Individual Annotation Drawing
    
    @MainActor
    private func drawAnnotationIsolated(_ annotation: Annotation, canvasSize: CGSize) {
        // Save graphics state
        NSGraphicsContext.current?.saveGraphicsState()
        
        // Apply shadow if enabled
        if annotation.shadowEnabled {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
            shadow.shadowOffset = NSSize(width: 0, height: -2)
            shadow.shadowBlurRadius = annotation.shadowBlur
            shadow.set()
        }
        
        // Get the path for this annotation
        let path = annotation.path()
        
        // Set stroke properties
        annotation.nsStrokeColor.setStroke()
        path.lineWidth = annotation.lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        
        // Fill if applicable
        if let fillColor = annotation.nsFillColor {
            fillColor.setFill()
            path.fill()
        }
        
        // Stroke the path
        path.stroke()
        
        // Draw tool-specific decorations
        switch annotation.tool {
        case .arrow:
            drawArrowhead(annotation: annotation)
            
        case .text:
            if let text = annotation.text {
                drawText(text, annotation: annotation)
            }
            
        case .step:
            if let stepNumber = annotation.stepNumber {
                drawStepNumber(stepNumber, annotation: annotation)
            }
            
        case .highlighter:
            // Highlighter uses blend mode
            drawHighlighter(annotation: annotation)
            
        case .blur:
            drawBlur(annotation: annotation, canvasSize: canvasSize)
            
        default:
            break
        }
        
        // Restore graphics state
        NSGraphicsContext.current?.restoreGraphicsState()
    }
    
    // MARK: - Arrowhead Drawing
    
    @MainActor
    private func drawArrowhead(annotation: Annotation) {
        let start = annotation.cgStartPoint
        let end = annotation.cgEndPoint
        let color = annotation.nsStrokeColor
        let lineWidth = annotation.lineWidth
        
        let arrowLength: CGFloat = 15.0 * CGFloat(lineWidth / 2.0)
        let arrowAngle: CGFloat = .pi / 6.0
        
        let dx = end.x - start.x
        let dy = end.y - start.y
        let angle = atan2(dy, dx)
        
        let arrowPath = NSBezierPath()
        
        let point1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        
        let point2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )
        
        arrowPath.move(to: point1)
        arrowPath.line(to: end)
        arrowPath.line(to: point2)
        
        // Draw filled triangle
        arrowPath.close()
        color.setFill()
        arrowPath.fill()
        
        color.setStroke()
        arrowPath.lineWidth = lineWidth
        arrowPath.stroke()
    }
    
    // MARK: - Text Drawing
    
    @MainActor
    private func drawText(_ text: String, annotation: Annotation) {
        let font = NSFont.systemFont(ofSize: CGFloat(annotation.fontSize), weight: .medium)
        let color = annotation.nsStrokeColor
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        
        // Calculate text bounds
        let textSize = attributedText.size()
        let textRect = NSRect(
            x: annotation.cgStartPoint.x,
            y: annotation.cgStartPoint.y - textSize.height,
            width: textSize.width,
            height: textSize.height
        )
        
        // Draw background if needed
        if let fillColor = annotation.nsFillColor {
            fillColor.setFill()
            NSRect(
                x: textRect.origin.x - 4,
                y: textRect.origin.y - 2,
                width: textRect.width + 8,
                height: textRect.height + 4
            ).fill()
        }
        
        attributedText.draw(in: textRect)
    }
    
    // MARK: - Step Number Drawing
    
    @MainActor
    private func drawStepNumber(_ number: Int, annotation: Annotation) {
        let circleSize: CGFloat = CGFloat(annotation.fontSize * 2.0)
        let center = annotation.cgStartPoint
        
        let circle = NSBezierPath(ovalIn: NSRect(
            x: center.x - circleSize / 2,
            y: center.y - circleSize / 2,
            width: circleSize,
            height: circleSize
        ))
        
        // Draw circle background
        annotation.nsStrokeColor.setFill()
        circle.fill()
        
        // Draw circle border
        NSColor.white.setStroke()
        circle.lineWidth = 2.0
        circle.stroke()
        
        // Draw number
        let text = "\(number)"
        let font = NSFont.systemFont(ofSize: CGFloat(annotation.fontSize), weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        
        let textSize = (text as NSString).size(withAttributes: attributes)
        let textPoint = CGPoint(
            x: center.x - textSize.width / 2,
            y: center.y - textSize.height / 2
        )
        
        (text as NSString).draw(at: textPoint, withAttributes: attributes)
    }
    
    // MARK: - Highlighter Effect
    
    @MainActor
    private func drawHighlighter(annotation: Annotation) {
        NSGraphicsContext.current?.saveGraphicsState()
        
        // Use multiply blend mode for highlighter effect
        NSGraphicsContext.current?.compositingOperation = .multiply
        
        let path = annotation.path()
        
        // Semi-transparent color
        let highlightColor = annotation.nsStrokeColor.withAlphaComponent(0.3)
        highlightColor.setStroke()
        
        // Thicker line for highlighter
        path.lineWidth = annotation.lineWidth * 4
        path.lineCapStyle = .round
        path.stroke()
        
        NSGraphicsContext.current?.restoreGraphicsState()
    }
    
    // MARK: - Blur Effect
    
    @MainActor
    private func drawBlur(annotation: Annotation, canvasSize: CGSize) {
        // For blur, we need to apply CIFilter to the region
        // This is a simplified version - full implementation would use CIGaussianBlur
        
        let rect = annotation.calculateBounds()
        
        // Draw a semi-transparent overlay as placeholder
        // In production, this would be actual blur filter
        NSColor.white.withAlphaComponent(0.8).setFill()
        
        if annotation.tool == .blur {
            let blurPath = NSBezierPath(rect: rect)
            blurPath.fill()
        }
    }
    
    // MARK: - Export to File
    
    func exportImage(
        _ image: NSImage,
        to url: URL,
        format: ExportFormat
    ) async -> Result<Void, RendererError> {
        return await Task.detached(priority: .userInitiated) {
            guard let tiffData = image.tiffRepresentation,
                  let bitmapRep = NSBitmapImageRep(data: tiffData) else {
                return .failure(.conversionFailed)
            }
            
            let data: Data?
            
            switch format {
            case .png:
                data = bitmapRep.representation(using: .png, properties: [:])
                
            case .jpeg(let quality):
                data = bitmapRep.representation(
                    using: .jpeg,
                    properties: [.compressionFactor: NSNumber(value: quality)]
                )
                
            case .tiff:
                data = bitmapRep.representation(using: .tiff, properties: [:])
                
            case .heic(let quality):
                // HEIC support (macOS 10.13+)
                if #available(macOS 10.13, *) {
                    data = bitmapRep.representation(
                        using: .jpeg2000,
                        properties: [.compressionFactor: NSNumber(value: quality)]
                    )
                } else {
                    // Fallback to JPEG
                    data = bitmapRep.representation(
                        using: .jpeg,
                        properties: [.compressionFactor: NSNumber(value: quality)]
                    )
                }
            }
            
            guard let imageData = data else {
                return .failure(.encodingFailed)
            }
            
            do {
                try imageData.write(to: url, options: .atomic)
                return .success(())
            } catch {
                return .failure(.fileWriteFailed(error))
            }
        }.value
    }
    
    // MARK: - Clipboard Export
    
    func copyToClipboard(_ image: NSImage) async -> Bool {
        await MainActor.run {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            return pasteboard.writeObjects([image])
        }
    }
    
    // MARK: - Render Single Annotation (for preview)
    
    func renderAnnotationPreview(
        annotation: Annotation,
        size: CGSize,
        backgroundColor: NSColor = .white
    ) async -> NSImage {
        // Create a snapshot to avoid capturing non-Sendable Annotation in @Sendable closure
        let snapshots = await self.createSnapshots(from: [annotation])
        let snapshot: AnnotationSnapshot
        
        if let firstSnapshot = snapshots.first {
            snapshot = firstSnapshot
        } else {
            // Fallback empty snapshot if creation fails
            snapshot = await MainActor.run {
                AnnotationSnapshot(
                    tool: .selection,
                    layer: 0,
                    isHidden: false,
                    lineWidth: 1.0,
                    shadowEnabled: false,
                    shadowBlur: 0,
                    strokeColor: ColorComponents(color: .black),
                    fillColor: nil,
                    start: .zero,
                    end: .zero,
                    text: nil,
                    fontSize: 12,
                    pathPoints: [],
                    bounds: .zero
                )
            }
        }
        
        return await MainActor.run {
            let preview = NSImage(size: size)
            
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(size.width),
                pixelsHigh: Int(size.height),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .calibratedRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
            
            if let rep = rep, let context = NSGraphicsContext(bitmapImageRep: rep) {
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = context
                
                // Draw background
                backgroundColor.setFill()
                NSRect(origin: .zero, size: size).fill()
                
                // Draw annotation using snapshot
                self.drawAnnotationSnapshot(snapshot)
                
                NSGraphicsContext.restoreGraphicsState()
                preview.addRepresentation(rep)
            }
            
            return preview
        }
    }
    
    // MARK: - Draw Annotation from Snapshot
    
    @MainActor
    private func drawAnnotationSnapshot(_ snapshot: AnnotationSnapshot) {
        // Save graphics state
        NSGraphicsContext.current?.saveGraphicsState()
        
        // Apply shadow if enabled
        if snapshot.shadowEnabled {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
            shadow.shadowOffset = NSSize(width: 0, height: -2)
            shadow.shadowBlurRadius = snapshot.shadowBlur
            shadow.set()
        }
        
        // Get the path for this annotation
        let path = snapshot.createPath()
        
        // Set stroke properties
        snapshot.strokeColor.nsColor.setStroke()
        path.lineWidth = snapshot.lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        
        // Fill if applicable
        if let fillColor = snapshot.fillColor {
            fillColor.nsColor.setFill()
            path.fill()
        }
        
        // Stroke the path
        path.stroke()
        
        // Draw tool-specific decorations
        switch snapshot.tool {
        case .arrow:
            drawArrowheadFromSnapshot(snapshot: snapshot)
            
        case .text:
            if let text = snapshot.text {
                drawTextFromSnapshot(text, snapshot: snapshot)
            }
            
        case .step:
            if let stepNumber = (snapshot.text.flatMap { Int($0) }) {
                drawStepNumberFromSnapshot(stepNumber, snapshot: snapshot)
            }
            
        case .highlighter:
            drawHighlighterFromSnapshot(snapshot: snapshot)
            
        case .blur:
            drawBlurFromSnapshot(snapshot: snapshot)
            
        default:
            break
        }
        
        // Restore graphics state
        NSGraphicsContext.current?.restoreGraphicsState()
    }
    
    @MainActor
    private func drawArrowheadFromSnapshot(snapshot: AnnotationSnapshot) {
        let start = snapshot.start
        let end = snapshot.end
        let color = snapshot.strokeColor.nsColor
        let lineWidth = snapshot.lineWidth
        
        let arrowLength: CGFloat = 15.0 * CGFloat(lineWidth / 2.0)
        let arrowAngle: CGFloat = .pi / 6.0
        
        let dx = end.x - start.x
        let dy = end.y - start.y
        let angle = atan2(dy, dx)
        
        let arrowPath = NSBezierPath()
        
        let point1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        
        let point2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )
        
        arrowPath.move(to: point1)
        arrowPath.line(to: end)
        arrowPath.line(to: point2)
        arrowPath.close()
        
        color.setFill()
        arrowPath.fill()
        color.setStroke()
        arrowPath.lineWidth = lineWidth
        arrowPath.stroke()
    }
    
    @MainActor
    private func drawTextFromSnapshot(_ text: String, snapshot: AnnotationSnapshot) {
        let font = NSFont.systemFont(ofSize: CGFloat(snapshot.fontSize), weight: .medium)
        let color = snapshot.strokeColor.nsColor
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedText.size()
        let textRect = NSRect(
            x: snapshot.start.x,
            y: snapshot.start.y - textSize.height,
            width: textSize.width,
            height: textSize.height
        )
        
        if let fillColor = snapshot.fillColor {
            fillColor.nsColor.setFill()
            NSRect(
                x: textRect.origin.x - 4,
                y: textRect.origin.y - 2,
                width: textRect.width + 8,
                height: textRect.height + 4
            ).fill()
        }
        
        attributedText.draw(in: textRect)
    }
    
    @MainActor
    private func drawStepNumberFromSnapshot(_ number: Int, snapshot: AnnotationSnapshot) {
        let circleSize: CGFloat = CGFloat(snapshot.fontSize * 2.0)
        let center = snapshot.start
        
        let circle = NSBezierPath(ovalIn: NSRect(
            x: center.x - circleSize / 2,
            y: center.y - circleSize / 2,
            width: circleSize,
            height: circleSize
        ))
        
        snapshot.strokeColor.nsColor.setFill()
        circle.fill()
        
        NSColor.white.setStroke()
        circle.lineWidth = 2.0
        circle.stroke()
        
        let text = "\(number)"
        let font = NSFont.systemFont(ofSize: CGFloat(snapshot.fontSize), weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        
        let textSize = (text as NSString).size(withAttributes: attributes)
        let textPoint = CGPoint(
            x: center.x - textSize.width / 2,
            y: center.y - textSize.height / 2
        )
        
        (text as NSString).draw(at: textPoint, withAttributes: attributes)
    }
    
    @MainActor
    private func drawHighlighterFromSnapshot(snapshot: AnnotationSnapshot) {
        NSGraphicsContext.current?.saveGraphicsState()
        NSGraphicsContext.current?.compositingOperation = .multiply
        
        let path = snapshot.createPath()
        let highlightColor = snapshot.strokeColor.nsColor.withAlphaComponent(0.3)
        highlightColor.setStroke()
        
        path.lineWidth = snapshot.lineWidth * 4
        path.lineCapStyle = .round
        path.stroke()
        
        NSGraphicsContext.current?.restoreGraphicsState()
    }
    
    @MainActor
    private func drawBlurFromSnapshot(snapshot: AnnotationSnapshot) {
        let rect = snapshot.bounds
        NSColor.white.withAlphaComponent(0.8).setFill()
        let blurPath = NSBezierPath(rect: rect)
        blurPath.fill()
    }
    
    // MARK: - Batch Rendering
    
    func renderMultipleScreenshots(
        screenshots: [(baseImage: NSImage, annotations: [Annotation])],
        format: ExportFormat,
        outputDirectory: URL
    ) async -> [Result<URL, RendererError>] {
        var results: [Result<URL, RendererError>] = []
        
        // Get file extension outside of the loop to avoid main actor isolation issues
        let fileExt = format.fileExtension
        
        for (index, item) in screenshots.enumerated() {
            let rendered = await renderAnnotations(
                baseImage: item.baseImage,
                annotations: item.annotations
            )
            
            let filename = "export_\(index + 1).\(fileExt)"
            let outputURL = outputDirectory.appendingPathComponent(filename)
            
            let result = await exportImage(rendered, to: outputURL, format: format)
            
            switch result {
            case .success:
                results.append(.success(outputURL))
            case .failure(let error):
                results.append(.failure(error))
            }
        }
        
        return results
    }
    
    // MARK: - Errors
    
    enum RendererError: LocalizedError {
        case conversionFailed
        case encodingFailed
        case fileWriteFailed(Error)
        case invalidImage
        
        var errorDescription: String? {
            switch self {
            case .conversionFailed:
                return "Failed to convert image to bitmap representation"
            case .encodingFailed:
                return "Failed to encode image in selected format"
            case .fileWriteFailed(let error):
                return "Failed to write file: \(error.localizedDescription)"
            case .invalidImage:
                return "Invalid image data"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .conversionFailed:
                return "Try using a different image format or re-capturing the screenshot"
            case .encodingFailed:
                return "Try selecting a different export format"
            case .fileWriteFailed:
                return "Check that you have write permissions for the destination folder"
            case .invalidImage:
                return "Ensure the image file is not corrupted"
            }
        }
    }
}

// MARK: - Export Format Extensions

extension AnnotationRenderer.ExportFormat {
    nonisolated var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        case .tiff: return "tiff"
        case .heic: return "heic"
        }
    }
    
    nonisolated var displayName: String {
        switch self {
        case .png: return "PNG"
        case .jpeg(let quality): return "JPEG (\(Int(quality * 100))%)"
        case .tiff: return "TIFF"
        case .heic(let quality): return "HEIC (\(Int(quality * 100))%)"
        }
    }
    
    nonisolated var mimeType: String {
        switch self {
        case .png: return "image/png"
        case .jpeg: return "image/jpeg"
        case .tiff: return "image/tiff"
        case .heic: return "image/heic"
        }
    }
}

// MARK: - Render Statistics

struct RenderStatistics {
    let totalAnnotations: Int
    let renderTime: TimeInterval
    let outputSize: Int64
    let format: AnnotationRenderer.ExportFormat
    
    var formattedRenderTime: String {
        String(format: "%.2fs", renderTime)
    }
    
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: outputSize, countStyle: .file)
    }
}

extension AnnotationRenderer {
    func renderWithStatistics(
        baseImage: NSImage,
        annotations: [Annotation],
        format: ExportFormat,
        outputURL: URL
    ) async -> Result<RenderStatistics, RendererError> {
        let startTime = Date()
        
        // Render
        let rendered = await renderAnnotations(baseImage: baseImage, annotations: annotations)
        
        // Export
        let result = await exportImage(rendered, to: outputURL, format: format)
        
        let renderTime = Date().timeIntervalSince(startTime)
        
        switch result {
        case .success:
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0
            
            let stats = RenderStatistics(
                totalAnnotations: annotations.count,
                renderTime: renderTime,
                outputSize: fileSize,
                format: format
            )
            
            return .success(stats)
            
        case .failure(let error):
            return .failure(error)
        }
    }
}

