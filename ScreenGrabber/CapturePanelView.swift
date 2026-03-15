//
//  CapturePanelView.swift
//  ScreenGrabber
//
//  Main capture panel with all capture options
//

import SwiftUI
import SwiftData
import AppKit
import ScreenCaptureKit

struct CapturePanelView: View {
    @Environment(\.modelContext) private var modelContext
    private let captureManager = UnifiedCaptureManager.shared
    @State private var selectedCaptureType: CaptureType = .area
    @State private var selectedOpenMethod: OpenMethod = .saveToFile
    @State private var isCapturing = false
    @State private var captureProgress: Double = 0.0
    @State private var captureStatus: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Screen Grabber")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Capture and edit your screen")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)
            
            Divider()
            
            // Capture Type Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Capture Type")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(CaptureType.allCases) { type in
                        CaptureTypeButton(
                            type: type,
                            isSelected: selectedCaptureType == type
                        ) {
                            selectedCaptureType = type
                        }
                    }
                }
            }
            
            Divider()
            
            // Open Method Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("After Capture")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    ForEach([OpenMethod.saveToFile, .clipboard, .editor], id: \.self) { method in
                        Button {
                            selectedOpenMethod = method
                        } label: {
                            Text(method.displayName)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    selectedOpenMethod == method ?
                                    Color.accentColor : Color(NSColor.controlBackgroundColor)
                                )
                                .foregroundColor(
                                    selectedOpenMethod == method ?
                                    .white : .primary
                                )
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Spacer()
            
            // Capture Button
            Button {
                Task {
                    await performCapture()
                }
            } label: {
                HStack {
                    if isCapturing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "camera.fill")
                    }
                    Text(isCapturing ? "Capturing..." : "Capture Now")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isCapturing)
            
            if isCapturing {
                VStack(spacing: 4) {
                    ProgressView(value: captureProgress)
                    Text(captureStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
        .frame(width: 400)
    }
    
    // MARK: - Capture Logic
    
    private func performCapture() async {
        isCapturing = true
        captureProgress = 0.0
        captureStatus = "Preparing capture..."
        
        defer {
            isCapturing = false
            captureProgress = 0.0
            captureStatus = ""
        }
        
        // Take screenshot based on type
        captureStatus = "Taking screenshot..."
        captureProgress = 0.3
        
        guard let image = await takeScreenshot(type: selectedCaptureType) else {
            captureStatus = "Failed to capture"
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            return
        }
        
        captureProgress = 0.6
        captureStatus = "Processing..."
        
        // Handle the capture based on open method
        switch selectedOpenMethod {
case .saveToFile:
            let metadata = LegacyUnifiedCaptureManager.CaptureMetadata(
                captureType: mapCaptureType(selectedCaptureType),
                timestamp: Date(),
                image: image
            )
            
            captureStatus = "Saving..."
            captureProgress = 0.8
            
            await captureManager.saveCapture(metadata, to: modelContext, copyToClipboard: false)

case .clipboard:
            captureStatus = "Copying to clipboard..."
            captureProgress = 0.9
            
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([image])

        case .editor:
            captureStatus = "Opening editor..."
            captureProgress = 0.9
            
            // Save to file first, then could open editor
            let metadata = LegacyUnifiedCaptureManager.CaptureMetadata(
                captureType: mapCaptureType(selectedCaptureType),
                timestamp: Date(),
                image: image
            )
            
            // Save the capture and open editor
            if let savedURL = await captureManager.saveCapture(metadata, to: modelContext, copyToClipboard: false) {
                // Create a Screenshot object from the saved file
                let screenshot = Screenshot(
                    filename: savedURL.lastPathComponent,
                    filePath: savedURL.path,
                    captureType: mapCaptureType(selectedCaptureType).rawValue,
                    width: Int(image.size.width),
                    height: Int(image.size.height),
                    timestamp: Date(),
                    sourceDisplay: nil,
                    sourceWindow: nil
                )
                EditorWindowHelper.shared.openEditor(for: screenshot)
            }
            captureProgress = 0.9
            
        case .preview:
            // This case exists in enum but is not used in UI
            // Handle it gracefully
            captureStatus = "Opening preview..."
            captureProgress = 0.9
            
            // Save to temporary location and open with Quick Look
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("png")
            
            if let tiffData = image.tiffRepresentation,
               let bitmapImage = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                try? pngData.write(to: tempURL)
                NSWorkspace.shared.open(tempURL)
            }
        }
        
        captureProgress = 1.0
        captureStatus = "Complete!"
    }
    
    private func takeScreenshot(type: CaptureType) async -> NSImage? {
        // Give time for UI to update
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        switch type {
        case .fullScreen:
            return captureFullScreen()
        case .area:
            return await captureArea()
        case .window:
            return await captureWindow()
        case .scrolling:
            return await captureScrolling()
        }
    }
    
    private func captureFullScreen() -> NSImage? {
        // Use ScreenCaptureKit for modern screen capture
        let semaphore = DispatchSemaphore(value: 0)
        var capturedImage: NSImage?
        
        Task {
            do {
                // Get available displays
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                
                guard let display = content.displays.first else {
                    semaphore.signal()
                    return
                }
                
                // Create content filter for the display
                let filter = SCContentFilter(display: display, excludingWindows: [])
                
                // Configure screenshot settings
                let config = SCStreamConfiguration()
                config.width = display.width
                config.height = display.height
                config.showsCursor = true
                
                // Capture the image
                let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                
                let size = NSSize(width: display.width, height: display.height)
                capturedImage = NSImage(cgImage: cgImage, size: size)
            } catch {
                print("ScreenCaptureKit capture failed: \(error)")
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        return capturedImage
    }
    
    private func captureArea() async -> NSImage? {
        // Use screencapture tool for interactive area selection
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        
        task.arguments = ["-i", "-s", tempURL.path]
        
        
        // Error handling setup
        
    return await withCheckedContinuation { continuation in
            task.terminationHandler = { _ in
                if FileManager.default.fileExists(atPath: tempURL.path),
                   let image = NSImage(contentsOf: tempURL) {
                    try? FileManager.default.removeItem(at: tempURL)
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            
            task.launch()
        }
    }
    
    private func captureWindow() async -> NSImage? {
        // Use screencapture tool for interactive window selection
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        
        task.arguments = ["-i", "-w", tempURL.path]
        
        
        // Error handling setup
        
    return await withCheckedContinuation { continuation in
            task.terminationHandler = { _ in
                if FileManager.default.fileExists(atPath: tempURL.path),
                   let image = NSImage(contentsOf: tempURL) {
                    try? FileManager.default.removeItem(at: tempURL)
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            
            task.launch()
        }
    }
    
    private func captureScrolling() async -> NSImage? {
        // Use ScrollingCaptureService for proper scrolling capture
        let result = await ScrollingCaptureService.shared.performScrollingCapture()
        
        switch result {
        case .success(let image):
            return image
        case .failure(let error):
            // Log the error and fall back to area capture
            print("Scrolling capture failed: \(error.localizedDescription)")
            return await captureArea()
        }
    }
    
    private func mapCaptureType(_ type: CaptureType) -> LegacyUnifiedCaptureManager.CaptureMetadata.CaptureType {
        switch type {
        case .fullScreen:
            return .fullScreen
        case .area:
            return .area
        case .window:
            return .window
        case .scrolling:
            return .scrolling
        }
    }
}

// MARK: - Capture Type Button

struct CaptureTypeButton: View {
    let type: CaptureType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .accentColor)
                
                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(type.description)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                isSelected ?
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ) :
                LinearGradient(
                    colors: [Color(NSColor.controlBackgroundColor)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CapturePanelView()
        .modelContainer(for: Screenshot.self, inMemory: true)
}
