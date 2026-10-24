import Foundation
import Observation
import SwiftData
import Estimator

@MainActor
@Observable
final class RoomMaterialsViewModel {
    let quote: Quote
    private let context: ModelContext
    private(set) var estimate: JobEstimate?
    private(set) var errorMessage: String?
    var formatters: Formatters

    init(quote: Quote, context: ModelContext, formatters: Formatters) {
        self.quote = quote
        self.context = context
        self.formatters = formatters
        recalculate()
    }

    var job: Job? { quote.job }
    var room: Room? { job?.room }

    var lines: [LineItem] { quote.sortedLineItems }
    var total: Decimal { (try? quote.totals().total) ?? quote.cachedTotal }

    var warnings: [String] {
        var messages = (estimate?.warnings ?? []).map(Self.message(for:))
        if let job, job.materialUnitPrice == 0 {
            messages.append(String(localized: "No price for \(job.materialName). Add one in Prices."))
        }
        return messages
    }

    // MARK: Settings

    func setJobType(_ type: JobType) {
        guard let job, job.type != type else { return }
        job.type = type
        apply { try QuoteBuilder.applyPriceDefaults(to: job, context: context) }
    }

    func changeCoats(by delta: Int) {
        guard let job else { return }
        let coats = min(max(job.coats + delta, 0), 10)
        guard coats != job.coats else { return }
        job.coats = coats
        recalculate()
    }

    func changeWaste(by delta: Decimal) {
        guard let job else { return }
        let waste = min(max(job.wastePercent + delta, 0), 50)
        guard waste != job.wastePercent else { return }
        job.wastePercent = waste
        recalculate()
    }

    /// Coverage typed by the user, in m²/L (metric) or ft²/gal (imperial).
    func setCoverage(_ text: String) -> Bool {
        guard let job, let value = DecimalInput.parse(text), value > 0 else { return false }
        job.coveragePerLitre = formatters.unitSystem == .metric
            ? value
            : Units.squareMetresPerLitre(fromSquareFeetPerGallon: value)
        recalculate()
        return true
    }

    /// Box coverage typed by the user, in m² or ft².
    func setBoxCoverage(_ text: String) -> Bool {
        guard let job, let value = DecimalInput.parse(text), value > 0 else { return false }
        job.boxCoverageM2 = formatters.unitSystem == .metric ? value : Units.squareMetres(fromSquareFeet: value)
        recalculate()
        return true
    }

    var coverageText: String {
        guard let job else { return "" }
        switch formatters.unitSystem {
        case .metric:
            return String(localized: "\(formatters.number(job.coveragePerLitre, 1, minimumFractionDigits: 0)) m² per litre")
        case .imperial:
            let value = Units.squareFeetPerGallon(fromSquareMetresPerLitre: job.coveragePerLitre)
            return String(localized: "\(formatters.number(value, 0)) ft² per gallon")
        }
    }

    var coverageEditValue: String {
        guard let job else { return "" }
        let value = formatters.unitSystem == .metric
            ? job.coveragePerLitre
            : Units.squareFeetPerGallon(fromSquareMetresPerLitre: job.coveragePerLitre)
        return DecimalInput.string(value, maximumFractionDigits: 1)
    }

    var boxCoverageText: String {
        guard let job else { return "" }
        return String(localized: "\(formatters.area(job.boxCoverageM2, fractionDigits: 2)) per box")
    }

    var boxCoverageEditValue: String {
        guard let job else { return "" }
        let value = formatters.unitSystem == .metric ? job.boxCoverageM2 : Units.squareFeet(fromSquareMetres: job.boxCoverageM2)
        return DecimalInput.string(value, maximumFractionDigits: 2)
    }

    func renameRoom(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let room, !trimmed.isEmpty else { return }
        room.name = trimmed
        save()
    }

    // MARK: Line items

    func addExtra(_ price: PriceItem) {
        apply {
            try QuoteBuilder.addExtra(price, to: quote, workArea: estimate?.workArea ?? 0, formatters: formatters, context: context)
        }
    }

    func remove(_ line: LineItem) {
        guard !line.isGenerated else { return }
        apply { try QuoteBuilder.removeLine(line, from: quote, context: context) }
    }

    /// Called when the user taps Create quote.
    func finalize() {
        if let profile = try? BusinessProfile.current(in: context) {
            quote.validUntil = Calendar.current.date(byAdding: .day, value: profile.quoteValidityDays, to: .now)
        }
        save()
    }

    func recalculate() {
        apply {}
    }

    private func apply(_ change: () throws -> Void) {
        do {
            try change()
            estimate = try QuoteBuilder.recalculate(quote, formatters: formatters, context: context)
            errorMessage = nil
        } catch let error as EstimatorError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        do {
            try context.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    static func message(for warning: EstimatorWarning) -> String {
        switch warning {
        case .openingClamped(let index):
            String(localized: "Opening \(index + 1) is bigger than the wall, so it was limited to the wall size.")
        case .openingsExceedWallArea:
            String(localized: "Openings cover more than the walls. Wall area is set to 0.")
        case .noCoats:
            String(localized: "0 coats: no paint is needed.")
        }
    }

    static func message(for error: EstimatorError) -> String {
        switch error {
        case .negative(let field), .notPositive(let field):
            String(localized: "Check \(field.title): it must be more than 0.")
        }
    }
}

extension EstimatorField {
    var title: String {
        switch self {
        case .roomLength: String(localized: "room length")
        case .roomWidth: String(localized: "room width")
        case .roomHeight: String(localized: "room height")
        case .openingWidth: String(localized: "opening width")
        case .openingHeight: String(localized: "opening height")
        case .openingQuantity: String(localized: "number of openings")
        case .coats: String(localized: "coats")
        case .coverage: String(localized: "coverage")
        case .canSize: String(localized: "can size")
        case .wastePercent: String(localized: "waste")
        case .packCoverage: String(localized: "box coverage")
        case .labourRate: String(localized: "labour rate")
        case .labourHours: String(localized: "labour hours")
        case .quantity: String(localized: "quantity")
        case .unitPrice: String(localized: "price")
        case .vatRate: String(localized: "VAT rate")
        }
    }
}
