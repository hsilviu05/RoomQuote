import Foundation

public struct PaintSpec: Hashable, Sendable {
    public var coats: Int
    /// Square metres one litre covers, per coat.
    public var coveragePerLitre: Decimal
    /// Extra on top, as a percentage (10 means +10%).
    public var wastePercent: Decimal
    /// Litres per can.
    public var canSize: Decimal

    public init(coats: Int, coveragePerLitre: Decimal, wastePercent: Decimal, canSize: Decimal) {
        self.coats = coats
        self.coveragePerLitre = coveragePerLitre
        self.wastePercent = wastePercent
        self.canSize = canSize
    }
}

public struct PaintEstimate: Equatable, Sendable {
    /// Exact litres needed including waste. Use `litresForDisplay` in the UI.
    public var litres: Decimal
    public var cans: Int
    public var warnings: [EstimatorWarning]

    public var litresForDisplay: Decimal { litres.rounded(scale: 2) }
}

extension Estimator {
    public static func paint(area: Decimal, spec: PaintSpec) throws -> PaintEstimate {
        try Validate.nonNegative(area, .quantity)
        try Validate.nonNegative(spec.coats, .coats)
        try Validate.positive(spec.coveragePerLitre, .coverage)
        try Validate.nonNegative(spec.wastePercent, .wastePercent)
        try Validate.positive(spec.canSize, .canSize)

        guard spec.coats > 0 else {
            return PaintEstimate(litres: 0, cans: 0, warnings: [.noCoats])
        }
        let base = area * Decimal(spec.coats) / spec.coveragePerLitre
        let litres = base * (1 + spec.wastePercent / 100)
        // Cans are counted from the exact amount, so 10.00 L in 5 L cans is 2, not 3.
        let cans = (litres / spec.canSize).ceilingToWhole.intValue
        return PaintEstimate(litres: litres, cans: cans, warnings: [])
    }
}
