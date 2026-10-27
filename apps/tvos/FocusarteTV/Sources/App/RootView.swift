import SwiftUI
import FocusarteCore
import AVKit

struct RootView: View {
    @StateObject private var session = SessionStore()
    @ObservedObject private var playback = PlaybackManager.shared

    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()

            switch session.state {
            case .restoring:
                ProgressView()
            case .signedOut:
                LoginView()
            case .signedIn:
                LibraryView()
            }
        }
        .environmentObject(session)
        .task { await session.restore() }
        .fullScreenCover(item: $playback.presented) { active in
            PlayerScreen(player: active.player, duration: active.duration) { seconds, percent in
                playback.handleFinish(seconds: seconds, percent: percent)
            }
        }
    }
}
