//
//  ImageEditorModels.swift
//  ScreenGrabber
//
//  Created by Victor Lam on 10/23/25.
//

import Foundation
import AppKit
import SwiftUI
import Combine

// MARK: - Editor Action Types
enum EditorAction: String, CaseIterable, Identifiable {
    case undo = "undo"
    case redo = "redo"
    case save = "save"
    case export = "export"
    case clear = "clear"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .undo: return "arrow.uturn.backward"
        case .redo: return "arrow.uturn.forward"
        case .save: return "square.and.arrow.down"
        case .export: return "square.and.arrow.up"
        case .clear: return "trash"
        }
    }
}

// MARK: - Editor Tool Types
// NOTE: EditorTool enum is now defined in EditorModels.swift
// This file uses that centralized definition

// MARK: - Shape Types
enum ShapeType: String, CaseIterable, Identifiable {
    case rectangle = "rectangle"
    case ellipse = "ellipse"
    case roundedRectangle = "roundedRectangle"
    case triangle = "triangle"
    case star = "star"
    case polygon = "polygon"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .rectangle: return "Rectangle"
        case .ellipse: return "Ellipse"
        case .roundedRectangle: return "Rounded Rectangle"
        case .triangle: return "Triangle"
        case .star: return "Star"
        case .polygon: return "Polygon"
        }
    }
    
    var icon: String {
        switch self {
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .roundedRectangle: return "rectangle.roundedtop"
        case .triangle: return "triangle"
        case .star: return "star"
        case .polygon: return "hexagon"
        }
    }
}

// MARK: - Drawing Annotation
struct DrawingAnnotation: Identifiable {
    let id = UUID()
    var tool: EditorTool
    var path: CGPath?
    var points: [CGPoint] = []
    var color: NSColor = .red
    var lineWidth: CGFloat = 2.0
    var text: String = ""
    var rect: CGRect = .zero
    var shapeType: ShapeType = .rectangle
    var isFilled: Bool = false
    var opacity: Double = 1.0
    var blurRadius: CGFloat = 0
    var fontSize: CGFloat = 16
    var fontWeight: NSFont.Weight = .regular
    var isCompleted: Bool = false
    
    // Arrow specific properties
    var arrowStyle: ArrowStyle = .simple
    var hasArrowHead: Bool = true
    var hasArrowTail: Bool = false
    
    init(tool: EditorTool = .selection) {
        self.tool = tool
    }
}

enum ArrowStyle: String, CaseIterable {
    case simple = "simple"
    case thick = "thick"
    case curved = "curved"
    case dashed = "dashed"
    
    var displayName: String {
        switch self {
        case .simple: return "Simple"
        case .thick: return "Thick"
        case .curved: return "Curved"
        case .dashed: return "Dashed"
        }
    }
}

// MARK: - Editor State
@MainActor
class ImageEditorState: ObservableObject {
    @Published var selectedTool: EditorTool = .selection
    @Published var currentColor: NSColor = .red
    @Published var lineWidth: CGFloat = 2.0
    @Published var fontSize: CGFloat = 16
    @Published var opacity: Double = 1.0
    @Published var selectedShape: ShapeType = .rectangle
    @Published var isShapeFilled: Bool = false
    @Published var blurRadius: CGFloat = 5.0
    @Published var currentText: String = ""
    @Published var showColorPicker: Bool = false
    @Published var showFontPanel: Bool = false
    @Published var zoomLevel: CGFloat = 1.0
    @Published var annotations: [DrawingAnnotation] = []
    @Published var selectedAnnotation: DrawingAnnotation?
    @Published var canUndo: Bool = false
    @Published var canRedo: Bool = false
    @Published var isModified: Bool = false
    
    // Undo/Redo stacks
    private var undoStack: [Data] = []
    private var redoStack: [Data] = []
    private let maxUndoSteps = 50
    
    func addAnnotation(_ annotation: DrawingAnnotation) {
        saveStateForUndo()
        annotations.append(annotation)
        isModified = true
        updateUndoRedoState()
    }
    
    func removeAnnotation(_ annotation: DrawingAnnotation) {
        saveStateForUndo()
        annotations.removeAll { $0.id == annotation.id }
        isModified = true
        updateUndoRedoState()
    }
    
