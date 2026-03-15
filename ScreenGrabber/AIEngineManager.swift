//
//  AIEngineManager.swift
//  ScreenGrabber
//
//  Protocol-based AI abstraction layer. Routes every AI request through
//  entitlement check → provider selection → HTTP call → parsed response.
//
//  Subscription backend: placeholder endpoint (configure SERVER_AI_ENDPOINT in env).
//  BYOK: directly calls the provider's public API with the user's key.
//
//  NOTE: Vision framework types are not Sendable in current macOS versions.
//  This is expected and the warnings are suppressed with @preconcurrency.
//

// MARK: - Vision Framework (non-Sendable types expected)
// Vision types (VNImageRequestHandler, VNGenerateForegroundInstanceMaskRequest)
// are not Sendable in macOS 15/16. This is a framework limitation, not a bug.

@preconcurrency import Foundation
@preconcurrency import AppKit
@preconcurrency import Vision

// MARK: - Errors

enum AIError: LocalizedError {
    case notEntitled
    case noProviderAvailable
    case noKeyForProvider(AIProvider)
    case networkError(String)
    case httpError(Int)
    case parseError(String)
    case imageConversionFailed
    case notImplemented(String)
    case subscriptionBackendNotConfigured

    var errorDescription: String? {
        switch self {
        case .notEntitled:                         return "AI features require an AI Pro subscription or a BYOK API key."
        case .noProviderAvailable:                 return "No AI provider is available. Please configure an API key."
        case .noKeyForProvider(let p):             return "No API key saved for \(p.displayName)."
        case .networkError(let msg):               return "Network error: \(msg)"
        case .httpError(let code):                 return "HTTP \(code) from AI provider."
        case .parseError(let msg):                 return "Could not parse AI response: \(msg)"
        case .imageConversionFailed:               return "Could not convert image for AI processing."
        case .subscriptionBackendNotConfigured:    return "Subscription AI backend is not yet configured."
        case .notImplemented(let message): return "Not implemented: \(message)"
        }
    }
}

// MARK: - Feature → Provider Preference

enum AIFeature: String, CaseIterable {
    case ocr                    // extract text from screenshot
    case captionGeneration      // short description of screenshot
    case tagGeneration          // 3–5 keyword tags
    case tutorialSteps          // numbered how-to steps from UI screenshot
    case smartCrop              // suggest crop region (returns JSON)
    case codeExplanation        // explain code visible in screenshot
    case autoAnnotate           // describe UI elements and their positions
    case sensitiveInfo          // detect sensitive data regions for blurring
    case removeBackground       // background removal (macOS 14+, Vision-based)
    case autoEnhance            // Core Image auto-enhancement

    /// Ordered list of preferred providers for each feature.
    /// The engine tries them in order and uses the first one the user has access to.
    var preferredProviders: [AIProvider] {
        switch self {
        case .ocr:                return [.minimax, .gemini, .openai, .anthropic, .deepseek]
        case .captionGeneration:  return [.gemini,  .openai, .anthropic, .minimax, .deepseek]
        case .tagGeneration:      return [.deepseek, .openai, .anthropic, .gemini, .minimax]
        case .tutorialSteps:      return [.anthropic, .openai, .deepseek, .gemini, .minimax]
        case .smartCrop:          return [.openai, .anthropic, .gemini, .deepseek, .minimax]
        case .codeExplanation:    return [.anthropic, .openai, .deepseek, .gemini, .minimax]
        case .autoAnnotate:       return [.anthropic, .openai, .gemini, .deepseek, .minimax]
        case .sensitiveInfo:      return [.anthropic, .openai, .gemini, .deepseek, .minimax]
        case .removeBackground:   return [.openai, .anthropic, .gemini, .minimax, .deepseek]
        case .autoEnhance:        return [.openai, .anthropic, .gemini, .minimax, .deepseek]
        }
    }

