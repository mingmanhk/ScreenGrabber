//
//  ScreenCaptureEditorView.swift
//  ScreenGrabber
//
//  Created by Screen Grabber Team on 11/28/25.
//

import SwiftUI
import Vision

// (Editor enums are now in SharedModels.swift)

struct ScreenCaptureEditorView: View {
    let fileURL: URL
    @Environment(\.dismiss) var dismiss
    
    @State private var zoomLevel: CGFloat = 1.0
    @State private var image: NSImage?
    @State private var ocrText: String = ""
    @State private var isOCRLoading = false
    @State private var showOCRPanel = true
    @State private var selectedTool: EditorTool = .selection
    @State private var annotationColor: Color = .red
    @State private var lineWidth: CGFloat = 2.0
    
    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                Color(NSColor.windowBackgroundColor)
                if let nsImage = image {
                    ScrollView([.horizontal, .vertical]) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: nsImage.size.width * zoomLevel, height: nsImage.size.height * zoomLevel)
                            .overlay(EditorAnnotationOverlay(tool: selectedTool, scale: zoomLevel, annotationColor: NSColor(annotationColor), lineWidth: lineWidth))
                    }
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            if showOCRPanel {
                Divider()
                VStack {
                    HStack {
                        Text("Inspector").font(.headline)
                        Spacer()
                        Button(action: { showOCRPanel = false }) { Image(systemName: "xmark.circle") }
                    }
                    .padding()
                    
                    Divider()
                    
                    // Tools
                    HStack {
                        ForEach(EditorTool.allCases) { tool in
                            Button(action: { selectedTool = tool }) {
                                Image(systemName: tool.icon)
                                    .padding(8)
                                    .background(selectedTool == tool ? Color.accentColor.opacity(0.2) : Color.clear)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    
                    Divider()
                    
                    // OCR
                    ScrollView {
                        Text(ocrText.isEmpty ? "No text detected" : ocrText)
                            .padding()
                            .textSelection(.enabled)
                    }
                }
                .frame(width: 250)
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showOCRPanel.toggle() }) { 
                    Image(systemName: "sidebar.right") 
                }
            }
        }
        .onAppear(perform: loadImage)
    }
    
    private func loadImage() {
        guard let loaded = NSImage(contentsOf: fileURL) else { return }
        self.image = loaded
        performOCR(on: loaded)
    }
    
    private func performOCR(on image: NSImage) {
        if let saved = ScreenCaptureManager.shared.getOCRText(for: fileURL) {
            self.ocrText = saved
            return
        }
        self.isOCRLoading = true
        let ocrManager = OCRManager.shared
        ocrManager.extractText(from: image) { res in
            DispatchQueue.main.async {
                self.isOCRLoading = false
                self.ocrText = (try? res.get()) ?? ""
            }
        }
    }
}

