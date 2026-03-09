//
//  ScreenshotEditorView.swift
//  ScreenGrabber
//
//  Complete screenshot editor with all features
//

import SwiftUI
import SwiftData
import Combine

struct ScreenshotEditorView: View {
    let screenshot: Screenshot
    
    @Environment(\.modelContext) private var modelContext
    @StateObject private var editorState = EditorStateManager()
    @State private var image: NSImage?
    @State private var showingOCR = false
    @State private var showingExport = false
    @State private var viewMode: ViewMode = .annotated
    
    enum ViewMode: String, CaseIterable {
        case original = "Original"
        case annotated = "Annotated"
        case split = "Split"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            EditorToolbarView(
                editorState: editorState,
                viewMode: $viewMode,
                onSave: saveAnnotations,
                onExport: { showingExport = true },
                onOCR: { showingOCR = true }
            )
            
            Divider()
            
            HStack(spacing: 0) {
                // Main canvas area
                VStack(spacing: 0) {
                    if let image = image {
                        EditorCanvasView(
                            image: image,
                            editorState: editorState,
                            viewMode: viewMode
                        )
                    } else {
                        ProgressView("Loading image...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    // Mini-map for tall images
                    if let image = image, image.size.height > 2000 {
                        Divider()
                        MiniMapView(
                            image: image,
                            annotations: editorState.annotations,
                            scrollOffset: editorState.scrollOffset
                        )
                        .frame(height: 120)
                    }
                }
                
                Divider()
                
                // Inspector panel
                EditorInspectorView(editorState: editorState)
                    .frame(width: 280)
            }
        }
        .task {
            await loadImage()
            await loadAnnotations()
        }
        .sheet(isPresented: $showingOCR) {
            OCRPanelView(image: image ?? NSImage())
        }
        .sheet(isPresented: $showingExport) {
            ExportPanelView(
                screenshot: screenshot,
                annotations: editorState.annotations
            )
        }
    }
    
    private func loadImage() async {
        if let loadedImage = NSImage(contentsOf: screenshot.fileURL) {
            await MainActor.run {
                self.image = loadedImage
            }
        }
    }
    
    private func loadAnnotations() async {
        // Load annotations from the screenshot's relationship
        let annotations = screenshot.annotations ?? []
        await MainActor.run {
            editorState.loadAnnotations(annotations)
        }
    }
    
    private func saveAnnotations() {
        Task {
            let result = await CaptureHistoryStore.shared.updateAnnotations(
                for: screenshot,
                annotations: editorState.annotations,
                modelContext: modelContext
            )
            
            if case .success = result {
                // Show saved confirmation
                print("Annotations saved successfully")
            }
        }
    }
}

// MARK: - Editor State Manager

@MainActor
class EditorStateManager: ObservableObject {
    // Tool selection
    @Published var selectedTool: EditorTool = .selection
    
    // Current annotation being drawn
    @Published var currentAnnotation: Annotation?
    
    // All annotations
    @Published var annotations: [Annotation] = []
    
    // Selected annotation for editing
    @Published var selectedAnnotation: Annotation?
    
    // Style properties
    @Published var strokeColor: NSColor = .red
    @Published var fillColor: NSColor? = nil
    @Published var lineWidth: Double = 2
    @Published var opacity: Double = 1
    @Published var isFilled: Bool = false
    @Published var fontSize: Double = 16
    
    // Undo/Redo
    private var undoStack: [[Annotation]] = []
    private var redoStack: [[Annotation]] = []
    private let maxUndoSteps = 50
    
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    
    // Scroll offset for mini-map
    @Published var scrollOffset: CGPoint = .zero
    
    // Snapping
    @Published var showSnapGuides: Bool = false
    @Published var snapGuides: [SnapGuide] = []
    
    func loadAnnotations(_ annotations: [Annotation]) {
        self.annotations = annotations
        saveStateForUndo()
    }
    
    func addAnnotation(_ annotation: Annotation) {
        saveStateForUndo()
        annotations.append(annotation)
    }
    
    func updateAnnotation(_ annotation: Annotation) {
        if let index = annotations.firstIndex(where: { $0.id == annotation.id }) {
            saveStateForUndo()
            annotations[index] = annotation
        }
    }
    
    func deleteAnnotation(_ annotation: Annotation) {
        saveStateForUndo()
        annotations.removeAll { $0.id == annotation.id }
        if selectedAnnotation?.id == annotation.id {
            selectedAnnotation = nil
        }
    }
    
    func deleteSelectedAnnotation() {
        if let selected = selectedAnnotation {
            deleteAnnotation(selected)
        }
    }
    
    func undo() {
        guard let previousState = undoStack.popLast() else { return }
        redoStack.append(annotations)
        annotations = previousState
        selectedAnnotation = nil
    }
    
    func redo() {
        guard let nextState = redoStack.popLast() else { return }
        undoStack.append(annotations)
        annotations = nextState
        selectedAnnotation = nil
    }
    
    func clearAll() {
        saveStateForUndo()
        annotations.removeAll()
        selectedAnnotation = nil
    }
    
    private func saveStateForUndo() {
        undoStack.append(annotations)
        if undoStack.count > maxUndoSteps {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
    }
    
    func checkSnapping(for point: CGPoint) -> CGPoint {
        // Implementation for snapping logic
        var snappedPoint = point
        var guides: [SnapGuide] = []
        
        let snapThreshold: CGFloat = 10
        
        // Check against other annotations
        for annotation in annotations {
            // Calculate bounds if not already cached
            let rect = annotation.bounds?.cgRect ?? annotation.calculateBounds()
            
            // Snap to center
            if abs(point.x - rect.midX) < snapThreshold {
                snappedPoint.x = rect.midX
                guides.append(SnapGuide(type: .vertical, position: rect.midX))
            }
            if abs(point.y - rect.midY) < snapThreshold {
                snappedPoint.y = rect.midY
                guides.append(SnapGuide(type: .horizontal, position: rect.midY))
            }
            
            // Snap to edges
            if abs(point.x - rect.minX) < snapThreshold {
                snappedPoint.x = rect.minX
                guides.append(SnapGuide(type: .vertical, position: rect.minX))
            }
            if abs(point.x - rect.maxX) < snapThreshold {
                snappedPoint.x = rect.maxX
                guides.append(SnapGuide(type: .vertical, position: rect.maxX))
            }
        }
        
        snapGuides = guides
        showSnapGuides = !guides.isEmpty
        
        return snappedPoint
    }
    
    struct SnapGuide: Identifiable {
        let id = UUID()
        enum GuideType {
            case horizontal, vertical
        }
        let type: GuideType
        let position: CGFloat
    }
}

#Preview {
    ScreenshotEditorView(
        screenshot: Screenshot(
            filename: "test.png",
            filePath: "/tmp/test.png",
            captureType: "area",
            width: 1920,
            height: 1080
        )
    )
    .modelContainer(for: Screenshot.self, inMemory: true)
    .frame(width: 1200, height: 800)
}
