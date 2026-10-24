import Foundation
import Estimator
#if canImport(RoomPlan)
import RoomPlan
#endif

/// The result of a room scan, in metres.
struct ScannedRoom: Equatable {
    var dimensions: RoomDimensions
    var wallCount: Int
}

/// How the Scan screen behaves on this device.
enum ScanMode: Equatable {
    /// LiDAR device: live RoomPlan scan.
    case live
    /// Debug builds without LiDAR (simulator): a demo scan with sample measurements.
    case demo
    /// No LiDAR: manual entry only.
    case unavailable

    static var current: ScanMode {
        #if canImport(RoomPlan) && !targetEnvironment(simulator)
        if RoomCaptureSession.isSupported { return .live }
        #endif
        #if DEBUG
        return .demo
        #else
        return .unavailable
        #endif
    }
}

enum RoomScannerError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        String(localized: "Room scanning needs an iPhone or iPad with LiDAR. Enter the measurements instead.")
    }
}

/// Debug-only demo scan for the simulator: the living room from the designs.
enum DemoScan {
    static let room = ScannedRoom(
        dimensions: RoomDimensions(
            length: Decimal(string: "4.2")!,
            width: Decimal(string: "3.6")!,
            height: Decimal(string: "2.6")!,
            openings: [
                OpeningDimensions(kind: .door, width: Decimal(string: "0.9")!, height: Decimal(string: "2.1")!),
                OpeningDimensions(kind: .window, width: Decimal(string: "1.2")!, height: Decimal(string: "1.4")!, quantity: 2)
            ]
        ),
        wallCount: 4
    )
}
