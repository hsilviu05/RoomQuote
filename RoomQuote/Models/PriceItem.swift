import Foundation
import SwiftData

/// An entry in the tradesperson's price list. Quotes copy from it, so editing
/// a price never changes a quote already made.
@Model
final class PriceItem {
    var name: String = ""
    var categoryRaw: String = PriceCategory.other.rawValue
    var unitRaw: String = PriceUnit.item.rawValue
    var unitPrice: Decimal = 0
    /// Litres per can, or m² per box. Zero when not applicable.
    var packSize: Decimal = 0
    var isArchived: Bool = false
    /// For labour prices: the job type this rate applies to. Empty for other categories.
    var jobTypeRaw: String = ""
    var createdAt: Date = Date.now

    init(name: String, category: PriceCategory, unit: PriceUnit, unitPrice: Decimal, packSize: Decimal = 0) {
        self.name = name
        self.categoryRaw = category.rawValue
        self.unitRaw = unit.rawValue
        self.unitPrice = unitPrice
        self.packSize = packSize
    }

    var category: PriceCategory {
        get { PriceCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var unit: PriceUnit {
        get { PriceUnit(rawValue: unitRaw) ?? .item }
        set { unitRaw = newValue.rawValue }
    }
}

enum PriceUnit: String, CaseIterable, Codable, Identifiable {
    case can, box, squareMetre, hour, item

    var id: String { rawValue }

    var title: String {
        switch self {
        case .can: String(localized: "per can")
        case .box: String(localized: "per box")
        case .squareMetre: String(localized: "per m²")
        case .hour: String(localized: "per hour")
        case .item: String(localized: "fixed")
        }
    }
}
