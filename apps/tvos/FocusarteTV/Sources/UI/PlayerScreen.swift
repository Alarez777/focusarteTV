import SwiftUI
import AVKit
import AVFoundation

/// Reproducción a pantalla completa con el player nativo de Apple.
struct PlayerScreen: View {
    let player: AVPlayer

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PlayerView(player: player)
            .ignoresSafeArea()
            .onAppear {
                player.play()
            }
            .onDisappear {
                player.pause()
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