    var systemPrompt: String {
        switch self {
        case .ocr:
            return "Extract all visible text from the image exactly as it appears. Return plain text only, preserving line breaks."
        case .captionGeneration:
            return "Describe this screenshot in one concise sentence (max 20 words). No preamble."
        case .tagGeneration:
            return "Return 3–5 comma-separated keyword tags that best describe this screenshot. No explanation."
        case .tutorialSteps:
            return "Analyse this UI screenshot and write numbered step-by-step instructions for what the user is doing or how to recreate it. Be concise."
        case .smartCrop:
            return "Analyse this image and suggest the best crop region to highlight the most important content. Return JSON: {\"x\":0,\"y\":0,\"width\":100,\"height\":100} as percentages of total size."
        case .codeExplanation:
            return "Explain the code visible in this screenshot in plain English. Be concise and accurate."
        case .autoAnnotate:
            return "Identify all UI elements in this screenshot (buttons, text fields, menus, labels, icons). For each element, list: 1) Element type 2) Approximate position 3) Likely purpose. Use a numbered list."
        case .sensitiveInfo:
            return "Identify any sensitive data visible in this screenshot: emails, phone numbers, passwords, API keys, credit card numbers, personal names in sensitive contexts, financial figures. List each item with its approximate location. If none found, say \"No sensitive information detected.\""
        case .removeBackground:
            return "This is a background removal request. Describe the main subject(s) in the image for context."
        case .autoEnhance:
            return "Describe the overall brightness, contrast, and color quality of this image. Suggest improvements."
        }
    }
}

// MARK: - Request / Response

struct AIRequest {
    let feature: AIFeature
    let userPrompt: String
    let image: NSImage?

    init(feature: AIFeature, userPrompt: String = "", image: NSImage? = nil) {
        self.feature = feature
        self.userPrompt = userPrompt
        self.image = image
    }

    /// JPEG base64 (≤1 MB) for multimodal calls, or nil for text-only.
    func jpegBase64(maxBytes: Int = 1_048_576) -> String? {
        guard let image else { return nil }
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }

        // Try quality steps until we're under maxBytes
        for quality in stride(from: 0.85, through: 0.3, by: -0.15) {
            if let jpeg = bitmap.representation(using: .jpeg,
                properties: [.compressionFactor: quality]),
               jpeg.count <= maxBytes {
                return jpeg.base64EncodedString()
            }
        }
        // Fallback: lowest quality
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.2])?.base64EncodedString()
    }
}

// MARK: - Engine

@MainActor
final class AIEngineManager {

    static let shared = AIEngineManager()
    private init() {}

    // Optional subscription backend base URL (e.g. "https://api.yourserver.com/ai")
    // When nil the engine falls through to BYOK.
    private let subscriptionBackendURL: URL? = {
        guard let raw = ProcessInfo.processInfo.environment["SG_AI_ENDPOINT"],
              !raw.isEmpty else { return nil }
        return URL(string: raw)
    }()

    // MARK: - Public API

    /// Run an AI request. Checks entitlement first; routes to subscription backend or BYOK.
    func run(_ request: AIRequest) async throws -> String {
        // Check entitlement for this specific feature
        let entitlement = AIEntitlementManager.shared.checkEntitlement(for: request.feature)
        
        switch entitlement {
        case .allowed(let source):
            switch source {
            case .local:
                // Handle local features without API calls
                switch request.feature {
                case .ocr:
                    guard let image = request.image else {
                        throw AIError.imageConversionFailed
                    }
                    // Use OCRManager for local OCR
                    if let result = try? await OCRManager.shared.extractTextWithConfidence(from: image) {
                        return result.text
                    } else {
                        // Fall back to the old method if local OCR fails
                        return try await callBYOK(request)
                    }
                case .removeBackground:
                    guard let image = request.image else {
                        throw AIError.imageConversionFailed
                    }
                    let _ = try await removeBackground(from: image)
                    // For local features, return a success message
                    return "Background removed successfully using local Vision processing."
                case .autoEnhance:
                    guard let image = request.image else {
                        throw AIError.imageConversionFailed
                    }
                    let _ = try await autoEnhance(image: image)
                    return "Image auto-enhanced successfully using Core Image."
                default:
                    // This shouldn't happen - local feature not implemented
                    throw AIError.notEntitled
                }
                
            case .subscription:
                do {
                    return try await callSubscriptionBackend(request)
                } catch AIError.subscriptionBackendNotConfigured {
                    // Fall through to BYOK if backend not configured
                    return try await callBYOK(request)
                }
            case .byok:
                return try await callBYOK(request)
            }
        case .denied:
            throw AIError.notEntitled
        }
    }

