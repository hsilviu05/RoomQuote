import Foundation
import SwiftData
import Estimator

/// Creates quotes from measured rooms and keeps their generated line items in
/// step with the job settings. All maths is delegated to `Estimator`.
@MainActor
enum QuoteBuilder {
    static func createDraft(
        roomName: String,
        clientName: String,
        dimensions: RoomDimensions,
        source: RoomSource,
        context: ModelContext
    ) throws -> Quote {
        try Estimator.validate(dimensions)
        let profile = try BusinessProfile.current(in: context)

        let quote = Quote(number: profile.takeQuoteNumber(), client: try findOrCreateClient(named: clientName, in: context), vat: profile.vatSetting)
        quote.validUntil = Calendar.current.date(byAdding: .day, value: profile.quoteValidityDays, to: .now)
        context.insert(quote)

        let trimmedName = roomName.trimmingCharacters(in: .whitespacesAndNewlines)
        let room = Room(
            name: trimmedName.isEmpty ? String(localized: "Room") : trimmedName,
            lengthM: dimensions.length,
            widthM: dimensions.width,
            heightM: dimensions.height,
            source: source
        )
        context.insert(room)
        room.openings = dimensions.openings.enumerated().map { index, opening in
            Opening(kind: opening.kind, widthM: opening.width, heightM: opening.height, quantity: opening.quantity, sortOrder: index)
        }

        let job = Job(type: .paint)
        context.insert(job)
        job.room = room
        quote.jobs = [job]
        try applyPriceDefaults(to: job, context: context)
        try context.save()
        return quote
    }

    static func findOrCreateClient(named name: String, in context: ModelContext) throws -> Client? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let existing = try context.fetch(FetchDescriptor<Client>())
        if let match = existing.first(where: { $0.name.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            return match
        }
        let client = Client(name: trimmed)
        context.insert(client)
        return client
    }

    /// Fills the job's material and labour prices from the price list for its job type.
    static func applyPriceDefaults(to job: Job, context: ModelContext) throws {
        let prices = try context.fetch(FetchDescriptor<PriceItem>(sortBy: [SortDescriptor(\.createdAt)]))
            .filter { !$0.isArchived }
        let type = job.type

        if let material = prices.first(where: { $0.category == type.priceCategory }) {
            job.materialName = material.name
            job.materialUnitPrice = material.unitPrice
            if material.packSize > 0 {
                if type == .paint { job.canSizeL = material.packSize } else { job.boxCoverageM2 = material.packSize }
            }
        } else {
            job.materialName = defaultMaterialName(for: type)
            job.materialUnitPrice = 0
        }

        if let labour = prices.first(where: { $0.category == .labour && $0.jobTypeRaw == type.rawValue }) {
            job.labourRate = labour.unitPrice
            job.labourMode = labour.unit == .hour ? .perHour : .perSquareMetre
        } else {
            job.labourRate = 0
            job.labourMode = .perSquareMetre
        }
    }

    static func defaultMaterialName(for type: JobType) -> String {
        switch type {
        case .paint: String(localized: "Wall paint")
        case .floor: String(localized: "Flooring")
        case .tiles: String(localized: "Tiles")
        }
    }

    /// Re-runs the estimate and replaces the generated lines; extras stay.
    @discardableResult
    static func recalculate(_ quote: Quote, formatters: Formatters, context: ModelContext) throws -> JobEstimate? {
        guard let job = quote.job, let room = job.room else { return nil }
        let estimate = try Estimator.estimate(JobInput(
            type: job.type,
            room: room.dimensions,
            paint: job.paintSpec,
            covering: job.coveringSpec,
            materialUnitPrice: job.materialUnitPrice,
            materialTitle: job.materialName,
            labour: job.labourPricing,
            labourTitle: String(localized: "Labour")
        ))

        let extras = quote.sortedLineItems.filter { !$0.isGenerated }
        for line in quote.lineItems ?? [] where line.isGenerated {
            context.delete(line)
        }

        var lines: [LineItem] = []
        for (index, item) in estimate.lineItems.enumerated() {
            let texts = describe(item, job: job, estimate: estimate, formatters: formatters)
            lines.append(LineItem(item: item, detail: texts.detail, summary: texts.summary, isGenerated: true, sortOrder: index))
        }
        // Extras sit between the main material and labour, as in the design.
        let labour = lines.popLast()
        lines += extras
        if let labour { lines.append(labour) }
        for (index, line) in lines.enumerated() { line.sortOrder = index }

        quote.lineItems = lines
        try quote.refreshTotal()
        try context.save()
        return estimate
    }

