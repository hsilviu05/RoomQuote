import Foundation

extension Decimal {
    /// Rounds to `scale` decimal places. `.plain` is half-up (away from zero on a tie).
    public func rounded(scale: Int, mode: NSDecimalNumber.RoundingMode = .plain) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, scale, mode)
        return result
    }

    /// Money is always shown and summed at 2 decimal places, half-up.
    public var roundedToCents: Decimal { rounded(scale: 2) }

    /// Smallest whole number >= self, for counting cans and boxes.
    var ceilingToWhole: Decimal { rounded(scale: 0, mode: self < 0 ? .down : .up) }

    var intValue: Int { NSDecimalNumber(decimal: self).intValue }
}
