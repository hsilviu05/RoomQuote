import Foundation
import Testing
@testable import Estimator

@Suite("Labour, subtotal and VAT")
struct TotalsTests {
    @Test("Labour per m² uses area rounded to 2 dp")
    func labourPerSquareMetre() throws {
        let line = try Estimator.labourLine(.perSquareMetre(rate: d("25")), area: d("35.3149"), title: "Labour")
        #expect(line.quantity == d("35.31"))
        #expect(line.unit == .squareMetre)
        #expect(line.total == d("882.75"))
    }

    @Test("Labour per hour")
    func labourPerHour() throws {
        let line = try Estimator.labourLine(.perHour(rate: d("80"), hours: d("6.5")), area: d("100"), title: "Labour")
        #expect(line.quantity == d("6.5"))
        #expect(line.unit == .hour)
        #expect(line.total == d("520"))
    }

    @Test("Negative labour inputs are rejected")
    func negativeLabour() {
        #expect(throws: EstimatorError.negative(.labourRate)) {
            try Estimator.labourLine(.perSquareMetre(rate: d("-1")), area: 10, title: "Labour")
        }
        #expect(throws: EstimatorError.negative(.labourHours)) {
            try Estimator.labourLine(.perHour(rate: 10, hours: d("-2")), area: 10, title: "Labour")
        }
    }

    let lines = [
        LineItem(title: "Paint 5 L", kind: .material, quantity: 2, unit: .can, unitPrice: d("189.90")),
        LineItem(title: "Labour", kind: .labour, quantity: d("35.31"), unit: .squareMetre, unitPrice: d("22.5"))
    ]

    @Test("Subtotal sums lines rounded to cents")
    func subtotal() throws {
        // 379.80 + 794.475 → 794.48 = 1174.28
        let totals = try Estimator.totals(for: lines, vat: .off)
        #expect(totals.subtotal == d("1174.28"))
        #expect(totals.vat == 0)
        #expect(totals.total == d("1174.28"))
    }

    @Test("VAT on adds rate × subtotal, rounded half-up")
    func vatOn() throws {
        let totals = try Estimator.totals(for: lines, vat: VATSetting(isEnabled: true, ratePercent: d("19")))
        #expect(totals.vat == d("223.11"))   // 223.1132
        #expect(totals.total == d("1397.39"))
    }

    @Test("VAT enabled at 0% adds nothing; disabled ignores the rate")
    func vatZeroAndDisabled() throws {
        #expect(try Estimator.totals(for: lines, vat: VATSetting(isEnabled: true, ratePercent: 0)).vat == 0)
        #expect(try Estimator.totals(for: lines, vat: VATSetting(isEnabled: false, ratePercent: d("20"))).vat == 0)
    }

    @Test("Half a cent rounds up")
    func halfCentRoundsUp() throws {
        let line = LineItem(title: "x", kind: .other, quantity: 1, unit: .item, unitPrice: d("0.125"))
        #expect(line.total == d("0.13"))
        let totals = try Estimator.totals(for: [LineItem(title: "x", kind: .other, quantity: 1, unit: .item, unitPrice: d("10.50"))],
                                          vat: VATSetting(isEnabled: true, ratePercent: d("5")))
        #expect(totals.vat == d("0.53")) // 0.525
    }

    @Test("No lines gives zero totals")
    func empty() throws {
        let totals = try Estimator.totals(for: [], vat: VATSetting(isEnabled: true, ratePercent: d("20")))
        #expect(totals == QuoteTotals(subtotal: 0, vat: 0, total: 0))
    }

    @Test("Negative prices, quantities and VAT rates are rejected")
    func negatives() {
        #expect(throws: EstimatorError.negative(.unitPrice)) {
            try Estimator.totals(for: [LineItem(title: "x", kind: .other, quantity: 1, unit: .item, unitPrice: d("-1"))], vat: .off)
        }
        #expect(throws: EstimatorError.negative(.quantity)) {
            try Estimator.totals(for: [LineItem(title: "x", kind: .other, quantity: d("-1"), unit: .item, unitPrice: 1)], vat: .off)
        }
        #expect(throws: EstimatorError.negative(.vatRate)) {
            try Estimator.totals(for: [], vat: VATSetting(isEnabled: true, ratePercent: d("-20")))
        }
    }
}
