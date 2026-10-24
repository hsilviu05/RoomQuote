import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var selectedID = SubscriptionConfig.yearlyProductID
    @State private var isWorking = false
    @State private var alert: AlertContent?

    struct AlertContent: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    private var store: EntitlementStore { appModel.entitlements }
    private var selected: Product? { store.products.first { $0.id == selectedID } }

    private let features: [LocalizedStringKey] = [
        "Unlimited room scans and quotes",
        "Your logo and terms on every PDF",
        "Saved price lists for paint, floors and tiles",
        "Quote tracking: sent, accepted, paid"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(Theme.sunken, in: Circle())
                }
                .accessibilityLabel(Text("Close"))
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Quote on the spot.\nWin more jobs.")
                        .font(.largeTitle.weight(.heavy))
                        .accessibilityAddTraits(.isHeader)
                    Text("Free plan: \(QuoteLimitPolicy.freeQuotesPerMonth) quotes a month. Pro removes every limit.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.top, 10)

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(features.enumerated()), id: \.offset) { _, feature in
                            Label {
                                Text(feature).font(.subheadline.weight(.bold))
                            } icon: {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.heavy))
                                    .foregroundStyle(Theme.accentText)
                            }
                        }
                    }
                    .padding(.top, 20)

                    plans.padding(.top, 26)
                }
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 24)
                .padding(.top, 4)
            }

            footer
        }
        .background(Theme.surface)
        .task { if store.loadState != .loaded { await store.loadProducts() } }
        .alert(item: $alert) { content in
            Alert(title: Text(content.title), message: Text(content.message))
        }
    }

    @ViewBuilder
    private var plans: some View {
        if store.isPro {
            Label("You're on Pro. Thank you!", systemImage: "checkmark.seal.fill")
                .font(.headline.weight(.heavy))
                .foregroundStyle(Theme.accentText)
        } else {
            switch store.loadState {
            case .loaded:
                VStack(spacing: 10) {
                    if let yearly = store.yearly {
                        planButton(yearly, title: "Yearly", detail: yearlyDetail(yearly), badge: savingsBadge)
                    }
                    if let monthly = store.monthly {
                        planButton(monthly, title: "Monthly", detail: String(localized: "\(monthly.displayPrice) / month"), badge: nil)
                    }
                }
            case .failed:
                VStack(alignment: .leading, spacing: 10) {
                    Text("Couldn't load subscription prices. Check your connection and try again.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Button("Try again") { Task { await store.loadProducts() } }
                        .font(.subheadline.weight(.bold))
                        .frame(minHeight: 44)
                }
            case .idle, .loading:
                ProgressView("Loading prices…")
                    .frame(maxWidth: .infinity, minHeight: 138)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            if !store.isPro {
                Button {
                    Task { await purchase() }
                } label: {
                    if isWorking { ProgressView().tint(.white) } else { Text(ctaTitle) }
                }
                .buttonStyle(PrimaryButtonStyle(minHeight: 56))
                .disabled(isWorking || selected == nil)

                if let terms = termsText {
                    Text(terms)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }

            HStack(spacing: 18) {
                Button("Restore purchases") { Task { await restore() } }
                    .disabled(isWorking)
                Button("Terms") { openURL(SubscriptionConfig.termsURL) }
                Button("Privacy") { openURL(SubscriptionConfig.privacyURL) }
            }
            .font(.footnote.weight(.bold))
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: Copy

    private var trialDays: Int? {
        guard store.isEligibleForTrial,
              let offer = selected?.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial
        else { return nil }
        return offer.period.days * offer.periodCount
    }

    private var ctaTitle: String {
        if let trialDays { return String(localized: "Start \(trialDays)-day free trial") }
        return String(localized: "Subscribe")
    }

    private var termsText: String? {
        guard let selected, let period = selected.subscription?.subscriptionPeriod else { return nil }
        let price = String(localized: "\(selected.displayPrice) per \(period.unitName)")
        if let trialDays {
            return String(localized: "Free for \(trialDays) days, then \(price). Cancel anytime in Settings at least 24 hours before renewal.")
        }
        return String(localized: "\(price), renews automatically. Cancel anytime in Settings at least 24 hours before renewal.")
    }

    private func yearlyDetail(_ yearly: Product) -> String {
        let perMonth = (yearly.price / 12).formatted(yearly.priceFormatStyle)
        return String(localized: "\(yearly.displayPrice) / year · \(perMonth) / month")
    }

    private var savingsBadge: String? {
        guard let yearly = store.yearly, let monthly = store.monthly,
              let percent = PaywallMath.savingsPercent(yearly: yearly.price, monthly: monthly.price)
        else { return nil }
        return String(localized: "Save \(percent)%")
    }

    private func planButton(_ product: Product, title: LocalizedStringKey, detail: String, badge: String?) -> some View {
        let isSelected = selectedID == product.id
        return Button {
            selectedID = product.id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.callout.weight(.heavy))
                    Text(detail).font(.footnote.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if let badge {
                    Text(badge)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.accentFill, in: Capsule())
                }
            }
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 64)
            .background(isSelected ? Theme.selectedPlan : Theme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? Theme.accentFill : Theme.strongBorder, lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: Actions

    private func purchase() async {
        guard let selected else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            if try await store.purchase(selected) { dismiss() }
        } catch {
            alert = AlertContent(title: String(localized: "Purchase not completed"), message: error.localizedDescription)
        }
    }

    private func restore() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await store.restorePurchases()
            if store.isPro {
                dismiss()
            } else {
                alert = AlertContent(title: String(localized: "Nothing to restore"),
                                     message: String(localized: "No active RoomQuote Pro subscription was found for this Apple Account."))
            }
        } catch {
            alert = AlertContent(title: String(localized: "Restore failed"), message: error.localizedDescription)
        }
    }
}

enum PaywallMath {
    /// How much cheaper a year is than 12 months, rounded down so the badge never overstates it.
    static func savingsPercent(yearly: Decimal, monthly: Decimal) -> Int? {
        let fullYear = monthly * 12
        guard fullYear > 0, yearly < fullYear else { return nil }
        let percent = ((fullYear - yearly) / fullYear * 100).rounded(scale: 0, mode: .down)
        let value = NSDecimalNumber(decimal: percent).intValue
        return value > 0 ? value : nil
    }
}

extension Product.SubscriptionPeriod {
    var days: Int {
        switch unit {
        case .day: value
        case .week: value * 7
        case .month: value * 30
        case .year: value * 365
        @unknown default: value
        }
    }

    var unitName: String {
        switch unit {
        case .day: String(localized: "day")
        case .week: String(localized: "week")
        case .month: String(localized: "month")
        case .year: String(localized: "year")
        @unknown default: String(localized: "period")
        }
    }
}
