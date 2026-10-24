import Foundation

/// Flooring or tiles sold in packs (boxes) that each cover a fixed area.
public struct CoveringSpec: Hashable, Sendable {
    /// Extra on top for cuts and breakage, as a percentage.
    public var wastePercent: Decimal
    /// Square metres one box covers.
    public var packCoverage: Decimal

    public init(wastePercent: Decimal, packCoverage: Decimal) {
        self.wastePercent = wastePercent
        self.packCoverage = packCoverage
    }
}

public struct CoveringEstimate: Equatable, Sendable {
    /// Area to cover, before waste.
    public var area: Decimal
    /// Area to order, including waste.
    public var orderArea: Decimal
    public var packs: Int
}

extension Estimator {
    public static func covering(area: Decimal, spec: CoveringSpec) throws -> CoveringEstimate {
        try Validate.nonNegative(area, .quantity)
        try Validate.nonNegative(spec.wastePercent, .wastePercent)
        try Validate.positive(spec.packCoverage, .packCoverage)

        let orderArea = area * (1 + spec.wastePercent / 100)
        let packs = (orderArea / spec.packCoverage).ceilingToWhole.intValue
        return CoveringEstimate(area: area, orderArea: orderArea, packs: packs)
    }
}
