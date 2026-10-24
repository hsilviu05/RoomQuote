import Foundation

public enum QuantityUnit: String, Sendable, CaseIterable, Codable {
    case litre, squareMetre, can, box, hour, item
}

public struct LineItem: Hashable, Sendable {
    public enum Kind: String, Sendable, CaseIterable, Codable {
        case material, labour, other
    }

    public var title: String
    public var kind: Kind
    public var quantity: Decimal
    public var unit: QuantityUnit
    public var unitPrice: Decimal

    public init(title: String, kind: Kind, quantity: Decimal, unit: QuantityUnit, unitPrice: Decimal) {
        self.title = title
        self.kind = kind
        self.quantity = quantity
        self.unit = unit
        self.unitPrice = unitPrice
    }

    public var total: Decimal { (quantity * unitPrice).roundedToCents }
}

public struct VATSetting: Hashable, Sendable {
    public var isEnabled: Bool
    /// Percentage, e.g. 20 for 20%.
    public var ratePercent: Decimal

    public init(isEnabled: Bool, ratePercent: Decimal) {
        self.isEnabled = isEnabled
        self.ratePercent = ratePercent
    }

    public static let off = VATSetting(isEnabled: false, ratePercent: 0)
}

public struct QuoteTotals: Equatable, Sendable {
    public var subtotal: Decimal
    public var vat: Decimal
    public var total: Decimal
}

extension Estimator {
    public static func totals(for lines: [LineItem], vat: VATSetting) throws -> QuoteTotals {
        for line in lines {
            try Validate.nonNegative(line.quantity, .quantity)
            try Validate.nonNegative(line.unitPrice, .unitPrice)
        }
        try Validate.nonNegative(vat.ratePercent, .vatRate)

        // Each line is rounded to cents before summing, matching what the quote shows.
        let subtotal = lines.reduce(Decimal(0)) { $0 + $1.total }
        let vatAmount = vat.isEnabled ? (subtotal * vat.ratePercent / 100).roundedToCents : 0
        return QuoteTotals(subtotal: subtotal, vat: vatAmount, total: subtotal + vatAmount)
    }
}
