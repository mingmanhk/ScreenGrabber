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
    case pan
    
    // Drawing tools
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
        case .pan: return "Pan"
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
    
    /// Human-readable description used in tooltips and the status bar.
        var toolDescription: String {
        switch self {
        case .selection:  return "Select and resize annotations. Shift-click to multi-select. Press Delete to remove. Shortcut: V"
        case .pan:       return "Pan the canvas view. Hold Space for temporary pan mode. Shortcut: M"
        case .highlighter: return "Draw semi-transparent highlight strokes over content. Shortcut: H"
        case .line:       return "Draw a straight line between two points. Shortcut: L"
        case .arrow:      return "Draw an arrow pointing to a region of interest. Shortcut: A"
        case .shape:      return "Insert a predefined shape (rectangle or ellipse). Shortcut: S"
        case .rectangle:  return "Draw a filled or outlined rectangle."
        case .ellipse:    return "Draw a filled or outlined ellipse or circle."
        case .text:       return "Add a text label anywhere on the canvas. Shortcut: T"
        case .blur:       return "Brush a Gaussian blur over sensitive content. Shortcut: B"
        case .spotlight:  return "Dim everything outside a region to focus attention."
        case .crop:       return "Crop the image to a selected rectangular region. Shortcut: R"
        case .callout:    return "Add a speech-bubble callout with a pointer tail."
        case .step:       return "Insert an auto-numbered step marker for instructions."
        case .stamp:      return "Place a predefined stamp icon on the image."
        case .eraser:     return "Erase drawn strokes and annotations. Shortcut: E"
        case .magnify:    return "Zoom into a region for detailed inspection. Shortcut: Z"
        case .freehand:   return "Draw freehand paths with full curve control."
        case .highlight:  return "Highlight content with a semi-transparent colour overlay."
        case .pixelate:   return "Pixelate a region to obscure sensitive content."
        }
    }

    var icon: String {
        switch self {
        case .selection: return "arrow.up.left.and.arrow.down.right"
        case .pan: return "move.3d"
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
