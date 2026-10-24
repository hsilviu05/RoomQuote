import Foundation
import StoreKit
import StoreKitTest
import Testing
@testable import RoomQuote

@Suite("Subscription maths")
struct PaywallMathTests {
    @Test("$119.99 a year vs $14.99 a month saves 33%")
    func designPrices() {
        #expect(PaywallMath.savingsPercent(yearly: Decimal(string: "119.99")!, monthly: Decimal(string: "14.99")!) == 33)
    }

    @Test("No badge when the year isn't cheaper")
    func noSaving() {
        #expect(PaywallMath.savingsPercent(yearly: 180, monthly: 15) == nil)
        #expect(PaywallMath.savingsPercent(yearly: 100, monthly: 0) == nil)
    }

    @Test("Entitlement rules: right product, not revoked, not expired")
    func grantsPro() {
        let now = Date.now
        let id = SubscriptionConfig.monthlyProductID
        #expect(EntitlementStore.grantsPro(productID: id, revocationDate: nil, expirationDate: now.addingTimeInterval(60), now: now))
        #expect(!EntitlementStore.grantsPro(productID: id, revocationDate: nil, expirationDate: now.addingTimeInterval(-60), now: now))
        #expect(!EntitlementStore.grantsPro(productID: id, revocationDate: now, expirationDate: now.addingTimeInterval(60), now: now))
        #expect(!EntitlementStore.grantsPro(productID: "other.product", revocationDate: nil, expirationDate: nil, now: now))
    }
}

/// Runs real StoreKit flows against StoreKit/RoomQuote.storekit, locally, with no App Store account.
/// One sequential test, because the test session's purchase history is shared state.
/// Opt-in: after this test the simulator's test runner takes about 10 minutes to exit (an
/// SKTestSession quirk seen with Xcode 27.0), so the default run skips it. Run it with:
/// TEST_RUNNER_RUN_STOREKIT_TESTS=1 xcodebuild test …
@MainActor
@Test("Load products, buy with a free trial, and see Pro from a fresh store",
      .enabled(if: ProcessInfo.processInfo.environment["RUN_STOREKIT_TESTS"] == "1"))
func storeKitFlow() async throws {
    let url = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "StoreKit/RoomQuote.storekit")
    try #require(FileManager.default.fileExists(atPath: url.path(percentEncoded: false)), "Missing \(url)")
    let session = try SKTestSession(contentsOf: url)
    session.disableDialogs = true
    session.clearTransactions()
    defer { session.clearTransactions() }

    let store = EntitlementStore()
    await store.loadProducts()
    #expect(store.loadState == .loaded)
    let yearly = try #require(store.yearly)
    let monthly = try #require(store.monthly)
    #expect(yearly.price == Decimal(string: "119.99"))
    #expect(monthly.price == Decimal(string: "14.99"))
    let offer = try #require(yearly.subscription?.introductoryOffer)
    #expect(offer.paymentMode == .freeTrial)
    #expect(offer.period.days * offer.periodCount == 7)

    await store.refreshEntitlements()
    #expect(!store.isPro)
    #expect(try await store.purchase(yearly))
    #expect(store.isPro)
    #expect(QuoteLimitPolicy.canCreateQuote(isPro: store.isPro, createdDates: Array(repeating: .now, count: 10)))

    // What a reinstall or second device sees after Restore Purchases.
    let fresh = EntitlementStore()
    await fresh.refreshEntitlements()
    #expect(fresh.isPro)
}
