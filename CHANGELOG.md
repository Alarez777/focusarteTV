# Changelog

Todas las versiones notables de FocusarteTV. Formato basado en
[Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y
[SemVer](https://semver.org/lang/es/).

## [Unreleased]

### Added
- Scaffold del proyecto: app tvOS mínima en SwiftUI, proyecto XcodeGen y CI que
  publica un `.ipa` sin firmar en cada push.
- `scripts/fetch-ipa.sh` para bajar el artifact a `~/Descargas/ABDM/Movil`.
- `docs/kajabi-protocol.md` con el protocolo verificado de Focusarte/Kajabi.
- Núcleo `FocusarteCore`: cliente HTTP con cookies y CSRF, login, parsers de
  biblioteca/curso/lección, resolución de Wistia a HLS y reporte de progreso.
  Cubierto por 24 tests sobre fixtures reales anonimizados.
- App: login con Keychain y re-login silencioso, "Mis Cursos", outline del curso
  con progreso, reproductor HLS, marcado de lección vista y visor de PDFs.
- Ícono de app y Top Shelf con la marca Focusarte (capas Back/Middle/Front).
- Cache de outlines en memoria (stale-while-revalidate): al reentrar a un curso
  se muestra al instante y se refresca en segundo plano.
- Cache de imágenes en dos niveles (memoria + URLCache en disco) para portadas,
  miniaturas y fotos del post.
- PiP nativo en tvOS: `allowsPictureInPicturePlayback`, delegate de
  `AVPlayerViewController` y `PlaybackManager` que reutiliza el player y lo
  restaura a pantalla completa al volver del PiP.
- `UIBackgroundModes: audio` y `AVAudioSession(.playback)` para reproducción en
  segundo plano.
- Metadatos del reproductor: `externalMetadata` (título, curso · bloque,
  carátula) y `MPNowPlayingInfoCenter` (lección / curso / bloque).

### Changed
- Al abrir un curso, el foco va a la primera lección sin completar (con scroll).
- La lección ya no reproduce sola: muestra el poster y un botón "Reproducir".
- La reproducción es a pantalla completa con `AVPlayerViewController` y vuelve
  al post al terminar.
- Play/Pause del control remoto sobre una fila abre el video directamente.
- "Reproducir" está en el header, a la derecha de "Vista"; la miniatura va
  arriba del título, centrada, y usa el `stillUrl` original de Kajabi.

### Fixed
- El primer "Reproducir" abría un player vacío y perdía el foco: ahora el cover
  usa `fullScreenCover(item:)` con el player dentro del item.
- Play del control remoto sobre el botón "Reproducir" también inicia el video.
- Login: `URLSession` seguía los redirects por su cuenta y se perdían los
  `Set-Cookie` del `302` de login; la sesión quedaba sin cookie y volvía a
  `/login`. Ahora los redirects se resuelven a mano absorbiendo cookies en cada
  salto.
- La app no arrancaba en el Apple TV: faltaba `UIApplicationSceneManifest` y
  `UILaunchScreen` en el `Info.plist`.
- Arranque en tvOS 27: se eliminaron del enlace `PDFKit` y `_AVKit_SwiftUI`
  (PDFs con Core Graphics; video con `AVPlayerViewController`).
- Login devolvía "Email o contraseña incorrectos" con credenciales válidas: el
  header `Origin` se enviaba con barra final y Rails respondía 422 (CSRF).
- Controles de login nativos de tvOS (sin fondo/borde propios) y con
  `textContentType` para el autocompletado desde el iPhone.
- Diagnóstico visible cuando el login falla sin mensaje del servidor
  (`HTTP · ruta · título · form · remember`) y `Referer` como un navegador.
