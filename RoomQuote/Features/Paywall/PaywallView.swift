import SwiftUI

struct PaywallView: View {
    enum Plan: Hashable { case yearly, monthly }

    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var plan: Plan = .yearly
    @State private var isWorking = false
    @State private var errorMessage: String?

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

                    VStack(spacing: 10) {
                        planButton(.yearly,
                                   title: "Yearly",
                                   detail: "\(SubscriptionConfig.yearlyDisplayPrice) / year · \(SubscriptionConfig.yearlyPerMonthDisplayPrice) / month",
                                   badge: "Save 33%")
                        planButton(.monthly,
                                   title: "Monthly",
                                   detail: "\(SubscriptionConfig.monthlyDisplayPrice) / month",
                                   badge: nil)
                    }
                    .padding(.top, 26)
                }
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 24)
                .padding(.top, 4)
            }

            VStack(spacing: 10) {
                Button {
                    Task { await purchase() }
                } label: {
                    if isWorking { ProgressView().tint(.white) } else { Text("Start \(SubscriptionConfig.trialDays)-day free trial") }
                }
                .buttonStyle(PrimaryButtonStyle(minHeight: 56))
                .disabled(isWorking)

                Text(termsText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                HStack(spacing: 18) {
                    Button("Restore purchases") { Task { await restore() } }
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
        .background(Theme.surface)
        .alert("Purchase not completed", isPresented: .constant(errorMessage != nil), presenting: errorMessage) { _ in
            Button("OK") { errorMessage = nil }
        } message: { Text($0) }
    }

    private var termsText: String {
        let price = plan == .yearly
            ? String(localized: "\(SubscriptionConfig.yearlyDisplayPrice) per year")
            : String(localized: "\(SubscriptionConfig.monthlyDisplayPrice) per month")
        return String(localized: "Free for \(SubscriptionConfig.trialDays) days, then \(price). Cancel anytime in Settings at least 24 hours before renewal.")
    }

    private func planButton(_ value: Plan, title: LocalizedStringKey, detail: String, badge: LocalizedStringKey?) -> some View {
        let isSelected = plan == value
        return Button {
            plan = value
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

    private func purchase() async {
        isWorking = true
        defer { isWorking = false }
        let productID = plan == .yearly ? SubscriptionConfig.yearlyProductID : SubscriptionConfig.monthlyProductID
        do {
            try await appModel.entitlements.purchase(productID: productID)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restore() async {
        do {
            try await appModel.entitlements.restorePurchases()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
