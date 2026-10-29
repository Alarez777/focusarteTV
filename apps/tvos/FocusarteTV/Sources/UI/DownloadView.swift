import SwiftUI
import FocusarteCore

struct DownloadView: View {
    let download: LessonDownload

    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var data: Data?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let data {
                PDFPagesView(data: data)
                    .ignoresSafeArea()
            } else if let errorMessage {
                VStack(spacing: 20) {
                    Text(errorMessage)
                    Button("Reintentar") { Task { await load() } }
                }
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Descargando PDF…")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .onExitCommand { dismiss() }
        .task { await load() }
    }

    private func load() async {
        do {
            data = try await session.client.download(path: download.path)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
