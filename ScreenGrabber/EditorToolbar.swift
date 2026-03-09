//
//  EditorToolbar.swift
//  ScreenGrabber
//
//  Top toolbar for Screen Capture Editor
//  Created by Victor Lam on 1/5/26.
//

import SwiftUI
import UniformTypeIdentifiers
import PDFKit
import ImageIO

/// Top toolbar with zoom, export, and view controls
struct EditorToolbar: View {
    @ObservedObject var editorState: ScreenCaptureEditorState
    
    let onExport: () -> Void
    let onPrint: () -> Void
    let onRename: () -> Void
    let onOCRToggle: () -> Void
    let onPropertiesToggle: () -> Void
    let onRecentToggle: () -> Void
    let onAdjustmentsToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Left: File Actions
            HStack(spacing: 8) {
                Button(action: {
                    editorState.imageEditorState.undo()
                    editorState.undo()
                }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 16))
                }
                .buttonStyle(.borderless)
                .disabled(!editorState.imageEditorState.canUndo && !editorState.canUndo)
                .help("Undo (⌘Z)")

                Button(action: {
                    editorState.imageEditorState.redo()
                    editorState.redo()
                }) {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 16))
                }
                .buttonStyle(.borderless)
                .disabled(!editorState.imageEditorState.canRedo && !editorState.canRedo)
                .help("Redo (⇧⌘Z)")
                
                Divider()
                    .frame(height: 20)
                
                Button(action: onRename) {
                    Label("Rename", systemImage: "pencil")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 16))
                }
                .buttonStyle(.borderless)
                .help("Rename file")
                
                Button(action: onExport) {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 16))
                }
                .buttonStyle(.borderless)
                .help("Export (⌘E)")

                Button(action: onPrint) {
                    Label("Print", systemImage: "printer")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 16))
                }
                .buttonStyle(.borderless)
                .help("Print (⌘P)")
            }
            
            Spacer()
            
            // Center: Zoom Controls
            HStack(spacing: 12) {
                Text("Zoom:")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                
                Button("Fit") {
                    editorState.imageEditorState.zoomLevel = 1.0
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("50%") {
                    editorState.imageEditorState.zoomLevel = 0.5
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("100%") {
                    editorState.imageEditorState.zoomLevel = 1.0
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("200%") {
                    editorState.imageEditorState.zoomLevel = 2.0
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Divider()
                    .frame(height: 20)
                
                // Zoom slider
                Slider(
                    value: $editorState.imageEditorState.zoomLevel,
                    in: 0.25...4.0
                )
                .frame(width: 120)
                
                Text("\(Int(editorState.imageEditorState.zoomLevel * 100))%")
                    .font(.system(size: 12, design: .monospaced))
                    .frame(width: 50, alignment: .trailing)
            }
            
            Spacer()
            
            // Right: View Options
            HStack(spacing: 8) {
                Button(action: onAdjustmentsToggle) {
                    Label("Adjustments", systemImage: "slider.vertical.3")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 16))
                }
                .buttonStyle(.borderless)
                .help("Toggle image adjustments")

                Button(action: onOCRToggle) {
                    Label("OCR Text", systemImage: "doc.text.magnifyingglass")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 16))
                }
                .buttonStyle(.borderless)
                .help("Toggle OCR panel")

                Button(action: onPropertiesToggle) {
                    Label("Properties", systemImage: "slider.horizontal.3")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 16))
                }
                .buttonStyle(.borderless)
                .help("Toggle properties panel")
                
                Divider()
                    .frame(height: 20)
                
                Button(action: onRecentToggle) {
                    Label("Recent", systemImage: "photo.stack")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 16))
                }
                .buttonStyle(.borderless)
                .help("Toggle recent captures")
                
                Button(action: {
                    editorState.showGrid.toggle()
                }) {
                    Label("Grid", systemImage: editorState.showGrid ? "grid.circle.fill" : "grid.circle")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 16))
                }
                .buttonStyle(.borderless)
                .help("Toggle grid overlay")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Zoom Controls Overlay