    // MARK: - Convenience Methods

    func extractText(from image: NSImage) async throws -> String {
        // Check if OCR is a local feature
        let entitlement = AIEntitlementManager.shared.checkEntitlement(for: .ocr)
        if case .allowed(let source) = entitlement, case .local = source {
            // Call local OCR implementation
            // For now, use a placeholder - need to integrate with AIFeatures.swift
            return try await run(AIRequest(feature: .ocr, image: image))
        } else {
            return try await run(AIRequest(feature: .ocr, image: image))
        }
    }

    func generateCaption(for image: NSImage) async throws -> String {
        try await run(AIRequest(feature: .captionGeneration, image: image))
    }

    func generateTags(for image: NSImage) async throws -> [String] {
        let raw = try await run(AIRequest(feature: .tagGeneration, image: image))
        return raw.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    func generateTutorialSteps(for image: NSImage) async throws -> String {
        try await run(AIRequest(feature: .tutorialSteps, image: image))
    }

    func explainCode(in image: NSImage) async throws -> String {
        try await run(AIRequest(feature: .codeExplanation, image: image))
    }
    // MARK: - Subscription Backend

    private func callSubscriptionBackend(_ request: AIRequest) async throws -> String {
        guard let base = subscriptionBackendURL else {
            throw AIError.subscriptionBackendNotConfigured
        }
        let url = base.appendingPathComponent("v1/run")
        var req = URLRequest(url: url, timeoutInterval: 30)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "feature": request.feature.rawValue,
            "prompt":  request.userPrompt
        ]
        if let b64 = request.jpegBase64() { body["image_base64"] = b64 }

        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await performRequest(req, extractPath: "result")
    }

    // MARK: - BYOK Routing

    private func callBYOK(_ request: AIRequest) async throws -> String {
        for provider in request.feature.preferredProviders {
            guard APIKeyManager.shared.hasKey(for: provider),
                  let key = APIKeyManager.shared.load(for: provider) else { continue }
            return try await callProvider(provider, key: key, request: request)
        }
        throw AIError.noProviderAvailable
    }

    private func callProvider(_ provider: AIProvider, key: String, request: AIRequest) async throws -> String {
        switch provider {
        case .anthropic: return try await callAnthropic(key: key, request: request)
        case .openai:    return try await callOpenAI(key: key, request: request)
        case .gemini:    return try await callGemini(key: key, request: request)
        case .deepseek:  return try await callDeepSeek(key: key, request: request)
        case .minimax:   return try await callMinimax(key: key, request: request)
        }
    }

    // MARK: - Anthropic (claude-3-haiku — fast + cheap)

