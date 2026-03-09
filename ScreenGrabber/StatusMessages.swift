//
//  StatusMessages.swift
//  ScreenGrabber
//
//  Created on 01/17/26.
//  Clear, actionable status messages for better UX
//

import SwiftUI

// MARK: - Status Message Model

@MainActor
@Observable
final class StatusManager {
    static let shared = StatusManager()
    
    var currentStatus: StatusMessage?
    
    // MARK: - Status Message Type
    
    struct StatusMessage: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let icon: String
        let color: Color
        let isProgress: Bool
        
        static func == (lhs: StatusMessage, rhs: StatusMessage) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    // MARK: - Show Status
    
    func showStatus(_ message: StatusMessage) {
        currentStatus = message
    }
    
    func showStatus(text: String, icon: String = "info.circle", color: Color = .secondary, isProgress: Bool = false) {
        currentStatus = StatusMessage(text: text, icon: icon, color: color, isProgress: isProgress)
    }
    
    func clearStatus() {
        currentStatus = nil
    }
    
    // MARK: - Predefined Status Messages
    
    // Capture States
    func showReadyToCapture() {
        showStatus(text: "Ready to capture", icon: "camera", color: .blue)
    }
    
    func showSelectingArea() {
        showStatus(text: "Drag to select an area", icon: "arrow.up.left.and.arrow.down.right", color: .blue)
    }
    
    func showSelectingWindow() {
        showStatus(text: "Click a window to capture", icon: "macwindow", color: .blue)
    }
    
    func showWaitingForWindowSelection() {
        showStatus(text: "Waiting for window selection…", icon: "macwindow", color: .blue, isProgress: true)
    }
    
    func showCapturing() {
        showStatus(text: "Capturing…", icon: "camera.fill", color: .blue, isProgress: true)
    }
    
    func showCaptureComplete() {
        showStatus(text: "Capture complete", icon: "checkmark.circle.fill", color: .green)
    }
    
    func showCaptureCancelled() {
        showStatus(text: "Capture cancelled", icon: "xmark.circle", color: .secondary)
    }
    
    // Scrolling Capture
    func showScrollingCaptureStarting() {
        showStatus(text: "Starting scrolling capture…", icon: "arrow.down.doc", color: .purple, isProgress: true)
    }
    
    func showScrollingCaptureInProgress(progress: Int, total: Int) {
        showStatus(text: "Capturing page \(progress) of \(total)…", icon: "arrow.down.doc.fill", color: .purple, isProgress: true)
    }
    
    func showScrollingCaptureProcessing() {
        showStatus(text: "Processing captured content…", icon: "gearshape.2.fill", color: .purple, isProgress: true)
    }
    
    func showScrollingCaptureComplete() {
        showStatus(text: "Scrolling capture complete", icon: "checkmark.circle.fill", color: .green)
    }
    
    // Recording
    func showRecordingStarting() {
        showStatus(text: "Starting recording…", icon: "record.circle", color: .red, isProgress: true)
    }
    
    func showRecording(duration: String) {
        showStatus(text: "Recording: \(duration)", icon: "record.circle.fill", color: .red)
    }
    
    func showRecordingStopping() {
        showStatus(text: "Stopping recording…", icon: "stop.circle", color: .red, isProgress: true)
    }
    
    func showRecordingProcessing() {
        showStatus(text: "Processing recording…", icon: "gearshape.2.fill", color: .orange, isProgress: true)
    }
    
    // Saving
    func showSaving() {
        showStatus(text: "Saving…", icon: "arrow.down.doc", color: .blue, isProgress: true)
    }
    
    func showSaveComplete(filename: String) {
        showStatus(text: "Saved: \(filename)", icon: "checkmark.circle.fill", color: .green)
    }
    
    func showSaveError() {
        showStatus(text: "Unable to save file", icon: "exclamationmark.triangle", color: .red)
    }
    
    // Copying
    func showCopying() {
        showStatus(text: "Copying to clipboard…", icon: "doc.on.clipboard", color: .blue, isProgress: true)
    }
    
    func showCopyComplete() {
        showStatus(text: "Copied to clipboard", icon: "checkmark.circle.fill", color: .green)
    }
    
    // Exporting
    func showExporting() {
        showStatus(text: "Exporting…", icon: "square.and.arrow.up", color: .blue, isProgress: true)
    }
    
    func showExportComplete() {
        showStatus(text: "Export complete", icon: "checkmark.circle.fill", color: .green)
    }
    
    // Editing
    func showProcessingImage() {
        showStatus(text: "Processing image…", icon: "wand.and.stars", color: .purple, isProgress: true)
    }
    
    func showApplyingAnnotations() {
        showStatus(text: "Applying annotations…", icon: "paintbrush.fill", color: .orange, isProgress: true)
    }
    
    // Errors
    func showPermissionError(permission: String) {
        showStatus(text: "\(permission) permission required", icon: "lock.shield", color: .red)
    }
    
    func showError(message: String) {
        showStatus(text: message, icon: "exclamationmark.triangle", color: .red)
    }
    
    // Tips
    func showTip(message: String) {
        showStatus(text: "Tip: \(message)", icon: "lightbulb", color: .yellow)
    }
}

// MARK: - Status Bar View

/// A status bar that displays current status messages
struct StatusBarView: View {
    @State private var manager = StatusManager.shared
    
