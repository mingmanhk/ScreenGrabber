//
//  EditorRightPanel.swift
//  ScreenGrabber
//
//  Right panel with properties and OCR text
//  Created by Victor Lam on 1/5/26.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Right panel containing tool properties, image adjustments, and OCR text
struct EditorRightPanel: View {
    @ObservedObject var editorState: ScreenCaptureEditorState
    let imageURL: URL
    let showingProperties: Bool
    let showingOCR: Bool
    var showingAdjustments: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Properties Panel
                if showingProperties {
                    ToolPropertiesSection(editorState: editorState)

                    if showingAdjustments || showingOCR {
                        Divider().padding(.vertical, 12)
                    }
                }

                // Adjustments Panel
                if showingAdjustments {
                    ImageAdjustmentsSection(editorState: editorState)

                    if showingOCR {
                        Divider().padding(.vertical, 12)
                    }
                }

                // OCR Text Panel
                if showingOCR {
                    OCRTextSection(
                        editorState: editorState,
                        imageURL: imageURL
                    )
                }

                Spacer()
            }
            .padding(16)
        }
    }
}

// MARK: - Tool Properties Section
struct ToolPropertiesSection: View {
    @ObservedObject var editorState: ScreenCaptureEditorState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.accentColor)
                Text("Properties")
                    .font(.headline)
                Spacer()
            }
            
            Divider()
            
            // Current Tool Display
            if editorState.selectedTool != .selection {
                HStack {
                    Image(systemName: editorState.selectedTool.icon)
                    Text(editorState.selectedTool.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                
                Divider()
            }
            
            // Tool-specific properties
            switch editorState.selectedTool {
            case .freehand, .highlighter, .line, .arrow:
                DrawingToolProperties(editorState: editorState)
                
            case .shape:
                ShapeToolProperties(editorState: editorState)
                
            case .text:
                TextToolProperties(editorState: editorState)
                
            case .blur, .pixelate:
                BlurToolProperties(editorState: editorState)
                
            default:
                Text("Select a tool to see its properties")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical)
            }
        }
    }
}

// MARK: - Drawing Tool Properties
struct DrawingToolProperties: View {
    @ObservedObject var editorState: ScreenCaptureEditorState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Color Picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Color")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ColorPicker("", selection: Binding(
                    get: { Color(editorState.imageEditorState.currentColor) },
                    set: { editorState.imageEditorState.currentColor = NSColor($0) }
                ))
                .labelsHidden()
            }
            
            // Line Width
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Line Width")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(editorState.imageEditorState.lineWidth))pt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: $editorState.imageEditorState.lineWidth,
                    in: 1...20
                )
            }
            
            // Opacity
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Opacity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(editorState.imageEditorState.opacity * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: $editorState.imageEditorState.opacity,
                    in: 0.1...1.0
                )
            }
            
            // Quick Color Presets
            VStack(alignment: .leading, spacing: 6) {
                Text("Quick Colors")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    ForEach(quickColors, id: \.self) { color in
                        Circle()
                            .fill(Color(color))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                            )
                            .onTapGesture {
                                editorState.imageEditorState.currentColor = color
                            }
                    }
                }
            }
        }
    }
    
    private let quickColors: [NSColor] = [
        .systemRed,
        .systemOrange,
        .systemYellow,
        .systemGreen,
        .systemBlue,
        .systemPurple,
        .black,
        .white
    ]
}

// MARK: - Shape Tool Properties
struct ShapeToolProperties: View {
    @ObservedObject var editorState: ScreenCaptureEditorState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Shape Type
            VStack(alignment: .leading, spacing: 6) {
                Text("Shape Type")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("", selection: $editorState.imageEditorState.selectedShape) {
                    ForEach(ShapeType.allCases) { shape in
                        Label(shape.displayName, systemImage: shape.icon)
                            .tag(shape)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
            
            // Fill Toggle
            Toggle("Fill Shape", isOn: $editorState.imageEditorState.isShapeFilled)
                .font(.caption)
            
            Divider()
            
            // Shared drawing properties
            DrawingToolProperties(editorState: editorState)
        }
    }
}

// MARK: - Text Tool Properties
struct TextToolProperties: View {
    @ObservedObject var editorState: ScreenCaptureEditorState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Font Size
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Font Size")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(editorState.imageEditorState.fontSize))pt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: $editorState.imageEditorState.fontSize,
                    in: 8...72
                )
            }
            
            // Color Picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Text Color")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ColorPicker("", selection: Binding(
                    get: { Color(editorState.imageEditorState.currentColor) },
                    set: { editorState.imageEditorState.currentColor = NSColor($0) }
                ))
                .labelsHidden()
            }
            
            // Quick Sizes
            VStack(alignment: .leading, spacing: 6) {
                Text("Quick Sizes")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    ForEach([12, 16, 24, 32, 48], id: \.self) { size in
                        Button("\(size)") {
                            editorState.imageEditorState.fontSize = CGFloat(size)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }
}

// MARK: - Blur Tool Properties
struct BlurToolProperties: View {
    @ObservedObject var editorState: ScreenCaptureEditorState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Blur Radius
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Blur Intensity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(editorState.imageEditorState.blurRadius))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: $editorState.imageEditorState.blurRadius,
                    in: 1...50
                )
            }
        }
    }
}