    static func addExtra(_ price: PriceItem, to quote: Quote, workArea: Decimal, formatters: Formatters, context: ModelContext) throws {
        let quantity: Decimal
        let unit: QuantityUnit
        let detail: String
        let summary: String
        switch price.unit {
        case .can:
            quantity = 1
            unit = .can
            let size = price.packSize > 0 ? "\(formatters.volume(price.packSize, packSize: true))" : ""
            detail = size.isEmpty ? String(localized: "1 can") : String(localized: "1 × \(size)")
            summary = size.isEmpty ? price.name : String(localized: "\(price.name), 1 × \(size)")
        case .box:
            quantity = 1
            unit = .box
            detail = String(localized: "1 box")
            summary = String(localized: "\(price.name), 1 box")
        case .squareMetre:
            quantity = workArea.rounded(scale: 2)
            unit = .squareMetre
            detail = String(localized: "\(formatters.area(quantity)) × \(formatters.money(price.unitPrice))/m²")
            summary = String(localized: "\(price.name), \(formatters.area(quantity))")
        case .hour:
            quantity = 1
            unit = .hour
            detail = String(localized: "1 h × \(formatters.money(price.unitPrice))/h")
            summary = price.name
        case .item:
            quantity = 1
            unit = .item
            detail = String(localized: "Fixed item")
            summary = price.name
        }
        let kind: PricedLine.Kind = price.category == .labour ? .labour : (price.category == .other ? .other : .material)
        let item = PricedLine(title: price.name, kind: kind, quantity: quantity, unit: unit, unitPrice: price.unitPrice)
        let line = LineItem(item: item, detail: detail, summary: summary, sortOrder: (quote.lineItems?.count ?? 0))
        context.insert(line)
        let labourIndex = quote.sortedLineItems.firstIndex { $0.isGenerated && $0.kindRaw == PricedLine.Kind.labour.rawValue }
        var lines = quote.sortedLineItems
        lines.insert(line, at: labourIndex ?? lines.endIndex)
        for (index, line) in lines.enumerated() { line.sortOrder = index }
        quote.lineItems = lines
        try quote.refreshTotal()
        try context.save()
    }

    static func removeLine(_ line: LineItem, from quote: Quote, context: ModelContext) throws {
        quote.lineItems?.removeAll { $0 == line }
        context.delete(line)
        try quote.refreshTotal()
        try context.save()
    }

    private static func describe(_ item: PricedLine, job: Job, estimate: JobEstimate, formatters: Formatters) -> (detail: String, summary: String) {
        switch item.kind {
        case .labour:
            switch job.labourMode {
            case .perSquareMetre:
                let area = formatters.area(item.quantity)
                return (String(localized: "\(area) × \(formatters.money(item.unitPrice))/m²"),
                        String(localized: "Labour, \(area)"))
            case .perHour:
                let hours = formatters.number(item.quantity, 1, minimumFractionDigits: 0)
                return (String(localized: "\(hours) h × \(formatters.money(item.unitPrice))/h"),
                        String(localized: "Labour, \(hours) h"))
            }
        case .material, .other:
            if let paint = estimate.paint {
                let can = formatters.volume(job.canSizeL, packSize: true)
                return (String(localized: "\(formatters.volume(paint.litres)) needed · \(paint.cans) × \(can) cans"),
                        String(localized: "\(item.title), \(paint.cans) × \(can)"))
            }
            if let covering = estimate.covering {
                return (String(localized: "\(formatters.area(covering.orderArea)) incl. waste · \(covering.packs) boxes"),
                        String(localized: "\(item.title), \(covering.packs) boxes"))
            }
            return ("", item.title)
        }
    }
}
