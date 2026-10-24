import Foundation

public enum UnitSystem: String, Sendable, CaseIterable, Codable {
    case metric, imperial
}

/// Exact conversion factors (international foot, US liquid gallon).
/// Estimator works in metric; convert user input and display with these.
public enum Units {
    public static let metresPerFoot = Decimal(string: "0.3048")!
    public static let metresPerInch = Decimal(string: "0.0254")!
    public static let squareMetresPerSquareFoot = Decimal(string: "0.09290304")!
    public static let litresPerUSGallon = Decimal(string: "3.785411784")!

    public static func metres(feet: Decimal, inches: Decimal = 0) -> Decimal {
        feet * metresPerFoot + inches * metresPerInch
    }

    public static func feet(fromMetres metres: Decimal) -> Decimal {
        metres / metresPerFoot
    }

    /// Whole feet plus remaining inches, inches rounded to `inchScale` places.
    /// A remainder that rounds up to 12 inches rolls over into the next foot.
    public static func feetAndInches(fromMetres metres: Decimal, inchScale: Int = 1) -> (feet: Int, inches: Decimal) {
        let totalInches = (metres / metresPerInch).rounded(scale: inchScale)
        let feet = (totalInches / 12).rounded(scale: 0, mode: .down)
        return (feet.intValue, totalInches - feet * 12)
    }

    public static func squareFeet(fromSquareMetres area: Decimal) -> Decimal {
        area / squareMetresPerSquareFoot
    }

    public static func squareMetres(fromSquareFeet area: Decimal) -> Decimal {
        area * squareMetresPerSquareFoot
    }

    public static func usGallons(fromLitres litres: Decimal) -> Decimal {
        litres / litresPerUSGallon
    }

    public static func litres(fromUSGallons gallons: Decimal) -> Decimal {
        gallons * litresPerUSGallon
    }

    /// m²/L → ft²/US gal.
    public static func squareFeetPerGallon(fromSquareMetresPerLitre coverage: Decimal) -> Decimal {
        squareFeet(fromSquareMetres: coverage) * litresPerUSGallon
    }

    /// ft²/US gal → m²/L.
    public static func squareMetresPerLitre(fromSquareFeetPerGallon coverage: Decimal) -> Decimal {
        squareMetres(fromSquareFeet: coverage) / litresPerUSGallon
    }
}
