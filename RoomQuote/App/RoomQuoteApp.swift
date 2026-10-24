import SwiftUI
import SwiftData

@main
struct RoomQuoteApp: App {
    private let containerResult: Result<ModelContainer, Error>
    @State private var appModel = AppModel()

    init() {
        let inMemory = ProcessInfo.processInfo.arguments.contains("-inMemoryStore")
        containerResult = Result { try AppSchema.makeContainer(inMemory: inMemory) }
    }

    var body: some Scene {
        WindowGroup {
            switch containerResult {
            case .success(let container):
                RootView()
                    .environment(appModel)
                    .modelContainer(container)
                    .task { SampleData.seedIfNeeded(container.mainContext) }
            case .failure(let error):
                StoreErrorView(error: error)
            }
        }
    }
}

/// Shown if the on-device database can't be opened (e.g. disk full or a failed migration).
struct StoreErrorView: View {
    let error: Error

    var body: some View {
        ContentUnavailableView {
            Label("Can't open your data", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("RoomQuote couldn't open its database. Free up some storage and restart the app.\n\n\(error.localizedDescription)")
        }
    }
}
