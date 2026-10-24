import Foundation
@testable import Estimator

/// Builds a Decimal from a string so test values are exact (no Double rounding).
func d(_ string: String) -> Decimal {
    guard let value = Decimal(string: string, locale: Locale(identifier: "en_US_POSIX")) else {
        fatalError("Bad decimal literal: \(string)")
    }
    return value
}

/// The room from the product brief: 4.2 × 3.6 m, 2.6 m high, one door, two windows.
let sanityRoom = RoomDimensions(
    length: d("4.2"),
    width: d("3.6"),
    height: d("2.6"),
    openings: [
        Opening(kind: .door, width: d("0.9"), height: d("2.1")),
        Opening(kind: .window, width: d("1.2"), height: d("1.4"), quantity: 2)
    ]
)
