# 🔧 IMPLEMENTATION PLAN — SCREENGRABBER FIXES

**Based on:** COMPREHENSIVE_TECHNICAL_REVIEW.md  
**Priority:** Critical issues first, then high/medium/low

---

## PART 1: CRITICAL DATA MODELS

### **FIX #1: CREATE SCREENSHOT SWIFTDATA MODEL**

**File:** `Models/Screenshot.swift` (NEW)

```swift
//
//  Screenshot.swift
//  ScreenGrabber
//
//  SwiftData model for captured screenshots
//

import Foundation
import SwiftData

@Model
final class Screenshot {
    // MARK: - Identity
    var id: UUID
    var timestamp: Date
    
    // MARK: - File Information
    var filename: String
    var filePath: String
    var fileSize: Int64
    
    // MARK: - Capture Details
    var captureType: String  // "area", "window", "fullscreen", "scrolling"
    var width: Int
    var height: Int
    
    // MARK: - Metadata
    var displayName: String?
    var notes: String?
    var tags: [String]
    
    // MARK: - Thumbnail
    @Attribute(.externalStorage)
    var thumbnailData: Data?
    
    // MARK: - Relationships
    @Relationship(deleteRule: .cascade, inverse: \Annotation.screenshot)
    var annotations: [Annotation]?
    
    // MARK: - Computed Properties
    var fileURL: URL {
        URL(fileURLWithPath: filePath)
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    // MARK: - Initialization
    init(
        filename: String,
        filePath: String,
        captureType: String,
        width: Int,
        height: Int,
        fileSize: Int64 = 0,
        timestamp: Date = Date()
    ) {
        self.id = UUID()
        self.filename = filename
        self.filePath = filePath
        self.captureType = captureType
        self.width = width
        self.height = height
        self.fileSize = fileSize
        self.timestamp = timestamp
        self.tags = []
    }
    
    // MARK: - Thumbnail Generation
    @MainActor
    func generateThumbnail(maxSize: CGSize = CGSize(width: 200, height: 200)) async {
        guard let image = NSImage(contentsOf: fileURL) else {
            print("[SCREENSHOT] ❌ Failed to load image for thumbnail: \(filePath)")
            return
        }
        
        let thumbnail = await Task.detached(priority: .utility) {
            let aspectRatio = image.size.width / image.size.height
            var thumbnailSize = maxSize
            
            if aspectRatio > 1 {
                thumbnailSize.height = maxSize.width / aspectRatio
            } else {
                thumbnailSize.width = maxSize.height * aspectRatio
            }
            
            let thumbnailImage = NSImage(size: thumbnailSize)
            thumbnailImage.lockFocus()
            image.draw(in: NSRect(origin: .zero, size: thumbnailSize))
            thumbnailImage.unlockFocus()
            
            return thumbnailImage.tiffRepresentation
        }.value
        
        self.thumbnailData = thumbnail
    }
}

// MARK: - Query Helpers
extension Screenshot {
    static func all(context: ModelContext) -> [Screenshot] {
        let descriptor = FetchDescriptor<Screenshot>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    static func recent(limit: Int, context: ModelContext) -> [Screenshot] {
        let descriptor = FetchDescriptor<Screenshot>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return Array((try? context.fetch(descriptor))?.prefix(limit) ?? [])
    }
    
    static func byType(_ type: String, context: ModelContext) -> [Screenshot] {
        let predicate = #Predicate<Screenshot> { screenshot in
            screenshot.captureType == type
        }
        let descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
```

**Integration:**
```swift
// Update ScreenGrabberApp.swift schema
let schema = Schema([
    Item.self,
    Screenshot.self,  // ✅ Now defined!
    Annotation.self   // ✅ Next step
])
```

---

### **FIX #2: CREATE ANNOTATION SWIFTDATA MODEL**

**File:** `Models/Annotation.swift` (NEW)

