import SwiftUI
import FocusarteCore
import AVKit

struct RootView: View {
    @StateObject private var session = SessionStore()

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
    }
}
