//
//  AIEditorPanel.swift
//  ScreenGrabber
//
//  AI-powered tools panel embedded in the editor.
//  Requires an active AI Pro subscription OR a valid BYOK key.
//
//  Supported features:
//    • OCR / Extract Text
//    • Generate Caption
//    • Generate Tags
//    • Tutorial Steps
//    • Remove Background
//    • Auto-Enhance
//    • Auto-Annotate (describe UI elements)
//    • Smart Blur / Detect Sensitive Info
//    • Explain Code
//
//  Each tool shows a lock icon when the user is not entitled and opens
//  the paywall sheet when tapped.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - AI Editor Panel

struct AIEditorPanel: View {
    let image: NSImage?
    @ObservedObject var editorState: ScreenCaptureEditorState

    @State private var isEntitled = false
    @State private var isRunning = false
    @State private var currentResult = ""
    @State private var activeFeature: AIEditorFeature? = nil
    @State private var errorMessage: String? = nil
    @State private var copiedToClipboard = false
    @State private var processedImage: NSImage? = nil
    @State private var showProcessedImage = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHeader
            Divider()
            if isEntitled {
                featureButtons
                if !currentResult.isEmpty || isRunning || errorMessage != nil || processedImage != nil {
                    Divider()
                    resultArea
                }
            } else {
                lockedOverlay
            }
        }
        .onAppear { refreshEntitlement() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("entitlementChanged"))) { _ in
            refreshEntitlement()
        }
    }

    // MARK: - Header

    private var panelHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.purple)
            Text("AI Tools")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            if isRunning {
                ProgressView().scaleEffect(0.7)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Feature Buttons

    private var featureButtons: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(AIEditorFeature.allCases) { feature in
                    AIFeatureButton(
                        feature: feature,
                        isActive: activeFeature == feature,
                        isRunning: isRunning && activeFeature == feature
                    ) {
                        run(feature)
                    }
                    if feature != AIEditorFeature.allCases.last {
                        Divider().padding(.leading, 40)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Result Area

    private var resultArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let error = errorMessage {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
            } else if isRunning {
                HStack {
                    ProgressView().scaleEffect(0.8)
                    Text("Processing…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
            } else if let processed = processedImage {
                // Show processed image result (background removal, enhancement)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Result Preview")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                    Image(nsImage: processed)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 160)
                        .cornerRadius(6)
                        .padding(.horizontal, 10)
                    HStack {
                        Spacer()
                        Button("Apply to Canvas") {
                            applyProcessedImage(processed)
                        }
                        .font(.caption)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        Button("Save As…") {
                            saveProcessedImage(processed)
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        Button("Discard") {
                            processedImage = nil
                            activeFeature = nil
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                }
            } else if !currentResult.isEmpty {
                ScrollView {
                    Text(currentResult)
                        .font(.system(size: 12))
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)

                HStack {
                    Spacer()
                    Button(copiedToClipboard ? "Copied!" : "Copy All") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(currentResult, forType: .string)
                        withAnimation { copiedToClipboard = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { copiedToClipboard = false }
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                    .foregroundColor(copiedToClipboard ? .green : .accentColor)

                    Button("Clear") {
                        currentResult = ""
                        activeFeature = nil
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Locked State

    private var lockedOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(.secondary)
            Text("AI Pro Required")
                .font(.system(size: 13, weight: .semibold))
            Text("Subscribe to AI Pro or add your own API key to unlock OCR, captions, remove background, and more.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button("Unlock AI Features") {
                NotificationCenter.default.post(name: Notification.Name("showPaywall"), object: nil)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Logic

    private func refreshEntitlement() {
        switch AIEntitlementManager.shared.checkEntitlement() {
        case .allowed: isEntitled = true
        case .denied:  isEntitled = false
        }
    }

    private func run(_ feature: AIEditorFeature) {
        guard let img = image, !isRunning else { return }
        activeFeature = feature
        isRunning = true
        errorMessage = nil
        currentResult = ""
        processedImage = nil

        Task {
            do {
                switch feature {
                case .removeBackground:
                    let result = try await AIEngineManager.shared.removeBackground(from: img)
                    await MainActor.run {
                        processedImage = result
                        isRunning = false
                    }
                case .autoEnhance:
                    let result = try await AIEngineManager.shared.autoEnhance(image: img)
                    await MainActor.run {
                        processedImage = result
                        isRunning = false
                    }
                default:
                    let result = try await feature.run(image: img)
                    await MainActor.run {
                        currentResult = result
                        isRunning = false
                        if feature == .ocr {
                            editorState.ocrText = result
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isRunning = false
                }
            }
        }
    }

    private func applyProcessedImage(_ processed: NSImage) {
        // Notify editor to replace the current image
        NotificationCenter.default.post(
            name: Notification.Name("replaceEditorImage"),
            object: processed
        )
        processedImage = nil
        activeFeature = nil
    }

    private func saveProcessedImage(_ processed: NSImage) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "processed_screenshot.png"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            if let tiff = processed.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let png = bitmap.representation(using: .png, properties: [:]) {
                try? png.write(to: url)
            }
        }
    }
}

// MARK: - AI Editor Feature

enum AIEditorFeature: String, CaseIterable, Identifiable {
    case ocr
    case caption
    case tags
    case tutorialSteps
    case removeBackground
    case autoEnhance
    case autoAnnotate
    case smartBlur
    case explainCode

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ocr:             return "Extract Text (OCR)"
        case .caption:         return "Generate Caption"
        case .tags:            return "Generate Tags"
        case .tutorialSteps:   return "Tutorial Steps"
        case .removeBackground:return "Remove Background"
        case .autoEnhance:     return "Auto-Enhance"
        case .autoAnnotate:    return "Auto-Annotate"
        case .smartBlur:       return "Detect Sensitive Info"
        case .explainCode:     return "Explain Code"
        }
    }

    var icon: String {
        switch self {
        case .ocr:             return "doc.text.magnifyingglass"
        case .caption:         return "text.bubble"
        case .tags:            return "tag"
        case .tutorialSteps:   return "list.number"
        case .removeBackground:return "scissors"
        case .autoEnhance:     return "wand.and.stars"
        case .autoAnnotate:    return "pencil.and.outline"
        case .smartBlur:       return "eye.slash"
        case .explainCode:     return "chevron.left.forwardslash.chevron.right"
        }
    }

    var description: String {
        switch self {
        case .ocr:             return "Extract all text visible in the screenshot"
        case .caption:         return "Write a one-sentence summary"
        case .tags:            return "Generate 3–5 keyword tags"
        case .tutorialSteps:   return "Convert screenshot into step-by-step guide"
        case .removeBackground:return "Remove background, keep foreground (macOS 14+)"
        case .autoEnhance:     return "Improve exposure, contrast & white balance"
        case .autoAnnotate:    return "Describe UI elements and their positions"
        case .smartBlur:       return "Find emails, passwords and sensitive data"
        case .explainCode:     return "Explain code or terminal output in plain English"
        }
    }

    var category: FeatureCategory {
        switch self {
        case .ocr, .caption, .tags, .tutorialSteps, .autoAnnotate, .smartBlur, .explainCode:
            return .text
        case .removeBackground, .autoEnhance:
            return .image
        }
    }

    enum FeatureCategory {
        case text, image
    }

    func run(image: NSImage) async throws -> String {
        switch self {
        case .ocr:
            return try await AIEngineManager.shared.extractText(from: image)
        case .caption:
            return try await AIEngineManager.shared.generateCaption(for: image)
        case .tags:
            let tags = try await AIEngineManager.shared.generateTags(for: image)
            return tags.joined(separator: ", ")
        case .tutorialSteps:
            return try await AIEngineManager.shared.generateTutorialSteps(for: image)
        case .autoAnnotate:
            return try await AIEngineManager.shared.generateAutoAnnotations(for: image)
        case .smartBlur:
            return try await AIEngineManager.shared.identifySensitiveRegions(in: image)
        case .explainCode:
            return try await AIEngineManager.shared.explainCodeInImage(image)
        case .removeBackground, .autoEnhance:
            // These are handled specially in AIEditorPanel (return NSImage, not String)
            throw AIError.parseError("Use AIEngineManager directly for image-result features")
        }
    }
}

// MARK: - Feature Button

private struct AIFeatureButton: View {
    let feature: AIEditorFeature
    let isActive: Bool
    let isRunning: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(iconBackground)
                        .frame(width: 24, height: 24)
                    Image(systemName: feature.icon)
                        .font(.system(size: 12))
                        .foregroundColor(iconForeground)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(feature.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                    Text(feature.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if isRunning {
                    ProgressView().scaleEffect(0.6)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .opacity(isHovering ? 1 : 0)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive
                          ? Color.purple.opacity(0.08)
                          : isHovering ? Color(NSColor.controlBackgroundColor) : Color.clear)
                    .padding(.horizontal, 4)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(feature.description)
    }

    private var iconBackground: Color {
        switch feature.category {
        case .image: return Color.blue.opacity(0.15)
        case .text:  return Color.purple.opacity(0.12)
        }
    }

    private var iconForeground: Color {
        switch feature.category {
        case .image: return .blue
        case .text:  return .purple
        }
    }
}
