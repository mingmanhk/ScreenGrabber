//
//  ScreenCaptureEditorState.swift
//  ScreenGrabber
//
//  Editor state management for screen capture editor
//

import Foundation
import SwiftUI
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins
import AppKit

// MARK: - Image Adjustments

struct ImageAdjustments: Equatable {
    /// -1.0 (dark) to 1.0 (bright), default 0.0
    var brightness: Double = 0.0
    /// 0.5 (flat) to 2.0 (punchy), default 1.0
    var contrast: Double = 1.0
    /// 0.0 (greyscale) to 2.0 (vivid), default 1.0
    var saturation: Double = 1.0
    /// 0.0 (none) to 1.0 (sharp), default 0.0
    var sharpness: Double = 0.0
    /// 0.0 (none) to 2.0 (heavy), default 0.0
    var vignette: Double = 0.0

    var isDefault: Bool {
        self == ImageAdjustments()
    }

    mutating func reset() {
        self = ImageAdjustments()
    }

    /// Apply all adjustments to the given image using Core Image.
    /// Returns `nil` only if the input image has no valid CGImage representation.
    func applied(to image: NSImage) -> NSImage? {
        guard let cgIn = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let ciContext = CIContext(options: [.useSoftwareRenderer: false])
        var ci = CIImage(cgImage: cgIn)

        // Colour controls (brightness / contrast / saturation)
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage  = ci
        colorControls.brightness  = Float(brightness)
        colorControls.contrast    = Float(contrast)
        colorControls.saturation  = Float(saturation)
        if let out = colorControls.outputImage { ci = out }

        // Sharpness (unsharp mask)
        if sharpness > 0 {
            let sharpen = CIFilter.unsharpMask()
            sharpen.inputImage = ci
            sharpen.intensity  = Float(sharpness * 1.5)
            sharpen.radius     = 2.5
            if let out = sharpen.outputImage { ci = out }
        }

        // Vignette
        if vignette > 0 {
            let vig = CIFilter.vignette()
            vig.inputImage = ci
            vig.intensity  = Float(vignette)
            vig.radius     = 1.5
            if let out = vig.outputImage { ci = out }
        }

        guard let cgOut = ciContext.createCGImage(ci, from: CGRect(origin: .zero, size: image.size)) else { return nil }
        return NSImage(cgImage: cgOut, size: image.size)
    }
}

// MARK: - Editor State

/// State manager for screen capture editor
@MainActor
class ScreenCaptureEditorState: ObservableObject {
    // Image editor state (for compatibility with existing code)
    @Published var imageEditorState = ImageEditorState()
    
    // OCR text
    @Published var ocrText: String = ""
    
    // Selected tool
    @Published var selectedTool: EditorTool = .selection
    
    // Current annotation being drawn
    @Published var currentAnnotation: Annotation?
    
    // All annotations
    @Published var annotations: [Annotation] = []
    
    // Selected annotation for editing
    @Published var selectedAnnotationID: UUID?
    
    // Style properties
    @Published var strokeColor: NSColor = .red
    @Published var fillColor: NSColor? = nil
    @Published var lineWidth: Double = 2.0
    @Published var fontSize: Double = 16.0
    
    // Image adjustments
    @Published var adjustments = ImageAdjustments()

    // Display options
    @Published var showGrid: Bool = false
    @Published var showRulers: Bool = false
    @Published var snapToGrid: Bool = false
    
    // Undo/Redo support
    private var undoStack: [[Annotation]] = []
    private var redoStack: [[Annotation]] = []
    private var cancellables = Set<AnyCancellable>()
    
    var canUndo: Bool {
        !undoStack.isEmpty
    }
    
    var canRedo: Bool {
        !redoStack.isEmpty
    }
    
    init() {
        imageEditorState.selectedTool = selectedTool
        // Auto-sync: any write to selectedTool propagates to imageEditorState
        $selectedTool
            .dropFirst()
            .sink { [weak self] tool in
                self?.imageEditorState.selectedTool = tool
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Tool Selection
    
    func selectTool(_ tool: EditorTool) {
        selectedTool = tool
        imageEditorState.selectedTool = tool
        // Deselect any selected annotation when switching tools
        if tool != .selection {
            selectedAnnotationID = nil
        }
    }
    
    // MARK: - Annotation Management
    
    func addAnnotation(_ annotation: Annotation) {
        saveStateForUndo()
        annotations.append(annotation)
        redoStack.removeAll()
    }
    
    func updateAnnotation(_ annotation: Annotation) {
        guard let index = annotations.firstIndex(where: { $0.id == annotation.id }) else {
            return
        }
        saveStateForUndo()
        annotations[index] = annotation
        redoStack.removeAll()
    }
    
    func deleteAnnotation(_ annotation: Annotation) {
        saveStateForUndo()
        annotations.removeAll { $0.id == annotation.id }
        redoStack.removeAll()
    }
    
    func deleteSelectedAnnotation() {
        guard let id = selectedAnnotationID,
              let annotation = annotations.first(where: { $0.id == id }) else {
            return
        }
        deleteAnnotation(annotation)
        selectedAnnotationID = nil
    }
    
    // MARK: - Undo/Redo
    
    func undo() {
        guard canUndo else { return }
        
        // Save current state to redo stack
        redoStack.append(annotations)
        
        // Restore previous state
        if let previousState = undoStack.popLast() {
            annotations = previousState
        }
    }
    
    func redo() {
        guard canRedo else { return }
        
        // Save current state to undo stack
        undoStack.append(annotations)
        
        // Restore next state
        if let nextState = redoStack.popLast() {
            annotations = nextState
        }
    }
    
    private func saveStateForUndo() {
        undoStack.append(annotations)
        
        // Limit undo stack size
        if undoStack.count > 50 {
            undoStack.removeFirst()
        }
    }
    
    // MARK: - Clear All
    
    func clearAllAnnotations() {
        saveStateForUndo()
        annotations.removeAll()
        selectedAnnotationID = nil
        redoStack.removeAll()
    }
}
