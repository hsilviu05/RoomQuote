import SwiftUI
import Estimator

struct QuoteRow: View {
    let quote: Quote
    let formatters: Formatters

    private var hasPrices: Bool {
        quote.sortedLineItems.contains { $0.unitPrice > 0 }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(Self.title(for: quote))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                if hasPrices {
                    Text(formatters.money(quote.cachedTotal))
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(Theme.textPrimary)
                }
                StatusPill(status: quote.status)
            }
        }
        .card(dashed: quote.status == .draft)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text(quote.status == .draft ? "Opens room and materials" : "Opens the quote"))
    }

    static func title(for quote: Quote) -> String {
        let client = quote.client?.name ?? String(localized: "Untitled")
        guard let room = quote.room?.name, !room.isEmpty else { return client }
        return "\(client) · \(room)"
    }

    private var subtitle: String {
        guard let job = quote.job, let room = job.room else {
            return String(localized: "No room yet")
        }
        guard hasPrices else {
            return room.source == .scan
                ? String(localized: "Scan saved, no prices yet")
                : String(localized: "Measurements saved, no prices yet")
        }
        let activity = job.type == .floor && !job.materialName.isEmpty ? job.materialName : job.type.activityTitle
        switch job.type {
        case .paint:
            let walls = (try? Estimator.wallArea(of: room.dimensions).net) ?? 0
            return String(localized: "\(activity) · \(formatters.area(walls)) walls")
        case .floor, .tiles:
            let floor = (try? Estimator.floorArea(of: room.dimensions)) ?? 0
            return String(localized: "\(activity) · \(formatters.area(floor)) floor")
        }
    }
}
