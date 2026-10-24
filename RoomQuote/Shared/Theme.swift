import SwiftUI
import UIKit

/// Colours from the design, each with a dark-mode counterpart.
enum Theme {
    static let background = dynamic(light: 0xF4F5F7, dark: 0x0F1115)
    static let paperBackdrop = dynamic(light: 0xE9EBEF, dark: 0x0B0D10)
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x1A1D23)
    static let sunken = dynamic(light: 0xF4F5F7, dark: 0x23272F)
    static let segmentTrack = dynamic(light: 0xE6E8EC, dark: 0x23272F)
    static let border = dynamic(light: 0xE6E8EC, dark: 0x2C313A)
    static let strongBorder = dynamic(light: 0xDADDE2, dark: 0x3A404A)
    static let divider = dynamic(light: 0xEEF0F2, dark: 0x262A31)
    static let textPrimary = dynamic(light: 0x15181D, dark: 0xF3F4F6)
    static let textSecondary = dynamic(light: 0x4B5563, dark: 0xA7AEB8)
    /// Filled buttons and cards behind white text. Same in both modes so white text keeps 5:1 contrast.
    static let accentFill = Color(hex: 0xC2410C)
    /// Accent used as text or icon colour on a surface.
    static let accentText = dynamic(light: 0xC2410C, dark: 0xFB923C)
    static let selectedPlan = dynamic(light: 0xFFF7F2, dark: 0x2A1A10)
    static let warningBackground = dynamic(light: 0xFDF0E1, dark: 0x3A2614)
    static let warningText = dynamic(light: 0x92400E, dark: 0xFDBA74)
    static let errorText = dynamic(light: 0xB91C1C, dark: 0xFCA5A5)

    // Scan screen is dark in both modes.
    static let scanBackground = Color(hex: 0x101318)
    static let scanViewport = Color(hex: 0x1B2029)
    static let scanSecondary = Color(hex: 0xC7CBD1)

    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

extension QuoteStatus {
    var pillForeground: Color {
        switch self {
        case .draft: Theme.warningText
        case .sent: Theme.dynamic(light: 0x1D4ED8, dark: 0x93C5FD)
        case .accepted: Theme.dynamic(light: 0x166534, dark: 0x86EFAC)
        case .paid: Theme.dynamic(light: 0x3F3F46, dark: 0xD4D4D8)
        }
    }

    var pillBackground: Color {
        switch self {
        case .draft: Theme.warningBackground
        case .sent: Theme.dynamic(light: 0xE8EEFC, dark: 0x1E2A4A)
        case .accepted: Theme.dynamic(light: 0xE5F4EA, dark: 0x163222)
        case .paid: Theme.dynamic(light: 0xECECEE, dark: 0x2A2A2E)
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
