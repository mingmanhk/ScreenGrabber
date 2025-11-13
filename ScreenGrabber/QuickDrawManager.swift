//
//  QuickDrawManager.swift
//  ScreenGrabber
//
//  Quick Draw on Capture - Instant markup overlay
//

import Foundation
import AppKit
import SwiftUI

class QuickDrawManager: ObservableObject {
    static let shared = QuickDrawManager()

    @Published var isQuickDrawEnabled = true
    @Published var currentImage: NSImage?
    @Published var showQuickDrawWindow = false

    // Drawing tools
    @Published var selectedTool: DrawingTool = .arrow
    @Published var strokeColor: NSColor = .red
    @Published var strokeWidth: CGFloat = 3.0
    @Published var fillColor: NSColor = .clear

    // Drawing elements
    @Published var drawingElements: [DrawingElement] = []

    private init() {
        loadSettings()
    }

    enum DrawingTool: String, CaseIterable {
        case arrow = "Arrow"
        case rectangle = "Rectangle"
        case ellipse = "Ellipse"
        case line = "Line"
        case pen = "Pen"
        case text = "Text"
        case highlight = "Highlight"
        case blur = "Blur"
        case number = "Number"

        var icon: String {
            switch self {
            case .arrow: return "arrow.up.right"
            case .rectangle: return "rectangle"
            case .ellipse: return "circle"
            case .line: return "line.diagonal"
            case .pen: return "pencil"
            case .text: return "textformat"
            case .highlight: return "highlighter"
            case .blur: return "aqi.medium"
            case .number: return "number.square"
            }
        }
    }

    struct DrawingElement: Identifiable {
        let id = UUID()
        var tool: DrawingTool
        var path: [CGPoint]
        var color: NSColor
        var width: CGFloat
        var text: String?
        var rect: CGRect?
    }

    // MARK: - Settings Persistence

    private func loadSettings() {
        isQuickDrawEnabled = UserDefaults.standard.object(forKey: "quickDrawEnabled") as? Bool ?? true

        if let colorData = UserDefaults.standard.data(forKey: "quickDrawColor"),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            strokeColor = color
        }

        strokeWidth = CGFloat(UserDefaults.standard.double(forKey: "quickDrawWidth"))
        if strokeWidth == 0 { strokeWidth = 3.0 }
    }

    func saveSettings() {
        UserDefaults.standard.set(isQuickDrawEnabled, forKey: "quickDrawEnabled")

        if let colorData = try? NSKeyedArchiver.archivedData(withRootObject: strokeColor, requiringSecureCoding: false) {
            UserDefaults.standard.set(colorData, forKey: "quickDrawColor")
        }

        UserDefaults.standard.set(Double(strokeWidth), forKey: "quickDrawWidth")
    }

    // MARK: - Quick Draw Actions

    func showQuickDraw(for image: NSImage) {
        guard isQuickDrawEnabled else { return }

        DispatchQueue.main.async {
            self.currentImage = image
            self.drawingElements.removeAll()
            self.showQuickDrawWindow = true
        }
    }

    func addDrawingElement(_ element: DrawingElement) {
        drawingElements.append(element)
    }

    func clearDrawing() {
        drawingElements.removeAll()
    }

    func saveAnnotatedImage(to path: String) -> Bool {
        guard let image = currentImage else { return false }

        let size = image.size
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )

        guard let imageRep = rep else { return false }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: imageRep)

        // Draw original image
        image.draw(in: NSRect(origin: .zero, size: size))

        // Draw annotations
        for element in drawingElements {
            drawElement(element)
        }

        NSGraphicsContext.restoreGraphicsState()

        // Save to file
        guard let data = imageRep.representation(using: .png, properties: [:]) else { return false }

        do {
            try data.write(to: URL(fileURLWithPath: path))
            return true
        } catch {
            print("Error saving annotated image: \(error)")
            return false
        }
    }

    private func drawElement(_ element: DrawingElement) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

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

                // Draw arrow head
                if element.tool == .arrow {
                    drawArrowHead(context: context, from: element.path[0], to: element.path[1], color: element.color, width: element.width)
                }
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

        case .pen:
            if element.path.count > 1 {
                context.move(to: element.path[0])
                for point in element.path.dropFirst() {
                    context.addLine(to: point)
                }
                context.strokePath()
            }

        case .highlight:
            context.setAlpha(0.3)
            context.setStrokeColor(NSColor.yellow.cgColor)
            context.setLineWidth(element.width * 3)
            if element.path.count > 1 {
                context.move(to: element.path[0])
                for point in element.path.dropFirst() {
                    context.addLine(to: point)
                }
                context.strokePath()
            }
            context.setAlpha(1.0)

        case .text, .number, .blur:
            // These require more complex implementation
            break
        }
    }

    private func drawArrowHead(context: CGContext, from: CGPoint, to: CGPoint, color: NSColor, width: CGFloat) {
        let headLength: CGFloat = width * 5
        let headAngle: CGFloat = .pi / 6

        let angle = atan2(to.y - from.y, to.x - from.x)

        let arrowPoint1 = CGPoint(
            x: to.x - headLength * cos(angle - headAngle),
            y: to.y - headLength * sin(angle - headAngle)
        )

        let arrowPoint2 = CGPoint(
            x: to.x - headLength * cos(angle + headAngle),
            y: to.y - headLength * sin(angle + headAngle)
        )

        context.move(to: to)
        context.addLine(to: arrowPoint1)
        context.move(to: to)
        context.addLine(to: arrowPoint2)
        context.strokePath()
    }
}

// MARK: - QuickDraw Settings

struct QuickDrawSettings {
    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "quickDrawEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "quickDrawEnabled") }
    }

    static var autoShowOnCapture: Bool {
        get { UserDefaults.standard.object(forKey: "quickDrawAutoShow") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "quickDrawAutoShow") }
    }
}
