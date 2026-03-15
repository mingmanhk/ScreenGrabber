//
//  EditorInspectorView.swift
//  ScreenGrabber
//
//  Inspector panel for editing annotation properties
//

import SwiftUI
import Combine

struct EditorInspectorView: View {
    @ObservedObject var editorState: EditorStateManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Tool Properties
                VStack(alignment: .leading, spacing: 12) {
                    InspectorSectionHeader(title: "Tool Properties")
                    
                    // Color picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Stroke Color")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        ColorPicker("", selection: Binding(
                            get: { Color(editorState.strokeColor) },
                            set: { editorState.strokeColor = NSColor($0) }
                        ))
                        .labelsHidden()
                    }
                    
                    // Fill color (for shapes)
                    if editorState.selectedTool == .rectangle || editorState.selectedTool == .ellipse {
                        Toggle("Fill Shape", isOn: $editorState.isFilled)
                        
                        if editorState.isFilled {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Fill Color")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                ColorPicker("", selection: Binding(
                                    get: { Color(editorState.fillColor ?? .clear) },
                                    set: { editorState.fillColor = NSColor($0) }
                                ))
                                .labelsHidden()
                            }
                        }
                    }
                    
                    // Line width
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Line Width")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(editorState.lineWidth))px")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Slider(value: $editorState.lineWidth, in: 1...10, step: 1)
                    }
                    
                    // Opacity
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Opacity")
                                .help("Adjust transparency from 0% (fully transparent) to 100% (fully opaque). For blur/pixelate tools, lower opacity makes the effect more subtle.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(editorState.opacity * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Slider(value: $editorState.opacity, in: 0...1, step: 0.05)
                    }
                    
                    // Font size (for text)
                    if editorState.selectedTool == .text {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Font Size")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(editorState.fontSize))pt")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Slider(value: $editorState.fontSize, in: 8...72, step: 1)
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                
                // Selected Annotation
                if let selected = editorState.selectedAnnotation {
                    VStack(alignment: .leading, spacing: 12) {
                        InspectorSectionHeader(title: "Selected Annotation")
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Type: \(selected.tool.rawValue.capitalized)")
                                .font(.caption)
                            
                            let rect = CGRect(
                                x: min(selected.cgStartPoint.x, selected.cgEndPoint.x),
                                y: min(selected.cgStartPoint.y, selected.cgEndPoint.y),
                                width: abs(selected.cgEndPoint.x - selected.cgStartPoint.x),
                                height: abs(selected.cgEndPoint.y - selected.cgStartPoint.y)
                            )
                            Text("Position: \(Int(rect.origin.x)), \(Int(rect.origin.y))")
                                .font(.caption)
                            Text("Size: \(Int(rect.width)) × \(Int(rect.height))")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                        
                        Button(role: .destructive) {
                            editorState.deleteSelectedAnnotation()
                        } label: {
                            Label("Delete", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                }
                
                // Quick Actions
                VStack(alignment: .leading, spacing: 12) {
                    InspectorSectionHeader(title: "Quick Actions")
                    
                    Button {
                        editorState.clearAll()
                    } label: {
                        Label("Clear All Annotations", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(editorState.annotations.isEmpty)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                
                Spacer()
            }
            .padding(16)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct InspectorSectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.headline)
            .fontWeight(.semibold)
    }
}

#Preview {
    EditorInspectorView(editorState: EditorStateManager())
        .frame(width: 280, height: 600)
}
