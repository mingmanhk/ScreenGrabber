//
//  ExportPanelView.swift
//  ScreenGrabber
//
//  Export panel for saving annotated images
//

import SwiftUI
import UniformTypeIdentifiers

struct ExportPanelView: View {
    let screenshot: Screenshot
    let annotations: [Annotation]
    
    @Environment(\.dismiss) private var dismiss
    @State private var exportFormat: ExportFormat = .png
    @State private var jpegQuality: Double = 0.9
    @State private var isExporting: Bool = false
    @State private var showingSuccess: Bool = false
    
    enum ExportFormat: String, CaseIterable {
        case png = "PNG"
        case jpeg = "JPEG"
        case tiff = "TIFF"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Export Screenshot")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Export with annotations flattened into the image")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
            }
            
            Divider()
            
            // Format selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Format")
                    .font(.headline)
                
                Picker("Format", selection: $exportFormat) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                
                if exportFormat == .jpeg {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Quality")
                                .font(.caption)
                            Spacer()
                            Text("\(Int(jpegQuality * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Slider(value: $jpegQuality, in: 0.1...1.0, step: 0.05)
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            
            // Preview
            VStack(alignment: .leading, spacing: 12) {
                Text("Preview")
                    .font(.headline)
                
                if let image = NSImage(contentsOf: screenshot.fileURL) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                
                Text("\(annotations.count) annotation(s) will be flattened")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            
            Spacer()
            
            // Actions
            HStack(spacing: 12) {
                Button("Copy to Clipboard") {
                    exportToClipboard()
                }
                .buttonStyle(.bordered)
                
                Button("Save As...") {
                    saveAs()
                }
                .buttonStyle(.borderedProminent)
            }
            
            if isExporting {
                ProgressView("Exporting...")
                    .controlSize(.small)
            }
            
            if showingSuccess {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Exported successfully!")
                        .font(.caption)
                }
            }
        }
        .padding(24)
        .frame(width: 500, height: 600)
    }
    
    private func exportToClipboard() {
        isExporting = true
        
        Task {
            guard let image = NSImage(contentsOf: screenshot.fileURL) else { return }
            
            let rendered = await AnnotationRenderer.shared.renderAnnotations(
                baseImage: image,
                annotations: annotations
            )
            
            await MainActor.run {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects([rendered])
                
                isExporting = false
                showingSuccess = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showingSuccess = false
                }
            }
        }
    }
    
    private func saveAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff]
        panel.nameFieldStringValue = screenshot.filename
        panel.canCreateDirectories = true
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            
            isExporting = true
            
            Task {
                guard let image = NSImage(contentsOf: screenshot.fileURL) else { return }
                
                let rendered = await AnnotationRenderer.shared.renderAnnotations(
                    baseImage: image,
                    annotations: annotations
                )
                
                let format: AnnotationRenderer.ExportFormat
                switch exportFormat {
                case .png:
                    format = .png
                case .jpeg:
                    format = .jpeg(quality: jpegQuality)
                case .tiff:
                    format = .tiff
                }
                
                let result = await AnnotationRenderer.shared.exportImage(
                    rendered,
                    to: url,
                    format: format
                )
                
                await MainActor.run {
                    isExporting = false
                    
                    if case .success = result {
                        showingSuccess = true
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showingSuccess = false
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ExportPanelView(
        screenshot: Screenshot(
            filename: "test.png",
            filePath: "/tmp/test.png",
            captureType: "area",
            width: 1920,
            height: 1080
        ),
        annotations: []
    )
}
