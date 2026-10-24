import Foundation
import Testing
@testable import Estimator

@Suite("Full job estimate")
struct JobTests {
    func job(_ type: JobType, labour: LabourPricing = .perSquareMetre(rate: d("20"))) -> JobInput {
        JobInput(
            type: type,
            room: sanityRoom,
            paint: PaintSpec(coats: 2, coveragePerLitre: 10, wastePercent: 10, canSize: 5),
            covering: CoveringSpec(wastePercent: 10, packCoverage: d("2.2")),
            materialUnitPrice: d("150"),
            materialTitle: "Material",
            labour: labour,
            labourTitle: "Labour"
        )
    }

    @Test("Paint job prices cans and labour on net wall area")
    func paintJob() throws {
        let estimate = try Estimator.estimate(job(.paint))
        #expect(estimate.workArea == d("35.31"))
        #expect(estimate.paint?.cans == 2)
        #expect(estimate.covering == nil)
        #expect(estimate.lineItems.map(\.total) == [d("300"), d("706.2")])
    }

    @Test("Floor and tile jobs price boxes and labour on floor area", arguments: [JobType.floor, .tiles])
    func coveringJob(type: JobType) throws {
        let estimate = try Estimator.estimate(job(type))
        #expect(estimate.workArea == d("15.12"))
        #expect(estimate.covering?.packs == 8)
        #expect(estimate.paint == nil)
        #expect(estimate.lineItems.map(\.total) == [d("1200"), d("302.4")])
    }

    @Test("Warnings from walls and paint are combined")
    func combinedWarnings() throws {
        var input = job(.paint)
        input.paint.coats = 0
        input.room.openings.append(Opening(kind: .other, width: 9, height: 1))
        let estimate = try Estimator.estimate(input)
        #expect(estimate.warnings == [.openingClamped(index: 2), .noCoats])
    }
}
