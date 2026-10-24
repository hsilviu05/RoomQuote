import Foundation

/// The three numbers at the top of the Quotes screen.
struct QuoteStats: Equatable {
    var sentThisMonth: Int
    var acceptedThisMonth: Int
    /// Accepted ÷ sent, as a whole percentage. Nil when nothing was sent.
    var winRatePercent: Int?

    /// A quote counts in the month it was sent; accepted and paid both count as won.
    static func compute(_ quotes: [(status: QuoteStatus, sentAt: Date?)], now: Date = .now, calendar: Calendar = .current) -> QuoteStats {
        let sent = quotes.filter { quote in
            guard quote.status != .draft, let sentAt = quote.sentAt else { return false }
            return calendar.isDate(sentAt, equalTo: now, toGranularity: .month)
        }
        let won = sent.filter { $0.status.isWon }.count
        let rate = sent.isEmpty ? nil : Int((Double(won) / Double(sent.count) * 100).rounded())
        return QuoteStats(sentThisMonth: sent.count, acceptedThisMonth: won, winRatePercent: rate)
    }
}
