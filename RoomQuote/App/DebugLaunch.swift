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

    /// `-prefillManual` fills the measurement form with the living room from the designs.
    static func prefillIfRequested(_ model: ManualMeasurementsViewModel) {
        guard ProcessInfo.processInfo.arguments.contains("-prefillManual") else { return }
        model.clientName = "Ana Popescu"
        model.roomName = "Living room"
        model.length = "4.2"
        model.width = "3.6"
        model.height = "2.6"
        model.addOpening(.door)
        model.openings[0].width = "0.9"
        model.openings[0].height = "2.1"
        model.addOpening(.window)
        model.openings[1].width = "1.2"
        model.openings[1].height = "1.4"
        model.openings[1].quantity = 2
    }
}
#endif
