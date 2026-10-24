import Foundation
import Testing
@testable import Estimator

@Suite("Floor and tiles")
struct CoveringTests {
    @Test("Waste is added before rounding up to whole boxes")
    func wasteAndBoxes() throws {
        // 15.12 m² + 10% = 16.632 m² ÷ 2.2 m²/box = 7.56 → 8 boxes.
        let estimate = try Estimator.covering(area: d("15.12"), spec: CoveringSpec(wastePercent: d("10"), packCoverage: d("2.2")))
        #expect(estimate.orderArea == d("16.632"))
        #expect(estimate.packs == 8)
    }

    @Test("Exact box multiple does not add a box")
    func exactMultiple() throws {
        // 20 m² + 10% = 22 m² ÷ 2.2 = exactly 10 boxes.
        let estimate = try Estimator.covering(area: d("20"), spec: CoveringSpec(wastePercent: d("10"), packCoverage: d("2.2")))
        #expect(estimate.orderArea == d("22"))
        #expect(estimate.packs == 10)
    }

    @Test("Area smaller than one box still needs one box")
    func lessThanOneBox() throws {
        let estimate = try Estimator.covering(area: d("1"), spec: CoveringSpec(wastePercent: 0, packCoverage: d("2.2")))
        #expect(estimate.packs == 1)
    }

    @Test("Zero area needs zero boxes")
    func zeroArea() throws {
        #expect(try Estimator.covering(area: 0, spec: CoveringSpec(wastePercent: d("10"), packCoverage: d("2"))).packs == 0)
    }

    @Test("Zero box coverage is rejected")
    func zeroPackCoverage() {
        #expect(throws: EstimatorError.notPositive(.packCoverage)) {
            try Estimator.covering(area: 10, spec: CoveringSpec(wastePercent: 0, packCoverage: 0))
        }
    }
}
