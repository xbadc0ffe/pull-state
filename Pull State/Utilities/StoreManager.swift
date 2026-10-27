import Foundation
import StoreKit

/// StoreKit 2 wrapper for the single non-consumable "Buy Me a Coffee" tip.
/// One instance lives for the whole app (created in `Pull_StateApp`, injected
/// via `.environment`). It:
///   • listens to `Transaction.updates` from launch, so purchases that resolve
///     outside the purchase call (Ask to Buy, interrupted purchases, refunds)
///     are observed and finished;
///   • re-derives `tipEntitled` from `Transaction.currentEntitlements` at
///     launch and on restore — `AppSettings.hasTipped` is only a UI cache of it;
///   • loads the product lazily and treats a load failure (offline, product
///     not yet live) as "price unavailable", not as an error to display.
/// No app feature is gated behind this product.
///
/// Local testing: select `Resources/PullState.storekit` under the scheme's
/// Run → Options → StoreKit Configuration (already saved in the shared scheme).
@Observable
@MainActor
final class StoreManager {
    static let tipProductID = "com.badc0ffe.pullstate.tip"

    private(set) var product: Product?
    private(set) var purchaseInFlight = false
    private(set) var restoreInFlight = false
    /// Set only by a failed purchase attempt; cleared on the next attempt.
    private(set) var purchaseError: String?
    /// True when a verified, unrevoked tip transaction exists.
    private(set) var tipEntitled = false

    enum RestoreOutcome {
        case restored, nothingToRestore, cancelled, failed
    }

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                await self.handle(result)
            }
        }
        Task {
            await loadProductIfNeeded()
            tipEntitled = await hasPriorEntitlement()
        }
    }

    func loadProductIfNeeded() async {
        guard product == nil else { return }
        product = try? await Product.products(for: [Self.tipProductID]).first
    }

    func hasPriorEntitlement() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let txn) = result,
               txn.productID == Self.tipProductID,
               txn.revocationDate == nil {
                return true
            }
        }
        return false
    }

    /// Forces a sync with the App Store, then re-reads the tip's entitlement.
    /// A cancelled sign-in prompt is reported as `.cancelled`, not a failure.
    func restore() async -> RestoreOutcome {
        restoreInFlight = true
        defer { restoreInFlight = false }
        do {
            try await AppStore.sync()
        } catch StoreKitError.userCancelled {
            return .cancelled
        } catch {
            return .failed
        }
        tipEntitled = await hasPriorEntitlement()
        return tipEntitled ? .restored : .nothingToRestore
    }

    /// Runs the purchase flow. Returns true only for a verified, finished
    /// transaction; `.pending` resolves later through `Transaction.updates`.
    func purchase() async -> Bool {
        purchaseError = nil
        await loadProductIfNeeded()
        guard let product else {
            purchaseError = "The tip jar isn't available right now."
            return false
        }
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    tipEntitled = true
                    return true
                case .unverified:
                    purchaseError = "Couldn't verify the purchase."
                    return false
                }
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            purchaseError = error.localizedDescription
            return false
        }
    }

    /// Localized price from the store, or nil when the product hasn't loaded.
    var displayPrice: String? {
        product?.displayPrice
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let txn) = result else { return }
        if txn.productID == Self.tipProductID {
            tipEntitled = txn.revocationDate == nil
        }
        await txn.finish()
    }
}
