import Foundation
import SwiftData
import Estimator

/// A measured room. All lengths are stored in metres.
@Model
final class Room {
    var name: String = ""
    var lengthM: Decimal = 0
    var widthM: Decimal = 0
    var heightM: Decimal = 0
    var sourceRaw: String = RoomSource.manual.rawValue
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \Opening.room)
    var openings: [Opening]? = []

    var job: Job?

    init(name: String, lengthM: Decimal, widthM: Decimal, heightM: Decimal, source: RoomSource = .manual) {
        self.name = name
        self.lengthM = lengthM
        self.widthM = widthM
        self.heightM = heightM
        self.sourceRaw = source.rawValue
    }

    var source: RoomSource { RoomSource(rawValue: sourceRaw) ?? .manual }

    /// Openings in a stable order (SwiftData to-many relationships are unordered).
    var sortedOpenings: [Opening] {
        (openings ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    var dimensions: RoomDimensions {
        RoomDimensions(
            length: lengthM,
            width: widthM,
            height: heightM,
            openings: sortedOpenings.map(\.estimatorOpening)
        )
    }

    var openingCount: Int {
        (openings ?? []).reduce(0) { $0 + max($1.quantity, 0) }
    }
}

@Model
final class Opening {
    var kindRaw: String = OpeningDimensions.Kind.door.rawValue
    var widthM: Decimal = 0
    var heightM: Decimal = 0
    var quantity: Int = 1
    var sortOrder: Int = 0
    var room: Room?

    init(kind: OpeningDimensions.Kind, widthM: Decimal, heightM: Decimal, quantity: Int = 1, sortOrder: Int = 0) {
        self.kindRaw = kind.rawValue
        self.widthM = widthM
        self.heightM = heightM
        self.quantity = quantity
        self.sortOrder = sortOrder
    }

    var kind: OpeningDimensions.Kind { OpeningDimensions.Kind(rawValue: kindRaw) ?? .other }

    var estimatorOpening: OpeningDimensions {
        OpeningDimensions(kind: kind, width: widthM, height: heightM, quantity: quantity)
    }
}
