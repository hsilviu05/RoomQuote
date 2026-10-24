import SwiftUI
import SwiftData
import PhotosUI
import Estimator

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppModel.self) private var appModel
    @Query private var profiles: [BusinessProfile]
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let profile = profiles.first {
                SettingsForm(profile: profile)
            } else {
                ProgressView()
                    .task {
                        do {
                            _ = try BusinessProfile.current(in: context)
                            try context.save()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
            }
        }
        .navigationTitle("Settings")
        .alert("Couldn't load settings", isPresented: .constant(errorMessage != nil), presenting: errorMessage) { _ in
            Button("OK") { errorMessage = nil }
        } message: { Text($0) }
    }
}

private struct SettingsForm: View {
    @Bindable var profile: BusinessProfile
    @Environment(\.modelContext) private var context
    @Environment(AppModel.self) private var appModel
    @State private var logoItem: PhotosPickerItem?
    @State private var vatText = ""
    @State private var errorMessage: String?

    private static let currencies = ["RON", "EUR", "GBP", "USD", "CHF", "PLN", "HUF"]

    var body: some View {
        let logoImage = profile.logo.flatMap { UIImage(data: $0) }
        return Form {
            Section("Business") {
                TextField("Business name", text: $profile.name).textContentType(.organizationName)
                TextField("Phone", text: $profile.phone).textContentType(.telephoneNumber).keyboardType(.phonePad)
                TextField("Email", text: $profile.email).textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                TextField("Address", text: $profile.address, axis: .vertical).textContentType(.fullStreetAddress)
                TextField("VAT / company number", text: $profile.vatNumber)
                PhotosPicker(selection: $logoItem, matching: .images) {
                    HStack {
                        Text("Logo")
                        Spacer()
                        if let logoImage {
                            Image(uiImage: logoImage).resizable().scaledToFit().frame(width: 36, height: 36)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .accessibilityLabel(Text("Current logo"))
                        } else {
                            Text("Choose").foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .frame(minHeight: 44)
                }
                if profile.logo != nil {
                    Button("Remove logo", role: .destructive) { profile.logo = nil }
                }
            }

            Section("Quotes") {
                Picker("Currency", selection: $profile.currencyCode) {
                    ForEach(Self.currencies, id: \.self) { Text($0).tag($0) }
                }
                Picker("Units", selection: $profile.unitSystemRaw) {
                    Text("Metric (m, m², L)").tag(UnitSystem.metric.rawValue)
                    Text("Imperial (ft, ft², gal)").tag(UnitSystem.imperial.rawValue)
                }
                Stepper(value: $profile.quoteValidityDays, in: 1...90) {
                    Text("Valid for \(profile.quoteValidityDays) days")
                }
                Toggle("Charge VAT", isOn: $profile.vatEnabled)
                if profile.vatEnabled {
                    LabeledContent("VAT rate (%)") {
                        TextField("19", text: $vatText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: vatText) { _, text in
                                if let value = DecimalInput.parse(text), value >= 0, value <= 100 {
                                    profile.vatRatePercent = value
                                }
                            }
                    }
                }
                TextField("Payment terms shown on quotes", text: $profile.terms, axis: .vertical)
            }

            Section {
                Button("Upgrade to Pro") { appModel.isPaywallPresented = true }
                Button("Restore purchases") {
                    Task {
                        do { try await appModel.entitlements.restorePurchases() } catch { errorMessage = error.localizedDescription }
                    }
                }
            } header: {
                Text("Subscription")
            } footer: {
                Text("Free plan: \(QuoteLimitPolicy.freeQuotesPerMonth) quotes a month.")
            }

            Section {
                Text("Your quotes, clients and prices are stored only on this iPhone. RoomQuote has no account and sends nothing to a server.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            } header: {
                Text("Privacy")
            }
        }
        .onAppear { vatText = DecimalInput.string(profile.vatRatePercent) }
        .onChange(of: logoItem) { _, item in
            guard let item else { return }
            Task { await loadLogo(item) }
        }
        .onDisappear { saveQuietly() }
        .alert("Something went wrong", isPresented: .constant(errorMessage != nil), presenting: errorMessage) { _ in
            Button("OK") { errorMessage = nil }
        } message: { Text($0) }
    }

    private func loadLogo(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                errorMessage = String(localized: "That image couldn't be opened.")
                return
            }
            // Keep the stored logo small: it only needs to print at about 40 pt.
            let size = CGSize(width: 512, height: 512 * image.size.height / max(image.size.width, 1))
            let resized = UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            profile.logo = resized.pngData()
            saveQuietly()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveQuietly() {
        do { try context.save() } catch { errorMessage = error.localizedDescription }
    }
}
