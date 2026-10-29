import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        TabView {
            ForEach(session.courses) { course in
                CourseBrowserView(course: course)
                    .tabItem {
                        Text(course.title)
                    }
            }

            SettingsView()
                .tabItem {
                    Text("Configuración")
                }
        }
    }
}
