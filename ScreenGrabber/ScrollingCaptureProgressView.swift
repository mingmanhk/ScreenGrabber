//
//  ScrollingCaptureProgressView.swift
//  ScreenGrabber
//
//  Modern progress UI for scrolling capture with state tracking
//

import SwiftUI

struct ScrollingCaptureProgressView: View {
    @ObservedObject var engine: WindowBasedScrollingEngine
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Content based on state
            switch engine.state {
            case .idle:
                EmptyView()
                
            case .selectingWindow:
                WindowSelectionPrompt()
                
            case .capturingSegments(let progress):
                CaptureProgressContent(progress: progress, onCancel: onCancel)
                
            case .stitching:
                StitchingProgressContent()
                
            case .saving:
                SavingProgressContent()
                
            case .complete(let url):
                CompletionContent(url: url)
                
            case .failed(let error):
                ErrorContent(error: error, onRetry: {
                    // Reset to selection flow so the user can pick a window again
                    engine.state = .selectingWindow
                })
            }
        }
        .frame(width: 360)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(radius: 20)
        )
    }
}

// MARK: - Window Selection Prompt

struct WindowSelectionPrompt: View {
    var body: some View {
        VStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 8) {
                Text("Select a Window")
                    .font(.title2.bold())
                
                Text("Click on the window you want to capture")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 12) {
                Image(systemName: "1.circle.fill")
                    .foregroundColor(.blue)
                Text("Hover over windows")
                    .font(.caption)
            }
            
            HStack(spacing: 12) {
                Image(systemName: "2.circle.fill")
                    .foregroundColor(.blue)
                Text("Click to select")
                    .font(.caption)
            }
        }
        .padding(30)
    }
}

// MARK: - Capture Progress Content

struct CaptureProgressContent: View {
    let progress: ScrollingCaptureState.CaptureProgress
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 8) {
                Text("Capturing Scrolling Content")
                    .font(.title3.bold())
                
                Text(progress.status)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Progress info
            VStack(spacing: 12) {
                HStack {
                    Text("Segment:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let total = progress.totalSegments {
                        Text("\(progress.currentSegment) / \(total)")
                            .font(.caption.bold())
                            .foregroundColor(.primary)
                    } else {
                        Text("\(progress.currentSegment)")
                            .font(.caption.bold())
                            .foregroundColor(.primary)
                    }
                }
                
                // Indeterminate progress bar
                ProgressView()
                    .progressViewStyle(.linear)
            }
            .padding(.horizontal, 20)
            
            // Cancel button
            Button(action: onCancel) {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                    Text("Cancel")
                }
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.red)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 30)
    }
}

// MARK: - Stitching Progress

struct StitchingProgressContent: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Image(systemName: "square.3.layers.3d")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(rotation))
            }
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
            
            VStack(spacing: 8) {
                Text("Merging Segments")
                    .font(.title3.bold())
                
                Text("Stitching captured images together...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            ProgressView()
                .progressViewStyle(.linear)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 30)
    }
}

// MARK: - Saving Progress

struct SavingProgressContent: View {
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.green, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 8) {
                Text("Saving Screenshot")
                    .font(.title3.bold())
                
                Text("Saving to Pictures/ScreenGrabber...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            ProgressView()
                .progressViewStyle(.linear)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 30)
    }
}

// MARK: - Completion Content

struct CompletionContent: View {
    let url: URL
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
            
            VStack(spacing: 8) {
                Text("Capture Complete!")
                    .font(.title3.bold())
                    .foregroundColor(.green)
                
                Text("Saved to ScreenGrabber folder")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: {
                    NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                        Text("Show in Finder")
                    }
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.blue)
                    )
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    NSWorkspace.shared.open(url)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye.fill")
                        Text("Preview")
                    }
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.purple)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 30)
    }
}

// MARK: - Error Content

struct ErrorContent: View {
    let error: Error
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.red, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 8) {
                Text("Capture Failed")
                    .font(.title3.bold())
                    .foregroundColor(.red)
                
                Text(error.localizedDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            
            Button(action: onRetry) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.blue)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 30)
    }
}

// MARK: - Preview

#Preview("Capturing") {
    ScrollingCaptureProgressView(
        engine: {
            let engine = WindowBasedScrollingEngine()
            engine.state = .capturingSegments(
                progress: .init(currentSegment: 5, totalSegments: nil, status: "Scrolling and capturing...")
            )
            return engine
        }(),
        onCancel: {}
    )
}

#Preview("Complete") {
    ScrollingCaptureProgressView(
        engine: {
            let engine = WindowBasedScrollingEngine()
            engine.state = .complete(imageURL: URL(fileURLWithPath: "/tmp/test.png"))
            return engine
        }(),
        onCancel: {}
    )
}