```swift
//
//  Annotation.swift
//  ScreenGrabber
//
//  SwiftData model for screenshot annotations
//

import Foundation
import SwiftData
import AppKit

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
    
    // MARK: - Geometry
    var startPoint: CodablePoint
    var endPoint: CodablePoint
    var controlPoints: [CodablePoint]  // For bezier curves
    
    // MARK: - Content
    var text: String?
    var stepNumber: Int?
    
    // MARK: - Metadata
    var layer: Int  // Z-order for overlapping annotations
    var isHidden: Bool
    var isLocked: Bool
    
    // MARK: - Relationship
    var screenshot: Screenshot?
    
    // MARK: - Initialization
    init(
        toolType: EditorTool,
        startPoint: CGPoint,
        endPoint: CGPoint,
        strokeColor: NSColor = .red,
        lineWidth: Double = 2.0
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.toolType = toolType.rawValue
        self.strokeColor = CodableColor(color: strokeColor)
        self.startPoint = CodablePoint(point: startPoint)
        self.endPoint = CodablePoint(point: endPoint)
        self.lineWidth = lineWidth
        self.fontSize = 16.0
        self.controlPoints = []
        self.layer = 0
        self.isHidden = false
        self.isLocked = false
    }
    
    // MARK: - Conversion
    var tool: EditorTool {
        EditorTool(rawValue: toolType) ?? .selection
    }
    
    var nsStrokeColor: NSColor {
        strokeColor.nsColor
    }
    
    var nsFillColor: NSColor? {
        fillColor?.nsColor
    }
    
    var cgStartPoint: CGPoint {
        startPoint.cgPoint
    }
    
    var cgEndPoint: CGPoint {
        endPoint.cgPoint
    }
    
    // MARK: - Rendering
    func path() -> NSBezierPath {
        let path = NSBezierPath()
        
        switch tool {
        case .line, .arrow:
            path.move(to: cgStartPoint)
            path.line(to: cgEndPoint)
            
        case .rectangle, .shape:
            let rect = CGRect(
                x: min(cgStartPoint.x, cgEndPoint.x),
                y: min(cgStartPoint.y, cgEndPoint.y),
                width: abs(cgEndPoint.x - cgStartPoint.x),
                height: abs(cgEndPoint.y - cgStartPoint.y)
            )
            path.appendRect(rect)
            
        case .ellipse:
            let rect = CGRect(
                x: min(cgStartPoint.x, cgEndPoint.x),
                y: min(cgStartPoint.y, cgEndPoint.y),
                width: abs(cgEndPoint.x - cgStartPoint.x),
                height: abs(cgEndPoint.y - cgStartPoint.y)
            )
            path.appendOval(in: rect)
            
        case .freehand:
            if !controlPoints.isEmpty {
                path.move(to: cgStartPoint)
                for point in controlPoints {
                    path.line(to: point.cgPoint)
                }
            }
            
        default:
            break
        }
        
        path.lineWidth = lineWidth
        return path
    }
}

// MARK: - Codable Wrappers
struct CodableColor: Codable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double
    
    init(color: NSColor) {
        let rgbColor = color.usingColorSpace(.deviceRGB) ?? color
        self.red = Double(rgbColor.redComponent)
        self.green = Double(rgbColor.greenComponent)
        self.blue = Double(rgbColor.blueComponent)
        self.alpha = Double(rgbColor.alphaComponent)
    }
    
    var nsColor: NSColor {
        NSColor(
            red: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: CGFloat(alpha)
        )
    }
}

struct CodablePoint: Codable {
    var x: Double
    var y: Double
    
    init(point: CGPoint) {
        self.x = Double(point.x)
        self.y = Double(point.y)
    }
    
    var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}
```

---

### **FIX #3: CREATE ANNOTATION RENDERER**

**File:** `Services/AnnotationRenderer.swift` (NEW)

