import Foundation
import Observation
import StoreKit

/// Product IDs and legal links for the subscription. Change these to match App Store Connect.
enum SubscriptionConfig {
    static let monthlyProductID = "com.hsilviu.roomquote.pro.monthly"
    static let yearlyProductID = "com.hsilviu.roomquote.pro.yearly"
    static var productIDs: [String] { [yearlyProductID, monthlyProductID] }
    // Both must open real pages before App Review (guideline 3.1.2).
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacyURL = URL(string: "https://hsilviu05.github.io/RoomQuote/privacy.html")!
}

/// Free plan: this many quotes per calendar month.
enum QuoteLimitPolicy {
    static let freeQuotesPerMonth = 3

    static func quotesCreatedThisMonth(_ dates: [Date], now: Date = .now, calendar: Calendar = .current) -> Int {
        dates.filter { calendar.isDate($0, equalTo: now, toGranularity: .month) }.count
    }

    static func canCreateQuote(isPro: Bool, createdDates: [Date], now: Date = .now, calendar: Calendar = .current) -> Bool {
        isPro || quotesCreatedThisMonth(createdDates, now: now, calendar: calendar) < freeQuotesPerMonth
    }
}

enum PurchaseError: LocalizedError {
    case productsUnavailable
    case failedVerification
    case pending

    var errorDescription: String? {
        switch self {
        case .productsUnavailable:
            String(localized: "Couldn't load subscription prices. Check your connection and try again.")
        case .failedVerification:
            String(localized: "The App Store couldn't verify this purchase.")
        case .pending:
            String(localized: "Your purchase is waiting for approval. Pro unlocks as soon as it's approved.")
        }
    }
}

/// Subscription state from StoreKit 2. All checks happen on the device against
/// App Store–signed transactions; there is no server.
@MainActor
@Observable
final class EntitlementStore {
    enum LoadState: Equatable { case idle, loading, loaded, failed }

    private(set) var isPro = false
    private(set) var products: [Product] = []
    private(set) var loadState: LoadState = .idle
    /// Whether the customer can still get the free trial in this subscription group.
    private(set) var isEligibleForTrial = true
    private var updatesTask: Task<Void, Never>?

    var monthly: Product? { products.first { $0.id == SubscriptionConfig.monthlyProductID } }
    var yearly: Product? { products.first { $0.id == SubscriptionConfig.yearlyProductID } }

    /// Call once at launch: listens for renewals, refunds and purchases made elsewhere.
    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }
        Task {
            await refreshEntitlements()
            await loadProducts()
        }
    }

    func loadProducts() async {
        guard loadState != .loading else { return }
        loadState = .loading
        do {
            let loaded = try await Product.products(for: SubscriptionConfig.productIDs)
            products = loaded.sorted { $0.price > $1.price }
            loadState = loaded.isEmpty ? .failed : .loaded
            if let subscription = loaded.first?.subscription {
                isEligibleForTrial = await subscription.isEligibleForIntroOffer
            }
        } catch {
            loadState = .failed
        }
    }

    /// Returns true when Pro is active afterwards; false if the user cancelled.
    @discardableResult
    func purchase(_ product: Product) async throws -> Bool {
        switch try await product.purchase() {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { throw PurchaseError.failedVerification }
            await transaction.finish()
            await refreshEntitlements()
            return isPro
        case .pending:
            throw PurchaseError.pending
        case .userCancelled:
            return false
        @unknown default:
            return false
        }
    }

    /// Restore Purchases: asks the App Store to sync, then re-reads entitlements.
    func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if Self.grantsPro(productID: transaction.productID, revocationDate: transaction.revocationDate,
                              expirationDate: transaction.expirationDate) {
                active = true
            }
        }
        isPro = active
    }

    nonisolated static func grantsPro(productID: String, revocationDate: Date?, expirationDate: Date?, now: Date = .now) -> Bool {
        guard SubscriptionConfig.productIDs.contains(productID), revocationDate == nil else { return false }
        if let expirationDate { return expirationDate > now }
        return true
    }
}
