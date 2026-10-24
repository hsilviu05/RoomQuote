import Foundation
import Observation
import Estimator
#if canImport(RoomPlan)
import RoomPlan
#endif

/// Live LiDAR scan through RoomPlan: shows the camera view, counts walls, doors and
/// windows as they're found, and turns the finished scan into room dimensions.
@MainActor
@Observable
final class RoomCaptureController {
    private(set) var wallCount = 0
    private(set) var doorCount = 0
    private(set) var windowCount = 0
    private(set) var isRunning = false

    #if canImport(RoomPlan) && !targetEnvironment(simulator)
    let captureView = RoomCaptureView(frame: .zero)
    private let delegate = CaptureDelegate()
    private var continuation: CheckedContinuation<CapturedRoom, Error>?

    init() {
        captureView.delegate = delegate
        captureView.captureSession.delegate = delegate
        delegate.onUpdate = { [weak self] room in self?.update(with: room) }
        delegate.onProcessed = { [weak self] result in self?.finish(with: result) }
    }

    func start() {
        guard !isRunning else { return }
        captureView.captureSession.run(configuration: RoomCaptureSession.Configuration())
        isRunning = true
    }

    func cancel() {
        guard isRunning else { return }
        captureView.captureSession.stop()
        isRunning = false
        continuation?.resume(throwing: CancellationError())
        continuation = nil
    }

    /// Stops scanning and waits for RoomPlan to finish processing the room.
    func finish() async throws -> ScannedRoom {
        let room: CapturedRoom = try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            captureView.captureSession.stop()
            isRunning = false
        }
        return try Self.scannedRoom(from: room)
    }

    private func update(with room: CapturedRoom) {
        wallCount = room.walls.count
        doorCount = room.doors.count
        windowCount = room.windows.count
    }

    private func finish(with result: Result<CapturedRoom, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }

    static func scannedRoom(from room: CapturedRoom) throws -> ScannedRoom {
        guard !room.walls.isEmpty else { throw ScanError.noWalls }
        let perimeter = room.walls.reduce(0.0) { $0 + Double($1.dimensions.x) }
        let height = room.walls.map { Double($0.dimensions.y) }.max() ?? 0

        let floorArea: Decimal
        if let floor = room.floors.first, floor.polygonCorners.count >= 3 {
            floorArea = RoomDimensions.polygonArea(floor.polygonCorners.map { (x: Double($0.x), z: Double($0.y)) })
        } else if let floor = room.floors.first {
            floorArea = centimetres(Double(floor.dimensions.x * floor.dimensions.y))
        } else {
            floorArea = 0 // Falls back to a square with the scanned perimeter.
        }

        func openings(_ surfaces: [CapturedRoom.Surface], _ kind: OpeningDimensions.Kind) -> [OpeningDimensions] {
            surfaces.map { OpeningDimensions(kind: kind, width: centimetres(Double($0.dimensions.x)), height: centimetres(Double($0.dimensions.y))) }
        }

        let dimensions = try RoomDimensions.fittedToScan(
            perimeter: centimetres(perimeter),
            floorArea: floorArea > 0 ? floorArea : Decimal(pow(perimeter / 4, 2)),
            height: centimetres(height),
            openings: openings(room.doors, .door) + openings(room.windows, .window) + openings(room.openings, .other)
        )
        return ScannedRoom(dimensions: dimensions, wallCount: room.walls.count)
    }
    #else
    func start() {}
    func cancel() {}
    func finish() async throws -> ScannedRoom { throw RoomScannerError.unavailable }
    #endif

    /// RoomPlan reports Float metres; round to the centimetre so quotes show clean numbers.
    nonisolated static func centimetres(_ metres: Double) -> Decimal {
        Decimal(metres).rounded(scale: 2)
    }
    private nonisolated static func centimetres(_ metres: Float) -> Decimal { centimetres(Double(metres)) }

    enum ScanError: LocalizedError {
        case noWalls
        var errorDescription: String? {
            String(localized: "No walls were found. Scan again, moving slowly along every wall, or enter the measurements instead.")
        }
    }
}

#if canImport(RoomPlan) && !targetEnvironment(simulator)
/// RoomPlan's delegates must be NSObject + NSCoding. Callbacks are forwarded to the main actor.
@objc(RQCaptureDelegate)
final class CaptureDelegate: NSObject, RoomCaptureViewDelegate, RoomCaptureSessionDelegate, @unchecked Sendable {
    var onUpdate: (@MainActor (CapturedRoom) -> Void)?
    var onProcessed: (@MainActor (Result<CapturedRoom, Error>) -> Void)?

    override init() { super.init() }
    required init?(coder: NSCoder) { super.init() }
    func encode(with coder: NSCoder) {}

    func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
        Task { @MainActor in self.onUpdate?(room) }
    }

    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
        if let error {
            Task { @MainActor in self.onProcessed?(.failure(error)) }
            return false
        }
        return true
    }

    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        Task { @MainActor in
            if let error { self.onProcessed?(.failure(error)) } else { self.onProcessed?(.success(processedResult)) }
        }
    }
}
#endif