// MARK: - Image Adjustments Section
struct ImageAdjustmentsSection: View {
    @ObservedObject var editorState: ScreenCaptureEditorState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "slider.vertical.3")
                    .foregroundColor(.accentColor)
                Text("Adjustments")
                    .font(.headline)
                Spacer()
                if !editorState.adjustments.isDefault {
                    Button("Reset") {
                        withAnimation { editorState.adjustments.reset() }
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
            }

            Divider()

            Group {
                AdjustmentSlider(
                    label: "Brightness",
                    value: $editorState.adjustments.brightness,
                    range: -1.0...1.0,
                    displayValue: { v in String(format: "%+.0f", v * 100) }
                )

                AdjustmentSlider(
                    label: "Contrast",
                    value: $editorState.adjustments.contrast,
                    range: 0.5...2.0,
                    displayValue: { v in String(format: "%.0f%%", (v - 1) * 100) }
                )

                AdjustmentSlider(
                    label: "Saturation",
                    value: $editorState.adjustments.saturation,
                    range: 0.0...2.0,
                    displayValue: { v in String(format: "%.0f%%", (v - 1) * 100) }
                )

                AdjustmentSlider(
                    label: "Sharpness",
                    value: $editorState.adjustments.sharpness,
                    range: 0.0...1.0,
                    displayValue: { v in String(format: "%.0f%%", v * 100) }
                )

                AdjustmentSlider(
                    label: "Vignette",
                    value: $editorState.adjustments.vignette,
                    range: 0.0...2.0,
                    displayValue: { v in String(format: "%.0f%%", v * 100) }
                )
            }
        }
    }
}

private struct AdjustmentSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let displayValue: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(displayValue(value))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
            Slider(value: $value, in: range)
        }
    }
}

// MARK: - OCR Text Section
struct OCRTextSection: View {
    @ObservedObject var editorState: ScreenCaptureEditorState
    let imageURL: URL
    
    @State private var isProcessing = false
    @State private var showCopiedConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundColor(.accentColor)
                Text("OCR Text")
                    .font(.headline)
                Spacer()
                
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            
            Divider()
            
            // OCR Text Content
            if !editorState.ocrText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    // Text display
                    ScrollView {
                        Text(editorState.ocrText)
                            .font(.system(size: 12))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color(nsColor: .textBackgroundColor))
                            .cornerRadius(8)
                    }
                    .frame(maxHeight: 300)
                    
                    // Character count
                    Text("\(editorState.ocrText.count) characters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Action buttons
                    HStack(spacing: 8) {
                        Button(action: copyToClipboard) {
                            Label("Copy", systemImage: "doc.on.clipboard")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button(action: exportToFile) {
                            Label("Export", systemImage: "square.and.arrow.up")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Spacer()
                        
                        if showCopiedConfirmation {
                            Text("Copied!")
                                .font(.caption)
                                .foregroundColor(.green)
                                .transition(.opacity)
                        }
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("No text detected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Scan for Text") {
                        scanForText()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
    }
    
    private func scanForText() {
        isProcessing = true
        
        // Trigger OCR
        ScreenCaptureManager.shared.performAutoOCR(for: imageURL)
        
        // Listen for completion (single-shot)
        let center = NotificationCenter.default
        var token: NSObjectProtocol?
        token = center.addObserver(forName: .screenshotOCRCompleted, object: nil, queue: .main) { [weak editorState] notification in
            defer {
                if let token = token { center.removeObserver(token) }
            }
            if let url = notification.userInfo?["url"] as? URL,
               url == imageURL,
               let text = notification.userInfo?["text"] as? String {
                MainActor.assumeIsolated {
                    editorState?.ocrText = text
                    isProcessing = false
                }
            }
        }
    }
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(editorState.ocrText, forType: .string)
        
        showCopiedConfirmation = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedConfirmation = false
            }
        }
    }
    
    private func exportToFile() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = imageURL.deletingPathExtension().lastPathComponent + "_text.txt"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try editorState.ocrText.write(to: url, atomically: true, encoding: .utf8)
                    CaptureLogger.log(.debug, "OCR text exported to \(url.lastPathComponent)", level: .success)
                } catch {
                    CaptureLogger.log(.debug, "OCR export failed: \(error.localizedDescription)", level: .error)
                }
            }
        }
    }
}

extension Notification.Name {
    static let screenshotOCRCompleted = Notification.Name("screenshotOCRCompleted")
}

// MARK: - Preview
struct EditorRightPanel_Previews: PreviewProvider {
    static var previews: some View {
        EditorRightPanel(
            editorState: ScreenCaptureEditorState(),
            imageURL: URL(fileURLWithPath: "/tmp/test.png"),
            showingProperties: true,
            showingOCR: true
        )
        .frame(width: 280, height: 600)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
