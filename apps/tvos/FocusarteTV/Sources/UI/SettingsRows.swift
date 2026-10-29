import SwiftUI

/// Fila de ajuste con título + explicación (estilo Settings de tvOS).
struct SettingsToggleRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    @FocusState private var isFocused: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundStyle(isFocused ? Color.black : Color.white)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(isFocused ? Color.black.opacity(0.7) : Color.white.opacity(0.55))
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .focused($isFocused)
    }
}

/// Fila de acción (botón) con título + explicación.
struct SettingsActionRow: View {
    let title: String
    let detail: String
    var destructive: Bool = false
    let action: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundStyle(
                        isFocused
                            ? Color.black
                            : (destructive ? Color.red : Color.white)
                    )

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(isFocused ? Color.black.opacity(0.7) : Color.white.opacity(0.55))
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .focused($isFocused)
    }
}
