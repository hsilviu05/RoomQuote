import SwiftUI
import SwiftData
import Estimator

struct RoomMaterialsView: View {
    let quote: Quote
    @Environment(\.modelContext) private var context
    @Query private var profiles: [BusinessProfile]
    @State private var model: RoomMaterialsViewModel?

    var body: some View {
        Group {
            if let model {
                RoomMaterialsContent(model: model)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if model == nil {
                let profile = profiles.first
                model = RoomMaterialsViewModel(
                    quote: quote,
                    context: context,
                    formatters: Formatters(currencyCode: profile?.currencyCode ?? "RON", unitSystem: profile?.unitSystem ?? .metric)
                )
            }
        }
    }
}

private struct RoomMaterialsContent: View {
    @Bindable var model: RoomMaterialsViewModel
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<PriceItem> { !$0.isArchived }, sort: \PriceItem.name) private var prices: [PriceItem]
    @State private var editing: EditField?
    @State private var editText = ""
    @State private var isRenaming = false
    @State private var renameText = ""

    enum EditField: Identifiable {
        case coverage, boxCoverage
        var id: Self { self }
    }

    private var f: Formatters { model.formatters }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    if let room = model.room, let estimate = model.estimate {
                        StatRow {
                            StatCard(value: f.area(estimate.wallArea.net), label: String(localized: "Walls"), order: .labelFirst)
                            StatCard(value: f.area(estimate.floorArea), label: String(localized: "Floor"), order: .labelFirst)
                            StatCard(value: "\(room.openingCount)", label: String(localized: "Openings"), order: .labelFirst)
                        }
                    }
                    if let job = model.job {
                        JobTypePicker(selection: Binding(get: { job.type }, set: { model.setJobType($0) }))
                        settingsCard(job)
                    }
                    if let error = model.errorMessage {
                        WarningBanner(messages: [error])
                    }
                    WarningBanner(messages: model.warnings)
                    linesSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            bottomBar
        }
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .alert(editing == .coverage ? "Coverage" : "Box coverage", isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
            TextField("Value", text: $editText)
                .keyboardType(.decimalPad)
            Button("Save") {
                if editing == .coverage { _ = model.setCoverage(editText) } else { _ = model.setBoxCoverage(editText) }
                editing = nil
            }
            Button("Cancel", role: .cancel) { editing = nil }
        } message: {
            Text(editing == .coverage
                 ? (f.unitSystem == .metric ? "Square metres one litre covers, per coat." : "Square feet one gallon covers, per coat.")
                 : (f.unitSystem == .metric ? "Square metres in one box." : "Square feet in one box."))
        }
        .alert("Room name", isPresented: $isRenaming) {
            TextField("Room name", text: $renameText)
            Button("Save") { model.renameRoom(renameText) }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            CircleIconButton(systemImage: "chevron.left", label: "Back") { dismiss() }
            Button {
                renameText = model.room?.name ?? ""
                isRenaming = true
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    Text(model.room?.name ?? "")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(Theme.textPrimary)
                    if let room = model.room {
                        Text("\(f.floorSize(length: room.lengthM, width: room.widthM)) · height \(f.length(room.heightM))")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Rename the room"))
            Spacer()
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func settingsCard(_ job: Job) -> some View {
        VStack(spacing: 12) {
            if job.type == .paint {
                HStack {
                    Text("Coats").font(.subheadline.weight(.bold))
                    Spacer()
                    CounterControl(
                        value: "\(job.coats)",
                        decrementLabel: "Fewer coats",
                        incrementLabel: "More coats",
                        canDecrement: job.coats > 0,
                        canIncrement: job.coats < 10,
                        onDecrement: { model.changeCoats(by: -1) },
                        onIncrement: { model.changeCoats(by: 1) }
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("Coats"))
                    .accessibilityValue(Text("\(job.coats)"))
                    .accessibilityAdjustableAction { direction in
                        model.changeCoats(by: direction == .increment ? 1 : -1)
                    }
                }
            }
            HStack {
                Text("Waste allowance").font(.subheadline.weight(.bold))
                Spacer()
                CounterControl(
                    value: "\(DecimalInput.string(job.wastePercent, maximumFractionDigits: 0))%",
                    decrementLabel: "Less waste",
                    incrementLabel: "More waste",
                    canDecrement: job.wastePercent > 0,
                    canIncrement: job.wastePercent < 50,
                    onDecrement: { model.changeWaste(by: -5) },
                    onIncrement: { model.changeWaste(by: 5) }
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Waste allowance"))
                .accessibilityValue(Text("\(DecimalInput.string(job.wastePercent, maximumFractionDigits: 0)) percent"))
                .accessibilityAdjustableAction { direction in
                    model.changeWaste(by: direction == .increment ? 5 : -5)
                }
            }
            Button {
                if job.type == .paint {
                    editText = model.coverageEditValue
                    editing = .coverage
                } else {
                    editText = model.boxCoverageEditValue
                    editing = .boxCoverage
                }
            } label: {
                HStack {
                    Text(job.type == .paint ? "Coverage" : "Box coverage").font(.subheadline.weight(.bold))
                    Spacer()
                    Text(job.type == .paint ? model.coverageText : model.boxCoverageText)
                        .font(.subheadline.weight(.heavy))
                    Image(systemName: "pencil").font(.footnote).foregroundStyle(Theme.textSecondary)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Edit"))
        }
        .foregroundStyle(Theme.textPrimary)
        .card(cornerRadius: 16)
    }

    private var linesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Materials & labour")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Menu {
                    if prices.isEmpty {
                        Text("Your price list is empty")
                    }
                    ForEach(PriceCategory.allCases) { category in
                        let items = prices.filter { $0.category == category }
                        if !items.isEmpty {
                            Section(category.title) {
                                ForEach(items) { price in
                                    Button("\(price.name) · \(f.money(price.unitPrice))") { model.addExtra(price) }
                                }
                            }
                        }
                    }
                } label: {
                    Label("Add item", systemImage: "plus")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.accentText)
                        .frame(minHeight: 44)
                }
            }
            .padding(.top, 6)

            VStack(spacing: 0) {
                ForEach(Array(model.lines.enumerated()), id: \.element.id) { index, line in
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(line.title).font(.subheadline.weight(.bold))
                            if !line.detail.isEmpty {
                                Text(line.detail)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        Spacer()
                        Text(f.money(line.total)).font(.subheadline.weight(.heavy))
                        if !line.isGenerated {
                            Button {
                                model.remove(line)
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(Theme.textSecondary)
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("Remove \(line.title)"))
                        }
                    }
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.vertical, 11)
                    .accessibilityElement(children: .combine)
                    if index < model.lines.count - 1 {
                        Divider().overlay(Theme.divider)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.border) }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Total")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
                Text(f.money(model.total))
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(Theme.textPrimary)
            }
            .accessibilityElement(children: .combine)
            Button("Create quote") {
                model.finalize()
                appModel.quotesPath.append(.quote(model.quote))
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(model.estimate == nil)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.surface)
        .overlay(alignment: .top) { Divider().overlay(Theme.border) }
    }
}

