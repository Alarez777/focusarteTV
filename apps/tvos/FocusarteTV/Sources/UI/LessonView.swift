import SwiftUI
import AVFoundation
import FocusarteCore

struct LessonView: View {
    let route: LessonRoute

    @EnvironmentObject private var session: SessionStore

    @State private var lesson: Lesson?
    @State private var blocks: [LessonBlock] = []
    @State private var videoAsset: VideoAsset?
    @State private var player: AVPlayer?
    @State private var isPlayerPresented = false
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
                header
                videoSection

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
        .fullScreenCover(isPresented: $isPlayerPresented, onDismiss: handlePlayerDismissed) {
            if let player {
                PlayerScreen(player: player)
            }
        }
    }

    // MARK: - Video

    @ViewBuilder
    private var videoSection: some View {
        if let asset = videoAsset {
            AsyncImage(url: lesson?.posterURL ?? asset.posterURL) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                }
            }
            .frame(maxWidth: 1200)
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        guard let url = videoAsset?.playbackURL else { return }
        player = AVPlayer(url: url)
        isPlayerPresented = true
    }

    private func handlePlayerDismissed() {
        guard let lesson, let player else { return }

        let seconds = player.currentTime().seconds
        let duration = videoAsset?.duration ?? 0
        let percent = (seconds.isFinite && duration > 0)
            ? min(Int((seconds / duration) * 100), 100)
            : 0

        player.pause()
        self.player = nil

        guard percent > 0 else { return }
        let shouldComplete = percent >= 90

        Task { @MainActor in
            try? await session.client.reportProgress(
                token: lesson.progressToken,
                seconds: seconds,
                percent: percent
            )
            if shouldComplete && !isCompleted {
                try? await session.client.setCompleted(true, token: lesson.progressToken)
                isCompleted = true
            }
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
