import SwiftUI
import SwiftData
import Estimator

struct PricesView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<PriceItem> { !$0.isArchived }, sort: \PriceItem.name) private var prices: [PriceItem]
    @Query private var profiles: [BusinessProfile]
    @State private var editing: PriceItem?
    @State private var isAdding = false
    @State private var errorMessage: String?

    private var f: Formatters {
        Formatters(currencyCode: profiles.first?.currencyCode ?? "RON", unitSystem: profiles.first?.unitSystem ?? .metric)
    }

    var body: some View {
        List {
            ForEach(PriceCategory.allCases) { category in
                let items = prices.filter { $0.category == category }
                if !items.isEmpty {
                    Section(category.title) {
                        ForEach(items) { price in
                            Button { editing = price } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(price.name).font(.body.weight(.bold))
                                        if price.packSize > 0 {
                                            Text(price.unit == .can ? f.volume(price.packSize, packSize: true) : f.area(price.packSize, fractionDigits: 2))
                                                .font(.footnote)
                                                .foregroundStyle(Theme.textSecondary)
                                        }
                                    }
                                    Spacer()
                                    Text("\(f.money(price.unitPrice, fractionDigits: 2)) \(price.unit.title)")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .combine)
                        }
                        .onDelete { archive(items, at: $0) }
                    }
                }
            }
        }
        .overlay {
            if prices.isEmpty {
                ContentUnavailableView {
                    Label("No prices yet", systemImage: "tag")
                } description: {
                    Text("Add your paint, flooring, tile and labour prices so quotes fill in automatically.")
                }
            }
        }
        .navigationTitle("Prices")
        .toolbar {
            Button { isAdding = true } label: { Image(systemName: "plus") }
                .accessibilityLabel(Text("Add price"))
        }
        .sheet(isPresented: $isAdding) { PriceForm(price: nil) }
        .sheet(item: $editing) { PriceForm(price: $0) }
        .alert("Couldn't remove", isPresented: .constant(errorMessage != nil), presenting: errorMessage) { _ in
            Button("OK") { errorMessage = nil }
        } message: { Text($0) }
    }

    /// Prices are archived, not deleted, so older quotes keep a consistent history.
    private func archive(_ items: [PriceItem], at offsets: IndexSet) {
        for index in offsets { items[index].isArchived = true }
        do { try context.save() } catch { errorMessage = error.localizedDescription }
    }
}

struct PriceForm: View {
    let price: PriceItem?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category: PriceCategory = .paint
    @State private var unit: PriceUnit = .can
    @State private var priceText = ""
    @State private var packText = ""
    @State private var labourJob: JobType = .paint
    @State private var errorMessage: String?

    private var parsedPrice: Decimal? { DecimalInput.parse(priceText).flatMap { $0 >= 0 ? $0 : nil } }
    private var parsedPack: Decimal? {
        packText.isEmpty ? 0 : DecimalInput.parse(packText).flatMap { $0 > 0 ? $0 : nil }
    }
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && parsedPrice != nil && parsedPack != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name, e.g. Wall paint 5 L", text: $name)
                Picker("Category", selection: $category) {
                    ForEach(PriceCategory.allCases) { Text($0.title).tag($0) }
                }
                if category == .labour {
                    Picker("Used for", selection: $labourJob) {
                        ForEach(JobType.allCases) { Text($0.activityTitle).tag($0) }
                    }
                }
                Picker("Charged", selection: $unit) {
                    ForEach(PriceUnit.allCases) { Text($0.title).tag($0) }
                }
                LabeledContent("Price") {
                    TextField("0", text: $priceText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                if !priceText.isEmpty && parsedPrice == nil {
                    Text("Enter a price of 0 or more").font(.footnote).foregroundStyle(Theme.errorText)
                }
                if unit == .can || unit == .box {
                    LabeledContent(unit == .can ? "Litres per can" : "m² per box") {
                        TextField(unit == .can ? "5" : "2.2", text: $packText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    if parsedPack == nil {
                        Text("Must be more than 0").font(.footnote).foregroundStyle(Theme.errorText)
                    }
                }
            }
            .navigationTitle(price == nil ? "New price" : "Edit price")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(!isValid) }
            }
            .onAppear {
                guard let price else { return }
                name = price.name
                category = price.category
                unit = price.unit
                priceText = DecimalInput.string(price.unitPrice)
                packText = price.packSize > 0 ? DecimalInput.string(price.packSize) : ""
                labourJob = JobType(rawValue: price.jobTypeRaw) ?? .paint
            }
            .alert("Couldn't save", isPresented: .constant(errorMessage != nil), presenting: errorMessage) { _ in
                Button("OK") { errorMessage = nil }
            } message: { Text($0) }
        }
    }

    private func save() {
        guard let value = parsedPrice, let pack = parsedPack else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let target = price ?? PriceItem(name: trimmed, category: category, unit: unit, unitPrice: value)
        if price == nil { context.insert(target) }
        target.name = trimmed
        target.category = category
        target.unit = unit
        target.unitPrice = value
        target.packSize = (unit == .can || unit == .box) ? pack : 0
        target.jobTypeRaw = category == .labour ? labourJob.rawValue : ""
        do {
            try context.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
