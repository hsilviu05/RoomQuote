import SwiftUI
import SwiftData
import Estimator

struct QuoteView: View {
    let quote: Quote
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var appModel
    @Query private var profiles: [BusinessProfile]
    @State private var isPDFStubAlertShown = false
    @State private var saveError: String?

    private var profile: BusinessProfile? { profiles.first }
    private var f: Formatters {
        Formatters(currencyCode: profile?.currencyCode ?? "RON", unitSystem: profile?.unitSystem ?? .metric)
    }
    private var shareText: String { QuoteText.make(quote: quote, profile: profile, formatters: f) }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 12) {
                    paper
                    statusPicker
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            actions
        }
        .background(Theme.paperBackdrop)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        // STUB: replaced by the PDF generator (UIGraphicsPDFRenderer) in the PDF step.
        .alert("PDF export is coming next", isPresented: $isPDFStubAlertShown) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("For now, WhatsApp and Email send the quote as text.")
        }
        .alert("Couldn't update the quote", isPresented: .constant(saveError != nil), presenting: saveError) { _ in
            Button("OK") { saveError = nil }
        } message: { Text($0) }
    }

    private var header: some View {
        HStack {
            CircleIconButton(systemImage: "chevron.left", label: "Back") { dismiss() }
            Spacer()
            Text("Quote \(quote.displayNumber)")
                .font(.headline.weight(.heavy))
                .foregroundStyle(Theme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            CircleIconButton(systemImage: "pencil", label: "Edit quote") {
                appModel.quotesPath = [.materials(quote)]
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private var paper: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                HStack(spacing: 10) {
                    logo
                    VStack(alignment: .leading, spacing: 0) {
                        Text(profile?.name.isEmpty == false ? profile!.name : String(localized: "[Your business name]"))
                            .font(.subheadline.weight(.heavy))
                        Text(contactLine)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("QUOTE")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.textSecondary)
                    Text(quote.sentAt ?? quote.createdAt, format: .dateTime.day().month(.abbreviated).year())
                        .font(.caption.weight(.bold))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                if let client = quote.client?.name {
                    (Text("For: ").fontWeight(.heavy) + Text(client))
                }
                if let summary = QuoteText.jobSummary(quote: quote, formatters: f) {
                    (Text("Job: ").fontWeight(.heavy) + Text(summary))
                }
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.sunken, in: RoundedRectangle(cornerRadius: 8))

            lineTable

            Text(footerText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: Color(hex: 0x101318).opacity(0.12), radius: 12, y: 6)
        // The preview stands for the printed quote, so it stays on white paper in dark mode.
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var logo: some View {
        if let data = profile?.logo, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityLabel(Text("Business logo"))
        } else {
            Text("LOGO")
                .font(.caption.weight(.heavy))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Theme.accentFill, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
        }
    }

    private var contactLine: String {
        let phone = profile?.phone.isEmpty == false ? profile!.phone : String(localized: "[Phone]")
        let email = profile?.email.isEmpty == false ? profile!.email : String(localized: "[Email]")
        return "\(phone) · \(email)"
    }

    private var lineTable: some View {
        VStack(spacing: 0) {
            row(Text("Item"), Text("Amount"), style: .header)
            ForEach(quote.sortedLineItems) { item in
                row(Text(item.summary), Text(f.money(item.total)), style: .item)
            }
            if let totals = try? quote.totals() {
                if quote.vatEnabled {
                    row(Text("Subtotal"), Text(f.money(totals.subtotal)), style: .item)
                    row(Text("VAT \(DecimalInput.string(quote.vatRatePercent))%"), Text(f.money(totals.vat)), style: .item)
                }
                HStack {
                    Text("Total")
                    Spacer()
                    Text(f.money(totals.total))
                }
                .font(.subheadline.weight(.heavy))
                .padding(.top, 10)
                .overlay(alignment: .top) { Rectangle().fill(Theme.textPrimary).frame(height: 2) }
                .accessibilityElement(children: .combine)
            }
        }
        .font(.caption)
    }

    private enum RowStyle { case header, item }

    private func row(_ left: Text, _ right: Text, style: RowStyle) -> some View {
        HStack(alignment: .firstTextBaseline) {
            left
            Spacer(minLength: 12)
            right
        }
        .fontWeight(style == .header ? .bold : .semibold)
        .foregroundStyle(style == .header ? Theme.textSecondary : Theme.textPrimary)
        .padding(.vertical, style == .header ? 6 : 7)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.divider).frame(height: 1) }
        .accessibilityElement(children: .combine)
    }

    private var footerText: String {
        var parts: [String] = []
        if let validity = QuoteText.validityText(quote: quote) { parts.append(validity) }
        let terms = profile?.terms ?? ""
        parts.append(terms.isEmpty ? String(localized: "[Your payment terms]") : terms)
        return parts.joined(separator: " ")
    }

    private var statusPicker: some View {
        Picker("Status", selection: Binding(get: { quote.status }, set: { setStatus($0) })) {
            ForEach(QuoteStatus.allCases) { status in
                Text(status.title).tag(status)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel(Text("Quote status"))
    }

    private var actions: some View {
        VStack(spacing: 10) {
            ShareLink(item: shareText, subject: Text("Quote \(quote.displayNumber)")) {
                Label("Send on WhatsApp", systemImage: "message")
            }
            .buttonStyle(PrimaryButtonStyle())
            .simultaneousGesture(TapGesture().onEnded { markSentIfDraft() })
            .accessibilityHint(Text("Opens the share sheet. Choose WhatsApp."))

            HStack(spacing: 10) {
                ShareLink(item: shareText, subject: Text("Quote \(quote.displayNumber)")) {
                    Text("Email")
                }
                .buttonStyle(SecondaryButtonStyle())
                .simultaneousGesture(TapGesture().onEnded { markSentIfDraft() })
                .accessibilityHint(Text("Opens the share sheet. Choose Mail."))

                Button("Save PDF") { isPDFStubAlertShown = true }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(Theme.surface)
        .overlay(alignment: .top) { Divider().overlay(Theme.strongBorder) }
    }

    private func markSentIfDraft() {
        guard quote.status == .draft else { return }
        setStatus(.sent)
    }

    private func setStatus(_ status: QuoteStatus) {
        quote.status = status
        do { try context.save() } catch { saveError = error.localizedDescription }
    }
}
