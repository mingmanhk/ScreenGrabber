//
//  EditorToolsSidebar.swift
//  ScreenGrabber
//
//  Left sidebar with annotation tools
//  Created by Victor Lam on 1/5/26.
//

import SwiftUI

/// Left sidebar containing all annotation tools
struct EditorToolsSidebar: View {
    @ObservedObject var editorState: ScreenCaptureEditorState
    
    // Tool groups for organization
    private let basicTools: [EditorTool] = [
        .selection,
        .move
    ]
    
    private let drawingTools: [EditorTool] = [
        .pen,
        .highlighter,
        .line,
        .arrow
    ]
    
    private let shapeTools: [EditorTool] = [
        .shape,
        .text
    ]
    
    private let effectTools: [EditorTool] = [
        .blur,
        .pixelate,
        .spotlight,
        .crop
    ]
    
    private let annotationTools: [EditorTool] = [
        .callout,
        .step,
        .stamp
    ]
    
    private let utilityTools: [EditorTool] = [
        .eraser,
        .magnify
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Basic Tools Section
                ToolGroup(title: "Select", tools: basicTools, editorState: editorState)
                
                Divider()
                    .padding(.vertical, 8)
                
                // Drawing Tools Section
                ToolGroup(title: "Draw", tools: drawingTools, editorState: editorState)
                
                Divider()
                    .padding(.vertical, 8)
                
                // Shape Tools Section
                ToolGroup(title: "Shapes", tools: shapeTools, editorState: editorState)
                
                Divider()
                    .padding(.vertical, 8)
                
                // Effect Tools Section
                ToolGroup(title: "Effects", tools: effectTools, editorState: editorState)
                
                Divider()
                    .padding(.vertical, 8)
                
                // Annotation Tools Section
                ToolGroup(title: "Annotate", tools: annotationTools, editorState: editorState)
                
                Divider()
                    .padding(.vertical, 8)
                
                // Utility Tools Section
                ToolGroup(title: "Utility", tools: utilityTools, editorState: editorState)

                Divider().padding(.vertical, 4)

                // Active tool description status bar
                Text(editorState.selectedTool.toolDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 8)

                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Tool Group
struct ToolGroup: View {
    let title: String
    let tools: [EditorTool]
    @ObservedObject var editorState: ScreenCaptureEditorState
    
    var body: some View {
        VStack(spacing: 4) {
            // Group label (optional, commented out for minimal design)
            // Text(title)
            //     .font(.caption2)
            //     .foregroundColor(.secondary)
            //     .frame(maxWidth: .infinity, alignment: .leading)
            //     .padding(.horizontal, 8)
            
            // Tool buttons
            ForEach(tools, id: \.self) { tool in
                ToolButton(
                    tool: tool,
                    isSelected: editorState.selectedTool == tool,
                    action: {
                        editorState.selectTool(tool)
                    }
                )
            }
        }
    }
}

// MARK: - Tool Button
struct ToolButton: View {
    let tool: EditorTool
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: tool.icon)
                    .font(.system(size: 20))
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(buttonBackgroundColor)
                    )
                    .foregroundColor(buttonForegroundColor)
                
                // Tool name label (shown on hover)
                if isHovering {
                    Text(tool.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
        }
        .buttonStyle(.plain)
        .help(tool.toolDescription)
        .onHover { hovering in
            isHovering = hovering
        }
        .padding(.horizontal, 8)
    }
    
    private var buttonBackgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.15)
        } else if isHovering {
            return Color(nsColor: .controlBackgroundColor)
        } else {
            return Color.clear
        }
    }
    
    private var buttonForegroundColor: Color {
        if isSelected {
            return Color.accentColor
        } else {
            return Color.primary
        }
    }
}

// MARK: - Keyboard Shortcuts Extension
extension EditorToolsSidebar {
    /// Keyboard shortcuts for tool selection
    func setupKeyboardShortcuts() {
        // V - Selection
        // M - Move
        // P - Pen
        // H - Highlighter
        // L - Line
        // A - Arrow
        // S - Shape
        // T - Text
        // B - Blur
        // R - Crop
        // E - Eraser
        // Z - Magnify
    }
}

// MARK: - Tool Palette Preview
struct EditorToolsSidebar_Previews: PreviewProvider {
    static var previews: some View {
        EditorToolsSidebar(editorState: ScreenCaptureEditorState())
            .frame(width: 60, height: 600)
            .background(Color(nsColor: .controlBackgroundColor))
    }
}
