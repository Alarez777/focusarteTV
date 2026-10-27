import SwiftUI
import FocusarteCore

struct LibraryView: View {
    @EnvironmentObject private var session: SessionStore

    private let columns = [GridItem(.adaptive(minimum: 520, maximum: 700), spacing: 60)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 50) {
                    header

                    if session.courses.isEmpty {
                        Text("No hay cursos en esta cuenta.")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 60) {
                            ForEach(session.courses) { course in
                                NavigationLink(value: course) {
                                    CourseCard(course: course)
                                }
                                .buttonStyle(.card)
                            }
                        }
                    }
                }
                .padding(80)
            }
            .navigationDestination(for: Course.self) { course in
                CourseView(course: course)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Mis Cursos")
                    .font(.system(size: 60, weight: .bold))

                if !session.signedInEmail.isEmpty {
                    Text(session.signedInEmail)
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            NavigationLink("Configuración") {
                SettingsView()
            }

            Button("Cerrar sesión") {
                Task { await session.signOut() }
            }
        }
    }
}
