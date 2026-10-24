import Foundation
import Testing
@testable import Estimator

@Suite("Unit conversion")
struct UnitsTests {
    @Test("Feet and inches to metres")
    func feetInchesToMetres() {
        #expect(Units.metres(feet: 1) == d("0.3048"))
        #expect(Units.metres(feet: 0, inches: 12) == d("0.3048"))
        #expect(Units.metres(feet: 10, inches: 6) == d("3.2004"))
    }

    @Test("Metres to feet and inches, with rollover at 12 inches")
    func metresToFeetInches() {
        let parts = Units.feetAndInches(fromMetres: d("3.2004"))
        #expect(parts.feet == 10)
        #expect(parts.inches == d("6"))
        // 0.3047 m = 11.996 in, which rounds to 12.0 in and must show as 1 ft 0 in.
        let rollover = Units.feetAndInches(fromMetres: d("0.3047"))
        #expect(rollover.feet == 1)
        #expect(rollover.inches == 0)
    }

    @Test("Area round trip m² ↔ ft²")
    func areaRoundTrip() {
        #expect(Units.squareMetres(fromSquareFeet: 1) == d("0.09290304"))
        #expect(Units.squareFeet(fromSquareMetres: d("0.09290304")) == 1)
        #expect(Units.squareFeet(fromSquareMetres: d("35.31")).rounded(scale: 2) == d("380.07"))
    }

    @Test("Litres ↔ US gallons")
    func volume() {
        #expect(Units.litres(fromUSGallons: 1) == d("3.785411784"))
        #expect(Units.usGallons(fromLitres: d("7.7682")).rounded(scale: 2) == d("2.05"))
    }

    @Test("Coverage m²/L ↔ ft²/gal")
    func coverage() {
        let imperial = Units.squareFeetPerGallon(fromSquareMetresPerLitre: 10)
        #expect(imperial.rounded(scale: 1) == d("407.5"))
        #expect(Units.squareMetresPerLitre(fromSquareFeetPerGallon: imperial).rounded(scale: 10) == 10)
    }

    @Test("An imperial room gives the same paint as the metric room")
    func imperialRoomMatchesMetric() throws {
        // 4.2 m etc. expressed in inches (exact: 1 in = 0.0254 m).
        func m(_ metres: String) -> Decimal { Units.metres(feet: 0, inches: d(metres) / Units.metresPerInch) }
        let room = RoomDimensions(length: m("4.2"), width: m("3.6"), height: m("2.6"), openings: sanityRoom.openings)
        let walls = try Estimator.wallArea(of: room)
        #expect(walls.net.rounded(scale: 6) == d("35.31"))
        let paint = try Estimator.paint(area: walls.net, spec: PaintSpec(coats: 2, coveragePerLitre: 10, wastePercent: 10, canSize: 5))
        #expect(paint.cans == 2)
    }
}
