import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: SessionStore
    @ObservedObject private var preferences = PlaybackPreferences.shared

    @State private var cacheCleared = false
    @State private var cacheBytes = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Reproducción") {
                    Toggle(
                        "Reproducir automáticamente la siguiente lección",
                        isOn: $preferences.autoplayNextLesson
                    )
                }

                Section("Almacenamiento") {
                    Button(cacheButtonTitle) {
                        session.clearCaches()
                        cacheBytes = 0
                        cacheCleared = true
                    }

                    if cacheCleared {
                        Text("Caché eliminada")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
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
            .onAppear {
                cacheBytes = session.cacheSizeBytes
            }
        }
    }

    private var cacheButtonTitle: String {
        guard cacheBytes > 0 else { return "Eliminar caché" }
        let size = ByteCountFormatter.string(fromByteCount: Int64(cacheBytes), countStyle: .file)
        return "Eliminar caché (\(size))"
    }

    private static var versionLabel: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
