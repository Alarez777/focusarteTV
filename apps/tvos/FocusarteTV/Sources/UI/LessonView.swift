import SwiftUI
import FocusarteCore

struct LessonView: View {
    let route: LessonRoute
    let onMarkedViewed: ((String) -> Void)?

    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var playback = PlaybackManager.shared

    @State private var displayedSummary: LessonSummary
    @State private var lesson: Lesson?
    @State private var blocks: [LessonBlock] = []
    @State private var videoAsset: VideoAsset?
    @State private var isCompleted = false
    @State private var isUpdating = false
    @State private var errorMessage: String?
    @State private var presentedDownload: LessonDownload?
    /// Solo devolver el foco al encabezado si el PDF se abrió desde ahí;
    /// los links de Descargas del final no deben arrastrar la vista arriba.
    @State private var restorePDFFocus = false
    @FocusState private var playButtonFocused: Bool
    @FocusState private var pdfButtonFocused: Bool

    private let baseURL = URL(string: "https://www.focusarte.com")!

    init(route: LessonRoute, onMarkedViewed: ((String) -> Void)? = nil) {
        self.route = route
        self.onMarkedViewed = onMarkedViewed
        _displayedSummary = State(initialValue: route.summary)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                videoSection
                header

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.accent)
                }

                ForEach(blocks.indices, id: \.self) { index in
                    LessonBlockView(block: blocks[index])
                }

                downloads
            }
            .padding(80)
        }
        .task { await loadLesson(displayedSummary) }
        .fullScreenCover(item: $presentedDownload) { download in
            DownloadView(download: download)
        }
        .onChange(of: playback.currentLessonKey) { _, newValue in
            followPlayback(newValue)
        }
        .onChange(of: playback.presented?.id) { _, newValue in
            guard newValue == nil else { return }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 200_000_000)
                playButtonFocused = true
            }
        }
        .onChange(of: presentedDownload) { _, newValue in
            guard newValue == nil, restorePDFFocus, pdfDownload != nil else { return }
            restorePDFFocus = false
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 200_000_000)
                pdfButtonFocused = true
            }
        }
    }

    // MARK: - Miniatura

    @ViewBuilder
    private var videoSection: some View {
        if let asset = videoAsset {
            CachedImage(url: lesson?.posterURL ?? asset.posterURL) {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
            }
            .frame(maxWidth: 1100)
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 24) {
            Text(lesson?.title ?? displayedSummary.title)
                .font(.system(size: 40, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            if let pdfDownload {
                Button {
                    restorePDFFocus = true
                    presentedDownload = pdfDownload
                } label: {
                    Label("Ver PDF", systemImage: "doc.text")
                        .font(.system(size: 22, weight: .semibold))
                }
                .focused($pdfButtonFocused)
            }

            Button {
                toggleCompleted()
            } label: {
                Text(isCompleted ? "Vista ✓" : "Marcar como vista")
                    .font(.system(size: 22, weight: .semibold))
            }
            .disabled(isUpdating || lesson == nil)

            if videoAsset?.playbackURL != nil {
                Button {
                    startPlayback()
                } label: {
                    Label("Reproducir", systemImage: "play.fill")
                        .font(.system(size: 22, weight: .semibold))
                }
                .focused($playButtonFocused)
                .onPlayPauseCommand {
                    startPlayback()
                }
            }
        }
    }

    @ViewBuilder
    private var downloads: some View {
        if let lesson, !lesson.downloads.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("Descargas")
                    .font(.system(size: 28, weight: .semibold))

                ForEach(lesson.downloads) { download in
                    Button {
                        restorePDFFocus = false
                        presentedDownload = download
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "arrow.down.doc")
                            Text(download.title)
                            Spacer()
                        }
                        .font(.system(size: 22))
                        .padding(.vertical, 6)
                    }
                }
            }
            .padding(.top, 20)
        }
    }

    // MARK: - Datos

    /// PDF del encabezado: solo para posts sin video. Si ninguna descarga
    /// parece PDF, se usa la primera para no dejar sin acceso al visor.
    private var pdfDownload: LessonDownload? {
        guard let lesson else { return nil }
        return primaryPDFDownload(in: lesson)
    }

    private func primaryPDFDownload(in lesson: Lesson) -> LessonDownload? {
        guard lesson.video == nil else { return nil }
        return lesson.downloads.first(where: { $0.isLikelyPDF }) ?? lesson.downloads.first
    }

    /// Cuando el player auto-avanza, esta pantalla sigue a la lección que suena.
    private func followPlayback(_ key: String?) {
        guard let key,
              key != displayedSummary.id,
              let outline = session.cachedOutline(for: route.courseSlug),
              let next = outline.allLessons.first(where: { $0.id == key }) else {
            return
        }

        displayedSummary = next
        Task { await loadLesson(next) }
    }

    private func loadLesson(_ target: LessonSummary) async {
        lesson = nil
        blocks = []
        videoAsset = nil
        errorMessage = nil

        do {
            let loaded = try await session.client.loadLesson(path: target.path)
            lesson = loaded
            isCompleted = loaded.isCompleted
            blocks = LessonHTMLParser.blocks(from: loaded.bodyHTML, baseURL: baseURL)

            if let video = loaded.video {
                videoAsset = try await session.client.resolveVideo(mediaID: video.mediaID)
            }

            if videoAsset != nil {
                try? await Task.sleep(nanoseconds: 150_000_000)
                playButtonFocused = true
            } else if primaryPDFDownload(in: loaded) != nil {
                try? await Task.sleep(nanoseconds: 150_000_000)
                pdfButtonFocused = true
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Reproducción

    private func startPlayback() {
        guard let url = videoAsset?.playbackURL, let lesson else { return }

        let metadata = PlaybackMetadata(
            title: lesson.title,
            courseTitle: route.courseTitle,
            sectionTitle: route.sectionTitle,
            artworkURL: lesson.posterURL ?? videoAsset?.posterURL
        )

        playback.play(
            key: lesson.id,
            url: url,
            duration: videoAsset?.duration ?? 0,
            progressToken: lesson.progressToken,
            client: session.client,
            metadata: metadata,
            courseSlug: route.courseSlug,
            nextProvider: session.makeNextProvider(
                courseSlug: route.courseSlug,
                courseTitle: route.courseTitle
            )
        )
    }

    private func toggleCompleted() {
        guard let lesson else { return }
        let willComplete = !isCompleted
        let shouldReturn = willComplete && lesson.video == nil
        isUpdating = true

        Task { @MainActor in
            do {
                try await session.client.setCompleted(willComplete, token: lesson.progressToken)
                isCompleted = willComplete

                if shouldReturn {
                    onMarkedViewed?(lesson.id)
                    dismiss()
                }
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isUpdating = false
        }
    }
}
