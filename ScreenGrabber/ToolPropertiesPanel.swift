//
//  ToolPropertiesPanel.swift
//  ScreenGrabber
//
//  Created by Victor Lam on 10/23/25.
//

import SwiftUI
import AppKit

struct ToolPropertiesPanel: View {
    @ObservedObject var editorState: ImageEditorState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Tool Properties")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                // Common properties
                ColorPickerSection(editorState: editorState)
                
                // Tool-specific properties
                switch editorState.selectedTool {
                case .pen, .line, .arrow, .highlighter:
                    LineWidthSection(editorState: editorState)
                    OpacitySection(editorState: editorState)
                    
                case .shape:
                    ShapePropertiesSection(editorState: editorState)
                    
                case .text:
                    TextPropertiesSection(editorState: editorState)
                    
                case .blur:
                    BlurPropertiesSection(editorState: editorState)
                    
                case .eraser:
                    EraserPropertiesSection(editorState: editorState)
                    
                default:
                    OpacitySection(editorState: editorState)
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - Color Picker Section
struct ColorPickerSection: View {
    @ObservedObject var editorState: ImageEditorState
    @State private var showingColorPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack(spacing: 8) {
                // Current color display
                Button(action: { showingColorPicker.toggle() }) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(editorState.currentColor))
                        .frame(width: 40, height: 30)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingColorPicker) {
                    ColorPickerPopover(selectedColor: Binding(
                        get: { Color(editorState.currentColor) },
                        set: { editorState.currentColor = NSColor($0) }
                    ))
                }
                
                // Preset colors
                LazyHGrid(rows: [GridItem(.fixed(20)), GridItem(.fixed(20))], spacing: 4) {
                    ForEach(presetColors, id: \.self) { color in
                        Button(action: { editorState.currentColor = color }) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(color))
                                .frame(width: 20, height: 20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(
                                            editorState.currentColor == color ? Color.blue : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    private var presetColors: [NSColor] {
        [
            .red, .orange, .yellow, .green, .blue, .purple,
            .black, .gray, .white, .brown, .cyan, .magenta
        ]
    }
}

// MARK: - Line Width Section
struct LineWidthSection: View {
    @ObservedObject var editorState: ImageEditorState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Line Width")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(Int(editorState.lineWidth))px")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Slider(value: $editorState.lineWidth, in: 1...20, step: 1)
            
            // Line width preview
            RoundedRectangle(cornerRadius: editorState.lineWidth / 2)
                .fill(Color(editorState.currentColor))
                .frame(height: editorState.lineWidth)
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Opacity Section
struct OpacitySection: View {
    @ObservedObject var editorState: ImageEditorState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Opacity")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(Int(editorState.opacity * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Slider(value: $editorState.opacity, in: 0.1...1.0)
        }
    }
}

// MARK: - Shape Properties Section
struct ShapePropertiesSection: View {
    @ObservedObject var editorState: ImageEditorState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shape Type")
                .font(.subheadline)
                .fontWeight(.medium)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(ShapeType.allCases, id: \.self) { shape in
                    Button(action: { editorState.selectedShape = shape }) {
                        VStack(spacing: 4) {
                            Image(systemName: shapeIcon(for: shape))
                                .font(.title3)
                                .foregroundColor(editorState.selectedShape == shape ? .white : .accentColor)
                            
                            Text(shape.displayName)
                                .font(.caption)
                                .foregroundColor(editorState.selectedShape == shape ? .white : .primary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(editorState.selectedShape == shape ? Color.accentColor : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.accentColor, lineWidth: editorState.selectedShape == shape ? 0 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Toggle("Fill Shape", isOn: $editorState.isShapeFilled)
            
            if !editorState.isShapeFilled {
                LineWidthSection(editorState: editorState)
            }
            
            OpacitySection(editorState: editorState)
        }
    }
    
    private func shapeIcon(for shape: ShapeType) -> String {
        switch shape {
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .roundedRectangle: return "rectangle.roundedtop"
        case .triangle: return "triangle"
        case .star: return "star"
        case .polygon: return "hexagon"
        }
    }
}

// MARK: - Text Properties Section
struct TextPropertiesSection: View {
    @ObservedObject var editorState: ImageEditorState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Font Size")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(Int(editorState.fontSize))pt")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Slider(value: $editorState.fontSize, in: 8...72, step: 1)
            
            // Font preview
            Text("Sample Text")
                .font(.system(size: editorState.fontSize))
                .foregroundColor(Color(editorState.currentColor))
                .opacity(editorState.opacity)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.1))
                )
            
            OpacitySection(editorState: editorState)
        }
    }
}

// MARK: - Blur Properties Section
struct BlurPropertiesSection: View {
    @ObservedObject var editorState: ImageEditorState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Blur Radius")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(Int(editorState.blurRadius))px")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Slider(value: $editorState.blurRadius, in: 1...50, step: 1)
            
            OpacitySection(editorState: editorState)
        }
    }
}

// MARK: - Eraser Properties Section
struct EraserPropertiesSection: View {
    @ObservedObject var editorState: ImageEditorState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Eraser Size")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(Int(editorState.lineWidth))px")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Slider(value: $editorState.lineWidth, in: 5...50, step: 1)
            
            // Eraser preview
            Circle()
                .fill(Color.gray.opacity(0.5))
                .frame(width: editorState.lineWidth, height: editorState.lineWidth)
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Color Picker Popover
struct ColorPickerPopover: View {
    @Binding var selectedColor: Color
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            ColorPicker("Choose Color", selection: $selectedColor, supportsOpacity: false)
                .labelsHidden()
            
            // Additional color controls could go here
            
            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding()
        .frame(width: 300, height: 400)
    }
}