    private func callAnthropic(key: String, request: AIRequest) async throws -> String {
        var urlReq = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!, timeoutInterval: 60)
        urlReq.httpMethod = "POST"
        urlReq.setValue(key,          forHTTPHeaderField: "x-api-key")
        urlReq.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlReq.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var contentArray: [[String: Any]] = []
        if let b64 = request.jpegBase64() {
            contentArray.append([
                "type": "image",
                "source": ["type": "base64", "media_type": "image/jpeg", "data": b64]
            ])
        }
        contentArray.append(["type": "text", "text": buildUserMessage(request)])

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 1024,
            "system": request.feature.systemPrompt,
            "messages": [["role": "user", "content": contentArray]]
        ]
        urlReq.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await performRequest(urlReq, extractPath: "content.0.text")
    }

    // MARK: - OpenAI (gpt-4o-mini — vision + affordable)

    private func callOpenAI(key: String, request: AIRequest) async throws -> String {
        var urlReq = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!, timeoutInterval: 60)
        urlReq.httpMethod = "POST"
        urlReq.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        urlReq.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var userContent: [Any] = [["type": "text", "text": buildUserMessage(request)]]
        if let b64 = request.jpegBase64() {
            userContent.append([
                "type": "image_url",
                "image_url": ["url": "data:image/jpeg;base64,\(b64)", "detail": "low"]
            ])
        }

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "max_tokens": 1024,
            "messages": [
                ["role": "system",  "content": request.feature.systemPrompt],
                ["role": "user",    "content": userContent]
            ]
        ]
        urlReq.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await performRequest(urlReq, extractPath: "choices.0.message.content")
    }

    // MARK: - Google Gemini (gemini-1.5-flash)

    private func callGemini(key: String, request: AIRequest) async throws -> String {
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(key)"
        guard let url = URL(string: endpoint) else { throw AIError.networkError("Bad Gemini URL") }
        var urlReq = URLRequest(url: url, timeoutInterval: 60)
        urlReq.httpMethod = "POST"
        urlReq.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var parts: [[String: Any]] = [["text": request.feature.systemPrompt + "\n\n" + buildUserMessage(request)]]
        if let b64 = request.jpegBase64() {
            parts.append(["inline_data": ["mime_type": "image/jpeg", "data": b64]])
        }

        let body: [String: Any] = [
            "contents": [["parts": parts]],
            "generationConfig": ["maxOutputTokens": 1024]
        ]
        urlReq.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await performRequest(urlReq, extractPath: "candidates.0.content.parts.0.text")
    }

    // MARK: - DeepSeek (deepseek-chat — text-only)

    private func callDeepSeek(key: String, request: AIRequest) async throws -> String {
        var urlReq = URLRequest(url: URL(string: "https://api.deepseek.com/chat/completions")!, timeoutInterval: 60)
        urlReq.httpMethod = "POST"
        urlReq.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        urlReq.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // DeepSeek does not support vision; combine system + image alt-text in user message
        let userText = buildUserMessage(request) + (request.image != nil ? "\n(Image provided but DeepSeek is text-only; describe based on context.)" : "")

        let body: [String: Any] = [
            "model": "deepseek-chat",
            "max_tokens": 1024,
            "messages": [
                ["role": "system",  "content": request.feature.systemPrompt],
                ["role": "user",    "content": userText]
            ]
        ]
        urlReq.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await performRequest(urlReq, extractPath: "choices.0.message.content")
    }

    // MARK: - Minimax (abab6.5s-chat — vision capable)

    private func callMinimax(key: String, request: AIRequest) async throws -> String {
        var urlReq = URLRequest(url: URL(string: "https://api.minimaxi.com/v1/text/chatcompletion_v2")!, timeoutInterval: 60)
        urlReq.httpMethod = "POST"
        urlReq.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        urlReq.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var userContent: [Any] = [["type": "text", "text": buildUserMessage(request)]]
        if let b64 = request.jpegBase64() {
            userContent.append(["type": "image_url",
                                 "image_url": ["url": "data:image/jpeg;base64,\(b64)"]])
        }

        let body: [String: Any] = [
            "model": "abab6.5s-chat",
            "max_tokens": 1024,
            "messages": [
                ["role": "system",  "content": request.feature.systemPrompt],
                ["role": "user",    "content": userContent]
            ]
        ]
        urlReq.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await performRequest(urlReq, extractPath: "choices.0.message.content")
    }

    // MARK: - Shared HTTP Helper

    /// Performs the request and extracts a string value at a dot-separated key path.
    private func performRequest(_ urlRequest: URLRequest, extractPath: String) async throws -> String {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
        } catch {
            throw AIError.networkError(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw AIError.httpError(http.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIError.parseError("Response is not valid JSON")
        }

        guard let result = extractValue(from: json, path: extractPath) else {
            throw AIError.parseError("Key path '\(extractPath)' not found in response")
        }
        return result
    }

    /// Resolves a dot-separated path like "choices.0.message.content" into a nested JSON value.
    private func extractValue(from json: [String: Any], path: String) -> String? {
        let components = path.components(separatedBy: ".")
        var current: Any = json
        for component in components {
            if let dict = current as? [String: Any], let next = dict[component] {
                current = next
            } else if let arr = current as? [Any], let idx = Int(component), idx < arr.count {
                current = arr[idx]
            } else {
                return nil
            }
        }
        return current as? String
    }

    // MARK: - Prompt Helpers

    private func buildUserMessage(_ request: AIRequest) -> String {
        request.userPrompt.isEmpty ? "Please analyse the provided image." : request.userPrompt
    }

    // MARK: - Extended AI Operations

    /// Remove background from image using Vision person/subject segmentation.
    /// Returns a new NSImage with transparent background (PNG-compatible).
    func removeBackground(from image: NSImage) async throws -> NSImage {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw AIError.parseError("Could not create CGImage")
        }
        
        // Try VNGenerateForegroundInstanceMaskRequest (macOS 14+)
        if #available(macOS 14.0, *) {
            
            return try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let request = VNGenerateForegroundInstanceMaskRequest()
                    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
                        try handler.perform([request])
                        guard let maskResult = request.results?.first else {
                            continuation.resume(throwing: AIError.parseError("No foreground mask generated"))
                            return
                        }
                        
                        // Apply mask to create transparent background
                        let maskBuffer = try maskResult.generateMaskedImage(
                            ofInstances: maskResult.allInstances,
                            from: handler,
                            croppedToInstancesExtent: false
                        )
                        
                        let maskedCIImage = CIImage(cvPixelBuffer: maskBuffer)
                        let context = CIContext()
                        guard let maskedCGImage = context.createCGImage(maskedCIImage, from: maskedCIImage.extent) else {
                            continuation.resume(throwing: AIError.parseError("Failed to create masked image"))
                            return
                        }
                        
                        let maskedNSImage = NSImage(cgImage: maskedCGImage, size: image.size)
                        continuation.resume(returning: maskedNSImage)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } else {
            // Fallback: use AI API for background removal description
            throw AIError.parseError("Background removal requires macOS 14 or later")
        }
    }

    /// Auto-enhance an image using Core Image filters.
    /// Applies auto-exposure, auto-white-balance, and contrast adjustment.
    func autoEnhance(image: NSImage) async throws -> NSImage {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw AIError.parseError("Could not create CGImage for enhancement")
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        
        // Apply auto-enhancement filters
        let filters = ciImage.autoAdjustmentFilters(options: nil)
        var enhancedImage = ciImage
        for filter in filters {
            filter.setValue(enhancedImage, forKey: kCIInputImageKey)
            if let output = filter.outputImage {
                enhancedImage = output
            }
        }
        
        guard let enhancedCGImage = context.createCGImage(enhancedImage, from: enhancedImage.extent) else {
            throw AIError.parseError("Could not create enhanced image")
        }
        
        return NSImage(cgImage: enhancedCGImage, size: image.size)
    }

    /// Generate auto-annotations for the image via AI (describes UI elements, code, etc.)
    func generateAutoAnnotations(for image: NSImage) async throws -> String {
        return try await run(AIRequest(
            feature: .captionGeneration,
            userPrompt: """
            Analyze this screenshot and identify all important UI elements, text, buttons, and regions.
            For each element, describe:
            1. What it is (button, text field, menu, etc.)
            2. Its approximate position (top-left, center, bottom-right, etc.)
            3. What action it likely performs
            Format as a numbered list. Be concise.
            """
        ))
    }

    /// Smart blur: identify sensitive information (emails, phone numbers, credit cards) and describe regions to blur.
    func identifySensitiveRegions(in image: NSImage) async throws -> String {
        return try await run(AIRequest(
            feature: .captionGeneration,
            userPrompt: """
            Analyze this screenshot and identify any sensitive information that should be blurred or redacted:
            - Email addresses
            - Phone numbers
            - Credit card numbers
            - Passwords or API keys
            - Personal names in sensitive contexts
            - Financial figures
            
            For each sensitive item found, describe its approximate location.
            If no sensitive information is found, say "No sensitive information detected."
            Format as a numbered list.
            """
        ))
    }

    /// Explain code visible in the screenshot.
    func explainCodeInImage(_ image: NSImage) async throws -> String {
        return try await run(AIRequest(
            feature: .captionGeneration,
            userPrompt: """
            Look at this screenshot. If it contains code or command-line output:
            1. Identify the programming language or tool
            2. Explain what the code/command does in plain English
            3. Point out any potential bugs, errors, or improvements
            
            If there is no code visible, say "No code found in this screenshot."
            Be concise but thorough.
            """
        ))
    }

}