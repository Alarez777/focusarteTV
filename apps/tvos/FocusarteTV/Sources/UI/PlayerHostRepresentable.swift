import SwiftUI
import UIKit

/// Muestra un `PlayerHostViewController` ya existente (creado y retenido por
/// `PlaybackManager`). No crea uno nuevo: así el player y su delegate de PiP
/// sobreviven a la pantalla.
struct PlayerHostRepresentable: UIViewControllerRepresentable {
    let host: PlayerHostViewController

    func makeUIViewController(context: Context) -> PlayerHostViewController {
        host
    }

    func updateUIViewController(_ uiViewController: PlayerHostViewController, context: Context) {}

    static func dismantleUIViewController(_ host: PlayerHostViewController, coordinator: Void) {
        PlaybackManager.shared.hostWasDismantled(host)
    }
}