struct ZoomControls: View {
    @ObservedObject var editorState: ScreenCaptureEditorState
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: {
                editorState.imageEditorState.zoomLevel = max(0.25, editorState.imageEditorState.zoomLevel - 0.25)
            }) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 14))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .help("Zoom out")
            
            Text("\(Int(editorState.imageEditorState.zoomLevel * 100))%")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .frame(width: 55)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
            
            Button(action: {
                editorState.imageEditorState.zoomLevel = min(4.0, editorState.imageEditorState.zoomLevel + 0.25)
            }) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 14))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .help("Zoom in")
            
            Divider()
                .frame(height: 24)
            
            Button(action: {
                editorState.imageEditorState.zoomLevel = 1.0
            }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 14))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Reset zoom to fit")
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Export Sheet
struct ExportSheet: View {
    let imageURL: URL
    @ObservedObject var editorState: ScreenCaptureEditorState
    @Environment(\.dismiss) private var dismiss
    
    @State private var exportFormat: ExportFormat = .png
    @State private var exportQuality: Double = 1.0
    @State private var includeAnnotations: Bool = true
    @State private var exportLocation: ExportLocation = .sameFolder
    
    enum ExportFormat: String, CaseIterable {
        case png  = "PNG"
        case jpg  = "JPG"
        case tiff = "TIFF"
        case heic = "HEIC"
        case pdf  = "PDF"
    }
    
    enum ExportLocation: String, CaseIterable {
        case sameFolder = "Same Folder"
        case desktop = "Desktop"
        case custom = "Choose..."
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("Export Screenshot")
                .font(.title2)
                .fontWeight(.semibold)
            
            // Format Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Format")
                    .font(.headline)
                
