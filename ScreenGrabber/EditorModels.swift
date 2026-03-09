//
//  EditorModels.swift
//  ScreenGrabber
//
//  Centralized editor models and enums
//

import Foundation

/// Editor tool types for annotation and editing
/// This is the ONLY EditorTool definition - all other files should use this one
public enum EditorTool: String, CaseIterable, Identifiable, Codable, Sendable {
    // Basic tools
    case selection
    case move
    
    // Drawing tools
    case pen
    case highlighter
    case line
    case arrow
    
    // Shape tools
    case shape
    case rectangle
    case ellipse
    case text
    
    // Effect tools
    case blur
    case spotlight
    case crop
    
    // Annotation tools
    case callout
    case step
    case stamp
    
    // Utility tools
    case eraser
    case magnify
    case freehand
    case highlight  // Deprecated: use highlighter instead
    case pixelate
    
    public var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .selection: return "Select"
        case .move: return "Move"
        case .pen: return "Pen"
        case .highlighter: return "Highlighter"
        case .line: return "Line"
        case .arrow: return "Arrow"
        case .shape: return "Shape"
        case .rectangle: return "Rectangle"
        case .ellipse: return "Ellipse"
        case .text: return "Text"
        case .blur: return "Blur"
        case .spotlight: return "Spotlight"
        case .crop: return "Crop"
        case .callout: return "Callout"
        case .step: return "Step"
        case .stamp: return "Stamp"
        case .eraser: return "Eraser"
        case .magnify: return "Magnify"
        case .freehand: return "Freehand"
        case .highlight: return "Highlight"
        case .pixelate: return "Pixelate"
        }
    }
    
    var icon: String {
        switch self {
        case .selection: return "arrow.up.left.and.arrow.down.right"
        case .move: return "move.3d"
        case .pen: return "pencil"
        case .highlighter: return "highlighter"
        case .line: return "line.diagonal"
        case .arrow: return "arrow.up.right"
        case .shape: return "square.on.circle"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .text: return "textformat"
        case .blur: return "camera.filters"
        case .spotlight: return "lightbulb.fill"
        case .crop: return "crop"
        case .callout: return "text.bubble"
        case .step: return "number.circle"
        case .stamp: return "seal"
        case .eraser: return "eraser"
        case .magnify: return "magnifyingglass"
        case .freehand: return "scribble"
        case .highlight: return "highlighter"
        case .pixelate: return "square.grid.3x3.fill"
        }
    }
}
