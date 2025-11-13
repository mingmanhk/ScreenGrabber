//
//  AIFeatures.swift
//  ScreenGrabber
//
//  AI-powered features using Vision and Core ML
//

import Foundation
import Vision
import CoreML
import NaturalLanguage
import AppKit

// MARK: - AI OCR Manager
class OCRManager: ObservableObject {
    static let shared = OCRManager()
    
    @Published var lastExtractedText: String = ""
    @Published var isProcessing: Bool = false
    
    private init() {}
    
    /// Extract text from screenshot using Vision framework
    func extractText(from image: NSImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion(.failure(OCRError.invalidImage))
            return
        }
        
        isProcessing = true
        
        let request = VNRecognizeTextRequest { [weak self] request, error in
            DispatchQueue.main.async {
                self?.isProcessing = false
                
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    completion(.failure(OCRError.noTextFound))
                    return
                }
                
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                self?.lastExtractedText = recognizedText
                completion(.success(recognizedText))
            }
        }
        
        // Configure for best accuracy
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US", "en-GB"]
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Extract text and copy to clipboard
    func extractAndCopy(from image: NSImage) {
        extractText(from: image) { result in
            switch result {
            case .success(let text):
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
                
                NotificationManager.shared.show(
                    title: "Text Extracted",
                    message: "Copied \(text.split(separator: "\n").count) lines to clipboard"
                )
            case .failure(let error):
                print("[OCR] Error: \(error.localizedDescription)")
                NotificationManager.shared.show(
                    title: "OCR Failed",
                    message: error.localizedDescription
                )
            }
        }
    }
    
    /// Extract text and save to file
    func extractAndSave(from image: NSImage, to fileURL: URL) {
        extractText(from: image) { result in
            switch result {
            case .success(let text):
                let txtURL = fileURL.deletingPathExtension().appendingPathExtension("txt")
                do {
                    try text.write(to: txtURL, atomically: true, encoding: .utf8)
                    NotificationManager.shared.show(
                        title: "Text Saved",
                        message: "Saved to \(txtURL.lastPathComponent)"
                    )
                } catch {
                    print("[OCR] Save error: \(error)")
                }
            case .failure(let error):
                print("[OCR] Error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - AI Smart Naming Manager
class SmartNamingManager: ObservableObject {
    static let shared = SmartNamingManager()
    
    @Published var suggestedName: String = ""
    @Published var confidence: Double = 0.0
    
    private init() {}
    
    /// Generate smart filename from screenshot content
    func suggestName(for image: NSImage, completion: @escaping (String) -> Void) {
        // First extract text using OCR
        OCRManager.shared.extractText(from: image) { [weak self] result in
            switch result {
            case .success(let text):
                let smartName = self?.generateSmartName(from: text, image: image) ?? "Screenshot"
                DispatchQueue.main.async {
                    self?.suggestedName = smartName
                    completion(smartName)
                }
            case .failure:
                // Fallback to basic naming
                let fallbackName = "Screenshot_\(self?.getTimestamp() ?? "")"
                DispatchQueue.main.async {
                    completion(fallbackName)
                }
            }
        }
    }
    
    private func generateSmartName(from text: String, image: NSImage) -> String {
        let lines = text.split(separator: "\n").map { String($0) }
        guard !lines.isEmpty else { return "Screenshot_\(getTimestamp())" }
        
        // Detect app name from common patterns
        let appName = detectAppName(from: lines)
        
        // Detect content type
        let contentType = detectContentType(from: text)
        
        // Extract key subject
        let subject = extractSubject(from: lines)
        
        // Build smart filename
        var components: [String] = []
        
        if let app = appName {
            components.append(app)
        }
        
        if !subject.isEmpty {
            components.append(subject)
        } else if let type = contentType {
            components.append(type)
        }
        
        if components.isEmpty {
            return "Screenshot_\(getTimestamp())"
        }
        
        let filename = components.joined(separator: "_")
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        
        return sanitizeFilename(filename)
    }
    
    private func detectAppName(from lines: [String]) -> String? {
        let appPatterns = [
            "Xcode": ["xcode", "swift", "build succeeded", "build failed"],
            "Safari": ["safari", "www.", "http", ".com"],
            "Slack": ["slack", "direct message", "channel"],
            "VSCode": ["visual studio code", "vscode", "main.py", "function"],
            "Terminal": ["terminal", "bash", "~", "$"],
            "Finder": ["finder", "items", "macintosh hd"],
            "Chrome": ["chrome", "google chrome"],
            "Messages": ["imessage", "messages"],
            "Mail": ["mail", "inbox", "from:", "to:"]
        ]
        
        let lowerText = lines.joined(separator: " ").lowercased()
        
        for (app, patterns) in appPatterns {
            if patterns.contains(where: { lowerText.contains($0) }) {
                return app
            }
        }
        
        return nil
    }
    
    private func detectContentType(from text: String) -> String? {
        let lowerText = text.lowercased()
        
        if lowerText.contains("error") || lowerText.contains("failed") {
            return "Error"
        } else if lowerText.contains("warning") {
            return "Warning"
        } else if lowerText.contains("success") {
            return "Success"
        } else if lowerText.contains("message") || lowerText.contains("chat") {
            return "Message"
        } else if lowerText.contains("code") || lowerText.contains("function") {
            return "Code"
        } else if lowerText.contains("article") || lowerText.contains("blog") {
            return "Article"
        }
        
        return nil
    }
    
    private func extractSubject(from lines: [String]) -> String {
        // Get first meaningful line (skip very short lines)
        for line in lines {
            let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.count >= 5 && cleaned.count <= 50 {
                // Tokenize and get first few words
                let words = cleaned.split(separator: " ").prefix(4)
                return words.joined(separator: " ")
            }
        }
        return ""
    }
    
    private func sanitizeFilename(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "\\/:*?\"<>|")
        let sanitized = name.components(separatedBy: invalidChars).joined(separator: "_")
        let shortened = String(sanitized.prefix(100)) // Limit length
        return shortened.isEmpty ? "Screenshot" : shortened
    }
    
    private func getTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: Date())
    }
}

// MARK: - AI Redaction Manager
class RedactionManager: ObservableObject {
    static let shared = RedactionManager()
    
    @Published var detectedSensitiveData: [SensitiveData] = []
    @Published var isScanning: Bool = false
    
    private init() {}
    
    /// Detect sensitive information in screenshot
    func detectSensitiveData(in image: NSImage, completion: @escaping ([SensitiveData]) -> Void) {
        isScanning = true
        var detected: [SensitiveData] = []
        
        // Extract text first
        OCRManager.shared.extractText(from: image) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let text):
                // Detect emails
                detected.append(contentsOf: self.detectEmails(in: text))
                
                // Detect phone numbers
                detected.append(contentsOf: self.detectPhoneNumbers(in: text))
                
                // Detect URLs
                detected.append(contentsOf: self.detectURLs(in: text))
                
                // Detect IP addresses
                detected.append(contentsOf: self.detectIPAddresses(in: text))
                
                // Detect file paths
                detected.append(contentsOf: self.detectFilePaths(in: text))
                
                // Detect API keys/tokens
                detected.append(contentsOf: self.detectAPIKeys(in: text))
                
                // Detect credit cards
                detected.append(contentsOf: self.detectCreditCards(in: text))
                
                // Detect faces
                self.detectFaces(in: image) { faces in
                    detected.append(contentsOf: faces)
                    
                    DispatchQueue.main.async {
                        self.detectedSensitiveData = detected
                        self.isScanning = false
                        completion(detected)
                    }
                }
                
            case .failure:
                DispatchQueue.main.async {
                    self.isScanning = false
                    completion([])
                }
            }
        }
    }
    
    private func detectEmails(in text: String) -> [SensitiveData] {
        let emailPattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return findMatches(pattern: emailPattern, in: text, type: .email)
    }
    
    private func detectPhoneNumbers(in text: String) -> [SensitiveData] {
        let phonePattern = "\\+?[1-9]\\d{1,14}|\\(?\\d{3}\\)?[-.\\s]?\\d{3}[-.\\s]?\\d{4}"
        return findMatches(pattern: phonePattern, in: text, type: .phone)
    }
    
    private func detectURLs(in text: String) -> [SensitiveData] {
        let urlPattern = "https?://[^\\s]+"
        return findMatches(pattern: urlPattern, in: text, type: .url)
    }
    
    private func detectIPAddresses(in text: String) -> [SensitiveData] {
        let ipPattern = "\\b(?:[0-9]{1,3}\\.){3}[0-9]{1,3}\\b"
        return findMatches(pattern: ipPattern, in: text, type: .ipAddress)
    }
    
    private func detectFilePaths(in text: String) -> [SensitiveData] {
        let pathPattern = "(/[^/\\s]+)+|([A-Z]:\\\\[^\\s]+)"
        return findMatches(pattern: pathPattern, in: text, type: .filePath)
    }
    
    private func detectAPIKeys(in text: String) -> [SensitiveData] {
        let apiKeyPattern = "[A-Za-z0-9_-]{32,}"
        return findMatches(pattern: apiKeyPattern, in: text, type: .apiKey)
    }
    
    private func detectCreditCards(in text: String) -> [SensitiveData] {
        let ccPattern = "\\b(?:\\d{4}[- ]?){3}\\d{4}\\b"
        return findMatches(pattern: ccPattern, in: text, type: .creditCard)
    }
    
    private func findMatches(pattern: String, in text: String, type: SensitiveDataType) -> [SensitiveData] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: range)
        
        return matches.compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            let matched = String(text[range])
            return SensitiveData(type: type, value: matched, location: .zero) // Location would need image coordinates
        }
    }
    
    private func detectFaces(in image: NSImage, completion: @escaping ([SensitiveData]) -> Void) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion([])
            return
        }
        
        let request = VNDetectFaceRectanglesRequest { request, error in
            guard error == nil,
                  let results = request.results as? [VNFaceObservation] else {
                completion([])
                return
            }
            
            let faces = results.map { observation in
                SensitiveData(
                    type: .face,
                    value: "Face",
                    location: observation.boundingBox
                )
            }
            
            completion(faces)
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }
    
    /// Apply redaction to image
    func redactImage(_ image: NSImage, sensitiveData: [SensitiveData], mode: RedactionMode) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        let size = image.size
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        // Draw original image
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        
        // Apply redaction to detected areas
        for data in sensitiveData where data.type == .face {
            let rect = convertBoundingBox(data.location, imageSize: size)
            applyRedaction(context: context, rect: rect, mode: mode)
        }
        
        guard let redactedCGImage = context.makeImage() else {
            return nil
        }
        
        let redactedImage = NSImage(cgImage: redactedCGImage, size: size)
        return redactedImage
    }
    
    private func convertBoundingBox(_ box: CGRect, imageSize: CGSize) -> CGRect {
        // Vision framework uses normalized coordinates (0-1)
        // Convert to actual pixel coordinates
        return CGRect(
            x: box.origin.x * imageSize.width,
            y: box.origin.y * imageSize.height,
            width: box.width * imageSize.width,
            height: box.height * imageSize.height
        )
    }
    
    private func applyRedaction(context: CGContext, rect: CGRect, mode: RedactionMode) {
        switch mode {
        case .blur:
            // Note: Blur requires more complex implementation with CIFilter
            context.setFillColor(NSColor.black.withAlphaComponent(0.8).cgColor)
            context.fill(rect)
        case .pixelate:
            context.setFillColor(NSColor.black.withAlphaComponent(0.9).cgColor)
            context.fill(rect)
        case .blackBox:
            context.setFillColor(NSColor.black.cgColor)
            context.fill(rect)
        case .customColor(let color):
            context.setFillColor(color.cgColor)
            context.fill(rect)
        }
    }
}

// MARK: - Models

struct SensitiveData: Identifiable {
    let id = UUID()
    let type: SensitiveDataType
    let value: String
    let location: CGRect
}

enum SensitiveDataType: String, CaseIterable {
    case email = "Email"
    case phone = "Phone"
    case face = "Face"
    case address = "Address"
    case password = "Password"
    case apiKey = "API Key"
    case filePath = "File Path"
    case ipAddress = "IP Address"
    case url = "URL"
    case creditCard = "Credit Card"
}

enum RedactionMode {
    case blur
    case pixelate
    case blackBox
    case customColor(NSColor)
}

enum OCRError: LocalizedError {
    case invalidImage
    case noTextFound
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format"
        case .noTextFound:
            return "No text found in image"
        }
    }
}

// MARK: - Notification Manager
class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    func show(title: String, message: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
}
