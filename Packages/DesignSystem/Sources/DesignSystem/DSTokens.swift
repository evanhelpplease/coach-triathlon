import SwiftUI

/// Jetons de design : couleurs, typographie, espacements, rayons.
/// Identité « triathlon premium » : eau (aqua), route (orange), effort (lime),
/// dark mode natif soigné (pas un simple inversé).
public enum DS {

    // MARK: - Couleurs

    public enum Color {
        // Fonds & surfaces
        public static let background = SwiftUI.Color.dsDynamic(light: 0xF4F6F9, dark: 0x0A0E13)
        public static let surface    = SwiftUI.Color.dsDynamic(light: 0xFFFFFF, dark: 0x131A22)
        public static let surfaceElevated = SwiftUI.Color.dsDynamic(light: 0xFFFFFF, dark: 0x1B2530)
        public static let separator  = SwiftUI.Color.dsDynamic(light: 0xE4E8EE, dark: 0x263141)

        // Texte
        public static let textPrimary   = SwiftUI.Color.dsDynamic(light: 0x0C1116, dark: 0xF2F6FB)
        public static let textSecondary = SwiftUI.Color.dsDynamic(light: 0x5A6572, dark: 0x9DB0C2)
        public static let textTertiary  = SwiftUI.Color.dsDynamic(light: 0x9AA4B0, dark: 0x5E7183)

        // Marque
        public static let primary = SwiftUI.Color.dsDynamic(light: 0x0E9FB0, dark: 0x16C0D4) // aqua / eau
        public static let accent  = SwiftUI.Color.dsDynamic(light: 0x88B900, dark: 0xC6F24E) // lime / effort

        // Disciplines
        public static let swim = SwiftUI.Color.dsDynamic(light: 0x1E88E5, dark: 0x39B7F5)
        public static let bike = SwiftUI.Color.dsDynamic(light: 0xF06A2B, dark: 0xFF8A50)
        public static let run  = SwiftUI.Color.dsDynamic(light: 0x2E9E5B, dark: 0x4CD787)
        public static let strength = SwiftUI.Color.dsDynamic(light: 0x8E63D6, dark: 0xB48CF0)

        // États
        public static let success = SwiftUI.Color.dsDynamic(light: 0x1E9E63, dark: 0x3FD98A)
        public static let warning = SwiftUI.Color.dsDynamic(light: 0xE08A00, dark: 0xFFB23E)
        public static let danger  = SwiftUI.Color.dsDynamic(light: 0xD64545, dark: 0xFF6B6B)

        /// Couleur associée à un sport (chaîne stable, découplée du moteur).
        public static func sport(_ key: String) -> SwiftUI.Color {
            switch key {
            case "swim": return swim
            case "bike": return bike
            case "run": return run
            case "strength": return strength
            default: return primary
            }
        }
    }

    // MARK: - Typographie

    public enum Font {
        public static func display(_ size: CGFloat = 34) -> SwiftUI.Font { .system(size: size, weight: .bold, design: .rounded) }
        public static let title    = SwiftUI.Font.system(.title2, design: .rounded).weight(.bold)
        public static let headline = SwiftUI.Font.system(.headline, design: .rounded).weight(.semibold)
        public static let body     = SwiftUI.Font.system(.body)
        public static let callout  = SwiftUI.Font.system(.callout)
        public static let caption  = SwiftUI.Font.system(.caption)
        /// Grands nombres (chronos, charges) : chiffres alignés, arrondi.
        public static func number(_ size: CGFloat = 28) -> SwiftUI.Font {
            .system(size: size, weight: .bold, design: .rounded).monospacedDigit()
        }
    }

    // MARK: - Espacements & rayons

    public enum Space {
        public static let xxs: CGFloat = 4
        public static let xs: CGFloat = 8
        public static let sm: CGFloat = 12
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let xl: CGFloat = 32
        public static let xxl: CGFloat = 48
    }

    public enum Radius {
        public static let sm: CGFloat = 10
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let pill: CGFloat = 999
    }
}
