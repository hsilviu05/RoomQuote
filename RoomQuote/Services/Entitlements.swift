import Foundation
import Observation

/// Product IDs and legal links for the subscription. Change these to match App Store Connect.
enum SubscriptionConfig {
    static let monthlyProductID = "com.hsilviu.roomquote.pro.monthly"
    static let yearlyProductID = "com.hsilviu.roomquote.pro.yearly"
    /// Shown until StoreKit returns localized prices.
    static let monthlyDisplayPrice = "$14.99"
    static let yearlyDisplayPrice = "$119.99"
    static let yearlyPerMonthDisplayPrice = "$10.00"
    static let trialDays = 7
    // Must point at pages you host before App Review (guideline 3.1.2).
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacyURL = URL(string: "https://example.com/roomquote/privacy")!
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
    case notConnected

    var errorDescription: String? {
        String(localized: "Subscriptions aren't available in this build yet.")
    }
}

// STUB: replaced by a StoreKit 2 implementation (Product.products, purchase(),
// Transaction.currentEntitlements, AppStore.sync()) in the paywall step.
@MainActor
@Observable
final class EntitlementStore {
    private(set) var isPro = false

    func purchase(productID: String) async throws {
        throw PurchaseError.notConnected
    }

    func restorePurchases() async throws {
        throw PurchaseError.notConnected
    }
}
