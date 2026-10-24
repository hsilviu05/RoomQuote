import SwiftUI
import SwiftData

struct ScanRoomView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var isFinishing = false
    @State private var errorMessage: String?
    @State private var capture = RoomCaptureController()

    private var mode: ScanMode { appModel.scanMode }
    private var canScan: Bool { mode != .unavailable }

    var body: some View {
        VStack(spacing: 0) {
            header
            viewport
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            footer
        }
        .background(Theme.scanBackground.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear { if mode == .live { capture.start() } }
        .onDisappear { capture.cancel() }
        .alert("Scan failed", isPresented: .constant(errorMessage != nil), presenting: errorMessage) { _ in
            Button("OK") { errorMessage = nil }
        } message: { message in
            Text(message)
        }
    }

    private var header: some View {
        HStack {
            CircleIconButton(systemImage: "xmark", label: "Cancel scan", style: .onDark) {
                capture.cancel()
                dismiss()
            }
            Spacer()
            Text("New room")
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Text(mode == .live ? "LiDAR" : (mode == .demo ? "Demo" : "No LiDAR"))
                .font(.caption.weight(.heavy))
                .foregroundStyle(mode == .live ? Color(hex: 0x86EFAC) : Theme.scanSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(mode == .live ? Color(hex: 0x22C55E).opacity(0.18) : Color.white.opacity(0.12), in: Capsule())
                .accessibilityLabel(mode == .live ? Text("LiDAR scanner available") : Text("No LiDAR scanner"))
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var viewport: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24).fill(Theme.scanViewport)
            if mode == .live {
                RoomCaptureViewRepresentable(controller: capture)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .accessibilityLabel(Text("Camera view of the room being scanned"))
                scanOverlay(walls: capture.wallCount, windows: capture.windowCount, doors: capture.doorCount)
            } else if mode == .demo {
                RoomOutline()
                    .padding(32)
                    .accessibilityElement()
                    .accessibilityLabel(Text("Outline of the room being scanned"))
                scanOverlay(walls: 4, windows: 2, doors: 1)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "ruler")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(Theme.scanSecondary)
                        .accessibilityHidden(true)
                    Text("This iPhone can't scan rooms")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.white)
                    Text("Room scanning needs a LiDAR sensor. Enter the room's length, width and height instead; it takes about a minute.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.scanSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func scanOverlay(walls: Int, windows: Int, doors: Int) -> some View {
        VStack {
            HStack(spacing: 6) {
                ScanChip(text: walls == 1 ? String(localized: "1 wall") : String(localized: "\(walls) walls"), foreground: 0xFDBA74, background: 0xFB923C)
                ScanChip(text: windows == 1 ? String(localized: "1 window") : String(localized: "\(windows) windows"), foreground: 0x93C5FD, background: 0x60A5FA)
                ScanChip(text: doors == 1 ? String(localized: "1 door") : String(localized: "\(doors) doors"), foreground: 0xC4B5FD, background: 0xA78BFA)
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            Spacer()
            Text(mode == .demo
                 ? String(localized: "Demo scan: this device has no LiDAR, so sample measurements are used.")
                 : String(localized: "Move slowly along the walls. Point at the corners."))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(16)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            if canScan {
                Button {
                    Task { await finishScan() }
                } label: {
                    if isFinishing { ProgressView().tint(.white) } else { Text("Finish scan") }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isFinishing)

                Button("No LiDAR? Enter measurements") {
                    appModel.quotesPath.append(.manualEntry)
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color(hex: 0xE5E7EB))
                .frame(maxWidth: .infinity, minHeight: 44)
            } else {
                Button("Enter measurements") {
                    appModel.quotesPath.append(.manualEntry)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    private func finishScan() async {
        isFinishing = true
        defer { isFinishing = false }
        do {
            let scanned = mode == .live ? try await capture.finish() : DemoScan.room
            let quote = try QuoteBuilder.createDraft(
                roomName: "",
                clientName: "",
                dimensions: scanned.dimensions,
                source: .scan,
                context: context
            )
            appModel.showMaterials(for: quote)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ScanChip: View {
    let text: String
    let foreground: UInt32
    let background: UInt32

    var body: some View {
        Text(text)
            .font(.caption.weight(.heavy))
            .foregroundStyle(Color(hex: foreground))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(hex: background).opacity(0.18), in: Capsule())
    }
}

/// The isometric room outline from the design, scaled to fit.
private struct RoomOutline: View {
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 320, size.height / 360)
            let offset = CGPoint(x: (size.width - 320 * scale) / 2, y: (size.height - 360 * scale) / 2)
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: offset.x + x * scale, y: offset.y + y * scale) }
            func polygon(_ points: [CGPoint]) -> Path {
                var path = Path()
                path.addLines(points)
                path.closeSubpath()
                return path
            }
            let orange = Color(hex: 0xFB923C)
            context.stroke(polygon([p(40, 90), p(160, 40), p(290, 95), p(290, 280), p(160, 330), p(40, 270)]),
                           with: .color(orange), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
            var hidden = Path()
            hidden.move(to: p(160, 40)); hidden.addLine(to: p(160, 230))
            hidden.move(to: p(40, 270)); hidden.addLine(to: p(160, 230)); hidden.addLine(to: p(290, 280))
            context.stroke(hidden, with: .color(orange.opacity(0.7)), style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
            let blue = Color(hex: 0x60A5FA)
            context.stroke(polygon([p(190, 130), p(240, 150), p(240, 230), p(190, 212)]), with: .color(blue), lineWidth: 2.5)
            context.stroke(polygon([p(70, 120), p(120, 100), p(120, 160), p(70, 182)]), with: .color(blue), lineWidth: 2.5)
            context.stroke(polygon([p(255, 170), p(280, 180), p(280, 270), p(255, 262)]), with: .color(Color(hex: 0xA78BFA)), lineWidth: 2.5)
        }
    }
}

/// Hosts RoomPlan's camera view. On the simulator this is an empty view (live mode never appears there).
private struct RoomCaptureViewRepresentable: UIViewRepresentable {
    let controller: RoomCaptureController

    func makeUIView(context: Context) -> UIView {
        #if canImport(RoomPlan) && !targetEnvironment(simulator)
        controller.captureView
        #else
        UIView()
        #endif
    }

    func updateUIView(_ view: UIView, context: Context) {}
}
