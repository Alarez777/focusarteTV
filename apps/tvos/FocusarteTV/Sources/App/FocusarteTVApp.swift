import SwiftUI
import AVFoundation

@main
struct FocusarteTVApp: App {
    init() {
        // Inicializa el cache de imágenes (memoria + URLCache en disco).
        _ = ImageStore.shared

        // Necesario para que el audio/video siga al mandar la app al fondo (PiP).
        let audio = AVAudioSession.sharedInstance()
        try? audio.setCategory(.playback, mode: .moviePlayback)
        try? audio.setActive(true)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
