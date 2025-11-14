//
//  AutomatedScrollingCapture.swift
//  ScreenGrabber
//
//  Created for automated scrolling capture feature
//

import Foundation
import AppKit
import SwiftUI
import Combine
import ScreenCaptureKit

// MARK: - Capture Status

enum ScrollingCaptureStatus: Equatable {
    case idle
    case initializing
    case capturing
    case capturingFrame(Int)
    case stitching
    case saving
    case complete(URL)
    case cancelled
    case error(String)
    
    var displayMessage: String {
        switch self {
        case .idle: return "Ready"
        case .initializing: return "Setting up..."
        case .capturing: return "Capturing..."
        case .capturingFrame(let num): return "Capturing frame \(num)"
        case .stitching: return "Stitching images..."
        case .saving: return "Saving..."
        case .complete: return "Complete!"
        case .cancelled: return "Cancelled"
        case .error(let msg): return "Error: \(msg)"
        }
    }
    
    var isActive: Bool {
        switch self {
        case .idle, .complete, .cancelled, .error:
            return false
        default:
            return true
        }
    }
}

// MARK: - Main Coordinator

@MainActor
class AutomatedScrollingCapture: ObservableObject {
    @Published var status: ScrollingCaptureStatus = .idle
    @Published var progress: Double = 0
    @Published var framesCaptured: Int = 0
    @Published var latestFrame: NSImage?
    
    private var capturedFrames: [NSImage] = []
    private var isCapturing = false
    var finalImage: NSImage?
    
    // Settings
    var scrollSpeed: TimeInterval = 0.5
    var overlapPercentage: CGFloat = 0.2
    var maxFrames: Int = 50
    
    // MARK: - Main Capture Function
    
    func startAutomatedCapture(rect: CGRect) async throws {
        guard !isCapturing else { return }
        isCapturing = true
        capturedFrames = []
        framesCaptured = 0
        progress = 0
        
        status = .initializing
        
        // Capture first frame
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        
        guard let firstFrame = captureFrame(at: rect) else {
            throw CaptureError.failedToCapture
        }
        
        capturedFrames.append(firstFrame)
        latestFrame = firstFrame
        framesCaptured = 1
        
        status = .capturing
        
        // Calculate scroll distance (80% of height to get 20% overlap)
        let scrollDistance = rect.height * (1.0 - overlapPercentage)
        
        // Capture loop - simulate scrolling (actual scroll would use Accessibility API)
        for frameNum in 2...maxFrames where isCapturing {
            status = .capturingFrame(frameNum)
            
            // Simulate scroll delay
            try await Task.sleep(nanoseconds: UInt64(scrollSpeed * 1_000_000_000))
            
            // In real implementation, we would:
            // 1. Post scroll event to target window
            // 2. Wait for content to stabilize
            // 3. Check if we've reached the end
            
            // For now, we'll simulate by capturing slightly offset regions
            var adjustedRect = rect
            adjustedRect.origin.y += CGFloat(frameNum - 1) * scrollDistance
            
            guard let frame = captureFrame(at: adjustedRect) else {
                // Probably reached end of content
                break
            }
            
            // Check if frame is significantly different from last
            // (simple check - in production use image comparison)
            if !isFrameDifferent(frame, from: capturedFrames.last!) {
                // Reached end of content
                break
            }
            
            capturedFrames.append(frame)
            latestFrame = frame
            framesCaptured = frameNum
            progress = Double(frameNum) / Double(maxFrames)
            
            // Stop if we have too many frames
            if frameNum >= maxFrames {
                break
            }
        }
        
        guard isCapturing else {
            status = .cancelled
            return
        }
        
        // Stitch frames
        status = .stitching
        progress = 0.9
        
        let stitcher = ImageStitcher()
        finalImage = try await stitcher.stitchFrames(capturedFrames, overlap: overlapPercentage)
        
        progress = 1.0
        status = .complete(URL(fileURLWithPath: "/tmp/scrolling_capture.png"))
    }
    
    func stopCapture() {
        isCapturing = false
        status = .cancelled
    }
    
    // MARK: - Helper Methods
    
    private func captureFrame(at rect: CGRect) -> NSImage? {
        // Use ScreenCaptureKit to capture screen region
        var capturedImage: NSImage?
        let semaphore = DispatchSemaphore(value: 0)
        
        Task {
            do {
                // Get available screens
                let content = try await SCShareableContent.excludingDesktopWindows(
                    false,
                    onScreenWindowsOnly: true
                )
                
                guard let display = content.displays.first else {
                    print("[ERROR] No displays available for capture")
                    semaphore.signal()
                    return
                }
                
                // Create content filter for the display
                let filter = SCContentFilter(display: display, excludingWindows: [])
                
                // Configure capture with the specified rect
                let config = SCStreamConfiguration()
                config.sourceRect = rect
                config.width = Int(rect.width)
                config.height = Int(rect.height)
                config.scalesToFit = false
                config.captureResolution = .best
                
                // Capture the screenshot
                let image = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: config
                )
                
                // Convert CGImage to NSImage
                capturedImage = NSImage(cgImage: image, size: rect.size)
                
            } catch {
                print("[ERROR] Failed to capture frame: \(error)")
            }
            
            semaphore.signal()
        }
        
        // Wait for capture to complete (with timeout)
        _ = semaphore.wait(timeout: .now() + 5.0)
        
