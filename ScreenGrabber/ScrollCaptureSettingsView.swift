//
//  ScrollCaptureSettingsView.swift
//  ScreenGrabber
//
//  Settings panel for scroll capture configuration
//  Created on 11/28/25.
//

import SwiftUI

struct ScrollCaptureSettingsView: View {
    @AppStorage("scrollCapture.stepOverlap") private var stepOverlap: Double = 50
    @AppStorage("scrollCapture.stepDelay") private var stepDelay: Double = 0.2
    @AppStorage("scrollCapture.maxSteps") private var maxSteps: Int = 200
    @AppStorage("scrollCapture.edgeMatchingEnabled") private var edgeMatchingEnabled: Bool = true
    @AppStorage("scrollCapture.maxTraversalDepth") private var maxTraversalDepth: Int = 30
    
    @State private var showingPermissionInfo = false
    @StateObject private var captureEngine = ScrollingCaptureEngine()
    @State private var hasAccessibilityPermission = false
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "camera.metering.center.weighted")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.green, .green.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Scrolling Capture")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Configure advanced scrolling screenshot settings")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    // Permission Status
                    HStack {
                        Label("Accessibility Permission", systemImage: hasAccessibilityPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundColor(hasAccessibilityPermission ? .green : .orange)
                        
                        Spacer()
                        
                        if !hasAccessibilityPermission {
                            Button("Grant Permission") {
                                requestAccessibilityPermission()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        
                        Button {
                            showingPermissionInfo.toggle()
                        } label: {
                            Image(systemName: "info.circle")
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if showingPermissionInfo {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About Accessibility Permission")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text("Accessibility permission allows precise control over scrolling, enabling high-quality captures of scrollable content. Without it, the app will use fallback methods that may be less accurate.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Benefits with permission:")
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.top, 4)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Deep search for nested scroll areas", systemImage: "scope")
                                Label("Precise programmatic scrolling", systemImage: "arrow.up.arrow.down")
                                Label("Better handling of complex layouts", systemImage: "square.split.2x2")
                                Label("Reduced seams and artifacts", systemImage: "sparkles")
                            }
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.blue.opacity(0.1))
                        )
                    }
                }
            } header: {
                Text("Permissions")
                    .font(.headline)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 20) {
                    // Edge Matching Toggle
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $edgeMatchingEnabled) {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Smart Edge Matching", systemImage: "wand.and.stars")
                                    .font(.headline)
                                
                                Text("Analyzes overlap regions to find optimal alignment and blend frames seamlessly")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        
                        if edgeMatchingEnabled {
                            HStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.green)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Recommended for best quality")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.green)
                                    Text("Handles sticky headers and complex layouts")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.green.opacity(0.1))
                            )
                        }
                    }
                    
                    Divider()
                    
                    // Step Overlap
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Frame Overlap", systemImage: "rectangle.stack")
                                .font(.headline)
                            
                            Spacer()
                            
                            Text("\(Int(stepOverlap)) px")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundColor(.accentColor)
                        }
                        
                        Slider(value: $stepOverlap, in: 20...100, step: 5) {
                            Text("Overlap")
                        } minimumValueLabel: {
                            Text("20")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } maximumValueLabel: {
                            Text("100")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .tint(.accentColor)
                        
                        Text("Overlap between frames. Higher values improve edge matching but increase capture time.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Step Delay
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Scroll Delay", systemImage: "timer")
                                .font(.headline)
                            
                            Spacer()
                            
                            Text(String(format: "%.2f sec", stepDelay))
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundColor(.accentColor)
                        }
                        
                        Slider(value: $stepDelay, in: 0.1...0.5, step: 0.05) {
                            Text("Delay")
                        } minimumValueLabel: {
                            Text("0.1")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } maximumValueLabel: {
                            Text("0.5")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .tint(.accentColor)
                        
                        Text("Time to wait after scrolling for content to render. Increase for slow-loading content.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Capture Quality")
                    .font(.headline)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 20) {
                    // Max Steps
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Maximum Steps", systemImage: "arrow.down.to.line")
                                .font(.headline)
                            
                            Spacer()
                            
                            Text("\(maxSteps)")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundColor(.accentColor)
                        }
                        
                        Slider(value: Binding(
                            get: { Double(maxSteps) },
                            set: { maxSteps = Int($0) }
                        ), in: 50...500, step: 10) {
                            Text("Max Steps")
                        } minimumValueLabel: {
                            Text("50")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } maximumValueLabel: {
                            Text("500")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .tint(.accentColor)
                        
                        Text("Safety limit for very long content. Prevents infinite loops.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Traversal Depth
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Accessibility Search Depth", systemImage: "scope")
                                .font(.headline)
                            
                            Spacer()
                            
                            Text("\(maxTraversalDepth)")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundColor(.accentColor)
                        }
                        
                        Slider(value: Binding(
                            get: { Double(maxTraversalDepth) },
                            set: { maxTraversalDepth = Int($0) }
                        ), in: 10...50, step: 5) {
                            Text("Search Depth")
                        } minimumValueLabel: {
                            Text("10")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } maximumValueLabel: {
                            Text("50")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .tint(.accentColor)
                        
                        Text("How deep to search the accessibility tree for scroll areas. Higher values find nested scrolls but may be slower.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Advanced")
                    .font(.headline)
            }
            
            Section {
                HStack {
                    Spacer()
                    
                    Button("Reset to Defaults") {
                        stepOverlap = 50
                        stepDelay = 0.2
                        maxSteps = 200
                        edgeMatchingEnabled = true
                        maxTraversalDepth = 30
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 600, minHeight: 700)
        .onAppear {
            // Refresh permission status
            hasAccessibilityPermission = checkAccessibilityPermission()
        }
    }
    
    // MARK: - Helper Methods
    
    private func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        
        // Check again after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            hasAccessibilityPermission = checkAccessibilityPermission()
        }
    }
}

// Helper to convert AppStorage values to ScrollingCaptureEngine.Configuration
extension ScrollingCaptureEngine.Configuration {
    static func fromAppStorage() -> ScrollingCaptureEngine.Configuration {
        var config = ScrollingCaptureEngine.Configuration()
        
        // Map old stepOverlap (pixels) to sliceOverlapPercentage
        if let overlap = UserDefaults.standard.object(forKey: "scrollCapture.stepOverlap") as? Double {
            // Convert pixel overlap to percentage (assuming ~800px viewport as baseline)
            config.sliceOverlapPercentage = CGFloat(overlap / 300.0) // Maps 50px to ~16%, 100px to ~33%
        }
        
        // Map stepDelay to scrollDelaySeconds
        if let delay = UserDefaults.standard.object(forKey: "scrollCapture.stepDelay") as? Double {
            config.scrollDelaySeconds = delay
        }
        
        // Map maxSteps to maxSlices
        if let steps = UserDefaults.standard.object(forKey: "scrollCapture.maxSteps") as? Int {
            config.maxSlices = steps
        }
        
        // Note: edgeMatchingEnabled and maxTraversalDepth are not directly supported in new engine
        // These are now handled differently in ScrollingCaptureEngine
        
        return config
    }
}

#Preview("Scroll Capture Settings") {
    ScrollCaptureSettingsView()
        .frame(width: 650, height: 750)
}
