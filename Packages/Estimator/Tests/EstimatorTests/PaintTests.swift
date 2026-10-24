import Foundation
import Testing
@testable import Estimator

@Suite("Paint")
struct PaintTests {
    let standard = PaintSpec(coats: 2, coveragePerLitre: d("10"), wastePercent: d("10"), canSize: d("5"))

    @Test("Sanity room: 7.77 L → 2 × 5 L cans")
    func sanityRoomPaint() throws {
        let walls = try Estimator.wallArea(of: sanityRoom)
        let paint = try Estimator.paint(area: walls.net, spec: standard)
        #expect(paint.litres == d("7.7682"))
        #expect(paint.litresForDisplay == d("7.77"))
        #expect(paint.cans == 2)
        #expect(paint.warnings.isEmpty)
    }

    @Test("Zero coats needs no paint and warns")
    func zeroCoats() throws {
        var spec = standard
        spec.coats = 0
        let paint = try Estimator.paint(area: d("35"), spec: spec)
        #expect(paint.litres == 0)
        #expect(paint.cans == 0)
        #expect(paint.warnings == [.noCoats])
    }

    @Test("Exactly 10 L in 5 L cans is 2 cans, not 3")
    func exactCanMultiple() throws {
        // 50 m² × 1 coat ÷ 5 m²/L = 10 L, no waste.
        let spec = PaintSpec(coats: 1, coveragePerLitre: d("5"), wastePercent: 0, canSize: d("5"))
        let paint = try Estimator.paint(area: d("50"), spec: spec)
        #expect(paint.litres == d("10"))
        #expect(paint.cans == 2)
    }

    @Test("Exact multiple reached through waste % still rounds correctly")
    func exactMultipleWithWaste() throws {
        // 40 m² ÷ 10 m²/L = 4 L, +25% = 5 L exactly → 1 can.
        let spec = PaintSpec(coats: 1, coveragePerLitre: d("10"), wastePercent: d("25"), canSize: d("5"))
        let paint = try Estimator.paint(area: d("40"), spec: spec)
        #expect(paint.litres == d("5"))
        #expect(paint.cans == 1)
    }

    @Test("Just over a multiple needs another can")
    func justOverMultiple() throws {
        let spec = PaintSpec(coats: 1, coveragePerLitre: d("5"), wastePercent: 0, canSize: d("5"))
        let paint = try Estimator.paint(area: d("50.05"), spec: spec)
        #expect(paint.litres == d("10.01"))
        #expect(paint.cans == 3)
    }

    @Test("Custom can size", arguments: [(d("2.5"), 4), (d("1"), 8), (d("10"), 1)])
    func customCanSize(canSize: Decimal, cans: Int) throws {
        var spec = standard
        spec.canSize = canSize
        #expect(try Estimator.paint(area: d("35.31"), spec: spec).cans == cans) // 7.7682 L
    }

    @Test("Zero area needs zero cans")
    func zeroArea() throws {
        let paint = try Estimator.paint(area: 0, spec: standard)
        #expect(paint.litres == 0)
        #expect(paint.cans == 0)
    }

    @Test("Invalid paint settings are rejected")
    func invalidSettings() {
        var spec = standard
        spec.coveragePerLitre = 0
        #expect(throws: EstimatorError.notPositive(.coverage)) { try Estimator.paint(area: 10, spec: spec) }
        spec = standard
        spec.canSize = 0
        #expect(throws: EstimatorError.notPositive(.canSize)) { try Estimator.paint(area: 10, spec: spec) }
        spec = standard
        spec.coats = -1
        #expect(throws: EstimatorError.negative(.coats)) { try Estimator.paint(area: 10, spec: spec) }
        spec = standard
        spec.wastePercent = d("-5")
        #expect(throws: EstimatorError.negative(.wastePercent)) { try Estimator.paint(area: 10, spec: spec) }
    }
}
