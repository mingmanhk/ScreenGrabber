//
//  AIEntitlementManager.swift
//  ScreenGrabber
//
//  Central AI entitlement gate. Every AI feature MUST call
//  AIEntitlementManager.shared.requireEntitlement() before running.
//
//  Entitlement is granted when:
//    1. The user has an active SubscriptionManager IAP subscription, OR
//    2. The user has saved at least one valid BYOK API key.
//
//  If neither condition is met, showPaywall is set to true.
//

import SwiftUI
import Combine

// MARK: - Entitlement Types

enum AIEntitlementSource {
    case subscription
    case byok(provider: AIProvider)
}

enum AIEntitlementResult {
    case allowed(source: AIEntitlementSource)
    case denied

    var isAllowed: Bool {
        if case .allowed = self { return true }
        return false
    }

    var source: AIEntitlementSource? {
        if case .allowed(let s) = self { return s }
        return nil
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

    func checkEntitlement() -> AIEntitlementResult {
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

    var isEntitled: Bool { checkEntitlement().isAllowed }

    /// Gate for AI features. Returns true if entitled; shows paywall and returns false if not.
    @discardableResult
    func requireEntitlement() -> Bool {
        let result = checkEntitlement()
        entitlementResult = result
        if case .denied = result {
            showPaywall = true
            return false
        }
        return true
    }

    // MARK: - UI Helpers

    var badgeText: String {
        switch checkEntitlement() {
        case .allowed(let source):
            switch source {
            case .subscription:   return "AI Pro"
            case .byok:           return "AI BYOK"
            }
        case .denied:             return "Upgrade"
        }
    }

    var badgeColor: Color {
        switch checkEntitlement() {
        case .allowed: return .green
        case .denied:  return .orange
        }
    }

    var badgeIcon: String {
        switch checkEntitlement() {
        case .allowed: return "sparkles"
        case .denied:  return "lock.fill"
        }
    }

    var activeProviderName: String? {
        guard case .allowed(let source) = checkEntitlement() else { return nil }
        switch source {
        case .subscription:       return "AI Pro"
        case .byok(let provider): return provider.displayName
        }
    }

    // MARK: - Reactive Updates

    private func bindObservers() {
        SubscriptionManager.shared.$isSubscribed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.entitlementResult = self?.checkEntitlement() ?? .denied
            }
            .store(in: &cancellables)

        APIKeyManager.shared.$validationStates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.entitlementResult = self?.checkEntitlement() ?? .denied
            }
            .store(in: &cancellables)
    }
}

// MARK: - Reusable Badge View

struct AIEntitlementBadge: View {
    @ObservedObject private var entitlement = AIEntitlementManager.shared

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: entitlement.badgeIcon)
                .font(.system(size: 9, weight: .bold))
            Text(entitlement.badgeText)
                .font(.system(size: 10, weight: .semibold))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(entitlement.badgeColor.opacity(0.12)))
        .overlay(Capsule().strokeBorder(entitlement.badgeColor.opacity(0.35), lineWidth: 1))
        .foregroundColor(entitlement.badgeColor)
    }
}

// MARK: - Locked Feature Overlay

/// Overlay a lock icon + "AI Pro" badge on any view when not entitled.
struct AILockedOverlay: View {
    @ObservedObject private var entitlement = AIEntitlementManager.shared
    let onTap: () -> Void

    var body: some View {
        if !entitlement.isEntitled {
            Button(action: onTap) {
                ZStack {
                    Color.black.opacity(0.35)
                    VStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                        Text("AI Pro")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}
