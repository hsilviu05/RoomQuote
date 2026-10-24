import Foundation
import Estimator

/// Where a quote is in its life. Stored as a raw string so SwiftData/CloudKit can persist it.
enum QuoteStatus: String, CaseIterable, Codable, Identifiable {
    case draft, sent, accepted, paid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .draft: String(localized: "Draft")
        case .sent: String(localized: "Sent")
        case .accepted: String(localized: "Accepted")
        case .paid: String(localized: "Paid")
        }
    }

    /// Accepted and paid quotes both count as won.
    var isWon: Bool { self == .accepted || self == .paid }
}

enum RoomSource: String, Codable {
    case manual, scan
}

enum LabourMode: String, CaseIterable, Codable, Identifiable {
    case perSquareMetre, perHour
    var id: String { rawValue }
}

enum PriceCategory: String, CaseIterable, Codable, Identifiable {
    case paint, floor, tiles, labour, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .paint: String(localized: "Paint")
        case .floor: String(localized: "Flooring")
        case .tiles: String(localized: "Tiles")
        case .labour: String(localized: "Labour")
        case .other: String(localized: "Other")
        }
    }
}

extension JobType: @retroactive Identifiable {
    public var id: String { rawValue }

    /// Short label for the job-type picker.
    var title: String {
        switch self {
        case .paint: String(localized: "Paint")
        case .floor: String(localized: "Floor")
        case .tiles: String(localized: "Tiles")
        }
    }

    /// Label used in quote summaries ("Painting · 35.3 m² walls").
    var activityTitle: String {
        switch self {
        case .paint: String(localized: "Painting")
        case .floor: String(localized: "Flooring")
        case .tiles: String(localized: "Tiles")
        }
    }

    var priceCategory: PriceCategory {
        switch self {
        case .paint: .paint
        case .floor: .floor
        case .tiles: .tiles
        }
    }
}
