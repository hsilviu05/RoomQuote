#if DEBUG
import Foundation
import SwiftData

/// Debug-only: `-route scan|manual|materials|quote|paywall` opens a screen at launch,
/// for screenshots and UI checks without tapping through the flow.
@MainActor
enum DebugLaunch {
    static func apply(to appModel: AppModel, context: ModelContext) {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-route"), index + 1 < arguments.count else { return }
        // The first sample quote by recency is the designed living-room quote.
        var descriptor = FetchDescriptor<Quote>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        let quote = try? context.fetch(descriptor).first
        switch arguments[index + 1] {
        case "scan": appModel.quotesPath = [.scan]
        case "manual": appModel.quotesPath = [.scan, .manualEntry]
        case "materials": if let quote { appModel.quotesPath = [.materials(quote)] }
        case "quote": if let quote { appModel.quotesPath = [.materials(quote), .quote(quote)] }
        case "paywall": appModel.isPaywallPresented = true
        default: break
        }
    }
}
#endif
