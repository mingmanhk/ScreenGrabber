//
//  QuickDrawView.swift
//  ScreenGrabber
//
//  UI for Quick Draw on Capture
//

import SwiftUI
import AppKit

struct QuickDrawView: View {
    @ObservedObject var manager = QuickDrawManager.shared
    @State private var currentPath: [CGPoint] = []
    @State private var showColorPicker = false
    @State private var showSaveDialog = false
    @Environment(\.dismiss) var dismiss

    var onSave: ((NSImage) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                // Tools
                ForEach(QuickDrawManager.DrawingTool.allCases, id: \.self) { tool in
                    Button(action: {
                        manager.selectedTool = tool
                    }) {
                        Image(systemName: tool.icon)
                            .font(.system(size: 16))
                            .foregroundColor(manager.selectedTool == tool ? .white : .primary)
                            .frame(width: 32, height: 32)
                            .background(manager.selectedTool == tool ? Color.accentColor : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help(tool.rawValue)
                }

                Divider()
                    .frame(height: 24)

                // Color picker
                ColorPicker("", selection: Binding(
                    get: { Color(manager.strokeColor) },
                    set: { manager.strokeColor = NSColor($0) }
                ))
                .labelsHidden()
                .frame(width: 32, height: 32)

                // Stroke width
                HStack(spacing: 4) {
                    Image(systemName: "line.diagonal")
                        .font(.system(size: 12))
                    Slider(value: $manager.strokeWidth, in: 1...10, step: 1)
                        .frame(width: 80)
                    Text("\(Int(manager.strokeWidth))")
                        .font(.caption)
                        .frame(width: 20)
                }

                Spacer()

                // Actions
                Button("Clear") {
                    manager.clearDrawing()
                }
                .keyboardShortcut("k", modifiers: .command)

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button("Save") {
                    saveImage()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            // Canvas
            if let image = manager.currentImage {
                QuickDrawCanvas(
                    image: image,
                    elements: $manager.drawingElements,
                    currentPath: $currentPath,
                    tool: manager.selectedTool,
                    color: manager.strokeColor,
                    width: manager.strokeWidth
                )
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    private func saveImage() {
        guard let image = manager.currentImage else { return }

        if manager.drawingElements.isEmpty {
            // No annotations, just use original
            onSave?(image)
        } else {
            // Save with annotations
            let tempPath = NSTemporaryDirectory() + "annotated_\(UUID().uuidString).png"
            if manager.saveAnnotatedImage(to: tempPath) {
                if let annotatedImage = NSImage(contentsOfFile: tempPath) {
                    onSave?(annotatedImage)
                }
                try? FileManager.default.removeItem(atPath: tempPath)
            }
        }

        dismiss()
    }
}

struct QuickDrawCanvas: NSViewRepresentable {
    let image: NSImage
    @Binding var elements: [QuickDrawManager.DrawingElement]
    @Binding var currentPath: [CGPoint]
    let tool: QuickDrawManager.DrawingTool
    let color: NSColor
    let width: CGFloat

    func makeNSView(context: Context) -> QuickDrawCanvasView {
        let view = QuickDrawCanvasView()
        view.image = image
        view.elements = elements
        view.tool = tool
        view.color = color
        view.width = width
        view.onDrawingComplete = { element in
            elements.append(element)
        }
        return view
    }

    func updateNSView(_ nsView: QuickDrawCanvasView, context: Context) {
        nsView.image = image
        nsView.elements = elements
        nsView.tool = tool
        nsView.color = color
        nsView.width = width
    }
}

class QuickDrawCanvasView: NSView {
    var image: NSImage?
    var elements: [QuickDrawManager.DrawingElement] = []
    var tool: QuickDrawManager.DrawingTool = .arrow
    var color: NSColor = .red
    var width: CGFloat = 3.0

    var currentPath: [CGPoint] = []
    var startPoint: CGPoint?

    var onDrawingComplete: ((QuickDrawManager.DrawingElement) -> Void)?

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        startPoint = point
        currentPath = [point]
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        currentPath.append(point)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let start = startPoint else { return }
        let end = convert(event.locationInWindow, from: nil)

        let element: QuickDrawManager.DrawingElement

        switch tool {
        case .arrow, .line:
            element = QuickDrawManager.DrawingElement(
                tool: tool,
                path: [start, end],
                color: color,
                width: width
            )
        case .rectangle, .ellipse:
            let rect = CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            )
            element = QuickDrawManager.DrawingElement(
                tool: tool,
                path: [],
                color: color,
                width: width,
                rect: rect
            )
        case .pen, .highlight:
            element = QuickDrawManager.DrawingElement(
                tool: tool,
                path: currentPath,
                color: color,
                width: width
            )
        default:
            return
        }

        onDrawingComplete?(element)
        currentPath = []
        startPoint = nil
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Draw image
        if let image = image {
            let imageRect = bounds
            image.draw(in: imageRect)
        }

        // Draw completed elements
        for element in elements {
            drawElement(element, in: context)
        }

        // Draw current path
        if !currentPath.isEmpty {
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(width)
            context.setLineCap(.round)
            context.setLineJoin(.round)

            switch tool {
            case .arrow, .line:
                if let start = currentPath.first, let end = currentPath.last {
                    context.move(to: start)
                    context.addLine(to: end)
                    context.strokePath()
                }
            case .rectangle:
                if let start = currentPath.first, let end = currentPath.last {
                    let rect = CGRect(
                        x: min(start.x, end.x),
                        y: min(start.y, end.y),
                        width: abs(end.x - start.x),
                        height: abs(end.y - start.y)
                    )
                    context.addRect(rect)
                    context.strokePath()
                }
            case .ellipse:
                if let start = currentPath.first, let end = currentPath.last {
                    let rect = CGRect(
                        x: min(start.x, end.x),
                        y: min(start.y, end.y),
                        width: abs(end.x - start.x),
                        height: abs(end.y - start.y)
                    )
                    context.addEllipse(in: rect)
                    context.strokePath()
                }
            case .pen, .highlight:
                if currentPath.count > 1 {
                    context.move(to: currentPath[0])
                    for point in currentPath.dropFirst() {
                        context.addLine(to: point)
                    }
                    context.strokePath()
                }
            default:
                break
            }
        }
    }

    private func drawElement(_ element: QuickDrawManager.DrawingElement, in context: CGContext) {
        context.setStrokeColor(element.color.cgColor)
        context.setLineWidth(element.width)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        switch element.tool {
        case .arrow, .line:
            if element.path.count >= 2 {
                context.move(to: element.path[0])
                context.addLine(to: element.path[1])
                context.strokePath()
            }
        case .rectangle:
            if let rect = element.rect {
                context.addRect(rect)
                context.strokePath()
            }
        case .ellipse:
            if let rect = element.rect {
                context.addEllipse(in: rect)
                context.strokePath()
            }
        case .pen, .highlight:
            if element.path.count > 1 {
                if element.tool == .highlight {
                    context.setAlpha(0.3)
                    context.setLineWidth(element.width * 3)
                }
                context.move(to: element.path[0])
                for point in element.path.dropFirst() {
                    context.addLine(to: point)
                }
                context.strokePath()
                context.setAlpha(1.0)
            }
        default:
            break
        }
    }
}
