//
//  APIKeyManager.swift
//  ScreenGrabber
//
//  Keychain-backed BYOK (Bring Your Own Key) storage for external AI providers.
//  Keys are stored per-provider in the app's Keychain item group.
//  Every AI feature must check AIEntitlementManager before using stored keys.
//

import Foundation
import Security
import Combine

// MARK: - Supported Providers

enum AIProvider: String, CaseIterable, Identifiable {
    case minimax   = "minimax"
    case deepseek  = "deepseek"
    case openai    = "openai"
    case anthropic = "anthropic"
    case gemini    = "gemini"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .minimax:   return "Minimax"
        case .deepseek:  return "DeepSeek"
        case .openai:    return "OpenAI (ChatGPT)"
        case .anthropic: return "Anthropic (Claude)"
        case .gemini:    return "Google Gemini"
        }
    }

    var keyPrefix: String {
        switch self {
        case .minimax:   return "eyJ"
        case .deepseek:  return "sk-"
        case .openai:    return "sk-"
        case .anthropic: return "sk-ant-"
        case .gemini:    return "AIza"
        }
    }

    var placeholder: String {
        switch self {
        case .minimax:   return "eyJ…"
        case .deepseek:  return "sk-…"
        case .openai:    return "sk-…"
        case .anthropic: return "sk-ant-…"
        case .gemini:    return "AIzaSy…"
        }
    }

    var documentationURL: URL {
        switch self {
        case .minimax:   return URL(string: "https://platform.minimaxi.com")!
        case .deepseek:  return URL(string: "https://platform.deepseek.com")!
        case .openai:    return URL(string: "https://platform.openai.com/api-keys")!
        case .anthropic: return URL(string: "https://console.anthropic.com")!
        case .gemini:    return URL(string: "https://aistudio.google.com/app/apikey")!
        }
    }
}

// MARK: - Validation State

enum KeyValidationState: Equatable {
    case unknown
    case validating
    case valid
    case invalid(reason: String)

    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    var statusText: String {
        switch self {
        case .unknown:              return "Not validated"
        case .validating:           return "Validating…"
        case .valid:                return "Valid ✓"
        case .invalid(let reason):  return "Invalid – \(reason)"
        }
    }

    var isValidating: Bool {
        if case .validating = self { return true }
        return false
    }
}

// MARK: - Manager

@MainActor
final class APIKeyManager: ObservableObject {

    static let shared = APIKeyManager()

    @Published var validationStates: [AIProvider: KeyValidationState] = {
        Dictionary(uniqueKeysWithValues: AIProvider.allCases.map { ($0, KeyValidationState.unknown) })
    }()

    private let service = "com.screengrabber.apikeys"

    private init() {}

    // MARK: - Keychain CRUD

    func save(key: String, for provider: AIProvider) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return }

        // Delete existing entry first
        let deleteQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new entry
        var addAttrs = deleteQuery
        addAttrs[kSecValueData as String] = data
        let status = SecItemAdd(addAttrs as CFDictionary, nil)
        if status != errSecSuccess {
            CaptureLogger.log(.error, "Keychain save failed for \(provider.displayName): OSStatus \(status)", level: .error)
        }
        validationStates[provider] = .unknown
    }

    func load(for provider: AIProvider) -> String? {
        // First try Keychain
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var item: AnyObject?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty {
            return key
        }
        
        // Fallback to environment variable in DEBUG builds
        #if DEBUG
        let envKey = environmentVariableName(for: provider)
        if let envValue = ProcessInfo.processInfo.environment[envKey], !envValue.isEmpty {
            CaptureLogger.log(.debug, "APIKeyManager: using environment variable \(envKey) for \(provider.rawValue)", level: .debug)
            return envValue
        }
        #endif
        
        return nil
    }

    func delete(for provider: AIProvider) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue
        ]
        SecItemDelete(query as CFDictionary)
        validationStates[provider] = .unknown
    }

    func hasKey(for provider: AIProvider) -> Bool { load(for: provider) != nil }

    // MARK: - Environment Variable Support
    
    private func environmentVariableName(for provider: AIProvider) -> String {
        switch provider {
        case .minimax:   return "MINIMAX_API_KEY"
        case .deepseek:  return "DEEPSEEK_API_KEY"
        case .openai:    return "OPENAI_API_KEY"
        case .anthropic: return "ANTHROPIC_API_KEY"
        case .gemini:    return "GEMINI_API_KEY"
        }
    }

    var hasAnyKey: Bool { AIProvider.allCases.contains { hasKey(for: $0) } }

    var firstAvailableProvider: AIProvider? { AIProvider.allCases.first { hasKey(for: $0) } }

    // MARK: - Validation

    /// Lightweight structural check (no network call).
    func quickValidate(key: String, for provider: AIProvider) -> Bool {
        let k = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return k.count >= 20 && k.hasPrefix(provider.keyPrefix)
    }

    /// Full async validation via a lightweight API call.
    func validate(for provider: AIProvider) async {
        guard let key = load(for: provider) else {
            validationStates[provider] = .invalid(reason: "No key saved")
            return
        }
        validationStates[provider] = .validating
        validationStates[provider] = await performNetworkValidation(key: key, provider: provider)
    }

    private func performNetworkValidation(key: String, provider: AIProvider) async -> KeyValidationState {
        switch provider {
        case .anthropic: return await validateAnthropic(key)
        case .openai:    return await validateOpenAI(key)
        case .gemini:    return await validateGemini(key)
        case .deepseek:  return await validateDeepSeek(key)
        case .minimax:   return quickValidate(key: key, for: .minimax) ? .valid : .invalid(reason: "Key format invalid")
        }
    }

    private func validateAnthropic(_ key: String) async -> KeyValidationState {
        guard var req = makeGET("https://api.anthropic.com/v1/models") else { return .invalid(reason: "Bad URL") }
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        return await checkHTTP(req)
    }

    private func validateOpenAI(_ key: String) async -> KeyValidationState {
        guard var req = makeGET("https://api.openai.com/v1/models") else { return .invalid(reason: "Bad URL") }
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        return await checkHTTP(req)
    }

    private func validateGemini(_ key: String) async -> KeyValidationState {
        guard let req = makeGET("https://generativelanguage.googleapis.com/v1beta/models?key=\(key)") else {
            return .invalid(reason: "Bad URL")
        }
        return await checkHTTP(req)
    }

    private func validateDeepSeek(_ key: String) async -> KeyValidationState {
        guard var req = makeGET("https://api.deepseek.com/models") else { return .invalid(reason: "Bad URL") }
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        return await checkHTTP(req)
    }

    private func makeGET(_ urlString: String) -> URLRequest? {
        guard let url = URL(string: urlString) else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.httpMethod = "GET"
        return req
    }

    private func checkHTTP(_ request: URLRequest) async -> KeyValidationState {
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
            case 200...299: return .valid
            case 401:       return .invalid(reason: "Unauthorized — check your key")
            case 403:       return .invalid(reason: "Forbidden — check permissions")
            case 429:       return .valid   // rate-limited = key is valid
            case let code:  return .invalid(reason: "HTTP \(code)")
            }
        } catch {
            return .invalid(reason: error.localizedDescription)
        }
    }
}