```swift
//
//  AnnotationRenderer.swift
//  ScreenGrabber
//
//  Renders annotations onto base images for export
//

import Foundation
import AppKit

actor AnnotationRenderer {
    static let shared = AnnotationRenderer()
    
    enum ExportFormat {
        case png
        case jpeg(quality: Double)
        case tiff
    }
    
    // MARK: - Render Annotations
    
    /// Renders annotations onto a base image
    func renderAnnotations(
        baseImage: NSImage,
        annotations: [Annotation]
    ) async -> NSImage {
        // Ensure we're working on background thread
        return await Task.detached(priority: .userInitiated) {
            let size = baseImage.size
            let rendered = NSImage(size: size)
            
            rendered.lockFocus()
            
            // Draw base image
            baseImage.draw(
                in: NSRect(origin: .zero, size: size),
                from: .zero,
                operation: .sourceOver,
                fraction: 1.0
            )
            
            // Sort annotations by layer (z-order)
            let sortedAnnotations = annotations
                .filter { !$0.isHidden }
                .sorted { $0.layer < $1.layer }
            
            // Draw each annotation
            for annotation in sortedAnnotations {
                self.drawAnnotation(annotation, in: size)
            }
            
            rendered.unlockFocus()
            
            return rendered
        }.value
    }
    
    // MARK: - Draw Individual Annotation
    
    private func drawAnnotation(_ annotation: Annotation, in canvasSize: CGSize) {
        let path = annotation.path()
        
        // Set stroke color and width
        annotation.nsStrokeColor.setStroke()
        path.lineWidth = annotation.lineWidth
        
        // Fill if applicable
        if let fillColor = annotation.nsFillColor {
            fillColor.setFill()
            path.fill()
        }
        
        // Stroke the path
        path.stroke()
        
        // Draw arrowhead for arrows
        if annotation.tool == .arrow {
            drawArrowhead(
                from: annotation.cgStartPoint,
                to: annotation.cgEndPoint,
                color: annotation.nsStrokeColor,
                lineWidth: annotation.lineWidth
            )
        }
        
        // Draw text for text annotations
        if annotation.tool == .text, let text = annotation.text {
            drawText(
                text,
                at: annotation.cgStartPoint,
                fontSize: annotation.fontSize,
                color: annotation.nsStrokeColor
            )
        }
        
        // Draw step number for step annotations
        if annotation.tool == .step, let stepNumber = annotation.stepNumber {
            drawStepNumber(
                stepNumber,
                at: annotation.cgStartPoint,
                color: annotation.nsStrokeColor
            )
        }
    }
    
    // MARK: - Helper Drawing Methods
    
    private func drawArrowhead(
        from start: CGPoint,
        to end: CGPoint,
        color: NSColor,
        lineWidth: Double
    ) {
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
        
        color.setStroke()
        arrowPath.lineWidth = lineWidth
        arrowPath.stroke()
    }
    
    private func drawText(
        _ text: String,
        at point: CGPoint,
        fontSize: Double,
        color: NSColor
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: CGFloat(fontSize), weight: .medium),
            .foregroundColor: color
        ]
        
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        attributedText.draw(at: point)
    }
    
    private func drawStepNumber(
        _ number: Int,
        at point: CGPoint,
        color: NSColor
    ) {
        let circleSize: CGFloat = 30.0
        let circle = NSBezierPath(ovalIn: NSRect(
            x: point.x - circleSize / 2,
            y: point.y - circleSize / 2,
            width: circleSize,
            height: circleSize
        ))
        
        color.setFill()
        circle.fill()
        
        let text = "\(number)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        
        let textSize = (text as NSString).size(withAttributes: attributes)
        let textPoint = CGPoint(
            x: point.x - textSize.width / 2,
            y: point.y - textSize.height / 2
        )
        
        (text as NSString).draw(at: textPoint, withAttributes: attributes)
    }
    
    // MARK: - Export
    
    func exportImage(
        _ image: NSImage,
        to url: URL,
        format: ExportFormat
    ) async -> Result<Void, Error> {
        return await Task.detached(priority: .userInitiated) {
            guard let tiffData = image.tiffRepresentation,
                  let bitmapRep = NSBitmapImageRep(data: tiffData) else {
                return .failure(RendererError.conversionFailed)
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
            }
            
            guard let imageData = data else {
                return .failure(RendererError.encodingFailed)
            }
            
            do {
                try imageData.write(to: url)
                return .success(())
            } catch {
                return .failure(error)
            }
        }.value
    }
    
    // MARK: - Errors
    
    enum RendererError: LocalizedError {
        case conversionFailed
        case encodingFailed
        
        var errorDescription: String? {
            switch self {
            case .conversionFailed:
                return "Failed to convert image to bitmap"
            case .encodingFailed:
                return "Failed to encode image in selected format"
            }
        }
    }
}
```

