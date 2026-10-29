import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var session: SessionStore
    @ObservedObject private var preferences = PlaybackPreferences.shared

    @State private var selection: String = ""

    var body: some View {
        ZStack(alignment: .topLeading) {
            TabView(selection: $selection) {
                ForEach(session.courses) { course in
                    CourseBrowserView(course: course)
                        .tabItem {
                            Text(course.title)
                        }
                        .tag(course.slug)
                }

                SettingsView()
                    .tabItem {
                        Text("Configuración")
                    }
                    .tag("settings")
            }
            .onAppear { selectInitialTab() }
            .onChange(of: session.courses.count) { _, _ in
                selectInitialTab()
            }

            Image("FocusarteWordmark")
                .resizable()
                .scaledToFit()
                .frame(height: 26)
                .padding(.leading, 60)
                .padding(.top, 30)
                .allowsHitTesting(false)
        }
    }

    private func selectInitialTab() {
        guard selection.isEmpty, let first = session.courses.first else { return }

        if let last = preferences.lastCourseSlug,
           session.courses.contains(where: { $0.slug == last }) {
            selection = last
        } else {
            selection = first.slug
        }
    }
}
