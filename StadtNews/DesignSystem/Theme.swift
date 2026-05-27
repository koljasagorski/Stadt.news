import SwiftUI
import UIKit

/// Central design tokens for an editorial, newspaper-grade look.
enum Theme {

    // MARK: Colour

    enum Color {
        /// Primary text – near-black on paper, warm off-white in the dark.
        static let ink = SwiftUI.Color(light: 0x111111, dark: 0xF2F0EC)
        static let secondaryInk = SwiftUI.Color(light: 0x595650, dark: 0xA9A69F)
        static let tertiaryInk = SwiftUI.Color(light: 0x8A867E, dark: 0x7C7972)
        /// Page background.
        static let paper = SwiftUI.Color(light: 0xFFFFFF, dark: 0x121212)
        /// Slightly tinted surface for cards and chips.
        static let surface = SwiftUI.Color(light: 0xF7F5F1, dark: 0x1D1D1F)
        /// Thin rules between stories.
        static let hairline = SwiftUI.Color(light: 0xE4E0D8, dark: 0x32312F)
        /// Editorial red used for kickers, the masthead accent and actions.
        static let brand = SwiftUI.Color(light: 0xA6192E, dark: 0xE8584E)
    }

    // MARK: Typography

    enum Font {
        static let masthead = SwiftUI.Font.system(size: 30, weight: .black, design: .serif)
        static let mastheadCompact = SwiftUI.Font.system(size: 19, weight: .black, design: .serif)

        static let featuredHeadline = SwiftUI.Font.system(.largeTitle, design: .serif).weight(.bold)
        static let headline = SwiftUI.Font.system(.title3, design: .serif).weight(.bold)
        static let secondaryHeadline = SwiftUI.Font.system(.headline, design: .serif).weight(.semibold)

        static let articleTitle = SwiftUI.Font.system(.title, design: .serif).weight(.bold)
        static let articleBody = SwiftUI.Font.system(.body, design: .serif)
        static let lead = SwiftUI.Font.system(.title3, design: .serif)

        static let summary = SwiftUI.Font.system(.subheadline, design: .default)
        static let kicker = SwiftUI.Font.system(.caption, design: .default).weight(.bold)
        static let meta = SwiftUI.Font.system(.caption, design: .default).weight(.medium)
    }

    // MARK: Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 28
        static let section: CGFloat = 36
    }

    static let pageMargin: CGFloat = 20
}

// MARK: - Hex colours with light / dark variants

extension Color {
    init(light: UInt32, dark: UInt32) {
        self = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