    var body: some View {
        Group {
            if let status = manager.currentStatus {
                HStack(spacing: 8) {
                    // Icon
                    if status.isProgress {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: status.icon)
                            .foregroundStyle(status.color)
                    }
                    
                    // Text
                    Text(status.text)
                        .font(.caption)
                        .foregroundStyle(status.color)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: manager.currentStatus)
    }
}

// MARK: - Floating Status View

/// A floating status indicator that appears during operations
struct FloatingStatusView: View {
    let message: String
    let icon: String
    let isProgress: Bool
    
    @State private var isVisible = false
    @State private var opacity: Double = 0
    
    init(message: String, icon: String = "info.circle", isProgress: Bool = false) {
        self.message = message
        self.icon = icon
        self.isProgress = isProgress
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 12) {
                // Icon or progress indicator
                if isProgress {
                    ProgressView()
                        .controlSize(.regular)
                } else {
                    Image(systemName: icon)
                        .font(.title)
                        .foregroundStyle(.blue)
                }
                
                // Message
                Text(message)
                    .font(.body)
                    .foregroundStyle(.primary)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
            )
            .opacity(opacity)
            .scaleEffect(isVisible ? 1 : 0.8)
            
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isVisible = true
                opacity = 1
            }
        }
    }
}

// MARK: - Status Overlay

/// Add status overlay to any view
extension View {
    func statusOverlay() -> some View {
        ZStack {
            self
            
            VStack {
                Spacer()
                StatusBarView()
                    .padding(.bottom, 20)
            }
        }
    }
    
    func floatingStatus(isShowing: Bool, message: String, icon: String = "info.circle", isProgress: Bool = false) -> some View {
        ZStack {
            self
            
            if isShowing {
                FloatingStatusView(message: message, icon: icon, isProgress: isProgress)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.spring(), value: isShowing)
    }
}

// MARK: - Capture Status Overlay

/// Shows status during capture operations
struct CaptureStatusOverlay: View {
    let mode: CaptureMode
    let isSelectingWindow: Bool
    
    enum CaptureMode {
        case area
        case window
        case scrolling
        
        var description: String {
            switch self {
            case .area: return "Drag to select an area"
            case .window: return "Click a window to capture"
            case .scrolling: return "Select a window to begin scrolling capture"
            }
        }
        
        var icon: String {
            switch self {
            case .area: return "arrow.up.left.and.arrow.down.right"
            case .window: return "macwindow"
            case .scrolling: return "arrow.down.doc"
            }
        }
    }
    
    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: mode.icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                
                Text(mode.description)
                    .font(.body)
                    .foregroundStyle(.white)
                
                Spacer()
                
                // Keyboard hint
                Text("Press Space to switch modes")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                
                Text("Esc to cancel")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.black.opacity(0.75))
            )
            .padding(20)
            
            Spacer()
        }
    }
}

// MARK: - Recording Status Indicator

/// Shows recording status with duration
struct RecordingStatusIndicator: View {
    let duration: String
    let onStop: () -> Void
    
    @State private var isPulsing = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Recording dot with pulse animation
            Circle()
                .fill(.red)
                .frame(width: 12, height: 12)
                .scaleEffect(isPulsing ? 1.2 : 1.0)
                .opacity(isPulsing ? 0.7 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
            
            // Duration
            Text(duration)
                .font(.body.monospaced())
                .foregroundStyle(.primary)
            
            Divider()
                .frame(height: 20)
            
            // Stop button
            Button {
                onStop()
            } label: {
                Label("Stop", systemImage: "stop.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10)
        )
        .onAppear {
            isPulsing = true
        }
    }
}

// MARK: - Progress HUD

/// A simple progress HUD for long operations
struct ProgressHUD: View {
    let title: String
    let message: String?
    let progress: Double? // 0.0 to 1.0, nil for indeterminate
    
    init(title: String, message: String? = nil, progress: Double? = nil) {
        self.title = title
        self.message = message
        self.progress = progress
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Progress indicator
            if let progress = progress {
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)
            }
            
            // Title
            Text(title)
                .font(.headline)
            
            // Message
            if let message = message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Progress percentage
            if let progress = progress {
                Text("\(Int(progress * 100))%")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(32)
        .frame(minWidth: 200)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 30, y: 10)
        )
    }
}

// MARK: - Previews

#Preview("Status Bar") {
    VStack(spacing: 20) {
        Button("Show Ready") {
            StatusManager.shared.showReadyToCapture()
        }
        
        Button("Show Capturing") {
            StatusManager.shared.showCapturing()
        }
        
        Button("Show Complete") {
            StatusManager.shared.showCaptureComplete()
        }
        
        Button("Show Error") {
            StatusManager.shared.showError(message: "Something went wrong")
        }
        
        Button("Clear") {
            StatusManager.shared.clearStatus()
        }
        
        Spacer()
        
        StatusBarView()
    }
    .frame(width: 400, height: 300)
    .padding()
}

#Preview("Floating Status") {
    FloatingStatusView(message: "Capturing screenshot…", icon: "camera.fill", isProgress: true)
        .frame(width: 400, height: 300)
}

#Preview("Capture Overlay") {
    ZStack {
        Color.black.opacity(0.3)
        CaptureStatusOverlay(mode: .area, isSelectingWindow: false)
    }
    .frame(width: 800, height: 600)
}

#Preview("Recording Indicator") {
    RecordingStatusIndicator(duration: "00:45") {
        print("Stop recording")
    }
    .padding()
}

#Preview("Progress HUD") {
    VStack(spacing: 40) {
        ProgressHUD(title: "Processing…", message: "This may take a moment")
        
        ProgressHUD(title: "Exporting", message: "Saving your capture", progress: 0.65)
    }
    .frame(width: 400, height: 400)
}
