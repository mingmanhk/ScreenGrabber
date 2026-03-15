import SwiftUI
import Combine

// MARK: - Entitlement Types

enum AIEntitlementSource {
    case subscription
    case byok(provider: AIProvider)
    case local  // For features that work without API (Vision, Core Image)
}

enum AIEntitlementResult {
    case allowed(source: AIEntitlementSource)
    case denied

    var isAllowed: Bool {
        if case .allowed = self { return true }
        return false
    }
}

// MARK: - Manager

@MainActor
final class AIEntitlementManager: ObservableObject {

    static let shared = AIEntitlementManager()

    @Published var entitlementResult: AIEntitlementResult = .denied
    @Published var showPaywall: Bool = false

    private var cancellables = Set<AnyCancellable>()

    private init() {
        bindObservers()
        entitlementResult = checkEntitlement()
    }

    // MARK: - Check (synchronous, real-time)

    /// Check entitlement for a specific feature
    func checkEntitlement(for feature: AIFeature? = nil) -> AIEntitlementResult {
        // Check if this is a local feature that doesn't require entitlement
        if let feature = feature, isLocalFeature(feature) {
            return .allowed(source: .local)
        }
        
        // Priority 1: Active IAP subscription
        if SubscriptionManager.shared.isSubscribed {
            return .allowed(source: .subscription)
        }
        
        // Priority 2: Any saved BYOK key
        for provider in AIProvider.allCases where APIKeyManager.shared.hasKey(for: provider) {
            return .allowed(source: .byok(provider: provider))
        }
        
        return .denied
    }
    
    /// Check if a feature works locally without API calls
    private func isLocalFeature(_ feature: AIFeature) -> Bool {
        switch feature {
        case .ocr, .removeBackground, .autoEnhance:
            return true
        default:
            return false
        }
    }

    // MARK: - Observers

    private func bindObservers() {
        SubscriptionManager.shared.$isSubscribed
            .sink { [weak self] _ in
                self?.entitlementResult = self?.checkEntitlement() ?? .denied
            }
            .store(in: &cancellables)

        APIKeyManager.shared.objectWillChange
            .sink { [weak self] _ in
                self?.entitlementResult = self?.checkEntitlement() ?? .denied
            }
            .store(in: &cancellables)
    }

    // MARK: - UI Helpers

    var entitlementDisplayText: String {
        switch entitlementResult {
        case .allowed(let source):
            switch source {
            case .subscription:   return "AI Pro"
            case .byok:           return "AI BYOK"
            case .local:          return "Local AI"
            }
        case .denied:             return "AI Locked"
        }
    }

    var entitlementSourceName: String {
        switch entitlementResult {
        case .allowed(let source):
            switch source {
            case .subscription:       return "AI Pro"
            case .byok(let provider): return provider.displayName
            case .local:              return "Local Processing"
            }
        case .denied:                 return "Not Available"
        }
    }

    func showPaywallIfNeeded(for feature: AIFeature) -> Bool {
        let result = checkEntitlement(for: feature)
        if !result.isAllowed {
            showPaywall = true
            return true
        }
        return false
    }
}