                Picker("", selection: $exportFormat) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Quality Slider (for JPG/HEIC only)
            if exportFormat == .jpg || exportFormat == .heic {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Quality")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(exportQuality * 100))%")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $exportQuality, in: 0.1...1.0)
                }
            }
            
            // Options
            VStack(alignment: .leading, spacing: 12) {
                Text("Options")
                    .font(.headline)
                
                Toggle("Include annotations", isOn: $includeAnnotations)
            }
            
            // Export Location
            VStack(alignment: .leading, spacing: 8) {
                Text("Save to")
                    .font(.headline)
                
                Picker("", selection: $exportLocation) {
                    ForEach(ExportLocation.allCases, id: \.self) { location in
                        Text(location.rawValue).tag(location)
                    }
                }
                .pickerStyle(.radioGroup)
            }
            
            Divider()
            
            // Actions
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Export") {
                    performExport()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
    
    private func performExport() {
        guard let source = NSImage(contentsOf: imageURL) else {
            CaptureLogger.log(.debug, "Export: failed to load source image", level: .error)
            return
        }

        // Determine destination directory
        let destDir: URL
        switch exportLocation {
        case .sameFolder:
            destDir = imageURL.deletingLastPathComponent()
        case .desktop:
            destDir = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
                ?? imageURL.deletingLastPathComponent()
        case .custom:
            // Fall through to NSSavePanel
            runSavePanel(for: source)
            return
        }

        // Build destination file name
        let baseName = imageURL.deletingPathExtension().lastPathComponent + "_exported"
        let ext = exportFormat.rawValue.lowercased()
        let destURL = destDir.appendingPathComponent(baseName).appendingPathExtension(ext)

        writeImage(source, to: destURL)
    }

    private func runSavePanel(for image: NSImage) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, UTType("public.heic") ?? .png, .pdf]
        panel.nameFieldStringValue = imageURL.deletingPathExtension().lastPathComponent + "_exported"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            self.writeImage(image, to: url)
        }
    }

    private func writeImage(_ image: NSImage, to url: URL) {
        // PDF export uses PDFKit
        if exportFormat == .pdf {
            writePDF(image, to: url)
            return
        }

        // HEIC export uses ImageIO (real implementation)
        if exportFormat == .heic {
            writeHEIC(image, to: url)
            return
        }

        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            CaptureLogger.log(.save, "Export: failed to create bitmap rep", level: .error)
            return
        }

        let data: Data?
        switch exportFormat {
        case .png:  data = rep.representation(using: .png, properties: [:])
        case .jpg:  data = rep.representation(using: .jpeg, properties: [.compressionFactor: exportQuality])
        case .tiff: data = rep.representation(using: .tiff, properties: [:])
        default:    data = nil
        }

        guard let imageData = data else {
            CaptureLogger.log(.save, "Export: failed to encode as \(exportFormat.rawValue)", level: .error)
            return
        }

        writeData(imageData, to: url)
    }

    private func writeHEIC(_ image: NSImage, to url: URL) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            CaptureLogger.log(.save, "HEIC export: failed to get CGImage", level: .error)
            return
        }

        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.heic" as CFString, 1, nil) else {
            CaptureLogger.log(.save, "HEIC export: failed to create destination", level: .error)
            return
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: exportQuality
        ]
        CGImageDestinationAddImage(dest, cgImage, options as CFDictionary)

        if CGImageDestinationFinalize(dest) {
            CaptureLogger.log(.save, "Exported HEIC to \(url.lastPathComponent)", level: .success)
            ScreenCaptureManager.shared.showNotification(title: "Exported", message: "Saved as \(url.lastPathComponent)")
        } else {
            CaptureLogger.log(.save, "HEIC export: CGImageDestinationFinalize failed", level: .error)
        }
    }

    private func writePDF(_ image: NSImage, to url: URL) {
        let pdfDoc = PDFDocument()
        let page = PDFPage(image: image)
        guard let page else {
            CaptureLogger.log(.save, "PDF export: failed to create PDFPage", level: .error)
            return
        }
        pdfDoc.insert(page, at: 0)

        if pdfDoc.write(to: url) {
            CaptureLogger.log(.save, "Exported PDF to \(url.lastPathComponent)", level: .success)
            ScreenCaptureManager.shared.showNotification(title: "Exported", message: "Saved as \(url.lastPathComponent)")
        } else {
            CaptureLogger.log(.save, "PDF export: write failed", level: .error)
        }
    }

    private func writeData(_ data: Data, to url: URL) {
        do {
            try data.write(to: url, options: .atomic)
            CaptureLogger.log(.save, "Exported to \(url.lastPathComponent)", level: .success)
            ScreenCaptureManager.shared.showNotification(title: "Exported", message: "Saved as \(url.lastPathComponent)")
        } catch {
            CaptureLogger.log(.save, "Export write failed: \(error.localizedDescription)", level: .error)
        }
    }
}

// MARK: - Rename Sheet
struct RenameSheet: View {
    let imageURL: URL
    @Environment(\.dismiss) private var dismiss
    
    @State private var newName: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Rename Screenshot")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Current name:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(imageURL.lastPathComponent)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("New name:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("Enter new filename", text: $newName)
                    .textFieldStyle(.roundedBorder)
            }
            
            Divider()
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Rename") {
                    performRename()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(newName.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
        .onAppear {
            newName = imageURL.deletingPathExtension().lastPathComponent
        }
    }
    
    private func performRename() {
        let fileExtension = imageURL.pathExtension
        let newFilename = "\(newName).\(fileExtension)"
        let newURL = imageURL.deletingLastPathComponent().appendingPathComponent(newFilename)
        
        do {
            try FileManager.default.moveItem(at: imageURL, to: newURL)
            print("[RENAME] Renamed to: \(newFilename)")
            
            ScreenCaptureManager.shared.showNotification(
                title: "Renamed",
                message: "File renamed to \(newFilename)"
            )
        } catch {
            print("[RENAME] Failed: \(error)")
            
            ScreenCaptureManager.shared.showNotification(
                title: "Error",
                message: "Could not rename file"
            )
        }
    }
}
