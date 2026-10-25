import Foundation
import Estimator

/// Display formatting for money, areas, lengths and volumes.
struct Formatters {
    var currencyCode: String
    var unitSystem: UnitSystem
    var locale: Locale = .current

    /// Whole currency units, as in the design ("1,194 lei"). Totals are stored to the cent.
    func money(_ value: Decimal, fractionDigits: Int = 0) -> String {
        let number = value.formatted(
            .number.precision(.fractionLength(fractionDigits)).grouping(.automatic).locale(locale)
        )
        if let symbol = Self.suffixSymbols[currencyCode] {
            return "\(number) \(symbol)"
        }
        return value.formatted(
            .currency(code: currencyCode).precision(.fractionLength(fractionDigits)).locale(locale)
        )
    }

    /// Unit prices (per m², per hour): whole amounts as "18 lei", others with cents ("$3.50").
    func rate(_ value: Decimal) -> String {
        money(value, fractionDigits: value == value.rounded(scale: 0) ? 0 : 2)
    }

    /// Currencies conventionally written after the amount.
    static let suffixSymbols = ["RON": "lei"]

    func area(_ squareMetres: Decimal, fractionDigits: Int = 1) -> String {
        switch unitSystem {
        case .metric:
            "\(number(squareMetres, fractionDigits)) m²"
        case .imperial:
            "\(number(Units.squareFeet(fromSquareMetres: squareMetres), 0)) ft²"
        }
    }

    func length(_ metres: Decimal) -> String {
        switch unitSystem {
        case .metric: "\(number(metres, 1, minimumFractionDigits: 0)) m"
        case .imperial: "\(number(Units.feet(fromMetres: metres), 1, minimumFractionDigits: 0)) ft"
        }
    }

    /// "4.2 × 3.6 m"
    func floorSize(length: Decimal, width: Decimal) -> String {
        switch unitSystem {
        case .metric:
            "\(number(length, 1, minimumFractionDigits: 0)) × \(number(width, 1, minimumFractionDigits: 0)) m"
        case .imperial:
            "\(number(Units.feet(fromMetres: length), 1, minimumFractionDigits: 0)) × \(number(Units.feet(fromMetres: width), 1, minimumFractionDigits: 0)) ft"
        }
    }

    /// `packSize` drops trailing zeros ("5 L") for can sizes; amounts keep one decimal ("7.8 L").
    func volume(_ litres: Decimal, packSize: Bool = false) -> String {
        let minimum = packSize ? 0 : 1
        return switch unitSystem {
        case .metric: "\(number(litres, 1, minimumFractionDigits: minimum)) L"
        case .imperial: "\(number(Units.usGallons(fromLitres: litres), 1, minimumFractionDigits: minimum)) gal"
        }
    }

    func number(_ value: Decimal, _ maximumFractionDigits: Int, minimumFractionDigits: Int? = nil) -> String {
        let minimum = minimumFractionDigits ?? maximumFractionDigits
        return value.formatted(
            .number.precision(.fractionLength(minimum...maximumFractionDigits)).locale(locale)
        )
    }
}

/// Parses numbers typed by the user. Accepts both "2.5" and "2,5" whatever the
/// device locale, because tradespeople often type either.
enum DecimalInput {
    static func parse(_ text: String, locale: Locale = .current) -> Decimal? {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        let grouping = locale.groupingSeparator ?? ","
        let decimal = locale.decimalSeparator ?? "."

        // A lone separator of the other kind is treated as the decimal mark.
        let hasDot = cleaned.contains(".")
        let hasComma = cleaned.contains(",")
        if hasDot && hasComma {
            cleaned = cleaned.replacingOccurrences(of: grouping, with: "")
            cleaned = cleaned.replacingOccurrences(of: decimal, with: ".")
        } else {
            cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
        }
        guard cleaned.filter({ $0 == "." }).count <= 1,
              cleaned.allSatisfy({ $0.isNumber || $0 == "." || $0 == "-" }),
              cleaned.firstIndex(of: "-").map({ $0 == cleaned.startIndex }) ?? true,
              cleaned.contains(where: \.isNumber)
        else { return nil }
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Formats a stored value for an editable text field.
    static func string(_ value: Decimal, maximumFractionDigits: Int = 2, locale: Locale = .current) -> String {
        value.formatted(.number.precision(.fractionLength(0...maximumFractionDigits)).grouping(.never).locale(locale))
    }
}
