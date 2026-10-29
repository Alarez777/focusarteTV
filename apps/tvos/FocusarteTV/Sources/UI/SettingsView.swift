import SwiftUI
import Foundation

/// Configuración con el layout de 1/3 + 2/3: perfil a la izquierda, opciones
/// con título y explicación a la derecha.
struct SettingsView: View {
    @EnvironmentObject private var session: SessionStore
    @ObservedObject private var preferences = PlaybackPreferences.shared

    @State private var cacheBytes = 0
    @State private var cacheCleared = false

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let third = max(0, proxy.size.width / 3)

                HStack(spacing: 0) {
                    profileColumn
                        .frame(width: third, height: proxy.size.height, alignment: .center)

                    ScrollView(.vertical, showsIndicators: false) {
                        optionsColumn
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    }
                    .frame(width: third * 2, height: proxy.size.height)
                }
            }
            .background(Color.black.ignoresSafeArea())
        }
        .task {
            cacheBytes = session.cacheSizeBytes
        }
    }

    // MARK: - Perfil

    private var profileColumn: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 180, height: 180)

                Text(initial)
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text(session.signedInEmail)
                .font(.system(size: 29))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(Self.versionLabel)
                .font(.system(size: 21))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Opciones

    private var optionsColumn: some View {
        VStack(spacing: 26) {
            SettingsToggleRow(
                title: "Reproducir automáticamente la siguiente lección",
                detail: "Muestra la tarjeta de la siguiente lección y avanza sola al terminar.",
                isOn: $preferences.autoplayNextLesson
            )

            SettingsActionRow(
                title: cacheButtonTitle,
                detail: "Libera las imágenes y posters descargados.",
                action: clearCache
            )

            if cacheCleared {
                Text("Caché eliminada")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            SettingsActionRow(
                title: "Cerrar sesión",
                detail: "Salir de tu cuenta en este Apple TV.",
                destructive: true
            ) {
                Task { await session.signOut() }
            }
        }
        .frame(width: 1100)
    }

    private var initial: String {
        let letter = session.signedInEmail.first.map(String.init) ?? "F"
        return letter.uppercased()
    }

    private var cacheButtonTitle: String {
        guard cacheBytes > 0 else { return "Eliminar caché" }
        let size = ByteCountFormatter.string(fromByteCount: Int64(cacheBytes), countStyle: .file)
        return "Eliminar caché (\(size))"
    }

    private func clearCache() {
        session.clearCaches()
        cacheBytes = 0
        cacheCleared = true
    }

    private static var versionLabel: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "FocusarteTV \(version) (\(build))"
    }
}
