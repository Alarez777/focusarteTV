import SwiftUI
import AVKit
import AVFoundation

/// Reproducción a pantalla completa con el player nativo de Apple.
struct PlayerScreen: View {
    let player: AVPlayer
    let duration: TimeInterval
    let onFinish: (Double, Int) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PlayerView(player: player)
            .ignoresSafeArea()
            .onAppear {
                player.play()
            }
            .onDisappear {
                // Si sigue en PiP, el video continúa fuera de la app.
                guard !PlaybackManager.shared.isPictureInPictureActive else { return }

                player.pause()

                let seconds = player.currentTime().seconds
                let percent: Int
                if seconds.isFinite, duration > 0 {
                    percent = min(Int((seconds / duration) * 100), 100)
                } else {
                    percent = 0
                }
                onFinish(seconds.isFinite ? seconds : 0, percent)
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            ) { notification in
                guard let item = notification.object as? AVPlayerItem,
                      item === player.currentItem else {
                    return
                }
                dismiss()
            }
    }
}
