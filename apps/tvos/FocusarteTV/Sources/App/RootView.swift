import SwiftUI

struct RootView: View {
    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()

            LoginView()
        }
    }
}
