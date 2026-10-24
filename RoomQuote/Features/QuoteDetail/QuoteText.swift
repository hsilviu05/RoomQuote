import Foundation
import Estimator

/// Plain-text version of a quote, used for sharing until the PDF step lands.
enum QuoteText {
    static func make(quote: Quote, profile: BusinessProfile?, formatters f: Formatters, now: Date = .now) -> String {
        var lines: [String] = []
        let business = profile?.name.isEmpty == false ? profile!.name : String(localized: "Quote")
        lines.append("\(business) · \(String(localized: "Quote")) \(quote.displayNumber)")
        if let client = quote.client?.name { lines.append(String(localized: "For: \(client)")) }
        if let summary = jobSummary(quote: quote, formatters: f) { lines.append(String(localized: "Job: \(summary)")) }
        lines.append("")
        for item in quote.sortedLineItems {
            lines.append("\(item.summary): \(f.money(item.total))")
        }
        if let totals = try? quote.totals() {
            if quote.vatEnabled {
                lines.append(String(localized: "Subtotal: \(f.money(totals.subtotal))"))
                lines.append(String(localized: "VAT \(DecimalInput.string(quote.vatRatePercent))%: \(f.money(totals.vat))"))
            }
            lines.append(String(localized: "Total: \(f.money(totals.total))"))
        }
        if let validity = validityText(quote: quote, now: now) {
            lines.append("")
            lines.append(validity)
        }
        if let terms = profile?.terms, !terms.isEmpty { lines.append(terms) }
        if let profile, !profile.phone.isEmpty || !profile.email.isEmpty {
            lines.append([profile.phone, profile.email].filter { !$0.isEmpty }.joined(separator: " · "))
        }
        return lines.joined(separator: "\n")
    }

    /// "Living room painting, 2 coats, 35.3 m²"
    static func jobSummary(quote: Quote, formatters f: Formatters) -> String? {
        guard let job = quote.job, let room = job.room else { return nil }
        let roomName = room.name
        switch job.type {
        case .paint:
            let walls = (try? Estimator.wallArea(of: room.dimensions).net) ?? 0
            return String(localized: "\(roomName) painting, \(job.coats) coats, \(f.area(walls))")
        case .floor:
            let floor = (try? Estimator.floorArea(of: room.dimensions)) ?? 0
            return String(localized: "\(roomName) flooring, \(f.area(floor))")
        case .tiles:
            let floor = (try? Estimator.floorArea(of: room.dimensions)) ?? 0
            return String(localized: "\(roomName) tiling, \(f.area(floor))")
        }
    }

    static func validityText(quote: Quote, now: Date = .now, calendar: Calendar = .current) -> String? {
        guard let validUntil = quote.validUntil else { return nil }
        let start = calendar.startOfDay(for: quote.createdAt)
        let days = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: validUntil)).day ?? 0
        guard days > 0 else { return nil }
        return String(localized: "Valid for \(days) days.")
    }
}
