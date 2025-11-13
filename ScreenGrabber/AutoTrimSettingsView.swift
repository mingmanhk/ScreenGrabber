//
//  AutoTrimSettingsView.swift
//  ScreenGrabber
//
//  UI for Auto-Trim / Smart Crop Settings
//

import SwiftUI

struct AutoTrimSettingsView: View {
    @ObservedObject var manager = AutoTrimManager.shared
    @State private var showPreview = false
    @State private var testImage: NSImage?

    var body: some View {
        Form {
            Section("Auto-Trim Settings") {
                Toggle("Enable auto-trim on capture", isOn: $manager.autoTrimEnabled)
                    .onChange(of: manager.autoTrimEnabled) { oldValue, newValue in
                        manager.saveSettings()
                    }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Trim Threshold: \(Int(manager.trimThreshold))")
                        .font(.caption)

                    Slider(value: $manager.trimThreshold, in: 1...50, step: 1)
                        .onChange(of: manager.trimThreshold) { oldValue, newValue in
                            manager.saveSettings()
                        }

                    Text("How sensitive the trim detection should be. Lower values detect more subtle borders.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Minimum Border Size: \(Int(manager.minBorderSize))px")
                        .font(.caption)

                    Slider(value: $manager.minBorderSize, in: 1...20, step: 1)
                        .onChange(of: manager.minBorderSize) { oldValue, newValue in
                            manager.saveSettings()
                        }

                    Text("Minimum number of pixels to trim from each edge.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Section("How Auto-Trim Works") {
                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(
                        icon: "viewfinder.circle",
                        title: "Border Detection",
                        description: "Automatically detects uniform colored borders around screenshots"
                    )

                    InfoRow(
                        icon: "crop",
                        title: "Smart Cropping",
                        description: "Removes unnecessary whitespace and borders"
                    )

                    InfoRow(
                        icon: "sparkles",
                        title: "Edge Enhancement",
                        description: "Optionally enhances edges after trimming"
                    )
                }
            }

            Section("Preview") {
                Button("Test Auto-Trim") {
                    testAutoTrim()
                }
                .buttonStyle(.borderedProminent)

                if showPreview, let image = testImage {
                    VStack {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)

                        Text("Preview of trimmed image")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func testAutoTrim() {
        // Create a test image or use the last screenshot
        // For now, show info
        showPreview = true
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct SmartCropView: View {
    let image: NSImage
    @State private var croppedImage: NSImage?
    @State private var aspectRatio: CGFloat = 1.0
    @ObservedObject var manager = AutoTrimManager.shared

    var body: some View {
        VStack {
            HStack {
                Text("Smart Crop")
                    .font(.headline)

                Spacer()

                Picker("Aspect Ratio", selection: $aspectRatio) {
                    Text("Original").tag(CGFloat(0))
                    Text("1:1").tag(CGFloat(1))
                    Text("16:9").tag(CGFloat(16/9))
                    Text("4:3").tag(CGFloat(4/3))
                    Text("3:2").tag(CGFloat(3/2))
                }
                .pickerStyle(.menu)
            }

            if let cropped = croppedImage {
                Image(nsImage: cropped)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 400)
            } else {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 400)
            }

            HStack {
                Button("Apply Smart Crop") {
                    let ratio = aspectRatio == 0 ? nil : aspectRatio
                    croppedImage = manager.smartCrop(image, aspectRatio: ratio)
                }
                .buttonStyle(.borderedProminent)

                if croppedImage != nil {
                    Button("Reset") {
                        croppedImage = nil
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
    }
}
