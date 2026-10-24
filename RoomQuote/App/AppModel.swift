import SwiftUI
import Observation

enum Route: Hashable {
    case scan
    case manualEntry
    case materials(Quote)
    case quote(Quote)
    case allQuotes(focusSearch: Bool)
}

enum AppTab: Hashable {
    case quotes, clients, prices, settings
}

/// App-wide state: navigation and services shared by every screen.
@MainActor
@Observable
final class AppModel {
    var selectedTab: AppTab = .quotes
    var quotesPath: [Route] = []
    var isPaywallPresented = false
    let entitlements = EntitlementStore()
    let scanMode = ScanMode.current

    /// Starts the new-quote flow, or shows the paywall when the free limit is used up.
    func startNewQuote(createdDates: [Date]) {
        guard QuoteLimitPolicy.canCreateQuote(isPro: entitlements.isPro, createdDates: createdDates) else {
            isPaywallPresented = true
            return
        }
        quotesPath.append(.scan)
    }

    /// After the room is saved, replace the scan/entry screens so Back goes home.
    func showMaterials(for quote: Quote) {
        quotesPath = [.materials(quote)]
    }
}
