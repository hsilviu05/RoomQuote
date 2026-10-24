import Foundation
import Observation
import Estimator

@MainActor
@Observable
final class ManualMeasurementsViewModel {
    struct OpeningDraft: Identifiable, Equatable {
        let id = UUID()
        var kind: OpeningDimensions.Kind
        var width: String = ""
        var height: String = ""
        var quantity: Int = 1
    }

    enum Field: Hashable {
        case length, width, height
        case openingWidth(UUID), openingHeight(UUID)
    }

    var clientName = ""
    var roomName = ""
    var length = ""
    var width = ""
    var height = ""
    var openings: [OpeningDraft] = []
    /// Errors stay hidden until the user tries to continue.
    var showErrors = false

    let unitSystem: UnitSystem
    let locale: Locale

    init(unitSystem: UnitSystem, locale: Locale = .current) {
        self.unitSystem = unitSystem
        self.locale = locale
    }

    var unitLabel: String { unitSystem == .metric ? "m" : "ft" }

    func addOpening(_ kind: OpeningDimensions.Kind) {
        openings.append(OpeningDraft(kind: kind))
    }

    func removeOpenings(at offsets: IndexSet) {
        openings.remove(atOffsets: offsets)
    }

    func removeOpening(id: UUID) {
        openings.removeAll { $0.id == id }
    }

    /// The message to show under a field, or nil when it is valid (or errors are hidden).
    func error(for field: Field) -> String? {
        guard showErrors else { return nil }
        return validationError(for: field)
    }

    func validationError(for field: Field) -> String? {
        let text: String
        switch field {
        case .length: text = length
        case .width: text = width
        case .height: text = height
        case .openingWidth(let id): text = openings.first { $0.id == id }?.width ?? ""
        case .openingHeight(let id): text = openings.first { $0.id == id }?.height ?? ""
        }
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            return String(localized: "Required")
        }
        guard let value = DecimalInput.parse(text, locale: locale) else {
            return String(localized: "Enter a number, like 2.5")
        }
        guard value > 0 else { return String(localized: "Must be more than 0") }
        guard value <= maximum else {
            return String(localized: "That's larger than a room. Check the units (\(unitLabel)).")
        }
        return nil
    }

    /// Upper bound that catches centimetres or inches typed into a metres/feet field.
    private var maximum: Decimal { unitSystem == .metric ? 100 : 330 }

    private var allFields: [Field] {
        [.length, .width, .height] + openings.flatMap { [Field.openingWidth($0.id), .openingHeight($0.id)] }
    }

    var isValid: Bool { allFields.allSatisfy { validationError(for: $0) == nil } }

    /// The room in metres, or nil while any field is invalid.
    var dimensions: RoomDimensions? {
        guard isValid,
              let l = metres(length), let w = metres(width), let h = metres(height)
        else { return nil }
        let converted = openings.compactMap { draft -> OpeningDimensions? in
            guard let ow = metres(draft.width), let oh = metres(draft.height) else { return nil }
            return OpeningDimensions(kind: draft.kind, width: ow, height: oh, quantity: draft.quantity)
        }
        return RoomDimensions(length: l, width: w, height: h, openings: converted)
    }

    /// Live wall/floor areas once the room dimensions are valid.
    var preview: (walls: WallArea, floor: Decimal)? {
        guard let dimensions, let walls = try? Estimator.wallArea(of: dimensions),
              let floor = try? Estimator.floorArea(of: dimensions)
        else { return nil }
        return (walls, floor)
    }

    func warningMessages(for walls: WallArea) -> [String] {
        walls.warnings.map { warning in
            switch warning {
            case .openingClamped(let index):
                let name = index < openings.count ? openings[index].kind.title : String(localized: "An opening")
                return String(localized: "\(name) \(index + 1) is bigger than the wall, so it was limited to the wall size.")
            case .openingsExceedWallArea:
                return String(localized: "Openings cover more than the walls. Wall area is set to 0.")
            case .noCoats:
                return String(localized: "No coats selected.")
            }
        }
    }

    private func metres(_ text: String) -> Decimal? {
        guard let value = DecimalInput.parse(text, locale: locale) else { return nil }
        return unitSystem == .metric ? value : Units.metres(feet: value)
    }
}

extension OpeningDimensions.Kind {
    var title: String {
        switch self {
        case .door: String(localized: "Door")
        case .window: String(localized: "Window")
        case .other: String(localized: "Opening")
        }
    }
}
