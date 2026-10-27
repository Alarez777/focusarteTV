import SwiftUI

enum Theme {
    /// #DE3E50 — color que Focusarte usa en el player de Wistia.
    static let accent = Color(red: 0.871, green: 0.243, blue: 0.314)

    static let background = LinearGradient(
        colors: [
            Color(red: 0.10, green: 0.08, blue: 0.10),
            Color(red: 0.02, green: 0.02, blue: 0.03)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
