import Foundation
import PDFKit
import SwiftData
import Testing
import Estimator
@testable import RoomQuote

@MainActor
@Suite("Quote PDF")
struct PDFTests {
    let formatters = Formatters(currencyCode: "RON", unitSystem: .metric, locale: Locale(identifier: "en_US"))

    func sampleQuote(in context: ModelContext) throws -> (Quote, BusinessProfile) {
        try SampleData.seed(context)
        let profile = try BusinessProfile.current(in: context)
        profile.name = "Popa Renovări"
        profile.phone = "0722 000 000"
        let quotes = try context.fetch(FetchDescriptor<Quote>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))
        return (try #require(quotes.first), profile)
    }

    @Test("Document carries business, client, lines with cents and total")
    func document() throws {
        let container = try AppSchema.makeContainer(inMemory: true)
        let (quote, profile) = try sampleQuote(in: container.mainContext)
        let doc = try QuoteDocument(quote: quote, profile: profile, formatters: formatters)
        #expect(doc.businessName == "Popa Renovări")
        #expect(doc.businessDetails == ["0722 000 000"])
        #expect(doc.clientName == "Ana Popescu")
        #expect(doc.lines.map(\.description) == ["Wall paint, 2 × 5 L", "Primer, 1 × 5 L", "Tape & protection", "Labour, 35.3 m²"])
        #expect(doc.lines.map(\.amount) == ["378.00 lei", "120.00 lei", "60.00 lei", "635.58 lei"])
        #expect(doc.total.amount == "1,193.58 lei")
        #expect(doc.vat == nil)
        #expect(doc.validity == "Valid for 14 days.")
        #expect(doc.fileName == "Quote-0030-Ana-Popescu.pdf")
    }

    @Test("VAT adds subtotal and VAT rows")
    func vatRows() throws {
        let container = try AppSchema.makeContainer(inMemory: true)
        let (quote, profile) = try sampleQuote(in: container.mainContext)
        quote.vatEnabled = true
        quote.vatRatePercent = 19
        let doc = try QuoteDocument(quote: quote, profile: profile, formatters: formatters)
        #expect(doc.subtotal?.amount == "1,193.58 lei")
        #expect(doc.vat == QuoteDocument.Line(description: "VAT 19%", amount: "226.78 lei"))
        #expect(doc.total.amount == "1,420.36 lei")
    }

    @Test("Rendered PDF is one A4 page with the quote's text")
    func render() throws {
        let container = try AppSchema.makeContainer(inMemory: true)
        let (quote, profile) = try sampleQuote(in: container.mainContext)
        let data = QuotePDFRenderer.render(try QuoteDocument(quote: quote, profile: profile, formatters: formatters))
        let pdf = try #require(PDFDocument(data: data))
        #expect(pdf.pageCount == 1)
        let bounds = try #require(pdf.page(at: 0)).bounds(for: .mediaBox)
        #expect(abs(bounds.width - 595.28) < 1 && abs(bounds.height - 841.89) < 1)
        let text = pdf.string ?? ""
        for expected in ["Popa Renovări", "#0030", "Ana Popescu", "Wall paint, 2 × 5 L", "1,193.58 lei", "Valid for 14 days."] {
            #expect(text.contains(expected), "missing \(expected)")
        }
    }

    @Test("Long quotes continue onto more pages")
    func pagination() {
        let lines = (1...80).map { QuoteDocument.Line(description: "Item \($0)", amount: "10.00 lei") }
        let doc = QuoteDocument(businessName: "B", businessDetails: [], logoPNG: nil, title: "QUOTE", number: "#0001",
                                date: "1 Oct 2026", clientName: nil, clientDetails: [], jobSummary: nil, lines: lines,
                                subtotal: nil, vat: nil, total: .init(description: "Total", amount: "800.00 lei"),
                                validity: nil, terms: nil)
        let pdf = PDFDocument(data: QuotePDFRenderer.render(doc))
        #expect((pdf?.pageCount ?? 0) >= 3)
        #expect(pdf?.string?.contains("Item 80") == true)
        #expect(pdf?.string?.contains("800.00 lei") == true)
    }
}
