//
//  SubscriptionManager.swift
//  ScreenGrabber
//
//  StoreKit 2 auto-renewable subscription manager.
//  Configure product IDs in App Store Connect to match the constants below.
//

import Foundation
import StoreKit
import Combine

// MARK: - Product IDs

/// Replace these with your App Store Connect product identifiers.
enum SubscriptionProductID: String, CaseIterable {
    case monthlyPro = "com.screengrabber.aipro.monthly"
    case yearlyPro  = "com.screengrabber.aipro.yearly"
}

// MARK: - Plan Model

struct SubscriptionPlan: Identifiable {
    let product: Product
    var id: String { product.id }
    var isYearly: Bool { product.id == SubscriptionProductID.yearlyPro.rawValue }
    var displayPrice: String { product.displayPrice }
    var title: String { isYearly ? "Yearly" : "Monthly" }
    var savingsBadge: String? { isYearly ? "Best Value" : nil }
}

// MARK: - Manager

@MainActor
final class SubscriptionManager: ObservableObject {

    static let shared = SubscriptionManager()

    @Published var isSubscribed: Bool = false
    @Published var availablePlans: [SubscriptionPlan] = []
    @Published var expiresDate: Date?
    @Published var isLoading: Bool = false
    @Published var purchaseError: String?

    private var updateListenerTask: Task<Void, Never>?

    private init() {}

    // MARK: - Lifecycle

    func start() {
        startTransactionListener()
        Task { await loadProducts() }
        Task { await refreshStatus() }
    }

    func stop() {
        updateListenerTask?.cancel()
        updateListenerTask = nil
    }

    // MARK: - Products

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let ids = Set(SubscriptionProductID.allCases.map(\.rawValue))
            let products = try await Product.products(for: ids).sorted { $0.price < $1.price }
            availablePlans = products.map { SubscriptionPlan(product: $0) }
        } catch {
            CaptureLogger.log(.error, "StoreKit: failed to load products: \(error)", level: .error)
        }
    }

    // MARK: - Purchase

    func purchase(_ plan: SubscriptionPlan) async {
        purchaseError = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await plan.product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    purchaseError = "Transaction could not be verified with Apple."
                    return
                }
                await transaction.finish()
                await refreshStatus()
            case .userCancelled:
                break
            case .pending:
                purchaseError = "Purchase is pending approval."
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
            CaptureLogger.log(.error, "Purchase error: \(error)", level: .error)
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        purchaseError = nil
        do {
            try await AppStore.sync()
            await refreshStatus()
        } catch {
            purchaseError = error.localizedDescription
            CaptureLogger.log(.error, "Restore error: \(error)", level: .error)
        }
    }

    // MARK: - Status Refresh

    /// Re-checks all current entitlements from StoreKit and updates isSubscribed.
    func refreshStatus() async {
        var foundActive = false
        var latestExpiry: Date?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  SubscriptionProductID(rawValue: transaction.productID) != nil,
                  transaction.revocationDate == nil else { continue }

            if let expDate = transaction.expirationDate {
                guard expDate > Date() else { continue }
                foundActive = true
                if latestExpiry == nil || expDate > latestExpiry! { latestExpiry = expDate }
            } else {
                foundActive = true   // no expiry = perpetual (shouldn't occur for subscriptions)
            }
        }

        isSubscribed = foundActive
        expiresDate  = latestExpiry
    }

    // MARK: - Transaction Listener

    private func startTransactionListener() {
        updateListenerTask?.cancel()
        updateListenerTask = Task {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await refreshStatus()
                }
            }
        }
    }

    // MARK: - Computed

    var monthlyPlan: SubscriptionPlan? { availablePlans.first { !$0.isYearly } }
    var yearlyPlan:  SubscriptionPlan? { availablePlans.first {  $0.isYearly } }
}
