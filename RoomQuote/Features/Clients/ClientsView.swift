import SwiftUI
import SwiftData

struct ClientsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Client.name) private var clients: [Client]
    @State private var editing: Client?
    @State private var isAdding = false
    @State private var searchText = ""
    @State private var errorMessage: String?

    private var filtered: [Client] {
        searchText.isEmpty ? clients : clients.filter { $0.name.localizedStandardContains(searchText) }
    }

    var body: some View {
        List {
            ForEach(filtered) { client in
                Button { editing = client } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(client.name).font(.body.weight(.bold))
                        let count = client.quotes?.count ?? 0
                        Text(count == 1 ? "1 quote" : "\(count) quotes")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .onDelete(perform: delete)
        }
        .overlay {
            if clients.isEmpty {
                ContentUnavailableView {
                    Label("No clients yet", systemImage: "person.2")
                } description: {
                    Text("Clients are added when you create a quote, or tap + to add one.")
                }
            } else if filtered.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .searchable(text: $searchText)
        .navigationTitle("Clients")
        .toolbar {
            Button { isAdding = true } label: { Image(systemName: "plus") }
                .accessibilityLabel(Text("Add client"))
        }
        .sheet(isPresented: $isAdding) { ClientForm(client: nil) }
        .sheet(item: $editing) { ClientForm(client: $0) }
        .alert("Couldn't delete", isPresented: .constant(errorMessage != nil), presenting: errorMessage) { _ in
            Button("OK") { errorMessage = nil }
        } message: { Text($0) }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { context.delete(filtered[index]) }
        do { try context.save() } catch { errorMessage = error.localizedDescription }
    }
}

struct ClientForm: View {
    let client: Client?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var address = ""
    @State private var notes = ""
    @State private var errorMessage: String?

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name).textContentType(.name)
                TextField("Phone", text: $phone).textContentType(.telephoneNumber).keyboardType(.phonePad)
                TextField("Email", text: $email).textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                TextField("Address", text: $address, axis: .vertical).textContentType(.fullStreetAddress)
                TextField("Notes", text: $notes, axis: .vertical)
            }
            .navigationTitle(client == nil ? "New client" : "Edit client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(trimmedName.isEmpty)
                }
            }
            .onAppear {
                guard let client else { return }
                name = client.name; phone = client.phone; email = client.email
                address = client.address; notes = client.notes
            }
            .alert("Couldn't save", isPresented: .constant(errorMessage != nil), presenting: errorMessage) { _ in
                Button("OK") { errorMessage = nil }
            } message: { Text($0) }
        }
    }

    private func save() {
        let target = client ?? Client(name: trimmedName)
        if client == nil { context.insert(target) }
        target.name = trimmedName
        target.phone = phone
        target.email = email.trimmingCharacters(in: .whitespaces)
        target.address = address
        target.notes = notes
        do {
            try context.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
