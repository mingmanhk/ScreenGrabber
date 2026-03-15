//
//  EditorUIComponents.swift
//  ScreenGrabber
//
//  Created on 01/05/26.
//  Reusable UI components for the editor
//

import SwiftUI

// MARK: - Tool Button
struct EditorToolLargeButton: View {
    let tool: EditorTool
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tool.icon)
                    .font(.system(size: 18, weight: .medium))
                Text(tool.rawValue)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .frame(width: 60, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .help(tool.displayName)
    }
}

// MARK: - Editor Action Button
// Renamed to EditorActionButton to avoid conflict with other ActionButtons
struct EditorActionButton: View {
    let action: EditorAction
    let isEnabled: Bool
    let onTap: () -> Void
    
    init(action: EditorAction, isEnabled: Bool = true, onTap: @escaping () -> Void) {
        self.action = action
        self.isEnabled = isEnabled
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: action.icon)
                    .font(.system(size: 13, weight: .medium))
                Text(action.rawValue)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(isEnabled ? .primary : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.5)
    }
}

// MARK: - Color Picker Button
struct ColorPickerButton: View {
    @Binding var selectedColor: Color
    let color: Color
    
    var body: some View {
        Button(action: {
            selectedColor = color
        }) {
            Circle()
                .fill(color)
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .strokeBorder(selectedColor == color ? Color.primary : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Slider Row
struct SliderRow: View {
    let title: String
    let icon: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let step: CGFloat = 1
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text("\(Int(value))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            
            Slider(value: $value, in: range, step: step)
                .controlSize(.small)
        }
    }
}

// MARK: - Tool Panel Header
struct ToolPanelHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.accentColor)
            
            Text(title)
                .font(.system(size: 16, weight: .bold))
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
}

// MARK: - Tool Section
struct ToolSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            content()
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Shape Type Picker
struct ShapeTypePicker: View {
    @Binding var selectedShape: ShapeType
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(ShapeType.allCases) { shape in
                Button(action: {
                    selectedShape = shape
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: shape.icon)
                            .font(.system(size: 16, weight: .medium))
                        Text(shape.rawValue)
                            .font(.system(size: 9))
                    }
                    .foregroundColor(selectedShape == shape ? .white : .primary)
                    .frame(width: 50, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selectedShape == shape ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Preview
#Preview("Tool Button") {
    HStack(spacing: 12) {
        EditorToolLargeButton(tool: .freehand, isSelected: false) {}
        EditorToolLargeButton(tool: .text, isSelected: true) {}
        EditorToolLargeButton(tool: .shape, isSelected: false) {}
    }
    .padding()
}

#Preview("Action Button") {
    HStack(spacing: 8) {
        EditorActionButton(action: .undo, isEnabled: true) {}
        EditorActionButton(action: .redo, isEnabled: false) {}
        EditorActionButton(action: .save, isEnabled: true) {}
    }
    .padding()
}

#Preview("Slider Row") {
    @Previewable @State var value: CGFloat = 5
    SliderRow(title: "Stroke Width", icon: "pencil", value: $value, range: 1...20)
        .padding()
        .frame(width: 280)
}

