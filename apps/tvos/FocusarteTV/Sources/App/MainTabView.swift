import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            LibraryView()
                .tabItem {
                    Label("Mis Cursos", systemImage: "play.rectangle.on.rectangle")
                }

            SettingsView()
                .tabItem {
                    Label("Configuración", systemImage: "gearshape")
                }
        }
    }
}
