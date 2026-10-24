import SwiftUI
import SwiftData
import Estimator

struct ManualMeasurementsView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Query private var profiles: [BusinessProfile]
    @State private var model: ManualMeasurementsViewModel?
    @State private var saveError: String?
    @FocusState private var focused: ManualMeasurementsViewModel.Field?

    var body: some View {
        Group {
            if let model {
                form(model)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Enter measurements")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            if model == nil {
                model = ManualMeasurementsViewModel(unitSystem: profiles.first?.unitSystem ?? .metric)
            }
        }
        .alert("Couldn't save the room", isPresented: .constant(saveError != nil), presenting: saveError) { _ in
            Button("OK") { saveError = nil }
        } message: { Text($0) }
    }

    private var formatters: Formatters {
        Formatters(currencyCode: profiles.first?.currencyCode ?? "RON", unitSystem: profiles.first?.unitSystem ?? .metric)
    }

    private func form(_ model: ManualMeasurementsViewModel) -> some View {
        @Bindable var model = model
        return Form {
            Section("Job") {
                TextField("Client name (optional)", text: $model.clientName)
                    .textContentType(.name)
                TextField("Room name, e.g. Living room", text: $model.roomName)
            }

            Section {
                measurementField("Length", text: $model.length, field: .length, model: model)
                measurementField("Width", text: $model.width, field: .width, model: model)
                measurementField("Height", text: $model.height, field: .height, model: model)
            } header: {
                Text("Room (\(model.unitLabel))")
            } footer: {
                Text("Measure the floor from wall to wall, and the height from floor to ceiling.")
            }

            Section {
                ForEach($model.openings) { $opening in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Picker("Type", selection: $opening.kind) {
                                ForEach(OpeningDimensions.Kind.allCases, id: \.self) { kind in
                                    Text(kind.title).tag(kind)
                                }
                            }
                            .labelsHidden()
                            .fixedSize()
                            Spacer()
                            Button(role: .destructive) {
                                model.removeOpening(id: opening.id)
                            } label: {
                                Image(systemName: "trash")
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(Text("Remove \(opening.kind.title.lowercased())"))
                        }
                        measurementField("Width", text: $opening.width, field: .openingWidth(opening.id), model: model)
                        measurementField("Height", text: $opening.height, field: .openingHeight(opening.id), model: model)
                        Stepper(value: $opening.quantity, in: 1...20) {
                            Text("How many: \(opening.quantity)")
                        }
                        .frame(minHeight: 44)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { model.removeOpenings(at: $0) }

                HStack {
                    Button {
                        model.addOpening(.door)
                    } label: {
                        Label("Add door", systemImage: "door.left.hand.closed")
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    Divider()
                    Button {
                        model.addOpening(.window)
                    } label: {
                        Label("Add window", systemImage: "window.vertical.closed")
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderless)
            } header: {
                Text("Doors and windows")
            } footer: {
                Text("These are taken off the wall area.")
            }

            if let preview = model.preview {
                Section("Result") {
                    LabeledContent("Walls", value: formatters.area(preview.walls.net))
                    LabeledContent("Floor", value: formatters.area(preview.floor))
                    WarningBanner(messages: model.warningMessages(for: preview.walls))
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            Section {
                Button("Continue") { save(model) }
                    .buttonStyle(PrimaryButtonStyle())
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func measurementField(
        _ title: LocalizedStringKey,
        text: Binding<String>,
        field: ManualMeasurementsViewModel.Field,
        model: ManualMeasurementsViewModel
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            LabeledContent(title) {
                TextField(model.unitSystem == .metric ? "0.0" : "0.0", text: text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($focused, equals: field)
                    .frame(minHeight: 44)
                    .accessibilityLabel(Text(title))
                    .accessibilityValue(Text(text.wrappedValue.isEmpty ? "Empty" : "\(text.wrappedValue) \(model.unitLabel)"))
            }
            if let error = model.error(for: field) {
                Text(error)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.errorText)
            }
        }
    }

    private func save(_ model: ManualMeasurementsViewModel) {
        model.showErrors = true
        guard let dimensions = model.dimensions else {
            focused = [.length, .width, .height].first { model.validationError(for: $0) != nil }
            return
        }
        do {
            let quote = try QuoteBuilder.createDraft(
                roomName: model.roomName,
                clientName: model.clientName,
                dimensions: dimensions,
                source: .manual,
                context: context
            )
            appModel.showMaterials(for: quote)
        } catch {
            saveError = error.localizedDescription
        }
    }
}
