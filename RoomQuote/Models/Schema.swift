import Foundation
import SwiftData

enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        BusinessProfile.self, Client.self, Room.self, Opening.self,
        Job.self, PriceItem.self, Quote.self, LineItem.self
    ]

    /// iCloud sync stays off until the CloudKit step; `.none` stops SwiftData
    /// from picking up a CloudKit container on its own.
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: Schema(models),
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: Schema(models), configurations: configuration)
    }
}
