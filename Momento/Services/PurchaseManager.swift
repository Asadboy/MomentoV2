//
//  PurchaseManager.swift
//  Momento
//
//  Singleton wrapper around RevenueCat for in-app purchase management.
//  Handles premium event upgrades (non-consumable, one per event).
//

import Foundation
import RevenueCat

@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    @Published var isConfigured = false

    private init() {}

    // MARK: - Configuration

    func configure() {
        guard !isConfigured else { return }

        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: RevenueCatConfig.apiKey)

        isConfigured = true
        debugLog("✅ RevenueCat configured")
    }

    /// Link the current Supabase user ID to RevenueCat for cross-platform tracking
    func identify(userId: String) async {
        do {
            let (customerInfo, _) = try await Purchases.shared.logIn(userId)
            debugLog("✅ RevenueCat identified user: \(customerInfo.originalAppUserId)")
        } catch {
            debugLog("⚠️ RevenueCat identify failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Purchase

    /// Purchase premium for a specific event.
    /// Returns true on success. Throws on failure/cancellation.
    func purchasePremium(for eventId: String) async throws -> Bool {
        // Fetch available offerings
        let offerings = try await Purchases.shared.offerings()

        guard let offering = offerings.current,
              let package = offering.availablePackages.first else {
            throw PurchaseError.noProductsAvailable
        }

        // Present purchase (4.x API returns tuple)
        let (transaction, _, userCancelled) = try await Purchases.shared.purchase(package: package)

        if userCancelled {
            return false
        }

        // Purchase succeeded — mark event as premium in Supabase
        guard let eventUUID = UUID(uuidString: eventId) else {
            throw PurchaseError.invalidEventId
        }

        let transactionId = transaction?.transactionIdentifier ?? "unknown"

        try await SupabaseManager.shared.markEventPremium(
            eventId: eventUUID,
            transactionId: transactionId
        )

        // Track analytics
        AnalyticsManager.shared.track(.premiumPurchased, properties: [
            "event_id": eventId,
            "transaction_id": transactionId
        ])

        debugLog("✅ Premium purchased for event \(eventId)")
        return true
    }

    // MARK: - Restore

    func restorePurchases() async throws -> CustomerInfo {
        let customerInfo = try await Purchases.shared.restorePurchases()
        debugLog("✅ Purchases restored: \(customerInfo.entitlements.active.count) active")
        return customerInfo
    }

    // MARK: - Price

    /// Get the localized price string for display (e.g., "£7.99")
    func getLocalizedPrice() async -> String? {
        do {
            let offerings = try await Purchases.shared.offerings()
            return offerings.current?.availablePackages.first?.storeProduct.localizedPriceString
        } catch {
            debugLog("⚠️ Failed to fetch price: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Errors

enum PurchaseError: LocalizedError {
    case noProductsAvailable
    case invalidEventId

    var errorDescription: String? {
        switch self {
        case .noProductsAvailable:
            return "No products available. Please try again later."
        case .invalidEventId:
            return "Invalid event. Please try again."
        }
    }
}
