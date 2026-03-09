//
//  AutoScrollCaptureWindow.swift
//  ScreenGrabber
//
//  Created on 11/13/25.
//

import SwiftUI
import AppKit
import ScreenCaptureKit
import Combine

/// Modern, user-friendly scrolling capture interface
struct AutoScrollCaptureWindow: View {
    @StateObject private var captureController = AutoScrollCaptureController()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                // Icon and Title
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.2), Color.blue.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "scroll.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Automatic Scrolling Capture")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Capture long content automatically")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Main Content
            ScrollView {
                VStack(spacing: 24) {
                    // Status Section
                    StatusCard(captureController: captureController)
                    
                    // Instructions Section
                    InstructionsCard(captureController: captureController)
                    
                    // Settings Section
                    SettingsCard(captureController: captureController)
                    
                    // Preview Section (if frames captured)
                    if !captureController.capturedFrames.isEmpty {
                        PreviewCard(captureController: captureController)
                    }
                }
                .padding(20)
            }
            
            Divider()
            
            // Action Bar
            HStack(spacing: 12) {
                // Cancel Button - CRITICAL FIX: Always functional
                Button(action: { 
                    // Stop any ongoing capture
                    if captureController.state == .capturing {
                        captureController.stopCapture()
                    }
                    dismiss() 
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Cancel")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
                .help("Cancel scrolling capture (Escape)")
                
                Spacer()
                
                // Action Buttons (context-aware)
                if captureController.state == .idle {
                    StartCaptureButton(captureController: captureController)
                } else if captureController.state == .capturing {
                    StopCaptureButton(captureController: captureController)
                } else if captureController.state == .completed {
                    HStack(spacing: 12) {
                        Button(action: captureController.restart) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Start Over")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: captureController.saveAndFinish) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Save & Finish")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [Color.green, Color.green.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(10)
                            .shadow(color: Color.green.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.return)
                    }
                }
            }
            .padding(20)
            .background(
                VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
            )
        }
        .frame(width: 600, height: 700)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Status Card
struct StatusCard: View {
    @ObservedObject var captureController: AutoScrollCaptureController
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Label("Status", systemImage: "info.circle")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Status Indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(captureController.state.color)
                        .frame(width: 10, height: 10)
                    
                    Text(captureController.state.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(captureController.state.color)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(captureController.state.color.opacity(0.15))
                .cornerRadius(20)
            }
            
            Divider()
            
            // Progress Info
            HStack(spacing: 20) {
                StatItem(
                    icon: "photo.stack",
                    label: "Frames",
                    value: "\(captureController.capturedFrames.count)",
                    color: .blue
                )
                
                StatItem(
                    icon: "arrow.down.circle",
                    label: "Scrolls",
                    value: "\(captureController.scrollCount)",
                    color: .purple
                )
                
                StatItem(
                    icon: "timer",
                    label: "Duration",
                    value: captureController.durationString,
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }
}

struct StatItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Instructions Card
struct InstructionsCard: View {
    @ObservedObject var captureController: AutoScrollCaptureController
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("How It Works", systemImage: "lightbulb.fill")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                InstructionStep(
                    number: 1,
                    title: "Select Area",
                    description: "Click Start and select the window or area you want to capture",
                    icon: "rectangle.dashed",
                    isActive: captureController.state == .idle
                )
                
                InstructionStep(
                    number: 2,
                    title: "Auto Scroll & Capture",
                    description: "The app will automatically scroll and capture frames for you",
                    icon: "arrow.down.circle.fill",
                    isActive: captureController.state == .capturing
                )
                
                InstructionStep(
                    number: 3,
                    title: "Auto Stitch",
                    description: "All frames are automatically stitched into one long image",
                    icon: "wand.and.stars",
                    isActive: captureController.state == .processing
                )
                
                InstructionStep(
                    number: 4,
                    title: "Save & Done",
                    description: "Review and save your final scrolling capture",
                    icon: "checkmark.circle.fill",
                    isActive: captureController.state == .completed
                )
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }
}

struct InstructionStep: View {
    let number: Int
    let title: String
    let description: String
    let icon: String
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Step Number Badge
            ZStack {
                Circle()
                    .fill(isActive ? Color.accentColor : Color.secondary.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Text("\(number)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isActive ? .white : .secondary)
            }
            
            // Icon
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(isActive ? .accentColor : .secondary)
                .frame(width: 30)
            
            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(isActive ? .primary : .secondary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Active Indicator
            if isActive {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
            }
        }
        .padding(12)
        .background(isActive ? Color.accentColor.opacity(0.08) : Color.clear)
        .cornerRadius(10)
    }
}

// MARK: - Settings Card
struct SettingsCard: View {
    @ObservedObject var captureController: AutoScrollCaptureController
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Settings", systemImage: "gearshape.fill")
                .font(.headline)
                .fontWeight(.bold)
            
            Divider()
            
            VStack(spacing: 12) {
                SettingRow(
                    icon: "arrow.down.to.line",
                    title: "Scroll Distance",
                    description: "Pixels to scroll between captures"
                ) {
                    Slider(value: $captureController.scrollDistance, in: 100...1000, step: 50)
                        .frame(width: 200)
                    Text("\(Int(captureController.scrollDistance))px")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .trailing)
                }
                
                SettingRow(
                    icon: "timer",
                    title: "Scroll Delay",
                    description: "Wait time between scrolls"
                ) {
                    Slider(value: $captureController.scrollDelay, in: 0.5...3.0, step: 0.5)
                        .frame(width: 200)
                    Text(String(format: "%.1fs", captureController.scrollDelay))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .trailing)
                }
                
                SettingRow(
                    icon: "photo.stack.fill",
                    title: "Max Frames",
                    description: "Maximum captures before auto-stop"
                ) {
                    Stepper(value: $captureController.maxFrames, in: 5...50, step: 5) {
                        Text("\(captureController.maxFrames)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .frame(width: 60)
                    }
                    .frame(width: 200)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .disabled(captureController.state != .idle)
        .opacity(captureController.state != .idle ? 0.6 : 1.0)
    }
}

struct SettingRow<Content: View>: View {
    let icon: String
    let title: String
    let description: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            content()
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
}

// MARK: - Preview Card
struct PreviewCard: View {
    @ObservedObject var captureController: AutoScrollCaptureController
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Preview", systemImage: "eye.fill")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("\(captureController.capturedFrames.count) frames")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(captureController.capturedFrames.enumerated()), id: \.offset) { index, frame in
                        VStack(spacing: 6) {
                            if let nsImage = NSImage(data: frame) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 140)
                                    .clipped()
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            
                            Text("Frame \(index + 1)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
            .frame(height: 170)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }
}

// MARK: - Action Buttons
struct StartCaptureButton: View {
    @ObservedObject var captureController: AutoScrollCaptureController
    
    var body: some View {
        Button(action: { captureController.startCapture() }) {
            HStack(spacing: 10) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text("Start Automatic Capture")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    
                    LinearGradient(
                        colors: [Color.white.opacity(0.2), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                }
            )
            .cornerRadius(12)
            .shadow(color: Color.blue.opacity(0.5), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.return)
    }
}

struct StopCaptureButton: View {
    @ObservedObject var captureController: AutoScrollCaptureController
    
    var body: some View {
        Button(action: { captureController.stopCapture() }) {
            HStack(spacing: 10) {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text("Stop Capture")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color.red, Color.orange],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: Color.red.opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.space)
    }
}

// MARK: - Controller
@MainActor
class AutoScrollCaptureController: ObservableObject {
    enum CaptureState {
        case idle, capturing, processing, completed, error
        
        var displayName: String {
            switch self {
            case .idle: return "Ready"
            case .capturing: return "Capturing..."
            case .processing: return "Processing..."
            case .completed: return "Complete"
            case .error: return "Error"
            }
        }
        
        var color: Color {
            switch self {
            case .idle: return .secondary
            case .capturing: return .blue
            case .processing: return .orange
            case .completed: return .green
            case .error: return .red
            }
        }
    }
    
    @Published var state: CaptureState = .idle
    @Published var capturedFrames: [Data] = []
    @Published var scrollCount: Int = 0
    @Published var scrollDistance: Double = 500
    @Published var scrollDelay: Double = 1.0
    @Published var maxFrames: Int = 20
    @Published var startTime: Date?
    
    var durationString: String {
        guard let startTime = startTime else { return "0s" }
        let duration = Date().timeIntervalSince(startTime)
        return String(format: "%.0fs", duration)
    }
    
    func startCapture() {
        state = .capturing
        startTime = Date()
        scrollCount = 0
        capturedFrames = []
        
        print("[AUTO-SCROLL] Starting automatic capture with window picker...")
        
        Task {
            do {
                if let selectedWindow = try await ScreenCaptureManager.shared.selectWindow() {
                    print("[AUTO-SCROLL] ✅ Window selected: \(selectedWindow.displayTitle)")
                    
                    // Start the actual scrolling capture
                    await self.performScrollCapture(window: selectedWindow)
                } else {
                    state = .idle
                }
            } catch {
                state = .error
            }
        }
    }
    
    /// Perform the actual scrolling capture on the selected window
    private func performScrollCapture(window: SelectableWindow) async {
        print("[AUTO-SCROLL] 📸 Starting scroll capture for: \(window.displayTitle)")
        
        // Simulate scrolling capture (replace with actual ScreenCaptureKit implementation)
        for step in 1...min(maxFrames, 10) {
            // Simulate frame capture
            if let mockFrame = createMockFrame() {
                capturedFrames.append(mockFrame)
                scrollCount = step
            }
            
            // Wait for scroll delay
            try? await Task.sleep(nanoseconds: UInt64(scrollDelay * 1_000_000_000))
        }
        
        // Move to processing
        state = .processing
        
        // Simulate stitching
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        state = .completed
    }
    
    /// Mock frame generation for testing (replace with actual capture)
    private func createMockFrame() -> Data? {
        let size = CGSize(width: 800, height: 600)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemBlue.withAlphaComponent(0.3).setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        return pngData
    }
    
    func stopCapture() {
        state = .processing
        
        // Simulate processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.state = .completed
        }
    }
    
    func restart() {
        state = .idle
        capturedFrames = []
        scrollCount = 0
        startTime = nil
    }
    
    func saveAndFinish() {
        // TODO: Implement save logic
        print("[AUTO-SCROLL] Saving capture...")
    }
}

#Preview {
    AutoScrollCaptureWindow()
}
