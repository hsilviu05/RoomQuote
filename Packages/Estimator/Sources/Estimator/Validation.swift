import Foundation

/// The input field a validation error refers to, so the UI can highlight it.
public enum EstimatorField: String, Sendable, CaseIterable {
    case roomLength, roomWidth, roomHeight
    case openingWidth, openingHeight, openingQuantity
    case coats, coverage, canSize, wastePercent, packCoverage
    case labourRate, labourHours
    case quantity, unitPrice, vatRate
}

public enum EstimatorError: Error, Equatable, Sendable {
    /// The value is below zero.
    case negative(EstimatorField)
    /// The value must be strictly greater than zero (it is used as a divisor).
    case notPositive(EstimatorField)
}

/// Non-fatal problems: the estimate is still produced, but the user should see these.
public enum EstimatorWarning: Equatable, Hashable, Sendable {
    /// The opening at this index was bigger than the wall it sits in and was clamped.
    case openingClamped(index: Int)
    /// Openings cover more than the total wall area; net wall area was clamped to zero.
    case openingsExceedWallArea
    /// Zero coats were requested, so no paint is needed.
    case noCoats
}

enum Validate {
    static func nonNegative(_ value: Decimal, _ field: EstimatorField) throws {
        if value < 0 { throw EstimatorError.negative(field) }
    }

    static func nonNegative(_ value: Int, _ field: EstimatorField) throws {
        if value < 0 { throw EstimatorError.negative(field) }
    }

    static func positive(_ value: Decimal, _ field: EstimatorField) throws {
        if value < 0 { throw EstimatorError.negative(field) }
        if value == 0 { throw EstimatorError.notPositive(field) }
    }
}
