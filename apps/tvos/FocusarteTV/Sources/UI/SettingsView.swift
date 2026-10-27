import SwiftUI

struct SettingsView: View {
    @ObservedObject private var preferences = PlaybackPreferences.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 44) {
                Text("Configuración")
                    .font(.system(size: 52, weight: .bold))

                VStack(alignment: .leading, spacing: 16) {
                    Toggle(
                        "Reproducir automáticamente la siguiente lección",
                        isOn: $preferences.autoplayNextLesson
                    )
                    .font(.system(size: 26, weight: .medium))

                    Text("Al terminar un video se muestra la tarjeta de la siguiente lección con una cuenta regresiva. Si no la cancelás, avanza sola.")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 1100, alignment: .leading)

                Text(Self.versionLabel)
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .padding(80)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Configuración")
    }

    private static var versionLabel: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "FocusarteTV v\(version) (\(build))"
    }
}
