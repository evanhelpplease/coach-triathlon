import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public extension Color {
    /// Initialise depuis un hex `RRGGBB` (ou `RRGGBBAA`).
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    /// Couleur dynamique clair/sombre. Sur iOS, bascule automatiquement selon le thème.
    static func dsDynamic(light: UInt32, dark: UInt32) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark))
                : UIColor(Color(hex: light))
        })
        #else
        return Color(hex: dark)
        #endif
    }
}
