import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: SessionStore
    @ObservedObject private var preferences = PlaybackPreferences.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Reproducción") {
                    Toggle(
                        "Reproducir automáticamente la siguiente lección",
                        isOn: $preferences.autoplayNextLesson
                    )
                }

                Section("Cuenta") {
                    if !session.signedInEmail.isEmpty {
                        LabeledContent("Cuenta", value: session.signedInEmail)
                    }

                    Button("Cerrar sesión", role: .destructive) {
                        Task { await session.signOut() }
                    }
                }

                Section("Acerca de") {
                    LabeledContent("Versión", value: Self.versionLabel)
                }
            }
            .navigationTitle("Configuración")
        }
    }

    private static var versionLabel: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