---

### **FIX #4: FIX ANNOTATION PERSISTENCE**

**File:** `ScreenCaptureEditorState.swift` (UPDATE)

```swift
//
//  ScreenCaptureEditorState.swift
//  ScreenGrabber
//
//  UPDATED: Integrated with SwiftData
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
class ScreenCaptureEditorState: ObservableObject {
    // MARK: - Context
    private let modelContext: ModelContext
    private let screenshot: Screenshot
    
    // MARK: - State
    @Published var annotations: [Annotation] = []
    @Published var selectedAnnotationID: UUID?
    @Published var selectedTool: EditorTool = .selection
    
    // Style properties
    @Published var strokeColor: NSColor = .red
    @Published var fillColor: NSColor? = nil
    @Published var lineWidth: Double = 2.0
    @Published var fontSize: Double = 16.0
    
    // Display options
    @Published var showGrid: Bool = false
    @Published var showRulers: Bool = false
    @Published var snapToGrid: Bool = false
    @Published var zoomLevel: Double = 1.0
    
    // OCR
    @Published var ocrText: String = ""
    
    // MARK: - Undo/Redo
    private var undoManager: UndoManager
    
    var canUndo: Bool {
        undoManager.canUndo
    }
    
    var canRedo: Bool {
        undoManager.canRedo
    }
    
    // MARK: - Initialization
    
    init(screenshot: Screenshot, modelContext: ModelContext) {
        self.screenshot = screenshot
        self.modelContext = modelContext
        self.undoManager = UndoManager()
        
        // Load existing annotations
        loadAnnotations()
    }
    
    // MARK: - Persistence
    
    func loadAnnotations() {
        annotations = screenshot.annotations ?? []
        print("[EDITOR] ✅ Loaded \(annotations.count) annotations")
    }
    
    func saveAnnotations() async {
        screenshot.annotations = annotations
        
        do {
            try modelContext.save()
            print("[EDITOR] ✅ Saved \(annotations.count) annotations")
        } catch {
            print("[EDITOR] ❌ Failed to save annotations: \(error)")
        }
    }
    
    // MARK: - Annotation Management
    
    func addAnnotation(_ annotation: Annotation) {
        registerUndo {
            self.deleteAnnotation(annotation)
        }
        
        annotations.append(annotation)
        annotation.screenshot = screenshot
        modelContext.insert(annotation)
        
        Task {
            await saveAnnotations()
        }
    }
    
    func updateAnnotation(_ annotation: Annotation) {
        guard let index = annotations.firstIndex(where: { $0.id == annotation.id }) else {
            return
        }
        
        let oldAnnotation = annotations[index]
        registerUndo {
            self.annotations[index] = oldAnnotation
        }
        
        annotations[index] = annotation
        
        Task {
            await saveAnnotations()
        }
    }
    
    func deleteAnnotation(_ annotation: Annotation) {
        registerUndo {
            self.addAnnotation(annotation)
        }
        
        annotations.removeAll { $0.id == annotation.id }
        modelContext.delete(annotation)
        
        Task {
            await saveAnnotations()
        }
    }
    
    // MARK: - Undo/Redo
    
    func undo() {
        undoManager.undo()
        
        Task {
            await saveAnnotations()
        }
    }
    
    func redo() {
        undoManager.redo()
        
        Task {
            await saveAnnotations()
        }
    }
    
    private func registerUndo(_ action: @escaping () -> Void) {
        undoManager.registerUndo(withTarget: self) { _ in
            action()
        }
    }
}
```

---

**Continue to IMPLEMENTATION_PLAN_PART2.md for remaining fixes...**
