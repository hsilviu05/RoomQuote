import Foundation
import SwiftData
import Estimator

/// Demo content matching the designs. Debug builds only, and only into an empty store,
/// so it never reaches customers.
@MainActor
enum SampleData {
    static func seedIfNeeded(_ context: ModelContext) {
        #if DEBUG
        guard !ProcessInfo.processInfo.arguments.contains("-noSampleData") else { return }
        do {
            guard try context.fetchCount(FetchDescriptor<Quote>()) == 0,
                  try context.fetchCount(FetchDescriptor<PriceItem>()) == 0
            else { return }
            try seed(context)
        } catch {
            assertionFailure("Sample data failed: \(error)")
        }
        #endif
    }

    static func d(_ string: String) -> Decimal { Decimal(string: string, locale: Locale(identifier: "en_US_POSIX"))! }

    static func seed(_ context: ModelContext, now: Date = .now) throws {
        let profile = try BusinessProfile.current(in: context)
        profile.currencyCode = "RON"
        profile.quoteValidityDays = 14
        profile.terms = String(localized: "Materials priced at today's supplier rates.")
        profile.nextQuoteNumber = 30

        let prices: [PriceItem] = [
            PriceItem(name: "Wall paint", category: .paint, unit: .can, unitPrice: 189, packSize: 5),
            PriceItem(name: "Primer", category: .paint, unit: .can, unitPrice: 120, packSize: 5),
            PriceItem(name: "Tape & protection", category: .other, unit: .item, unitPrice: 60),
            PriceItem(name: "Laminate", category: .floor, unit: .box, unitPrice: d("144.57"), packSize: d("2.22")),
            PriceItem(name: "Ceramic tiles", category: .tiles, unit: .box, unitPrice: d("151.52"), packSize: d("1.44")),
            labour("Painting labour", rate: 18, job: .paint),
            labour("Flooring labour", rate: 40, job: .floor),
            labour("Tiling labour", rate: 80, job: .tiles)
        ]
        for (index, price) in prices.enumerated() {
            price.createdAt = now.addingTimeInterval(Double(index - prices.count))
            context.insert(price)
        }
        try context.save()

        let calendar = Calendar.current
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        // Created last month so the free-plan limit still leaves room to try the flow.
        let created = calendar.date(byAdding: .day, value: -5, to: monthStart) ?? now
        func sent(_ hoursAgo: Double) -> Date { max(monthStart, now.addingTimeInterval(-hoursAgo * 3600)) }

        let formatters = Formatters(currencyCode: "RON", unitSystem: .metric)

        func make(_ client: String, room: String, _ l: String, _ w: String, _ h: String,
                  openings: [OpeningDimensions] = [], type: JobType, status: QuoteStatus,
                  sentHoursAgo: Double?, extras: [PriceItem] = [], priced: Bool = true,
                  source: RoomSource = .manual) throws {
            let quote = try QuoteBuilder.createDraft(
                roomName: room, clientName: client,
                dimensions: RoomDimensions(length: d(l), width: d(w), height: d(h), openings: openings),
                source: source, context: context
            )
            if let job = quote.job, job.type != type {
                job.type = type
                try QuoteBuilder.applyPriceDefaults(to: job, context: context)
            }
            if priced {
                let estimate = try QuoteBuilder.recalculate(quote, formatters: formatters, context: context)
                for extra in extras {
                    try QuoteBuilder.addExtra(extra, to: quote, workArea: estimate?.workArea ?? 0, formatters: formatters, context: context)
                }
            }
            quote.createdAt = created
            if let hours = sentHoursAgo {
                quote.status = status
                quote.sentAt = sent(hours)
                quote.updatedAt = sent(hours)
            } else {
                quote.updatedAt = now.addingTimeInterval(-36 * 3600)
            }
            quote.validUntil = calendar.date(byAdding: .day, value: 14, to: quote.sentAt ?? created)
        }

        let primer = prices[1], tape = prices[2]
        try make("Ana Popescu", room: "Living room", "4.2", "3.6", "2.6",
                 openings: [OpeningDimensions(kind: .door, width: d("0.9"), height: d("2.1")),
                            OpeningDimensions(kind: .window, width: d("1.2"), height: d("1.4"), quantity: 2)],
                 type: .paint, status: .sent, sentHoursAgo: 2, extras: [primer, tape])
        try make("Mihai Ionescu", room: "Kitchen", "3.6", "3.28", "2.5", type: .tiles, status: .accepted, sentHoursAgo: 20)
        try make("Elena Dinu", room: "2 bedrooms", "5.2", "5.27", "2.6", type: .floor, status: .paid, sentHoursAgo: 30)
        try make("", room: "Bathroom", "2.4", "2.0", "2.5", type: .tiles, status: .draft, sentHoursAgo: nil,
                 priced: false, source: .scan)

        // Older quotes this month so the stats read 12 sent, 7 accepted, 58%.
        let older: [(String, String, JobType, QuoteStatus)] = [
            ("Andrei Stan", "Hallway", .paint, .accepted), ("Ioana Marin", "Bedroom", .paint, .paid),
            ("Radu Georgescu", "Office", .floor, .accepted), ("Cristina Pop", "Kids' room", .paint, .sent),
            ("Vlad Munteanu", "Bathroom", .tiles, .paid), ("Maria Dobre", "Living room", .floor, .sent),
            ("Paul Ene", "Kitchen", .tiles, .accepted), ("Sorina Lupu", "Bedroom", .paint, .sent),
            ("Dan Matei", "Studio", .floor, .sent)
        ]
        for (index, entry) in older.enumerated() {
            try make(entry.0, room: entry.1, "3.8", "3.2", "2.6", type: entry.2, status: entry.3,
                     sentHoursAgo: 48 + Double(index) * 24)
        }
        try context.save()
    }

    private static func labour(_ name: String, rate: Decimal, job: JobType) -> PriceItem {
        let item = PriceItem(name: name, category: .labour, unit: .squareMetre, unitPrice: rate)
        item.jobTypeRaw = job.rawValue
        return item
    }
}
