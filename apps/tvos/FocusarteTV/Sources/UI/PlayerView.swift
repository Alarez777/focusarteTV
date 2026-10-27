import SwiftUI
import AVKit

/// Reproductor nativo de tvOS.
///
/// Usamos `AVPlayerViewController` en vez del `VideoPlayer` de SwiftUI a
/// propósito: `VideoPlayer` enlaza el framework privado `_AVKit_SwiftUI`, que
/// no está garantizado entre versiones de tvOS. Si falta, la app muere en el
/// arranque (dyld), aunque nunca se abra un video.
struct PlayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.updatesNowPlayingInfoCenter = false
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player {
            controller.player = player
        }
    }
}
