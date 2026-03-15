//
//  PaywallView.swift
//  ScreenGrabber
//
//  Apple HIG-compliant paywall.  Shows IAP plans as primary upgrade path
//  with BYOK as a secondary option, per App Store Guideline 3.1.1.
//  No external payment links are shown.
//

import SwiftUI
import StoreKit

// MARK: - Feature Row Model

private struct AIFeatureRow: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
}

private let aiFeatures: [AIFeatureRow] = [
    AIFeatureRow(icon: "text.viewfinder",       title: "Smart OCR",              subtitle: "Extract text from any screenshot instantly"),
    AIFeatureRow(icon: "text.bubble.fill",       title: "AI Captions",            subtitle: "Auto-generate concise image descriptions"),
    AIFeatureRow(icon: "tag.fill",               title: "Smart Tags",             subtitle: "Keyword tags generated automatically"),
    AIFeatureRow(icon: "list.number",            title: "Tutorial Steps",         subtitle: "Turn UI screenshots into step-by-step guides"),
    AIFeatureRow(icon: "scissors",               title: "Remove Background",      subtitle: "Isolate subjects with one click (macOS 14+)"),
    AIFeatureRow(icon: "wand.and.stars",         title: "Auto-Enhance",           subtitle: "AI exposure, contrast & white balance fix"),
    AIFeatureRow(icon: "pencil.and.outline",     title: "Auto-Annotate",          subtitle: "Describe UI elements and positions automatically"),
    AIFeatureRow(icon: "eye.slash",              title: "Smart Blur",             subtitle: "Detect and redact sensitive info automatically"),
    AIFeatureRow(icon: "chevron.left.forwardslash.chevron.right", title: "Code Explain", subtitle: "Understand code visible in any screenshot"),
]

// MARK: - Paywall View