    func updateAnnotation(_ annotation: DrawingAnnotation) {
        saveStateForUndo()
        if let index = annotations.firstIndex(where: { $0.id == annotation.id }) {
            annotations[index] = annotation
            isModified = true
        }
        updateUndoRedoState()
    }
    
    private func saveStateForUndo() {
        if let data = try? JSONEncoder().encode(annotations.map { AnnotationData(from: $0) }) {
            undoStack.append(data)
            if undoStack.count > maxUndoSteps {
                undoStack.removeFirst()
            }
            redoStack.removeAll()
        }
    }
    
    private func updateUndoRedoState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
    
    func undo() {
        guard let lastState = undoStack.popLast() else { return }
        
        // Save current state to redo stack
        if let currentData = try? JSONEncoder().encode(annotations.map { AnnotationData(from: $0) }) {
            redoStack.append(currentData)
        }
        
        // Restore previous state
        if let annotationsData = try? JSONDecoder().decode([AnnotationData].self, from: lastState) {
            annotations = annotationsData.compactMap { $0.toDrawingAnnotation() }
        }
        
        updateUndoRedoState()
    }
    
    func redo() {
        guard let nextState = redoStack.popLast() else { return }
        
        // Save current state to undo stack
        if let currentData = try? JSONEncoder().encode(annotations.map { AnnotationData(from: $0) }) {
            undoStack.append(currentData)
        }
        
        // Restore next state
        if let annotationsData = try? JSONDecoder().decode([AnnotationData].self, from: nextState) {
            annotations = annotationsData.compactMap { $0.toDrawingAnnotation() }
        }
        
        updateUndoRedoState()
    }
    
    func clearAll() {
        saveStateForUndo()
        annotations.removeAll()
        selectedAnnotation = nil
        isModified = true
        updateUndoRedoState()
    }
}

// MARK: - Serializable Annotation Data
struct AnnotationData: Codable {
    let id: String
    let tool: String
    let colorData: Data
    let lineWidth: CGFloat
    let text: String
    let rectData: Data
    let shapeType: String
    let isFilled: Bool
    let opacity: Double
    let blurRadius: CGFloat
    let fontSize: CGFloat
    let isCompleted: Bool
    let points: [CGPoint]
    
    init(from annotation: DrawingAnnotation) {
        self.id = annotation.id.uuidString
        self.tool = annotation.tool.rawValue
        self.colorData = (try? NSKeyedArchiver.archivedData(withRootObject: annotation.color, requiringSecureCoding: false)) ?? Data()
        self.lineWidth = annotation.lineWidth
        self.text = annotation.text
        self.rectData = (try? NSKeyedArchiver.archivedData(withRootObject: NSValue(rect: annotation.rect), requiringSecureCoding: false)) ?? Data()
        self.shapeType = annotation.shapeType.rawValue
        self.isFilled = annotation.isFilled
        self.opacity = annotation.opacity
        self.blurRadius = annotation.blurRadius
        self.fontSize = annotation.fontSize
        self.isCompleted = annotation.isCompleted
        self.points = annotation.points
    }
    
    func toDrawingAnnotation() -> DrawingAnnotation? {
        guard let tool = EditorTool(rawValue: self.tool),
              let shapeType = ShapeType(rawValue: self.shapeType),
              let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData),
              let rectValue = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSValue.self, from: rectData) else {
            return nil
        }
        
        var annotation = DrawingAnnotation(tool: tool)
        annotation.color = color
        annotation.lineWidth = lineWidth
        annotation.text = text
        annotation.rect = rectValue.rectValue
        annotation.shapeType = shapeType
        annotation.isFilled = isFilled
        annotation.opacity = opacity
        annotation.blurRadius = blurRadius
        annotation.fontSize = fontSize
        annotation.isCompleted = isCompleted
        annotation.points = points
        
        return annotation
    }
}
// MARK: - Lightweight Editor Models for Overlay
struct EditorAnnotation: Identifiable {
    let id = UUID()
    var type: EditorTool
    var startPoint: CGPoint
    var endPoint: CGPoint
    var color: NSColor
    var lineWidth: CGFloat
    
    init(type: EditorTool, startPoint: CGPoint, endPoint: CGPoint, color: NSColor, lineWidth: CGFloat) {
        self.type = type
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.color = color
        self.lineWidth = lineWidth
    }
}

