import Foundation
import SwiftData
import Testing
import Estimator
@testable import RoomQuote

private func d(_ s: String) -> Decimal { Decimal(string: s, locale: Locale(identifier: "en_US_POSIX"))! }

private let sanityRoom = RoomDimensions(
    length: d("4.2"), width: d("3.6"), height: d("2.6"),
    openings: [OpeningDimensions(kind: .door, width: d("0.9"), height: d("2.1")),
               OpeningDimensions(kind: .window, width: d("1.2"), height: d("1.4"), quantity: 2)]
)

private let formatters = Formatters(currencyCode: "RON", unitSystem: .metric, locale: Locale(identifier: "en_US"))

@MainActor
@Suite("SwiftData models and QuoteBuilder")
struct ModelTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try AppSchema.makeContainer(inMemory: true)
    }

    private func addPrices() throws {
        context.insert(PriceItem(name: "Wall paint", category: .paint, unit: .can, unitPrice: 189, packSize: 5))
        let labour = PriceItem(name: "Painting labour", category: .labour, unit: .squareMetre, unitPrice: 18)
        labour.jobTypeRaw = JobType.paint.rawValue
        context.insert(labour)
        context.insert(PriceItem(name: "Tape", category: .other, unit: .item, unitPrice: 60))
        try context.save()
    }

    @Test("Creating a draft saves the room, openings and job")
    func createDraft() throws {
        let quote = try QuoteBuilder.createDraft(roomName: "Living room", clientName: "Ana", dimensions: sanityRoom, source: .manual, context: context)
        #expect(quote.status == .draft)
        #expect(quote.number == 1)
        #expect(quote.client?.name == "Ana")
        #expect(quote.room?.name == "Living room")
        #expect(quote.room?.sortedOpenings.count == 2)
        #expect(quote.room?.openingCount == 3)
        #expect(quote.room?.dimensions == sanityRoom)
    }

    @Test("Quote numbers increase")
    func quoteNumbers() throws {
        let first = try QuoteBuilder.createDraft(roomName: "A", clientName: "", dimensions: sanityRoom, source: .manual, context: context)
        let second = try QuoteBuilder.createDraft(roomName: "B", clientName: "", dimensions: sanityRoom, source: .manual, context: context)
        #expect(second.number == first.number + 1)
        #expect(second.displayNumber == "#0002")
    }

    @Test("Clients are matched by name, ignoring case and accents")
    func clientMatching() throws {
        _ = try QuoteBuilder.createDraft(roomName: "A", clientName: "Ana Popescu", dimensions: sanityRoom, source: .manual, context: context)
        _ = try QuoteBuilder.createDraft(roomName: "B", clientName: "  ana popescu ", dimensions: sanityRoom, source: .manual, context: context)
        #expect(try context.fetchCount(FetchDescriptor<Client>()) == 1)
    }

    @Test("Blank client and room names fall back sensibly")
    func blankNames() throws {
        let quote = try QuoteBuilder.createDraft(roomName: "  ", clientName: "", dimensions: sanityRoom, source: .scan, context: context)
        #expect(quote.client == nil)
        #expect(quote.room?.name == "Room")
        #expect(quote.room?.source == .scan)
    }

    @Test("Invalid dimensions are rejected before anything is saved")
    func invalidDimensions() throws {
        let bad = RoomDimensions(length: d("-1"), width: 3, height: 2)
        #expect(throws: EstimatorError.negative(.roomLength)) {
            try QuoteBuilder.createDraft(roomName: "A", clientName: "", dimensions: bad, source: .manual, context: context)
        }
        #expect(try context.fetchCount(FetchDescriptor<Quote>()) == 0)
    }

    @Test("Recalculating fills material and labour from the price list")
    func recalculate() throws {
        try addPrices()
        let quote = try QuoteBuilder.createDraft(roomName: "Living room", clientName: "Ana", dimensions: sanityRoom, source: .manual, context: context)
        let estimate = try #require(try QuoteBuilder.recalculate(quote, formatters: formatters, context: context))
        #expect(estimate.paint?.cans == 2)
        let lines = quote.sortedLineItems
        #expect(lines.map(\.title) == ["Wall paint", "Labour"])
        #expect(lines.map(\.total) == [d("378"), d("635.58")])
        #expect(quote.cachedTotal == d("1013.58"))
        #expect(lines[0].detail == "7.8 L needed · 2 × 5 L cans")
        #expect(lines[1].detail == "35.3 m² × 18 lei/m²")
    }

    @Test("Extras survive recalculation and sit before labour")
    func extrasKept() throws {
        try addPrices()
        let quote = try QuoteBuilder.createDraft(roomName: "Living room", clientName: "", dimensions: sanityRoom, source: .manual, context: context)
        try QuoteBuilder.recalculate(quote, formatters: formatters, context: context)
        let tape = try #require(try context.fetch(FetchDescriptor<PriceItem>()).first { $0.name == "Tape" })
        try QuoteBuilder.addExtra(tape, to: quote, workArea: 0, formatters: formatters, context: context)
        quote.job?.coats = 3
        try QuoteBuilder.recalculate(quote, formatters: formatters, context: context)
        #expect(quote.sortedLineItems.map(\.title) == ["Wall paint", "Tape", "Labour"])
        #expect(quote.sortedLineItems.first?.quantity == 3) // 35.31 × 3 ÷ 10 × 1.1 = 11.65 L → 3 cans
    }

    @Test("Removing an extra updates the total")
    func removeExtra() throws {
        try addPrices()
        let quote = try QuoteBuilder.createDraft(roomName: "R", clientName: "", dimensions: sanityRoom, source: .manual, context: context)
        try QuoteBuilder.recalculate(quote, formatters: formatters, context: context)
        let tape = try #require(try context.fetch(FetchDescriptor<PriceItem>()).first { $0.name == "Tape" })
        try QuoteBuilder.addExtra(tape, to: quote, workArea: 0, formatters: formatters, context: context)
        #expect(quote.cachedTotal == d("1073.58"))
        let line = try #require(quote.sortedLineItems.first { $0.title == "Tape" })
        try QuoteBuilder.removeLine(line, from: quote, context: context)
        #expect(quote.cachedTotal == d("1013.58"))
    }

    @Test("VAT from the business profile is applied to new quotes")
    func vatFromProfile() throws {
        try addPrices()
        let profile = try BusinessProfile.current(in: context)
        profile.vatEnabled = true
        profile.vatRatePercent = 19
        let quote = try QuoteBuilder.createDraft(roomName: "R", clientName: "", dimensions: sanityRoom, source: .manual, context: context)
        try QuoteBuilder.recalculate(quote, formatters: formatters, context: context)
        let totals = try quote.totals()
        #expect(totals.vat == d("192.58")) // 1013.58 × 19% = 192.5802
        #expect(totals.total == d("1206.16"))
    }

    @Test("Missing prices give zero-priced lines, not a crash")
    func noPrices() throws {
        let quote = try QuoteBuilder.createDraft(roomName: "R", clientName: "", dimensions: sanityRoom, source: .manual, context: context)
        try QuoteBuilder.recalculate(quote, formatters: formatters, context: context)
        #expect(quote.job?.materialName == "Wall paint")
        #expect(quote.cachedTotal == 0)
    }

    @Test("Deleting a quote deletes its job, room, openings and lines; the client stays")
    func cascadeDelete() throws {
        try addPrices()
        let quote = try QuoteBuilder.createDraft(roomName: "R", clientName: "Ana", dimensions: sanityRoom, source: .manual, context: context)
        try QuoteBuilder.recalculate(quote, formatters: formatters, context: context)
        context.delete(quote)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Job>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Room>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<RoomQuote.Opening>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<RoomQuote.LineItem>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Client>()) == 1)
    }

    @Test("Setting a status other than draft records when it was sent")
    func statusSetsSentAt() throws {
        let quote = try QuoteBuilder.createDraft(roomName: "R", clientName: "", dimensions: sanityRoom, source: .manual, context: context)
        #expect(quote.sentAt == nil)
        quote.status = .sent
        let sentAt = try #require(quote.sentAt)
        quote.status = .accepted
        #expect(quote.sentAt == sentAt)
    }

    @Test("Sample data seeds the designed home screen")
    func sampleData() throws {
        try SampleData.seed(context)
        let quotes = try context.fetch(FetchDescriptor<Quote>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))
        let stats = QuoteStats.compute(quotes.map { ($0.status, $0.sentAt) })
        #expect(stats == QuoteStats(sentThisMonth: 12, acceptedThisMonth: 7, winRatePercent: 58))
        let top = quotes.prefix(4)
        #expect(top.map { QuoteRow.title(for: $0) } == ["Ana Popescu · Living room", "Mihai Ionescu · Kitchen", "Elena Dinu · 2 bedrooms", "Untitled · Bathroom"])
        #expect(top.map { formatters.money($0.cachedTotal) }.prefix(3) == ["1,194 lei", "2,460 lei", "3,120 lei"])
        #expect(top.map(\.status) == [.sent, .accepted, .paid, .draft])
    }
}
