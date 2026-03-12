//
//  ImageEditorView.swift
//  ScreenGrabber
//
//  Simplified image viewer
//  Created by Victor Lam on 10/23/25.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ImageEditorView: View {
    let imageURL: URL
    @State private var originalImage: NSImage?
    @State private var showingExportDialog = false
    @State private var isImageLoaded = false
    @State private var zoomLevel: CGFloat = 1.0
    @State private var loadError: Error?
    @State private var showingScrollSelection = false
    @State private var selectedScrollRect: CGRect? = nil
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()
            
            if let error = loadError {
                // Error state
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    
                    Text("Failed to Load Image")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Text(error.localizedDescription)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
            } else if isImageLoaded {
                VStack(spacing: 0) {
                    // Modern Top Toolbar
                    modernTopToolbar
                    
                    Divider()
                    
                    // Main Content Area
                    modernCanvasArea
                }
            } else {
                // Loading state
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading Image Viewer...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .overlay(
            Group {
                if showingScrollSelection {
                    ScrollSelectionOverlay(isPresented: $showingScrollSelection, selectedRect: $selectedScrollRect) { rect in
                        Task {
                            // Create the scrolling capture engine
                            let engine = ScrollingCaptureEngine()
                            
                            // Create a scrollable region from the selected rect
                            let region = ScrollingCaptureEngine.ScrollableRegion(
                                windowNumber: 0, // Window detection will be handled by the engine
                                frame: rect,
                                scrollDirection: .vertical,
                                axElement: nil
                            )
                            
                            do {
                                let image = try await engine.captureRegion(region, direction: .vertical)
                                await MainActor.run {
                                    self.originalImage = image
                                    self.isImageLoaded = true
                                }
                            } catch {
                                await MainActor.run {
                                    self.loadError = error
                                    self.isImageLoaded = true
                                }
                            }
                        }
                    }
                }
            }
        )
        .frame(minWidth: 800, idealWidth: 1000, maxWidth: .infinity, 
               minHeight: 600, idealHeight: 800, maxHeight: .infinity)
        .task {
            await loadImageAsync()
        }
        .sheet(isPresented: $showingExportDialog) {
            ExportDialog(imageURL: imageURL)
        }
    }
    
    // MARK: - Modern Top Toolbar
    private var modernTopToolbar: some View {
        HStack(spacing: 20) {
            // Left: File Info & Close
            HStack(spacing: 16) {
                // Close Button
                Button(action: { dismiss() }) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.12))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.red)
                    }
                }
                .buttonStyle(.plain)
                .keyboardShortcut("w", modifiers: .command)
                .help("Close (⌘W)")
                
                Divider()
                    .frame(height: 32)
                
                // File Info
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.blue.opacity(0.15), .purple.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: "photo.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Image Viewer")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 6) {
                            Text(imageURL.lastPathComponent)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            
                            if let image = originalImage {
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text("\(Int(image.size.width)) × \(Int(image.size.height))")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            // Center: Zoom Controls
            HStack(spacing: 10) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        zoomLevel = max(0.25, zoomLevel - 0.25)
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(
                            zoomLevel > 0.25 ? Color.blue : Color.secondary
                        )
                }
                .buttonStyle(.plain)
                .disabled(zoomLevel <= 0.25)
                .help("Zoom Out")
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        zoomLevel = 1.0
                    }
                }) {
                    Text("\(Int(zoomLevel * 100))%")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: 65)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.blue.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
                .help("Reset Zoom (100%)")
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        zoomLevel = min(4.0, zoomLevel + 0.25)
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(
                            zoomLevel < 4.0 ? Color.blue : Color.secondary
                        )
                }
                .buttonStyle(.plain)
                .disabled(zoomLevel >= 4.0)
                .help("Zoom In")
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            
            Spacer()
            
            // Right: Scrolling Capture Action
            Button(action: {
                showingScrollSelection = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "camera.metering.center.weighted")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Scrolling Capture")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(colors: [Color.green, Color.green.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .cornerRadius(10)
                .shadow(color: Color.green.opacity(0.25), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(ScaleButtonStyle())
            .help("Select area and auto-scroll capture")
            
            // Right: Export Action
            Button(action: {
                showingExportDialog = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Export")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(10)
                .shadow(color: Color.blue.opacity(0.3), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(ScaleButtonStyle())
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .help("Export (⌘⇧E)")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [
                    Color(NSColor.controlBackgroundColor),
                    Color(NSColor.controlBackgroundColor).opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Canvas Area
    private var modernCanvasArea: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                ZStack {
                    // Checkered background pattern
                    Canvas { context, size in
                        let squareSize: CGFloat = 20
                        let cols = Int(ceil(size.width / squareSize))
                        let rows = Int(ceil(size.height / squareSize))
                        
                        for row in 0..<rows {
                            for col in 0..<cols {
                                if (row + col) % 2 == 0 {
                                    let rect = CGRect(
                                        x: CGFloat(col) * squareSize,
                                        y: CGFloat(row) * squareSize,
                                        width: squareSize,
                                        height: squareSize
                                    )
                                    context.fill(Path(rect), with: .color(.gray.opacity(0.1)))
                                }
                            }
                        }
                    }
                    .frame(
                        width: (originalImage?.size.width ?? 800) * zoomLevel,
                        height: (originalImage?.size.height ?? 600) * zoomLevel
                    )
                    
                    // Display image
                    if let image = originalImage {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(
                                width: image.size.width * zoomLevel,
                                height: image.size.height * zoomLevel
                            )
                    }
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func loadImageAsync() async {
        // Ensure URL is accessible and start accessing security-scoped resource if needed
        let shouldStopAccessing = imageURL.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                imageURL.stopAccessingSecurityScopedResource()
            }
        }
        
        // Verify the file exists
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            await MainActor.run {
                loadError = NSError(domain: "ImageEditorView", code: 404, userInfo: [
                    NSLocalizedDescriptionKey: "Image file not found at path: \(imageURL.path)"
                ])
                isImageLoaded = true
            }
            return
        }
        
        // Load image on background thread to avoid blocking UI
        let image = await Task.detached(priority: .userInitiated) { [imageURL] in
            NSImage(contentsOf: imageURL)
        }.value
        
        await MainActor.run {
            if let image = image {
                originalImage = image
                loadError = nil
            } else {
                loadError = NSError(domain: "ImageEditorView", code: 500, userInfo: [
                    NSLocalizedDescriptionKey: "Unable to load image from file"
                ])
            }
            isImageLoaded = true
        }
    }
}

// MARK: - Export Dialog
struct ExportDialog: View {
    let imageURL: URL
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat: ImageFormat = .png
    @State private var jpegQuality: Double = 0.8
    @State private var exportSize: ExportSize = .original
    
    enum ImageFormat: String, CaseIterable {
        case png = "png"
        case jpeg = "jpeg"
        case tiff = "tiff"
        case gif = "gif"
        
        var displayName: String {
            switch self {
            case .png: return "PNG"
            case .jpeg: return "JPEG"
            case .tiff: return "TIFF"
            case .gif: return "GIF"
            }
        }
        
        var icon: String {
            switch self {
            case .png: return "photo"
            case .jpeg: return "photo.fill"
            case .tiff: return "doc.text.image"
            case .gif: return "photo.stack"
            }
        }
    }
    
    enum ExportSize: String, CaseIterable {
        case original = "original"
        case half = "half"
        case double = "double"
        case custom = "custom"
        
        var displayName: String {
            switch self {
            case .original: return "Original"
            case .half: return "50%"
            case .double: return "200%"
            case .custom: return "Custom"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Export Image")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Choose format and size options")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(24)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Format Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Label("File Format", systemImage: "doc.badge.gearshape")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                            ForEach(ImageFormat.allCases, id: \.self) { format in
                                Button(action: { selectedFormat = format }) {
                                    VStack(spacing: 8) {
                                        Image(systemName: format.icon)
                                            .font(.system(size: 24, weight: .medium))
                                            .foregroundStyle(
                                                selectedFormat == format ? Color.accentColor : .secondary
                                            )
                                        
                                        Text(format.displayName)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(
                                                selectedFormat == format ? Color.accentColor : .primary
                                            )
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(
                                                selectedFormat == format 
                                                    ? Color.accentColor.opacity(0.12) 
                                                    : Color.clear
                                            )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(
                                                selectedFormat == format 
                                                    ? Color.accentColor 
                                                    : Color.secondary.opacity(0.3),
                                                lineWidth: selectedFormat == format ? 2 : 1
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        // JPEG Quality Slider
                        if selectedFormat == .jpeg {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                    
                                    Text("Quality: \(Int(jpegQuality * 100))%")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                
                                Slider(value: $jpegQuality, in: 0.1...1.0)
                                    .tint(Color.accentColor)
                                
                                HStack {
                                    Text("Smaller")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("Better")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.accentColor.opacity(0.05))
                            )
                        }
                    }
                    
                    // Size Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Export Size", systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                            ForEach(ExportSize.allCases, id: \.self) { size in
                                Button(action: { exportSize = size }) {
                                    VStack(spacing: 6) {
                                        Text(size.displayName)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(
                                                exportSize == size ? Color.accentColor : .primary
                                            )
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(
                                                exportSize == size 
                                                    ? Color.accentColor.opacity(0.12) 
                                                    : Color.clear
                                            )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(
                                                exportSize == size 
                                                    ? Color.accentColor 
                                                    : Color.secondary.opacity(0.3),
                                                lineWidth: exportSize == size ? 2 : 1
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(24)
            }
            
            Divider()
            
            // Footer Actions
            HStack(spacing: 12) {
                Button(action: {
                    dismiss()
                }) {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.secondary.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                
                Button(action: { 
                    exportImage()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Export")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(10)
                    .shadow(color: Color.blue.opacity(0.3), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(ScaleButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        }
        .frame(minWidth: 1200, idealWidth: 1400, maxWidth: .infinity, 
               minHeight: 800, idealHeight: 900, maxHeight: .infinity)
    }
    
    private func exportImage() {
        let savePanel = NSSavePanel()
        
        // Set allowed file types based on selected format
        switch selectedFormat {
        case .png:
            savePanel.allowedContentTypes = [UTType.png]
        case .jpeg:
            savePanel.allowedContentTypes = [UTType.jpeg]
        case .tiff:
            savePanel.allowedContentTypes = [UTType.tiff]
        case .gif:
            savePanel.allowedContentTypes = [UTType.gif]
        }
        
        savePanel.nameFieldStringValue = imageURL.deletingPathExtension().lastPathComponent + "_exported"
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        
        savePanel.begin { [self] response in
            if response == .OK, let url = savePanel.url {
                // Perform export
                guard let originalImage = NSImage(contentsOf: self.imageURL) else { return }
                
                // Convert and save based on format
                if let tiffData = originalImage.tiffRepresentation,
                   let bitmapRep = NSBitmapImageRep(data: tiffData) {
                    
                    var imageData: Data?
                    
                    switch self.selectedFormat {
                    case .png:
                        imageData = bitmapRep.representation(using: .png, properties: [:])
                    case .jpeg:
                        imageData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: NSNumber(value: self.jpegQuality)])
                    case .tiff:
                        imageData = bitmapRep.representation(using: .tiff, properties: [:])
                    case .gif:
                        imageData = bitmapRep.representation(using: .gif, properties: [:])
                    }
                    
                    if let data = imageData {
                        do {
                            try data.write(to: url)
                            CaptureLogger.log(.save, "Exported to \(url.lastPathComponent)", level: .success)
                            
                            // Show success notification
                            DispatchQueue.main.async {
                                self.dismiss()
                            }
                        } catch {
                            CaptureLogger.log(.save, "Export failed: \(error.localizedDescription)", level: .error)
                        }
                    }
                }
            }
        }
    }
}
