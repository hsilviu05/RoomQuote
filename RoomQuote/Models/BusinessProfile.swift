import Foundation
import SwiftData
import Estimator

/// The tradesperson's own details, printed on every quote. One record per store.
@Model
final class BusinessProfile {
    var name: String = ""
    var phone: String = ""
    var email: String = ""
    var address: String = ""
    var vatNumber: String = ""
    @Attribute(.externalStorage) var logo: Data?
    /// ISO 4217 code, e.g. "RON".
    var currencyCode: String = "RON"
    var unitSystemRaw: String = UnitSystem.metric.rawValue
    var vatEnabled: Bool = false
    var vatRatePercent: Decimal = 19
    var quoteValidityDays: Int = 14
    var terms: String = ""
    var nextQuoteNumber: Int = 1

    init() {}

    var unitSystem: UnitSystem {
        get { UnitSystem(rawValue: unitSystemRaw) ?? .metric }
        set { unitSystemRaw = newValue.rawValue }
    }

    var vatSetting: VATSetting {
        VATSetting(isEnabled: vatEnabled, ratePercent: vatRatePercent)
    }

    /// Returns the next quote number and advances the counter.
    func takeQuoteNumber() -> Int {
        let number = max(nextQuoteNumber, 1)
        nextQuoteNumber = number + 1
        return number
    }

    /// Fetches the single profile, creating it on first use.
    static func current(in context: ModelContext) throws -> BusinessProfile {
        var descriptor = FetchDescriptor<BusinessProfile>()
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let profile = BusinessProfile()
        context.insert(profile)
        return profile
    }
}
