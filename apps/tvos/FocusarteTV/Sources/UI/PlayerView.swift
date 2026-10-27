import SwiftUI
import AVKit

/// Reproductor nativo de tvOS.
///
/// Usamos `AVPlayerViewController` (no el `VideoPlayer` de SwiftUI) porque es
/// el que expone PiP nativo y no enlaza `_AVKit_SwiftUI`.
struct PlayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.allowsPictureInPicturePlayback = true
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player {
            controller.player = player
        }
    }

    final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        func playerViewControllerDidStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
            Task { @MainActor in
                PlaybackManager.shared.setPictureInPicture(active: true)
            }
        }

        func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
            Task { @MainActor in
                PlaybackManager.shared.setPictureInPicture(active: false)
            }
        }

        func playerViewController(
            _ playerViewController: AVPlayerViewController,
            failedToStartPictureInPictureWithError error: Error
        ) {
            Task { @MainActor in
                PlaybackManager.shared.setPictureInPicture(active: false)
            }
        }

        func playerViewController(
            _ playerViewController: AVPlayerViewController,
            restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
        ) {
            Task { @MainActor in
                PlaybackManager.shared.restore()
            }
            completionHandler(true)
        }
    }
}
