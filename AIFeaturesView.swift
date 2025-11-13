//
//  AIFeaturesView.swift
//  ScreenGrabber
//
//  UI for AI-powered features
//

import SwiftUI
import AppKit

// MARK: - AI Features Settings Panel
struct AIFeaturesSettingsView: View {
    @StateObject private var ocrManager = OCRManager.shared
    @StateObject private var smartNaming = SmartNamingManager.shared
    @StateObject private var redactionManager = RedactionManager.shared
    
    @State private var ocrEnabled = UserDefaults.standard.bool(forKey: "ocrEnabled")
    @State private var smartNamingEnabled = UserDefaults.standard.bool(forKey: "smartNamingEnabled")
    @State private var autoRedactionEnabled = UserDefaults.standard.bool(forKey: "autoRedactionEnabled")
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // OCR Settings
            VStack(alignment: .leading, spacing: 10) {
                SectionHeaderView(title: "AI OCR", icon: "doc.text.viewfinder")
                
                Toggle("Extract text from screenshots", isOn: $ocrEnabled)
                    .onChange(of: ocrEnabled) { value in
                        UserDefaults.standard.set(value, forKey: "ocrEnabled")
                    }
                
                if ocrEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Automatically:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        CheckboxRow(label: "Copy text to clipboard", isOn: .constant(true))
                        CheckboxRow(label: "Save as .txt file", isOn: .constant(false))
                        CheckboxRow(label: "Add to search index", isOn: .constant(true))
                    }
                    .padding(.leading, 20)
                }
            }
            
            Divider()
            
            // Smart Naming Settings
            VStack(alignment: .leading, spacing: 10) {
                SectionHeaderView(title: "AI Smart Naming", icon: "text.badge.checkmark")
                
                Toggle("Suggest intelligent filenames", isOn: $smartNamingEnabled)
                    .onChange(of: smartNamingEnabled) { value in
                        UserDefaults.standard.set(value, forKey: "smartNamingEnabled")
                    }
                
                if smartNamingEnabled {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("AI will analyze screenshot content and suggest meaningful names")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if !smartNaming.suggestedName.isEmpty {
                            HStack {
                                Text("Last suggestion:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(smartNaming.suggestedName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.accentColor)
                            }
                            .padding(8)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                    .padding(.leading, 20)
                }
            }
            
            Divider()
            
            // Redaction Settings
            VStack(alignment: .leading, spacing: 10) {
                SectionHeaderView(title: "AI Redaction", icon: "eye.trianglebadge.exclamationmark")
                
                Toggle("Auto-detect sensitive information", isOn: $autoRedactionEnabled)
                    .onChange(of: autoRedactionEnabled) { value in
                        UserDefaults.standard.set(value, forKey: "autoRedactionEnabled")
                    }
                
                if autoRedactionEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Automatically detect and offer to redact:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                            ForEach(SensitiveDataType.allCases.prefix(8), id: \.self) { type in
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                    Text(type.rawValue)
                                        .font(.caption2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    }
                    .padding(.leading, 20)
                }
            }
        }
    }
}

