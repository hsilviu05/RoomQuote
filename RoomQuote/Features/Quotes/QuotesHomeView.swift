import SwiftUI
import SwiftData

struct QuotesHomeView: View {
    @Environment(AppModel.self) private var appModel
    @Query(sort: \Quote.updatedAt, order: .reverse) private var quotes: [Quote]
    @Query private var profiles: [BusinessProfile]

    private var formatters: Formatters {
        let profile = profiles.first
        return Formatters(currencyCode: profile?.currencyCode ?? "RON", unitSystem: profile?.unitSystem ?? .metric)
    }

    private var stats: QuoteStats {
        QuoteStats.compute(quotes.map { ($0.status, $0.sentAt) })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                StatRow {
                    StatCard(value: "\(stats.sentThisMonth)", label: String(localized: "Sent this month"))
                    StatCard(value: "\(stats.acceptedThisMonth)", label: String(localized: "stat.accepted", defaultValue: "Accepted", comment: "Stat card: number of quotes accepted this month"))
                    StatCard(value: stats.winRatePercent.map { "\($0)%" } ?? "–", label: String(localized: "Win rate"))
                }
                newQuoteButton
                recentSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack {
            Text("Quotes")
                .font(.largeTitle.weight(.heavy))
                .foregroundStyle(Theme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            CircleIconButton(systemImage: "magnifyingglass", label: "Search quotes") {
                appModel.quotesPath.append(.allQuotes(focusSearch: true))
            }
        }
        .padding(.top, 12)
    }

    private var newQuoteButton: some View {
        Button {
            appModel.startNewQuote(createdDates: quotes.map(\.createdAt))
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "viewfinder")
                    .font(.title2.weight(.semibold))
                    .frame(width: 48, height: 48)
                    .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("New quote")
                        .font(.title3.weight(.heavy))
                    Text("Scan a room or enter measurements")
                        .font(.subheadline.weight(.semibold))
                        .opacity(0.92)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Theme.accentFill, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var recentSection: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Recent")
                .font(.headline.weight(.heavy))
                .foregroundStyle(Theme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if !quotes.isEmpty {
                Button("See all") {
                    appModel.quotesPath.append(.allQuotes(focusSearch: false))
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.accentText)
                .frame(minHeight: 44)
            }
        }
        if quotes.isEmpty {
            ContentUnavailableView {
                Label("No quotes yet", systemImage: "doc.text")
            } description: {
                Text("Tap New quote to scan a room or enter its measurements.")
            }
            .padding(.vertical, 24)
        } else {
            LazyVStack(spacing: 8) {
                ForEach(quotes.prefix(4)) { quote in
                    QuoteLink(quote: quote, formatters: formatters)
                }
            }
        }
    }
}

/// A row that opens the right screen for the quote's state.
struct QuoteLink: View {
    let quote: Quote
    let formatters: Formatters

    var body: some View {
        NavigationLink(value: quote.status == .draft ? Route.materials(quote) : Route.quote(quote)) {
            QuoteRow(quote: quote, formatters: formatters)
        }
        .buttonStyle(.plain)
    }
}

struct AllQuotesView: View {
    let focusSearch: Bool
    @Query(sort: \Quote.updatedAt, order: .reverse) private var quotes: [Quote]
    @Query private var profiles: [BusinessProfile]
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var statusFilter: QuoteStatus?

    private var formatters: Formatters {
        let profile = profiles.first
        return Formatters(currencyCode: profile?.currencyCode ?? "RON", unitSystem: profile?.unitSystem ?? .metric)
    }

    private var filtered: [Quote] {
        quotes.filter { quote in
            if let statusFilter, quote.status != statusFilter { return false }
            guard !searchText.isEmpty else { return true }
            let haystack = [QuoteRow.title(for: quote), quote.displayNumber].joined(separator: " ")
            return haystack.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                Picker("Status", selection: $statusFilter) {
                    Text("All").tag(QuoteStatus?.none)
                    ForEach(QuoteStatus.allCases) { status in
                        Text(status.title).tag(QuoteStatus?.some(status))
                    }
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 8)

                if filtered.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ForEach(filtered) { quote in
                        QuoteLink(quote: quote, formatters: formatters)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Theme.background)
        .navigationTitle("All quotes")
        .searchable(text: $searchText, isPresented: $isSearchPresented, prompt: "Client, room or number")
        .onAppear { if focusSearch { isSearchPresented = true } }
    }
}
