import Foundation
import Testing
@testable import Estimator

@Suite("Wall and floor area")
struct GeometryTests {
    @Test("Sanity room: 35.31 m² of wall")
    func sanityRoomWallArea() throws {
        let walls = try Estimator.wallArea(of: sanityRoom)
        #expect(walls.gross == d("40.56"))
        #expect(walls.openings == d("5.25"))
        #expect(walls.net == d("35.31"))
        #expect(walls.warnings.isEmpty)
    }

    @Test("No openings: net equals perimeter × height")
    func zeroOpenings() throws {
        let room = RoomDimensions(length: d("4"), width: d("3"), height: d("2.5"))
        let walls = try Estimator.wallArea(of: room)
        #expect(walls.gross == d("35"))
        #expect(walls.openings == 0)
        #expect(walls.net == d("35"))
        #expect(walls.warnings.isEmpty)
    }

    @Test("Opening quantity multiplies its area")
    func openingQuantity() throws {
        let room = RoomDimensions(length: d("5"), width: d("4"), height: d("2.5"),
                                  openings: [OpeningDimensions(kind: .window, width: d("1"), height: d("1"), quantity: 3)])
        #expect(try Estimator.wallArea(of: room).openings == d("3"))
    }

    @Test("Opening wider than the longest wall is clamped with a warning")
    func openingWiderThanWall() throws {
        let room = RoomDimensions(length: d("3"), width: d("2"), height: d("2.5"),
                                  openings: [OpeningDimensions(kind: .other, width: d("5"), height: d("2"))])
        let walls = try Estimator.wallArea(of: room)
        #expect(walls.openings == d("6")) // 3 m (longest wall) × 2 m
        #expect(walls.net == d("19"))     // 25 − 6
        #expect(walls.warnings == [.openingClamped(index: 0)])
    }

    @Test("Opening taller than the room is clamped to room height")
    func openingTallerThanRoom() throws {
        let room = RoomDimensions(length: d("4"), width: d("4"), height: d("2.4"),
                                  openings: [
                                      OpeningDimensions(kind: .door, width: d("0.8"), height: d("2")),
                                      OpeningDimensions(kind: .door, width: d("1"), height: d("3"))
                                  ])
        let walls = try Estimator.wallArea(of: room)
        #expect(walls.openings == d("4")) // 1.6 + 1 × 2.4
        #expect(walls.warnings == [.openingClamped(index: 1)])
    }

    @Test("Openings bigger than all the wall clamp net area to zero")
    func openingsExceedWalls() throws {
        let room = RoomDimensions(length: d("2"), width: d("2"), height: d("2"),
                                  openings: [OpeningDimensions(kind: .window, width: d("2"), height: d("2"), quantity: 5)])
        let walls = try Estimator.wallArea(of: room)
        #expect(walls.gross == d("16"))
        #expect(walls.openings == d("20"))
        #expect(walls.net == 0)
        #expect(walls.warnings == [.openingsExceedWallArea])
    }

    @Test("Zero-size room has zero areas and no errors")
    func zeroRoom() throws {
        let room = RoomDimensions(length: 0, width: 0, height: 0)
        #expect(try Estimator.wallArea(of: room).net == 0)
        #expect(try Estimator.floorArea(of: room) == 0)
    }

    @Test("Floor area is length × width")
    func floorArea() throws {
        #expect(try Estimator.floorArea(of: sanityRoom) == d("15.12"))
    }

    @Test("Negative dimensions are rejected", arguments: [
        (RoomDimensions(length: d("-1"), width: d("3"), height: d("2.5")), EstimatorField.roomLength),
        (RoomDimensions(length: d("4"), width: d("-3"), height: d("2.5")), .roomWidth),
        (RoomDimensions(length: d("4"), width: d("3"), height: d("-2.5")), .roomHeight),
        (RoomDimensions(length: d("4"), width: d("3"), height: d("2.5"),
                        openings: [OpeningDimensions(kind: .door, width: d("-0.9"), height: d("2"))]), .openingWidth),
        (RoomDimensions(length: d("4"), width: d("3"), height: d("2.5"),
                        openings: [OpeningDimensions(kind: .door, width: d("0.9"), height: d("2"), quantity: -1)]), .openingQuantity)
    ])
    func negativeRejected(room: RoomDimensions, field: EstimatorField) {
        #expect(throws: EstimatorError.negative(field)) { try Estimator.wallArea(of: room) }
    }
}
