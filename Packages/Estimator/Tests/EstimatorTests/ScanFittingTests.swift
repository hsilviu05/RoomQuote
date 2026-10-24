import Foundation
import Testing
@testable import Estimator

@Suite("Fitting scanned rooms")
struct ScanFittingTests {
    @Test("A rectangular scan gives back its own sides")
    func rectangle() throws {
        let room = try RoomDimensions.fittedToScan(perimeter: d("15.6"), floorArea: d("15.12"), height: d("2.6"), openings: sanityRoom.openings)
        #expect(room.length == d("4.2"))
        #expect(room.width == d("3.6"))
        #expect(try Estimator.wallArea(of: room).net == d("35.31"))
    }

    @Test("An L-shaped room keeps its wall and floor area")
    func lShape() throws {
        // 6 × 4 m with a 2 × 2 m corner cut out: perimeter 20 m, floor 20 m².
        let outline: [(x: Double, z: Double)] = [(0, 0), (6, 0), (6, 2), (4, 2), (4, 4), (0, 4)]
        let floor = RoomDimensions.polygonArea(outline)
        #expect(floor == 20)
        let room = try RoomDimensions.fittedToScan(perimeter: 20, floorArea: floor, height: d("2.5"), openings: [])
        #expect(room.perimeter == 20)
        #expect((room.length * room.width).rounded(scale: 1) == 20)
        #expect(try Estimator.wallArea(of: room).gross == 50)
    }

    @Test("Floor area too big for the perimeter falls back to a square")
    func impossibleArea() throws {
        let room = try RoomDimensions.fittedToScan(perimeter: 16, floorArea: 17, height: 2, openings: [])
        #expect(room.length == 4)
        #expect(room.width == 4)
    }

    @Test("Fewer than three points has no area")
    func degenerate() {
        #expect(RoomDimensions.polygonArea([(0, 0), (1, 1)]) == 0)
    }
}
