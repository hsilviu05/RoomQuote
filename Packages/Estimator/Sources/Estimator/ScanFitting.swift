import Foundation

extension RoomDimensions {
    /// Builds an equivalent rectangle for a scanned room of any shape.
    ///
    /// Estimator works with length × width rooms. For an L-shaped or angled room we pick
    /// the rectangle with the same perimeter (so wall area is exact) and the same floor
    /// area (so flooring is exact): L + W = perimeter / 2 and L × W = floor area.
    /// If the floor area is larger than any rectangle with that perimeter can hold
    /// (scan noise), it falls back to a square, keeping the wall area exact.
    public static func fittedToScan(
        perimeter: Decimal,
        floorArea: Decimal,
        height: Decimal,
        openings: [OpeningDimensions]
    ) throws -> RoomDimensions {
        try Validate.nonNegative(perimeter, .roomLength)
        try Validate.nonNegative(floorArea, .roomWidth)
        try Validate.nonNegative(height, .roomHeight)

        let halfPerimeter = perimeter / 2
        let discriminant = halfPerimeter * halfPerimeter - 4 * floorArea
        let length: Decimal
        let width: Decimal
        if discriminant > 0 {
            let root = Decimal(sqrt(NSDecimalNumber(decimal: discriminant).doubleValue))
            length = ((halfPerimeter + root) / 2).rounded(scale: 3)
            width = halfPerimeter - length
        } else {
            length = (halfPerimeter / 2).rounded(scale: 3)
            width = halfPerimeter - length
        }
        return RoomDimensions(length: length, width: width, height: height, openings: openings)
    }

    /// Area of a floor outline (shoelace formula). Points are (x, z) in metres, in order.
    public static func polygonArea(_ points: [(x: Double, z: Double)]) -> Decimal {
        guard points.count >= 3 else { return 0 }
        var sum = 0.0
        for index in points.indices {
            let a = points[index]
            let b = points[(index + 1) % points.count]
            sum += a.x * b.z - b.x * a.z
        }
        return Decimal(abs(sum) / 2).rounded(scale: 3)
    }
}
