import Foundation
import Testing
import Estimator
@testable import RoomQuote

private let en = Locale(identifier: "en_US")
private let ro = Locale(identifier: "ro_RO")

@Suite("Free plan limit")
struct QuoteLimitTests {
    let calendar = Calendar(identifier: .gregorian)
    var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 12))! }
    func date(_ month: Int, _ day: Int) -> Date { calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 9))! }

    @Test("Three quotes a month on the free plan")
    func freeLimit() {
        let two = [date(10, 1), date(10, 20)]
        let three = two + [date(10, 25)]
        #expect(QuoteLimitPolicy.canCreateQuote(isPro: false, createdDates: two, now: now, calendar: calendar))
        #expect(!QuoteLimitPolicy.canCreateQuote(isPro: false, createdDates: three, now: now, calendar: calendar))
    }

    @Test("Last month's quotes don't count")
    func resetsMonthly() {
        let dates = [date(9, 28), date(9, 29), date(9, 30), date(10, 2)]
        #expect(QuoteLimitPolicy.quotesCreatedThisMonth(dates, now: now, calendar: calendar) == 1)
    }

    @Test("Pro has no limit")
    func pro() {
        let many = Array(repeating: date(10, 10), count: 50)
        #expect(QuoteLimitPolicy.canCreateQuote(isPro: true, createdDates: many, now: now, calendar: calendar))
    }
}

@Suite("Home stats")
struct QuoteStatsTests {
    @Test("Win rate is won ÷ sent this month, rounded")
    func winRate() {
        let now = Date.now
        let quotes: [(status: QuoteStatus, sentAt: Date?)] = [
            (.sent, now), (.accepted, now), (.paid, now), (.draft, nil),
            (.accepted, Calendar.current.date(byAdding: .month, value: -1, to: now))
        ]
        #expect(QuoteStats.compute(quotes, now: now) == QuoteStats(sentThisMonth: 3, acceptedThisMonth: 2, winRatePercent: 67))
    }

    @Test("No quotes sent gives no win rate")
    func empty() {
        #expect(QuoteStats.compute([]) == QuoteStats(sentThisMonth: 0, acceptedThisMonth: 0, winRatePercent: nil))
    }
}

@Suite("Number input")
struct DecimalInputTests {
    @Test("Dot and comma decimals both work", arguments: ["2.5", "2,5", " 2.5 "])
    func separators(text: String) {
        #expect(DecimalInput.parse(text, locale: en) == Decimal(string: "2.5"))
        #expect(DecimalInput.parse(text, locale: ro) == Decimal(string: "2.5"))
    }

    @Test("Grouping separators are understood when both marks appear")
    func grouping() {
        #expect(DecimalInput.parse("1,234.5", locale: en) == Decimal(string: "1234.5"))
        #expect(DecimalInput.parse("1.234,5", locale: ro) == Decimal(string: "1234.5"))
    }

    @Test("Garbage is rejected", arguments: ["", "abc", "1.2.3", "2-1", "-", ".", "1e5"])
    func invalid(text: String) {
        #expect(DecimalInput.parse(text, locale: en) == nil)
    }

    @Test("Negative numbers parse so validation can reject them with a message")
    func negative() {
        #expect(DecimalInput.parse("-2", locale: en) == -2)
    }
}

@Suite("Formatting")
struct FormattersTests {
    @Test("Lei are written after the amount, in whole units")
    func lei() {
        let f = Formatters(currencyCode: "RON", unitSystem: .metric, locale: en)
        #expect(f.money(Decimal(string: "1193.58")!) == "1,194 lei")
        #expect(f.money(Decimal(string: "120")!, fractionDigits: 2) == "120.00 lei")
    }

    @Test("Other currencies use the standard format")
    func euro() {
        let f = Formatters(currencyCode: "EUR", unitSystem: .metric, locale: en)
        #expect(f.money(1194) == "€1,194")
    }

    @Test("Areas and lengths in metric and imperial")
    func units() {
        let metric = Formatters(currencyCode: "RON", unitSystem: .metric, locale: en)
        let imperial = Formatters(currencyCode: "USD", unitSystem: .imperial, locale: en)
        #expect(metric.area(Decimal(string: "35.31")!) == "35.3 m²")
        #expect(imperial.area(Decimal(string: "35.31")!) == "380 ft²")
        #expect(metric.floorSize(length: Decimal(string: "4.2")!, width: Decimal(string: "3.6")!) == "4.2 × 3.6 m")
        #expect(imperial.length(Decimal(string: "3.048")!) == "10 ft")
        #expect(imperial.volume(Decimal(string: "7.7682")!) == "2.1 gal")
    }
}

@MainActor
@Suite("Manual measurement entry")
struct ManualMeasurementsTests {
    func filled(_ unitSystem: UnitSystem = .metric) -> ManualMeasurementsViewModel {
        let model = ManualMeasurementsViewModel(unitSystem: unitSystem, locale: en)
        model.length = "4.2"
        model.width = "3,6"
        model.height = "2.6"
        return model
    }

    @Test("A complete room is valid and gives the right areas")
    func valid() throws {
        let model = filled()
        model.addOpening(.door)
        model.openings[0].width = "0.9"
        model.openings[0].height = "2.1"
        model.addOpening(.window)
        model.openings[1].width = "1.2"
        model.openings[1].height = "1.4"
        model.openings[1].quantity = 2
        let preview = try #require(model.preview)
        #expect(preview.walls.net == Decimal(string: "35.31"))
        #expect(preview.floor == Decimal(string: "15.12"))
    }

    @Test("Errors only show after trying to continue")
    func errorsHidden() {
        let model = ManualMeasurementsViewModel(unitSystem: .metric, locale: en)
        #expect(model.error(for: .length) == nil)
        model.showErrors = true
        #expect(model.error(for: .length) == "Required")
        #expect(!model.isValid)
        #expect(model.dimensions == nil)
    }

    @Test("Zero, negative, non-numeric and huge values are rejected", arguments: [
        ("0", "Must be more than 0"), ("-3", "Must be more than 0"),
        ("abc", "Enter a number, like 2.5"), ("420", "That's larger than a room. Check the units (m).")
    ])
    func invalidValues(text: String, message: String) {
        let model = filled()
        model.length = text
        #expect(model.validationError(for: .length) == message)
        #expect(!model.isValid)
    }

    @Test("An empty opening blocks saving")
    func emptyOpening() {
        let model = filled()
        model.addOpening(.window)
        #expect(!model.isValid)
        model.removeOpening(id: model.openings[0].id)
        #expect(model.isValid)
    }

    @Test("Imperial feet are converted to metres")
    func imperial() throws {
        let model = ManualMeasurementsViewModel(unitSystem: .imperial, locale: en)
        model.length = "10"
        model.width = "12"
        model.height = "8"
        let dimensions = try #require(model.dimensions)
        #expect(dimensions.length == Decimal(string: "3.048"))
        #expect(dimensions.height == Decimal(string: "2.4384"))
    }

    @Test("Oversized openings produce a readable warning")
    func clampWarning() throws {
        let model = filled()
        model.addOpening(.door)
        model.openings[0].width = "9"
        model.openings[0].height = "2"
        let preview = try #require(model.preview)
        #expect(model.warningMessages(for: preview.walls) == ["Door 1 is bigger than the wall, so it was limited to the wall size."])
    }
}
