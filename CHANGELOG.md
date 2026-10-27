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
  Cubierto por 21 tests sobre fixtures reales anonimizados.
- App: login con Keychain y re-login silencioso, "Mis Cursos", outline del curso
  con progreso, reproductor HLS, marcado de lección vista y visor de PDFs.
- Ícono de app y Top Shelf con la marca Focusarte (capas Back/Middle/Front).

### Fixed
- La app no arrancaba en el Apple TV: faltaba `UIApplicationSceneManifest` y
  `UILaunchScreen` en el `Info.plist`.
