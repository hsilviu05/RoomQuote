import Foundation

/// A door, window or other gap in the walls. Sizes are in metres.
public struct OpeningDimensions: Hashable, Sendable {
    public enum Kind: String, Sendable, CaseIterable, Codable {
        case door, window, other
    }

    public var kind: Kind
    public var width: Decimal
    public var height: Decimal
    public var quantity: Int

    public init(kind: Kind, width: Decimal, height: Decimal, quantity: Int = 1) {
        self.kind = kind
        self.width = width
        self.height = height
        self.quantity = quantity
    }
}

/// A rectangular room. Sizes are in metres.
public struct RoomDimensions: Hashable, Sendable {
    public var length: Decimal
    public var width: Decimal
    public var height: Decimal
    public var openings: [OpeningDimensions]

    public init(length: Decimal, width: Decimal, height: Decimal, openings: [OpeningDimensions] = []) {
        self.length = length
        self.width = width
        self.height = height
        self.openings = openings
    }

    public var perimeter: Decimal { 2 * (length + width) }
}

public struct WallArea: Equatable, Sendable {
    /// Perimeter × height, before openings.
    public var gross: Decimal
    /// Total area of openings after clamping.
    public var openings: Decimal
    /// Area to cover: gross − openings, never below zero.
    public var net: Decimal
    public var warnings: [EstimatorWarning]
}

extension Estimator {
    public static func validate(_ room: RoomDimensions) throws {
        try Validate.nonNegative(room.length, .roomLength)
        try Validate.nonNegative(room.width, .roomWidth)
        try Validate.nonNegative(room.height, .roomHeight)
        for opening in room.openings {
            try Validate.nonNegative(opening.width, .openingWidth)
            try Validate.nonNegative(opening.height, .openingHeight)
            try Validate.nonNegative(opening.quantity, .openingQuantity)
        }
    }

    public static func wallArea(of room: RoomDimensions) throws -> WallArea {
        try validate(room)
        var warnings: [EstimatorWarning] = []
        let gross = room.perimeter * room.height

        // An opening can't be wider than the longest wall or taller than the room.
        let longestWall = max(room.length, room.width)
        var openingsArea: Decimal = 0
        for (index, opening) in room.openings.enumerated() {
            let width = min(opening.width, longestWall)
            let height = min(opening.height, room.height)
            if width != opening.width || height != opening.height {
                warnings.append(.openingClamped(index: index))
            }
            openingsArea += width * height * Decimal(opening.quantity)
        }

        var net = gross - openingsArea
        if net < 0 {
            net = 0
            warnings.append(.openingsExceedWallArea)
        }
        return WallArea(gross: gross, openings: openingsArea, net: net, warnings: warnings)
    }

    public static func floorArea(of room: RoomDimensions) throws -> Decimal {
        try validate(room)
        return room.length * room.width
    }
}
