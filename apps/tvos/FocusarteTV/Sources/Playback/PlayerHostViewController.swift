import Foundation
import AVFoundation
import AVKit
import UIKit

/// Host propio del `AVPlayerViewController`.
///
/// Existe para que el player (y su delegate de PiP) sobreviva a la pantalla de
/// SwiftUI que lo creó. Sin esto, al desmontarse el cover se libera el delegate
/// y el PiP queda flotando sin forma de volver a pantalla completa.
@MainActor
final class PlayerHostViewController: UIViewController, AVPlayerViewControllerDelegate {
    let playerViewController = AVPlayerViewController()

    private(set) var key = ""
    private(set) var isPictureInPictureActive = false
    private(set) var isDetachedFromScreen = false
    private(set) var duration: TimeInterval = 0

    private var onFinish: ((Double, Int) -> Void)?
    private var onTick: ((Double) -> Void)?
    private var onPiPChange: ((Bool) -> Void)?
    private var onRestore: (() -> Void)?

    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var didTearDown = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        playerViewController.allowsPictureInPicturePlayback = true
        playerViewController.delegate = self

        addChild(playerViewController)
        playerViewController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(playerViewController.view)
        NSLayoutConstraint.activate([
            playerViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            playerViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        playerViewController.didMove(toParent: self)
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        [playerViewController]
    }

    func configure(
        key: String,
        url: URL,
        duration: TimeInterval,
        metadata: PlaybackMetadata,
        onFinish: @escaping (Double, Int) -> Void,
        onTick: @escaping (Double) -> Void,
        onPiPChange: @escaping (Bool) -> Void,
        onRestore: @escaping () -> Void
    ) {
        self.key = key
        self.duration = duration
        self.onFinish = onFinish
        self.onTick = onTick
        self.onPiPChange = onPiPChange
        self.onRestore = onRestore

        let item = AVPlayerItem(url: url)
        item.externalMetadata = metadata.metadataItems()
        metadata.attachArtwork(to: item)

        let player = AVPlayer(playerItem: item)
        playerViewController.player = player

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                let seconds = time.seconds
                guard seconds.isFinite else { return }
                self.onTick?(max(self.duration - seconds, 0))
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.onFinish?(self.duration, 100)
            }
        }
    }

    var player: AVPlayer? {
        playerViewController.player
    }

    func play() {
        playerViewController.player?.play()
    }

    var currentSeconds: Double {
        playerViewController.player?.currentTime().seconds ?? 0
    }

    func teardown() {
        guard !didTearDown else { return }
        didTearDown = true

        if let timeObserver {
            playerViewController.player?.removeTimeObserver(timeObserver)
        }
        timeObserver = nil

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil

        playerViewController.player?.pause()
        playerViewController.player = nil
        playerViewController.contextualActions = []
    }

    // MARK: - Up Next

    func setContextualActions(
        active: Bool,
        onNext: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        guard active else {
            playerViewController.contextualActions = []
            return
        }

        let cancel = UIAction(
            title: "Cancelar",
            image: UIImage(systemName: "xmark")
        ) { _ in
            onCancel()
        }

        let next = UIAction(
            title: "Siguiente",
            image: UIImage(systemName: "forward.end.fill")
        ) { _ in
            onNext()
        }

        playerViewController.contextualActions = [cancel, next]
    }

    // MARK: - PiP

    func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        isPictureInPictureActive = true
        onPiPChange?(true)
    }

    func playerViewControllerDidStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        isPictureInPictureActive = true
        onPiPChange?(true)
    }

    func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        isPictureInPictureActive = false
        onPiPChange?(false)
    }

    func playerViewController(
        _ playerViewController: AVPlayerViewController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        isPictureInPictureActive = false
        onPiPChange?(false)
    }

    func playerViewController(
        _ playerViewController: AVPlayerViewController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        onRestore?()
        completionHandler(true)
    }

    func detachFromScreen() {
        isDetachedFromScreen = true
    }
}
