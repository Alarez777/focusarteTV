import SwiftUI
import AVFoundation
import FocusarteCore

struct LessonView: View {
    let route: LessonRoute

    @EnvironmentObject private var session: SessionStore
    @ObservedObject private var playback = PlaybackManager.shared

    @State private var lesson: Lesson?
    @State private var blocks: [LessonBlock] = []
    @State private var videoAsset: VideoAsset?
    @State private var isCompleted = false
    @State private var isUpdating = false
    @State private var errorMessage: String?
    @State private var autoPlayHandled = false
    @FocusState private var playButtonFocused: Bool

    private let baseURL = URL(string: "https://www.focusarte.com")!
    private var summary: LessonSummary { route.summary }

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
        .task { await load() }
        .onChange(of: playback.presented?.id) { _, newValue in
            guard newValue == nil else { return }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 200_000_000)
                playButtonFocused = true
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
            Text(lesson?.title ?? summary.title)
                .font(.system(size: 40, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

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
                    NavigationLink(value: download) {
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

    private func load() async {
        do {
            let loaded = try await session.client.loadLesson(path: summary.path)
            lesson = loaded
            isCompleted = loaded.isCompleted
            blocks = LessonHTMLParser.blocks(from: loaded.bodyHTML, baseURL: baseURL)

            if let video = loaded.video {
                videoAsset = try await session.client.resolveVideo(mediaID: video.mediaID)
            }

            if route.autoPlay, !autoPlayHandled {
                autoPlayHandled = true
                if videoAsset?.playbackURL != nil {
                    startPlayback()
                    return
                }
            }

            if videoAsset != nil {
                // El foco arranca en "Reproducir", que es la acción principal.
                try? await Task.sleep(nanoseconds: 150_000_000)
                playButtonFocused = true
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
            nextProvider: makeNextProvider()
        )
    }

    /// Resuelve la próxima lección reproducible a partir del outline cacheado.
    private func makeNextProvider() -> PlaybackManager.NextProvider? {
        guard let outline = session.cachedOutline(for: route.courseSlug) else { return nil }

        let flat: [(section: String, lesson: LessonSummary)] = outline.sections.flatMap { section in
            section.lessons.map { (section.title, $0) }
        }

        return { currentKey in
            guard let index = flat.firstIndex(where: { $0.lesson.id == currentKey }) else {
                return nil
            }

            let candidates = flat[(index + 1)...].prefix(4)
            for candidate in candidates {
                guard let lesson = try? await session.client.loadLesson(path: candidate.lesson.path),
                      let video = lesson.video,
                      let asset = try? await session.client.resolveVideo(mediaID: video.mediaID),
                      let url = asset.playbackURL else {
                    continue
                }

                return UpNextLesson(
                    key: lesson.id,
                    url: url,
                    duration: asset.duration,
                    progressToken: lesson.progressToken,
                    client: session.client,
                    metadata: PlaybackMetadata(
                        title: lesson.title,
                        courseTitle: route.courseTitle,
                        sectionTitle: candidate.section,
                        artworkURL: lesson.posterURL ?? asset.posterURL
                    )
                )
            }
            return nil
        }
    }

    private func toggleCompleted() {
        guard let lesson else { return }
        isUpdating = true

        Task { @MainActor in
            do {
                try await session.client.setCompleted(!isCompleted, token: lesson.progressToken)
                isCompleted.toggle()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isUpdating = false
        }
    }
}
