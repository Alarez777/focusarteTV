import SwiftUI
import FocusarteCore

struct RootView: View {
    @StateObject private var session = SessionStore()
    @ObservedObject private var playback = PlaybackManager.shared
    @ObservedObject private var preferences = PlaybackPreferences.shared

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
                MainTabView()
            }
        }
        .environmentObject(session)
        .task { await session.restore() }
        .fullScreenCover(item: $playback.presented) { active in
            ZStack {
                PlayerHostRepresentable(host: active.host)
                    .id(active.id)
                    .ignoresSafeArea()

                if preferences.autoplayNextLesson, let next = playback.upNext {
                    UpNextOverlayView(next: next, countdown: playback.upNextCountdown)
                }
            }
        }
    }
}
