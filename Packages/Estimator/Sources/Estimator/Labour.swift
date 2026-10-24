import Foundation

public enum LabourPricing: Hashable, Sendable {
    /// Rate per square metre of the area worked on.
    case perSquareMetre(rate: Decimal)
    /// Rate per hour for a fixed number of hours.
    case perHour(rate: Decimal, hours: Decimal)
}

extension Estimator {
    /// The labour line for a job. Per-m² quantity is rounded to 2 dp first,
    /// so the quantity shown on the quote times the rate equals the line total.
    public static func labourLine(_ pricing: LabourPricing, area: Decimal, title: String) throws -> LineItem {
        switch pricing {
        case let .perSquareMetre(rate):
            try Validate.nonNegative(rate, .labourRate)
            try Validate.nonNegative(area, .quantity)
            return LineItem(title: title, kind: .labour, quantity: area.rounded(scale: 2), unit: .squareMetre, unitPrice: rate)
        case let .perHour(rate, hours):
            try Validate.nonNegative(rate, .labourRate)
            try Validate.nonNegative(hours, .labourHours)
            return LineItem(title: title, kind: .labour, quantity: hours, unit: .hour, unitPrice: rate)
        }
    }
}
