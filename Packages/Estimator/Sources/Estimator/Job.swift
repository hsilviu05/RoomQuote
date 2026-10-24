import Foundation

public enum JobType: String, Sendable, CaseIterable, Codable {
    case paint, floor, tiles
}

/// Everything needed to price one job in one room.
public struct JobInput: Hashable, Sendable {
    public var type: JobType
    public var room: RoomDimensions
    /// Used when `type` is `.paint`.
    public var paint: PaintSpec
    /// Used when `type` is `.floor` or `.tiles`.
    public var covering: CoveringSpec
    /// Price of one can (paint) or one box (floor, tiles).
    public var materialUnitPrice: Decimal
    public var materialTitle: String
    public var labour: LabourPricing
    public var labourTitle: String

    public init(
        type: JobType,
        room: RoomDimensions,
        paint: PaintSpec,
        covering: CoveringSpec,
        materialUnitPrice: Decimal,
        materialTitle: String,
        labour: LabourPricing,
        labourTitle: String
    ) {
        self.type = type
        self.room = room
        self.paint = paint
        self.covering = covering
        self.materialUnitPrice = materialUnitPrice
        self.materialTitle = materialTitle
        self.labour = labour
        self.labourTitle = labourTitle
    }
}

public struct JobEstimate: Equatable, Sendable {
    public var wallArea: WallArea
    public var floorArea: Decimal
    /// The area this job covers: net wall area for paint, floor area otherwise.
    public var workArea: Decimal
    public var paint: PaintEstimate?
    public var covering: CoveringEstimate?
    public var lineItems: [LineItem]
    public var warnings: [EstimatorWarning]
}

extension Estimator {
    public static func estimate(_ job: JobInput) throws -> JobEstimate {
        try Validate.nonNegative(job.materialUnitPrice, .unitPrice)
        let walls = try wallArea(of: job.room)
        let floor = try floorArea(of: job.room)
        var warnings = walls.warnings

        var paintEstimate: PaintEstimate?
        var coveringEstimate: CoveringEstimate?
        let workArea: Decimal
        let material: LineItem

        switch job.type {
        case .paint:
            workArea = walls.net
            let paint = try paint(area: workArea, spec: job.paint)
            warnings += paint.warnings
            paintEstimate = paint
            material = LineItem(title: job.materialTitle, kind: .material, quantity: Decimal(paint.cans), unit: .can, unitPrice: job.materialUnitPrice)
        case .floor, .tiles:
            workArea = floor
            let covering = try covering(area: workArea, spec: job.covering)
            coveringEstimate = covering
            material = LineItem(title: job.materialTitle, kind: .material, quantity: Decimal(covering.packs), unit: .box, unitPrice: job.materialUnitPrice)
        }

        let labour = try labourLine(job.labour, area: workArea, title: job.labourTitle)
        return JobEstimate(
            wallArea: walls,
            floorArea: floor,
            workArea: workArea,
            paint: paintEstimate,
            covering: coveringEstimate,
            lineItems: [material, labour],
            warnings: warnings
        )
    }
}
