//
//  EditorPanel.swift
//  ScreenGrabber
//
//  Right panel with style presets and tool properties
//

import SwiftUI
import AppKit

struct EditorPanel: View {
    var selectedImageURL: URL?
    
    @State private var selectedStyle: AnnotationStylePreset = .none
    @State private var selectedTool: EditorTool = .selection  // Use value from ImageEditorModels
    @State private var selectedShape: AnnotationShape = .rectangle
    
    // OCR States
    @State private var showingOCRResults = false
    @State private var ocrText: String = ""
    @State private var isOCRLoading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Editor Tools")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Customize your annotations")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 20)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Quick Styles
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Styles")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(AnnotationStylePreset.allCases) { style in
                                    StyleThumbnail(
                                        style: style,
                                        isSelected: selectedStyle == style,
                                        onSelect: { selectedStyle = style }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Tool Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tools")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 20)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(EditorTool.allCases) { tool in
                                EditorPanelToolButton(
                                    tool: tool,
                                    isSelected: selectedTool == tool,
                                    onSelect: { selectedTool = tool }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Shape Selection (for drawing tools)
                    if selectedTool == .shape {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Shapes")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .padding(.horizontal, 20)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                ForEach(AnnotationShape.allCases) { shape in
                                    ShapeButton(
                                        shape: shape,
                                        isSelected: selectedShape == shape,
                                        onSelect: { selectedShape = shape }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                    }
                    
                    // Tool Properties
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Properties")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 20)
                        
                        // Color Picker
                        HStack {
                            Text("Color:")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            ColorPicker("", selection: .constant(Color.red))
                                .labelsHidden()
                        }
                        .padding(.horizontal, 20)
                        
                        // Line Width
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Line Width:")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                Text("2")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            Slider(value: .constant(2), in: 1...10, step: 1)
                        }
                        .padding(.horizontal, 20)
                        
                        // Opacity
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Opacity:")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                Text("100%")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            Slider(value: .constant(100), in: 0...100, step: 5)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Quick Actions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Actions")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 8) {
                            PanelActionButton(
                                title: "Select All (Blur)",
                                icon: "circle.hexagongrid.fill",
                                color: .blue
                            ) {}
                            
                            PanelActionButton(
                                title: "Remove Background",
                                icon: "person.crop.circle.badge.minus",
                                color: .purple
                            ) {}
                            
                            PanelActionButton(
                                title: "Apply Template",
                                icon: "square.grid.3x3.fill",
                                color: .orange
                            ) {}
                            
                            // OCR Button - Functional
                            PanelActionButton(
                                title: "Grab Text (OCR)",
                                icon: "doc.text.viewfinder",
                                color: .green
                            ) {
                                loadOCRText()
                            }
                            .popover(isPresented: $showingOCRResults) {
                                OCRResultView(text: ocrText, isLoading: isOCRLoading)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 20)
            }
        }
        .frame(width: 280)
        .background(Color(NSColor.windowBackgroundColor))
        .disabled(selectedImageURL == nil)
        .opacity(selectedImageURL == nil ? 0.6 : 1.0)
    }
    
    private func loadOCRText() {
        guard let url = selectedImageURL else { return }
        
        showingOCRResults = true
        isOCRLoading = true
        ocrText = ""
        
        // 1. Try to get text from xattrs first (fast)
        if let cachedText = ScreenCaptureManager.shared.getOCRText(for: url) {
            ocrText = cachedText
            isOCRLoading = false
        } else {
            // 2. If missing (e.g. old screenshot), run OCR on demand
            if let image = NSImage(contentsOf: url) {
                OCRManager.shared.extractText(from: image) { result in
                    DispatchQueue.main.async {
                        self.isOCRLoading = false
                        switch result {
                        case .success(let text):
                            self.ocrText = text.isEmpty ? "No text detected." : text
                        case .failure(let error):
                            self.ocrText = "Error: \(error.localizedDescription)"
                        }
                    }
                }
            } else {
                ocrText = "Could not load image."
                isOCRLoading = false
            }
        }
    }
}

// MARK: - OCR Result View
struct OCRResultView: View {
    let text: String
    let isLoading: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Detected Text")
                    .font(.headline)
                Spacer()
                if !isLoading && !text.isEmpty {
                    Button(action: {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(text, forType: .string)
                    }) {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.bottom, 4)
            
            if isLoading {
                ProgressView("Scanning text...")
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                TextEditor(text: .constant(text))
                    .font(.system(.body, design: .monospaced))
                    .frame(minWidth: 300, minHeight: 200)
                    .padding(4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(4)
            }
        }
        .padding()
    }
}

// MARK: - Style Thumbnail
struct StyleThumbnail: View {
    let style: AnnotationStylePreset
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(style.previewColor)
                        .frame(width: 60, height: 60)
                    
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.red, lineWidth: 3)
                            .frame(width: 60, height: 60)
                    }
                }
                
                Text(style.displayName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Editor Panel Tool Button
struct EditorPanelToolButton: View {
    let tool: EditorTool
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                Image(systemName: tool.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .white : .primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isSelected ? Color.red : Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                
                Text(tool.displayName)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shape Button
struct ShapeButton: View {
    let shape: AnnotationShape
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            Image(systemName: shape.icon)
                .font(.system(size: 20))
                .foregroundColor(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(isSelected ? Color.red : Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Panel Action Button
struct PanelActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Supporting Models
enum AnnotationStylePreset: String, CaseIterable, Identifiable {
    case none, highlight, arrow, callout, pixelate, sketch
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .highlight: return "Highlight"
        case .arrow: return "Arrow"
        case .callout: return "Callout"
        case .pixelate: return "Pixelate"
        case .sketch: return "Sketch"
        }
    }
    
    var previewColor: Color {
        switch self {
        case .none: return Color.gray.opacity(0.2)
        case .highlight: return Color.yellow.opacity(0.5)
        case .arrow: return Color.red.opacity(0.5)
        case .callout: return Color.blue.opacity(0.5)
        case .pixelate: return Color.purple.opacity(0.5)
        case .sketch: return Color.orange.opacity(0.5)
        }
    }
}

// EditorTool enum is defined in EditorModels.swift to avoid ambiguity

enum AnnotationShape: String, CaseIterable, Identifiable {
    case rectangle, circle, line, freeform
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .rectangle: return "rectangle"
        case .circle: return "circle"
        case .line: return "line.diagonal"
        case .freeform: return "scribble"
        }
    }
}

#Preview {
    EditorPanel()
}

