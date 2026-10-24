import Foundation
import SwiftData
import Estimator

@Model
final class Quote {
    var number: Int = 0
    var statusRaw: String = QuoteStatus.draft.rawValue
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var sentAt: Date?
    var validUntil: Date?
    var vatEnabled: Bool = false
    var vatRatePercent: Decimal = 0
    var notes: String = ""
    /// Cached grand total for list screens; recomputed whenever line items change.
    var cachedTotal: Decimal = 0

    var client: Client?

    @Relationship(deleteRule: .cascade, inverse: \Job.quote)
    var jobs: [Job]? = []

    @Relationship(deleteRule: .cascade, inverse: \LineItem.quote)
    var lineItems: [LineItem]? = []

    init(number: Int, client: Client? = nil, vat: VATSetting = .off) {
        self.number = number
        self.client = client
        self.vatEnabled = vat.isEnabled
        self.vatRatePercent = vat.ratePercent
    }

    var status: QuoteStatus {
        get { QuoteStatus(rawValue: statusRaw) ?? .draft }
        set {
            statusRaw = newValue.rawValue
            if newValue != .draft, sentAt == nil { sentAt = .now }
            updatedAt = .now
        }
    }

    /// This MVP has one job (one room) per quote.
    var job: Job? { jobs?.first }
    var room: Room? { job?.room }

    var sortedLineItems: [LineItem] {
        (lineItems ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    var vatSetting: VATSetting {
        VATSetting(isEnabled: vatEnabled, ratePercent: vatRatePercent)
    }

    var displayNumber: String { String(format: "#%04d", number) }

    func totals() throws -> QuoteTotals {
        try Estimator.totals(for: sortedLineItems.map(\.estimatorLineItem), vat: vatSetting)
    }

    /// Recomputes the cached total after line items change.
    func refreshTotal() throws {
        cachedTotal = try totals().total
        updatedAt = .now
    }
}

@Model
final class LineItem {
    var title: String = ""
    var detail: String = ""
    var kindRaw: String = PricedLine.Kind.other.rawValue
    var quantity: Decimal = 0
    var unitRaw: String = QuantityUnit.item.rawValue
    var unitPrice: Decimal = 0
    var sortOrder: Int = 0
    /// Generated lines (main material, labour) are rebuilt on every recalculation;
    /// extras the user added from the price list are kept.
    var isGenerated: Bool = false
    /// How the line reads on the quote document ("Wall paint, 2 × 5 L").
    var summary: String = ""
    var quote: Quote?

    init(item: PricedLine, detail: String = "", summary: String = "", isGenerated: Bool = false, sortOrder: Int) {
        self.title = item.title
        self.detail = detail
        self.summary = summary.isEmpty ? item.title : summary
        self.isGenerated = isGenerated
        self.kindRaw = item.kind.rawValue
        self.quantity = item.quantity
        self.unitRaw = item.unit.rawValue
        self.unitPrice = item.unitPrice
        self.sortOrder = sortOrder
    }

    var estimatorLineItem: PricedLine {
        PricedLine(
            title: title,
            kind: PricedLine.Kind(rawValue: kindRaw) ?? .other,
            quantity: quantity,
            unit: QuantityUnit(rawValue: unitRaw) ?? .item,
            unitPrice: unitPrice
        )
    }

    var total: Decimal { estimatorLineItem.total }
}
