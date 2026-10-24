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

protocol RoomScanner: Sendable {
    /// True when the device can scan (LiDAR). Otherwise the app offers manual entry only.
    var isAvailable: Bool { get }
    func finishScan() async throws -> ScannedRoom
}

enum RoomScannerError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        String(localized: "Room scanning needs an iPhone or iPad with LiDAR. Enter the measurements instead.")
    }
}

// STUB: replaced by a RoomPlan-backed scanner (RoomCaptureView + CapturedRoom) in the RoomPlan step.
// It returns the sample room from the design so the flow can be tried end to end.
struct StubRoomScanner: RoomScanner {
    var isAvailable: Bool {
        #if DEBUG
        true
        #else
        Self.deviceSupportsRoomPlan
        #endif
    }

    static var deviceSupportsRoomPlan: Bool {
        #if canImport(RoomPlan) && !targetEnvironment(simulator)
        RoomCaptureSession.isSupported
        #else
        false
        #endif
    }

    func finishScan() async throws -> ScannedRoom {
        guard isAvailable else { throw RoomScannerError.unavailable }
        return ScannedRoom(
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
}
