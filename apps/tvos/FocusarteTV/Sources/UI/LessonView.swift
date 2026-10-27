import SwiftUI
import AVFoundation
import FocusarteCore

struct LessonView: View {
    let summary: LessonSummary

    @EnvironmentObject private var session: SessionStore

    @State private var lesson: Lesson?
    @State private var blocks: [LessonBlock] = []
    @State private var player: AVPlayer?
    @State private var duration: Double = 0
    @State private var isCompleted = false
    @State private var isUpdating = false
    @State private var errorMessage: String?

    private let baseURL = URL(string: "https://www.focusarte.com")!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                if let player {
                    PlayerView(player: player)
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .frame(maxWidth: 1400)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

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
        .onDisappear { reportProgress() }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 30) {
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

    private func load() async {
        do {
            let loaded = try await session.client.loadLesson(path: summary.path)
            lesson = loaded
            isCompleted = loaded.isCompleted
            blocks = LessonHTMLParser.blocks(from: loaded.bodyHTML, baseURL: baseURL)

            if let video = loaded.video {
                let asset = try await session.client.resolveVideo(mediaID: video.mediaID)
                duration = asset.duration
                if let url = asset.playbackURL {
                    let newPlayer = AVPlayer(url: url)
                    player = newPlayer
                    newPlayer.play()
                }
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
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

    private func reportProgress() {
        guard let lesson, let player else { return }

        let seconds = player.currentTime().seconds
        guard seconds.isFinite, seconds > 0, duration > 0 else { return }

        let percent = min(Int((seconds / duration) * 100), 100)
        let shouldComplete = percent >= 90

        Task { @MainActor in
            try? await session.client.reportProgress(
                token: lesson.progressToken,
                seconds: seconds,
                percent: percent
            )
            if shouldComplete && !isCompleted {
                try? await session.client.setCompleted(true, token: lesson.progressToken)
            }
        }
    }
}
