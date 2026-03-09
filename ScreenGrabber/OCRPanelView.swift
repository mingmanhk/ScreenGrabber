//
//  OCRPanelView.swift
//  ScreenGrabber
//
//  OCR text extraction panel
//

import SwiftUI

struct OCRPanelView: View {
    let image: NSImage
    @Environment(\.dismiss) private var dismiss
    
    @State private var extractedText: String = ""
    @State private var isProcessing: Bool = false
    @State private var error: String?
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Extract Text")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Uses Vision framework to recognize text in the image")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
            }
            
            Divider()
            
            // Content
            if isProcessing {
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Processing image...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                    
                    Text("Error")
                        .font(.headline)
                    
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Try Again") {
                        performOCR()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if extractedText.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)
                    
                    Text("Ready to Extract Text")
                        .font(.headline)
                    
                    Text("Click the button below to analyze this image and extract any text found.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Run OCR") {
                        performOCR()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Extracted Text")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(extractedText, forType: .string)
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    TextEditor(text: .constant(extractedText))
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .border(Color.gray.opacity(0.3), width: 1)
                    
                    HStack {
                        Text("\(extractedText.components(separatedBy: .newlines).count) lines")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text("\(extractedText.count) characters")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 500, height: 600)
        .onAppear {
            // Auto-run OCR on appear
            performOCR()
        }
    }
    
    private func performOCR() {
        isProcessing = true
        error = nil
        extractedText = ""
        
        OCRManager.shared.extractText(from: image) { [self] result in
            DispatchQueue.main.async {
                isProcessing = false
                
                switch result {
                case .success(let text):
                    if text.isEmpty {
                        extractedText = "(No text found in image)"
                    } else {
                        extractedText = text
                    }
                case .failure(let err):
                    error = err.localizedDescription
                }
            }
        }
    }
}

#Preview {
    OCRPanelView(image: NSImage(systemSymbolName: "photo", accessibilityDescription: nil)!)
}
