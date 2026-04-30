import Foundation
import StoreKit

// Local development reminder: in Xcode, set
// Run → Options → StoreKit Configuration → PullState.storekit
// so the tip product loads from Resources/PullState.storekit
// without needing a live App Store Connect entry.

/// StoreKit 2 wrapper for the single non-consumable "Buy Me a Coffee" tip. Loads
/// the product eagerly on init, runs verified purchases via async/await, and
/// exposes `hasPriorEntitlement()` so the About sheet can restore the tipped
/// state on a fresh install without forcing a re-purchase. No app feature is
/// gated behind this product.
@Observable
@MainActor
final class StoreManager {
    static let tipProductID = "com.badc0ffe.pullstate.tip"

    var product: Product?
    var purchaseInFlight = false
    var purchaseError: String?

    init() {
        Task { await loadProductIfNeeded() }
    }

    func loadProductIfNeeded() async {
        guard product == nil else { return }
        do {
            let products = try await Product.products(for: [Self.tipProductID])
            product = products.first
        } catch {
            purchaseError = "Couldn't load tip product."
        }
    }

    func hasPriorEntitlement() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let txn) = result, txn.productID == Self.tipProductID {
                return true
            }
        }
        return false
    }

    func purchase() async -> Bool {
        guard let product else { return false }
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    return true
                case .unverified:
                    purchaseError = "Couldn't verify the purchase."
                    return false
                }
            case .userCancelled:
                return false
            case .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            purchaseError = error.localizedDescription
            return false
        }
    }

    var displayPrice: String {
        product?.displayPrice ?? "$2.99"
    }
}