        return capturedImage
    }
    
    private func isFrameDifferent(_ frame1: NSImage, from frame2: NSImage) -> Bool {
        // Simple comparison - in production, use perceptual hash or correlation
        guard let data1 = frame1.tiffRepresentation,
              let data2 = frame2.tiffRepresentation else {
            return false
        }
        
        // If sizes are different, definitely different
        if data1.count != data2.count {
            return true
        }
        
        // Check if images are identical (extremely unlikely for scrolled content)
        return data1 != data2
    }
}

// MARK: - Image Stitcher

actor ImageStitcher {
    func stitchFrames(_ frames: [NSImage], overlap: CGFloat) async throws -> NSImage {
        guard !frames.isEmpty else {
            throw CaptureError.noFramesToStitch
        }
        
        guard frames.count > 1 else {
            return frames[0]
        }
        
        // Calculate total height
        let frameHeight = frames[0].size.height
        let overlapHeight = frameHeight * overlap
        let totalHeight = frameHeight + (frameHeight - overlapHeight) * CGFloat(frames.count - 1)
        let width = frames[0].size.width
        
        let finalSize = CGSize(width: width, height: totalHeight)
        let stitchedImage = NSImage(size: finalSize)
        
        stitchedImage.lockFocus()
        
        // Draw first frame at top
        frames[0].draw(
            at: CGPoint(x: 0, y: totalHeight - frameHeight),
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0
        )
        
        // Draw subsequent frames with overlap
        var currentY = totalHeight - frameHeight
        
        for i in 1..<frames.count {
            currentY -= (frameHeight - overlapHeight)
            
            // Simple blend - draw with slight transparency in overlap region
            let frame = frames[i]
            
            // Draw the non-overlapping part fully opaque
            let nonOverlapRect = CGRect(
                x: 0,
                y: overlapHeight,
                width: frame.size.width,
                height: frame.size.height - overlapHeight
            )
            
            frame.draw(
                at: CGPoint(x: 0, y: currentY + overlapHeight),
                from: nonOverlapRect,
                operation: .sourceOver,
                fraction: 1.0
            )
            
            // Draw the overlapping part with reduced opacity for smooth blend
            let overlapRect = CGRect(
                x: 0,
                y: 0,
                width: frame.size.width,
                height: overlapHeight
            )
            
            frame.draw(
                at: CGPoint(x: 0, y: currentY),
                from: overlapRect,
                operation: .sourceOver,
                fraction: 0.5 // Blend with 50% opacity
            )
        }
        
        stitchedImage.unlockFocus()
        
        return stitchedImage
    }
}

// MARK: - Errors

enum CaptureError: LocalizedError {
    case failedToCapture
    case noFramesToStitch
    case stitchingFailed
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .failedToCapture:
            return "Failed to capture screenshot"
        case .noFramesToStitch:
            return "No frames available to stitch"
        case .stitchingFailed:
            return "Failed to stitch frames together"
        case .saveFailed:
            return "Failed to save final image"
        }
    }
}

// MARK: - Progress HUD View

struct ScrollingCaptureHUD: View {
    @ObservedObject var capture: AutomatedScrollingCapture
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            // Title with icon
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "scroll.fill")
                        .font(.title3)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.accentColor, .accentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                Text("Scrolling Capture")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            // Status message
            Text(capture.status.displayMessage)
                .font(.headline)
                .foregroundColor(.secondary)
            
            // Progress section
            VStack(spacing: 12) {
                // Progress bar
                ProgressView(value: capture.progress)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
                
                // Stats
                HStack {
                    Label("\(capture.framesCaptured) frames", systemImage: "photo.stack")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(capture.progress * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                }
            }
            
            // Latest frame thumbnail
            if let frame = capture.latestFrame {
                VStack(spacing: 8) {
                    Text("Latest Frame")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Image(nsImage: frame)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 80)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                }
            }
            
            // Control buttons
            HStack(spacing: 12) {
                if capture.status.isActive {
                    Button(action: {
                        capture.stopCapture()
                    }) {
                        Label("Cancel", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .keyboardShortcut(.cancelAction)
                    .controlSize(.large)
                } else {
                    Button(action: {
                        dismiss()
                    }) {
                        Label("Close", systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(width: 340)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.1))
        )
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Instructions View

struct ScrollingCaptureInstructions: View {
    let onStart: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "scroll.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accentColor, .accentColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            // Title and subtitle
            VStack(spacing: 8) {
                Text("Automated Scrolling Capture")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Let us handle the scrolling for you!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Instructions
            VStack(alignment: .leading, spacing: 16) {
                InstructionRow(
                    number: 1,
                    title: "Select Area",
                    description: "Draw a rectangle around the scrollable content"
                )
                
                InstructionRow(
                    number: 2,
                    title: "Sit Back & Relax",
                    description: "We'll automatically scroll and capture everything"
                )
                
                InstructionRow(
                    number: 3,
                    title: "Done!",
                    description: "Review your perfectly stitched long screenshot"
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            
            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Start Capture") {
                    onStart()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(32)
        .frame(width: 480)
        .background(.regularMaterial)
        .cornerRadius(16)
        .shadow(radius: 20)
    }
}

struct InstructionRow: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Number badge
            Text("\(number)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.accentColor, .accentColor.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview("HUD") {
    ScrollingCaptureHUD(capture: {
        let capture = AutomatedScrollingCapture()
        capture.status = .capturingFrame(5)
        capture.progress = 0.45
        capture.framesCaptured = 5
        return capture
    }())
}

#Preview("Instructions") {
    ScrollingCaptureInstructions(
        onStart: {},
        onCancel: {}
    )
}
