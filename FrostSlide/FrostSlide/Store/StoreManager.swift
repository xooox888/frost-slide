import Combine
import Foundation
import StoreKit

/// The game's one purchase: a non-consumable "Remove Ads" that switches off the menu banners
/// and the full-screen ads between screens. The optional rewarded refill stays, because the
/// player asks for it.
///
/// This file deliberately does not import SwiftUI: SwiftUI has its own `Transaction` type, which
/// would make StoreKit's ambiguous here.
@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    /// Create a non-consumable in-app purchase with this product ID in App Store Connect.
    static let removeAdsProductID = "com.frostslide.FrostSlide.removeads"

    enum Busy: Equatable {
        case none
        case buying
        case restoring
    }

    /// Cached between launches so a paying player never sees an ad flash up while StoreKit starts.
    @Published private(set) var adsRemoved: Bool
    /// Localised price for the button, once the App Store has answered.
    @Published private(set) var price: String?
    @Published private(set) var busy: Busy = .none
    /// A short result for the settings card ("Purchase restored", "Waiting for approval", ...).
    @Published private(set) var message: String?

    private static let cacheKey = "frostslide.adsRemoved"
    private let defaults: UserDefaults
    private var product: Product?
    private var updatesTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        adsRemoved = defaults.bool(forKey: Self.cacheKey)
    }

    /// Starts listening for transactions (purchases made elsewhere, Ask to Buy approvals,
    /// refunds), then loads the product and checks what the player already owns.
    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task {
            await loadProduct()
            await refreshEntitlements()
        }
    }

    func purchase() async {
        guard busy == .none else { return }
        if product == nil {
            await loadProduct()
        }
        guard let product else {
            message = "The App Store isn't available right now. Please try again in a moment."
            return
        }
        busy = .buying
        message = nil
        defer { busy = .none }
        do {
            switch try await product.purchase() {
            case .success(let result):
                if await handle(result) {
                    message = "Thank you! Ads are removed."
                    Analytics.track(.adsRemoved)
                } else {
                    message = "The purchase couldn't be verified."
                }
            case .pending:
                message = "Waiting for approval. Ads go away once the purchase is approved."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = "The purchase didn't go through. Please try again."
        }
    }

    /// Asks the App Store for the player's purchases again (required for apps with in-app purchases).
    func restore() async {
        guard busy == .none else { return }
        busy = .restoring
        message = nil
        defer { busy = .none }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            message = adsRemoved ? "Purchase restored. Ads are removed." : "No earlier purchase was found for this Apple ID."
        } catch StoreKitError.userCancelled {
            // The player backed out of the sign-in prompt.
        } catch {
            message = "Couldn't reach the App Store. Please try again."
        }
    }

    private func loadProduct() async {
        do {
            product = try await Product.products(for: [Self.removeAdsProductID]).first
            price = product?.displayPrice
        } catch {
            product = nil
            price = nil
        }
    }

    /// Only ever switches ads off: a refund arrives as a revoked transaction through `handle`,
    /// so an offline launch can't wrongly bring the ads back for someone who paid.
    private func refreshEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.removeAdsProductID,
               transaction.revocationDate == nil {
                setAdsRemoved(true)
            }
        }
    }

    /// Returns whether the transaction passed StoreKit's signature check.
    @discardableResult
    private func handle(_ result: VerificationResult<Transaction>) async -> Bool {
        switch result {
        case .unverified:
            return false
        case .verified(let transaction):
            if transaction.productID == Self.removeAdsProductID {
                setAdsRemoved(transaction.revocationDate == nil)
            }
            await transaction.finish()
            return true
        }
    }

    private func setAdsRemoved(_ removed: Bool) {
        guard removed != adsRemoved else { return }
        adsRemoved = removed
        defaults.set(removed, forKey: Self.cacheKey)
    }
}
