import Foundation
import SwiftData
import Estimator

/// The work to price in one room, with the settings used for the estimate.
@Model
final class Job {
    var typeRaw: String = JobType.paint.rawValue
    var coats: Int = 2
    /// m² per litre per coat.
    var coveragePerLitre: Decimal = 10
    var canSizeL: Decimal = 5
    var wastePercent: Decimal = 10
    /// m² per box for flooring and tiles.
    var boxCoverageM2: Decimal = Decimal(string: "2.2")!
    var labourModeRaw: String = LabourMode.perSquareMetre.rawValue
    var labourRate: Decimal = 0
    var labourHours: Decimal = 0
    /// Price of one can or box of the main material.
    var materialUnitPrice: Decimal = 0
    var materialName: String = ""

    @Relationship(deleteRule: .cascade, inverse: \Room.job)
    var room: Room?

    var quote: Quote?

    init(type: JobType = .paint) {
        self.typeRaw = type.rawValue
    }

    var type: JobType {
        get { JobType(rawValue: typeRaw) ?? .paint }
        set { typeRaw = newValue.rawValue }
    }

    var labourMode: LabourMode {
        get { LabourMode(rawValue: labourModeRaw) ?? .perSquareMetre }
        set { labourModeRaw = newValue.rawValue }
    }

    var labourPricing: LabourPricing {
        switch labourMode {
        case .perSquareMetre: .perSquareMetre(rate: labourRate)
        case .perHour: .perHour(rate: labourRate, hours: labourHours)
        }
    }

    var paintSpec: PaintSpec {
        PaintSpec(coats: coats, coveragePerLitre: coveragePerLitre, wastePercent: wastePercent, canSize: canSizeL)
    }

    var coveringSpec: CoveringSpec {
        CoveringSpec(wastePercent: wastePercent, packCoverage: boxCoverageM2)
    }
}
