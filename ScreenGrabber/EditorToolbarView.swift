//
//  EditorToolbarView.swift
//  ScreenGrabber
//
//  Toolbar for the screenshot editor
//

import SwiftUI
import Combine

struct EditorToolbarView: View {
    @ObservedObject var editorState: EditorStateManager
    @Binding var viewMode: ScreenshotEditorView.ViewMode
    let onSave: () -> Void
    let onExport: () -> Void
    let onOCR: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Tools
            HStack(spacing: 8) {
                EditorToolButton(
                    icon: "arrow.up.right",
                    title: "Arrow",
                    isSelected: editorState.selectedTool == .arrow
                ) {
                    editorState.selectedTool = .arrow
                }
                
                EditorToolButton(
                    icon: "rectangle",
                    title: "Rectangle",
                    isSelected: editorState.selectedTool == .rectangle
                ) {
                    editorState.selectedTool = .rectangle
                }
                
                EditorToolButton(
                    icon: "circle",
                    title: "Ellipse",
                    isSelected: editorState.selectedTool == .ellipse
                ) {
                    editorState.selectedTool = .ellipse
                }
                
                EditorToolButton(
                    icon: "line.diagonal",
                    title: "Line",
                    isSelected: editorState.selectedTool == .line
                ) {
                    editorState.selectedTool = .line
                }
                
                EditorToolButton(
                    icon: "textformat",
                    title: "Text",
                    isSelected: editorState.selectedTool == .text
                ) {
                    editorState.selectedTool = .text
                }
                
                EditorToolButton(
                    icon: "highlighter",
                    title: "Highlight",
                    isSelected: editorState.selectedTool == .highlight
                ) {
                    editorState.selectedTool = .highlight
                }
                
                EditorToolButton(
                    icon: "camera.filters",
                    title: "Blur",
                    isSelected: editorState.selectedTool == .blur
                ) {
                    editorState.selectedTool = .blur
                }
                
                EditorToolButton(
                    icon: "scribble",
                    title: "Freehand",
                    isSelected: editorState.selectedTool == .freehand
                ) {
                    editorState.selectedTool = .freehand
                }
            }
            
            Divider()
                .frame(height: 24)
            
            // Undo/Redo
            HStack(spacing: 4) {
                Button {
                    editorState.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!editorState.canUndo)
                .help("Undo")
                
                Button {
                    editorState.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled(!editorState.canRedo)
                .help("Redo")
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            // View mode
            Picker("View", selection: $viewMode) {
                ForEach(ScreenshotEditorView.ViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            
            Divider()
                .frame(height: 24)
            
            // Actions
            HStack(spacing: 8) {
                Button {
                    onOCR()
                } label: {
                    Label("OCR", systemImage: "doc.text.viewfinder")
                }
                .help("Extract Text")
                
                Button {
                    onSave()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut("s", modifiers: .command)
                .help("Save Annotations")
                
                Button {
                    onExport()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .keyboardShortcut("e", modifiers: .command)
                .help("Export Image")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Editor Tool Button

struct EditorToolButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 9))
            }
            .frame(width: 60, height: 44)
            .background(
                isSelected ?
                Color.accentColor.opacity(0.2) :
                Color.clear
            )
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

#Preview {
    EditorToolbarView(
        editorState: EditorStateManager(),
        viewMode: .constant(.annotated),
        onSave: {},
        onExport: {},
        onOCR: {}
    )
    .frame(height: 68)
}