struct PaywallView: View {
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var entitlement = AIEntitlementManager.shared

    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlan: SubscriptionPlan?
    @State private var showBYOK = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                featureList
                planPicker
                actionButtons
                footer
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .frame(width: 480)
        .fixedSize(horizontal: true, vertical: false)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            if subscriptionManager.availablePlans.isEmpty {
                Task { await subscriptionManager.loadProducts() }
            }
            selectedPlan = subscriptionManager.yearlyPlan ?? subscriptionManager.monthlyPlan
        }
        .sheet(isPresented: $showBYOK) {
            BYOKSetupView()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.purple.opacity(0.8), Color.accentColor],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 72, height: 72)
                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }
            .shadow(color: Color.accentColor.opacity(0.3), radius: 12)

            Text("Unlock AI Features")
                .font(.system(size: 26, weight: .bold))

            Text("Supercharge your screenshots with AI-powered text extraction, captions, tags, and more.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 28)
    }

    // MARK: - Feature List

    private var featureList: some View {
        VStack(spacing: 0) {
            ForEach(aiFeatures) { feature in
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: feature.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .font(.system(size: 13, weight: .semibold))
                        Text(feature.subtitle)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 16))
                }
                .padding(.vertical, 8)

                if feature.id != aiFeatures.last?.id {
                    Divider().padding(.leading, 50)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .padding(.bottom, 24)
    }

    // MARK: - Plan Picker

    @ViewBuilder
    private var planPicker: some View {
        if subscriptionManager.isLoading {
            ProgressView("Loading plans…")
                .padding(.bottom, 24)
        } else if subscriptionManager.availablePlans.isEmpty {
            Text("Plans unavailable — check your internet connection.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 24)
        } else {
            VStack(spacing: 10) {
                ForEach(subscriptionManager.availablePlans) { plan in
                    PlanCard(plan: plan, isSelected: selectedPlan?.id == plan.id) {
                        selectedPlan = plan
                    }
                }
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Primary: Subscribe
            Button {
                guard let plan = selectedPlan else { return }
                Task { await subscriptionManager.purchase(plan) }
            } label: {
                Group {
                    if subscriptionManager.isLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(selectedPlan != nil
                             ? "Subscribe · \(selectedPlan!.displayPrice)"
                             : "Subscribe to AI Pro")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .font(.system(size: 15, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(selectedPlan == nil || subscriptionManager.isLoading)

            if let error = subscriptionManager.purchaseError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            // Secondary: Restore
            Button("Restore Purchases") {
                Task { await subscriptionManager.restorePurchases() }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundColor(.secondary)

            Divider()

            // BYOK option
            Button {
                showBYOK = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "key.fill")
                    Text("Use My Own API Key (BYOK)")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .font(.system(size: 13, weight: .medium))
            .help("Connect your own API key from OpenAI, Anthropic, Google Gemini, DeepSeek, or Minimax.")

            // Close / dismiss
            Button("Maybe Later") { dismiss() }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.bottom, 20)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 6) {
            Text("Subscriptions auto-renew unless cancelled at least 24 hours before the end of the period.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("Terms of Use",
                     destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Link("Privacy Policy",
                     destination: URL(string: "https://example.com/privacy")!)
            }
            .font(.system(size: 10))
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Plan Card

private struct PlanCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(plan.title)
                            .font(.system(size: 14, weight: .semibold))
                        if let badge = plan.savingsBadge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.green.opacity(0.18)))
                                .foregroundColor(.green)
                        }
                    }
                    Text(plan.isYearly ? "\(plan.displayPrice) / year" : "\(plan.displayPrice) / month")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .accentColor : Color(NSColor.tertiaryLabelColor))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                isSelected ? Color.accentColor : Color(NSColor.separatorColor),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - BYOK Setup View

struct BYOKSetupView: View {
    @ObservedObject private var keyManager = APIKeyManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProvider: AIProvider = .openai
    @State private var keyInput: String = ""
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add Your API Key")
                        .font(.headline)
                    Text("Your key is stored securely in the Keychain and never leaves your device.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    // Provider picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Provider").font(.caption).foregroundColor(.secondary)
                        Picker("Provider", selection: $selectedProvider) {
                            ForEach(AIProvider.allCases) { provider in
                                Text(provider.displayName).tag(provider)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedProvider) { _, _ in
                            keyInput = keyManager.load(for: selectedProvider) ?? ""
                        }
                    }

                    // Key input
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("API Key").font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Link("Get key ↗", destination: selectedProvider.documentationURL)
                                .font(.caption)
                        }
                        SecureField(selectedProvider.placeholder, text: $keyInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))

                        if !keyInput.isEmpty && !keyManager.quickValidate(key: keyInput, for: selectedProvider) {
                            Label("Key format looks incorrect for \(selectedProvider.displayName)", systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }

                    // Validation state
                    if case .validating = keyManager.validationStates[selectedProvider] ?? .unknown {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.mini)
                            Text("Validating…").font(.caption).foregroundColor(.secondary)
                        }
                    } else if let state = keyManager.validationStates[selectedProvider] {
                        switch state {
                        case .valid:
                            Label(state.statusText, systemImage: "checkmark.circle.fill")
                                .font(.caption).foregroundColor(.green)
                        case .invalid(let reason):
                            Label("Invalid – \(reason)", systemImage: "xmark.circle.fill")
                                .font(.caption).foregroundColor(.red)
                        default:
                            EmptyView()
                        }
                    }

                    // Action buttons
                    HStack(spacing: 12) {
                        if keyManager.hasKey(for: selectedProvider) {
                            Button("Remove Key", role: .destructive) {
                                keyManager.delete(for: selectedProvider)
                                keyInput = ""
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        Spacer()

                        Button("Validate") {
                            Task { await keyManager.validate(for: selectedProvider) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(keyInput.isEmpty)

                        Button(isSaving ? "Saving…" : "Save Key") {
                            isSaving = true
                            keyManager.save(key: keyInput, for: selectedProvider)
                            Task {
                                await keyManager.validate(for: selectedProvider)
                                isSaving = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(keyInput.isEmpty || isSaving)
                    }

                    // Existing keys summary
                    let savedProviders = AIProvider.allCases.filter { keyManager.hasKey(for: $0) }
                    if !savedProviders.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Saved Keys").font(.caption).foregroundColor(.secondary)
                            ForEach(savedProviders) { provider in
                                HStack(spacing: 8) {
                                    Image(systemName: "key.fill")
                                        .font(.caption)
                                        .foregroundColor(.accentColor)
                                    Text(provider.displayName)
                                        .font(.system(size: 12, weight: .medium))
                                    Spacer()
                                    let state = keyManager.validationStates[provider] ?? .unknown
                                    Text(state.statusText)
                                        .font(.caption)
                                        .foregroundColor(state.isValid ? .green : .secondary)
                                }
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color(NSColor.controlBackgroundColor)))
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 440, height: 520)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            keyInput = keyManager.load(for: selectedProvider) ?? ""
        }
    }
}

// MARK: - Paywall Sheet Modifier

extension View {
    /// Presents the paywall as a sheet when `AIEntitlementManager.showPaywall` is true.
    func aiPaywall() -> some View {
        self.modifier(AIPaywallModifier())
    }
}

private struct AIPaywallModifier: ViewModifier {
    @ObservedObject private var entitlement = AIEntitlementManager.shared

    func body(content: Content) -> some View {
        content.sheet(isPresented: $entitlement.showPaywall) {
            PaywallView()
        }
    }
}
