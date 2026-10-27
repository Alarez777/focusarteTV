import SwiftUI
import FocusarteCore

struct DownloadView: View {
    let download: LessonDownload

    @EnvironmentObject private var session: SessionStore

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
                ProgressView()
            }
        }
        .navigationTitle(download.title)
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
