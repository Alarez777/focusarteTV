import SwiftUI
import PDFKit
import FocusarteCore

struct DownloadView: View {
    let download: LessonDownload

    @EnvironmentObject private var session: SessionStore

    @State private var data: Data?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let data {
                PDFKitView(data: data)
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

private struct PDFKitView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .black
        view.document = PDFDocument(data: data)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}