// MARK: - OCR Action Sheet
struct OCRActionSheet: View {
    let imageURL: URL
    @StateObject private var ocrManager = OCRManager.shared
    @State private var extractedText: String = ""
    @State private var showingText = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "doc.text.viewfinder")
                    .font(.title)
                    .foregroundColor(.accentColor)
                
                Text("Extract Text")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                if ocrManager.isProcessing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            
            if showingText && !extractedText.isEmpty {
                // Extracted text display
                ScrollView {
                    Text(extractedText)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                }
                .frame(height: 300)
                
                // Actions
                HStack(spacing: 12) {
                    Button("Copy") {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(extractedText, forType: .string)
                        
                        NotificationManager.shared.show(
                            title: "Copied",
                            message: "Text copied to clipboard"
                        )
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Save as TXT") {
                        saveasTXT()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Done") {
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            } else {
                // Processing state
                VStack(spacing: 16) {
                    if ocrManager.isProcessing {
                        ProgressView()
                        Text("Analyzing screenshot...")
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("Click Extract to analyze screenshot")
                            .foregroundColor(.secondary)
                        
                        Button("Extract Text") {
                            performOCR()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .frame(width: 500)
    }
    
    private func performOCR() {
        guard let image = NSImage(contentsOf: imageURL) else { return }
        
        ocrManager.extractText(from: image) { result in
            switch result {
            case .success(let text):
                extractedText = text
                showingText = true
            case .failure(let error):
                extractedText = "Error: \(error.localizedDescription)"
                showingText = true
            }
        }
    }
    
    private func saveasTXT() {
        let txtURL = imageURL.deletingPathExtension().appendingPathExtension("txt")
        do {
            try extractedText.write(to: txtURL, atomically: true, encoding: .utf8)
            NotificationManager.shared.show(
                title: "Saved",
                message: "Text saved to \(txtURL.lastPathComponent)"
            )
        } catch {
            print("Save error: \(error)")
        }
    }
}

// MARK: - Smart Naming Sheet
struct SmartNamingSheet: View {
    let imageURL: URL
    let onRename: (String) -> Void
    
    @StateObject private var smartNaming = SmartNamingManager.shared
    @State private var suggestedNames: [String] = []
    @State private var customName: String = ""
    @State private var isGenerating = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "text.badge.checkmark")
                    .font(.title)
                    .foregroundColor(.accentColor)
                
                Text("Smart Rename")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
            }
            
            // Current name
            VStack(alignment: .leading, spacing: 4) {
                Text("Current:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(imageURL.lastPathComponent)
                    .font(.body)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            if isGenerating {
                ProgressView("Analyzing screenshot...")
                    .frame(height: 100)
            } else if !suggestedNames.isEmpty {
                // Suggestions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggestions:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(suggestedNames, id: \.self) { name in
                        Button(action: {
                            customName = name
                        }) {
                            HStack {
                                Image(systemName: customName == name ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(.accentColor)
                                Text(name)
                                    .font(.body)
                                Spacer()
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(customName == name ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Custom name input
            VStack(alignment: .leading, spacing: 4) {
                Text("Or enter custom name:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("Screenshot name", text: $customName)
                    .textFieldStyle(.roundedBorder)
            }
            
            Spacer()
            
            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Rename") {
                    if !customName.isEmpty {
                        onRename(customName + ".png")
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(customName.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 500, height: 400)
        .onAppear {
            generateSuggestions()
        }
    }
    
    private func generateSuggestions() {
        guard let image = NSImage(contentsOf: imageURL) else { return }
        isGenerating = true
        
        smartNaming.suggestName(for: image) { name in
            // Generate multiple variations
            suggestedNames = [
                name,
                name + "_v1",
                imageURL.deletingPathExtension().lastPathComponent
            ]
            isGenerating = false
            customName = name
        }
    }
}

// MARK: - Redaction Preview
struct RedactionPreviewView: View {
    let imageURL: URL
    @StateObject private var redactionManager = RedactionManager.shared
    @State private var selectedMode: RedactionMode = .blur
    @State private var redactedImage: NSImage?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "eye.trianglebadge.exclamationmark")
                    .font(.title)
                    .foregroundColor(.red)
                
                Text("Redact Sensitive Data")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                if redactionManager.isScanning {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            
            // Detected items
            if !redactionManager.detectedSensitiveData.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Found \(redactionManager.detectedSensitiveData.count) sensitive items:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(redactionManager.detectedSensitiveData) { data in
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.red)
                                    Text(data.type.rawValue)
                                        .font(.caption)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(4)
                            }
                        }
                    }
                }
            }
            
            // Redaction mode selector
            Picker("Mode:", selection: $selectedMode) {
                Text("Blur").tag(RedactionMode.blur)
                Text("Pixelate").tag(RedactionMode.pixelate)
                Text("Black Box").tag(RedactionMode.blackBox)
            }
            .pickerStyle(.segmented)
            
            // Preview
            if let redacted = redactedImage {
                Image(nsImage: redacted)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 400)
                    .cornerRadius(8)
            }
            
            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                
                Spacer()
                
                Button("Scan") {
                    scanForSensitiveData()
                }
                .buttonStyle(.bordered)
                .disabled(redactionManager.isScanning)
                
                Button("Apply Redaction") {
                    applyRedaction()
                }
                .buttonStyle(.borderedProminent)
                .disabled(redactionManager.detectedSensitiveData.isEmpty)
            }
        }
        .padding()
        .frame(width: 600, height: 600)
    }
    
    private func scanForSensitiveData() {
        guard let image = NSImage(contentsOf: imageURL) else { return }
        
        redactionManager.detectSensitiveData(in: image) { detected in
            print("Found \(detected.count) sensitive items")
        }
    }
    
    private func applyRedaction() {
        guard let image = NSImage(contentsOf: imageURL) else { return }
        
        if let redacted = redactionManager.redactImage(
            image,
            sensitiveData: redactionManager.detectedSensitiveData,
            mode: selectedMode
        ) {
            redactedImage = redacted
            
            // Save redacted version
            let redactedURL = imageURL.deletingLastPathComponent()
                .appendingPathComponent(imageURL.deletingPathExtension().lastPathComponent + "_redacted.png")
            
            if let tiffData = redacted.tiffRepresentation,
               let bitmapRep = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                try? pngData.write(to: redactedURL)
                
                NotificationManager.shared.show(
                    title: "Redaction Complete",
                    message: "Saved to \(redactedURL.lastPathComponent)"
                )
            }
        }
    }
}

// MARK: - Helper Views
struct CheckboxRow: View {
    let label: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Image(systemName: isOn ? "checkmark.square.fill" : "square")
                .foregroundColor(isOn ? .accentColor : .secondary)
            Text(label)
                .font(.caption)
        }
    }
}

#Preview {
    AIFeaturesSettingsView()
        .padding()
        .frame(width: 400)
}