/// Paint / Floor / Tiles segmented control styled like the design.
struct JobTypePicker: View {
    @Binding var selection: JobType

    var body: some View {
        HStack(spacing: 4) {
            ForEach(JobType.allCases) { type in
                Button {
                    selection = type
                } label: {
                    Text(type.title)
                        .font(.subheadline.weight(selection == type ? .heavy : .bold))
                        .foregroundStyle(selection == type ? Theme.textPrimary : Theme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background {
                            if selection == type {
                                RoundedRectangle(cornerRadius: 9)
                                    .fill(Theme.surface)
                                    .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == type ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(Theme.segmentTrack, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Job type"))
    }
}

struct CounterControl: View {
    let value: String
    let decrementLabel: LocalizedStringKey
    let incrementLabel: LocalizedStringKey
    let canDecrement: Bool
    let canIncrement: Bool
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            counterButton("minus", label: decrementLabel, enabled: canDecrement, action: onDecrement)
            Text(value)
                .font(.callout.weight(.heavy))
                .frame(minWidth: 28)
                .monospacedDigit()
            counterButton("plus", label: incrementLabel, enabled: canIncrement, action: onIncrement)
        }
    }

    private func counterButton(_ systemImage: String, label: LocalizedStringKey, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.heavy))
                .frame(width: 44, height: 44)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.strongBorder) }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(Text(label))
    }
}
