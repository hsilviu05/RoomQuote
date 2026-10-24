import SwiftUI

/// White rounded card with a hairline border, as used throughout the design.
struct CardModifier: ViewModifier {
    var padding: CGFloat = 14
    var cornerRadius: CGFloat = 14
    var dashed = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        dashed ? Theme.strongBorder : Theme.border,
                        style: StrokeStyle(lineWidth: 1, dash: dashed ? [5, 4] : [])
                    )
            }
    }
}

extension View {
    func card(padding: CGFloat = 14, cornerRadius: CGFloat = 14, dashed: Bool = false) -> some View {
        modifier(CardModifier(padding: padding, cornerRadius: cornerRadius, dashed: dashed))
    }
}

struct StatusPill: View {
    let status: QuoteStatus

    var body: some View {
        Text(status.title)
            .font(.caption.weight(.bold))
            .foregroundStyle(status.pillForeground)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(status.pillBackground, in: Capsule())
            .accessibilityLabel(Text("Status: \(status.title)"))
    }
}

/// Number on top, label below (Quotes home) or label on top, number below (Room & materials).
struct StatCard: View {
    enum Order { case valueFirst, labelFirst }

    let value: String
    let label: String
    var order: Order = .valueFirst

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if order == .labelFirst { labelText }
            Text(value)
                .font(order == .valueFirst ? .title2.weight(.heavy) : .title3.weight(.heavy))
                .foregroundStyle(Theme.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            if order == .valueFirst { labelText }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .card(padding: 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(label): \(value)"))
    }

    private var labelText: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.textSecondary)
    }
}

/// Lays out stat cards in a row, or stacked at accessibility text sizes.
struct StatRow<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ViewBuilder var content: Content

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 8) { content }
        } else {
            HStack(alignment: .top, spacing: 8) { content }
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// 44 pt round icon button with a bordered white background.
struct CircleIconButton: View {
    let systemImage: String
    let label: LocalizedStringKey
    var style: Style = .light
    let action: () -> Void

    enum Style { case light, onDark }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(style == .light ? Theme.textPrimary : .white)
                .padding(10)
                .frame(minWidth: 44, minHeight: 44)
                .background(style == .light ? Theme.surface : Color.white.opacity(0.12), in: Circle())
                .overlay {
                    if style == .light { Circle().strokeBorder(Theme.strongBorder) }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var minHeight: CGFloat = 54

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.heavy))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .padding(.horizontal, 12)
            .background(Theme.accentFill.opacity(isEnabled ? 1 : 0.4), in: RoundedRectangle(cornerRadius: 16))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 8)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.strongBorder) }
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Inline warning banner for estimator warnings and validation messages.
struct WarningBanner: View {
    let messages: [String]

    var body: some View {
        if !messages.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(messages, id: \.self) { message in
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.semibold))
                }
            }
            .foregroundStyle(Theme.warningText)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.warningBackground, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .combine)
        }
    }
}
