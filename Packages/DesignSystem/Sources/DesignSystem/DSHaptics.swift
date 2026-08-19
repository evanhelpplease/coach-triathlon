import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Retours haptiques subtils et cohérents.
public enum DSHaptics {
    public enum Kind { case light, medium, success, warning }

    @MainActor public static func play(_ kind: Kind) {
        #if canImport(UIKit)
        switch kind {
        case .light:  UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning: UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
        #endif
    }
}
