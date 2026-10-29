# Changelog

Todas las versiones notables de FocusarteTV. Formato basado en
[Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y
[SemVer](https://semver.org/lang/es/).

## [Unreleased]

### Added
- Scaffold del proyecto: app tvOS mínima en SwiftUI, proyecto XcodeGen y CI que publica un `.ipa` sin firmar en cada push.
- `scripts/fetch-ipa.sh` para bajar el artifact a `~/Descargas/ABDM/Movil`.
- `docs/kajabi-protocol.md` con el protocolo verificado de Focusarte/Kajabi.
- Núcleo `FocusarteCore`: cliente HTTP con cookies y CSRF, login, parsers de biblioteca/curso/lección, resolución de Wistia a HLS y reporte de progreso. Cubierto por 24 tests sobre fixtures reales anonimizados.
- App: login con Keychain y re-login silencioso, "Mis Cursos", outline del curso con progreso, reproductor HLS, marcado de lección vista y visor de PDFs.
- Ícono de app y Top Shelf con la marca Focusarte (capas Back/Middle/Front).
- Cache de outlines en memoria (stale-while-revalidate): al reentrar a un curso se muestra al instante y se refresca en segundo plano.
- Cache de imágenes en dos niveles (memoria + URLCache en disco) para portadas, miniaturas y fotos del post.
- PiP nativo en tvOS: `allowsPictureInPicturePlayback`, delegate de `AVPlayerViewController` y `PlaybackManager` que reutiliza el player y lo restaura a pantalla completa al volver del PiP.
- `UIBackgroundModes: audio` y `AVAudioSession(.playback)` para reproducción en segundo plano.
- Metadatos del reproductor: `externalMetadata` (título, curso · bloque, carátula) y `MPNowPlayingInfoCenter` (lección / curso / bloque).

### Added
- PiP nativo con `PlayerHostViewController` retenido por `PlaybackManager`: el player y su delegate sobreviven al cover, así el restore a pantalla completa funciona aunque el video flote.
- Subtítulo `"Curso · Bloque"` en la barra de transporte del player.
- Autoplay de la siguiente lección con tarjeta Up Next (miniatura, título y cuenta regresiva) y acciones nativas Cancelar/Siguiente; al terminar el temporizador avanza sola.
- Pantalla Configuración con toggle para desactivar el autoplay.

### Changed
- Navegación principal: **una pestaña por curso** + Configuración (TabView nativo), sin sub-pestañas ni botones custom.
- Dentro de cada curso, un **Picker segmentado de bloques** (etiquetas "Bloque N") con el nombre completo debajo y **un solo carrusel** para el bloque elegido.
- Header del curso con portada, intro y progreso nativo.
- Miniaturas con prioridad: actual y siguientes del bloque → bloque siguiente → uno atrás → resto; mapa de posters persistido en UserDefaults.
- Botón "Eliminar caché" en Configuración.
- Header con imagen 580×326, título 40 pt, intro 26 pt (6 líneas) y contador de lecciones de 26 pt; barra con fondo gris oscuro para lo pendiente, 20 pt más arriba que antes y porcentaje al final.
- Logo Focusarte a 65 pt de alto, alineado arriba a la izquierda (offset -16).
- Progreso por capítulo: barra de 9 pt superpuesta al ras de la parte inferior del poster, en vez de debajo del título.
- Título del capítulo con 10 pt de margen izquierdo (el foco redondeado ya no recorta la primera letra) y marquee en loop cuando no entra, al enfocar.
- Perfil de Configuración estilo PatreonTV: círculo de 180 con inicial 72, email 29 pt y "FocusarteTV versión (build)" en una sola línea de 21 pt.
- Intro por curso desde `#section-product_body` (Historia y Thyssen tienen la suya) y sin el prefijo genérico del sitio.
- "Eliminar caché" muestra cuántos MB liberaría.
- Logo de Focusarte en la esquina superior izquierda, a la altura de las pestañas.
- Configuración con layout 1/3 + 2/3 estilo tvOS: perfil (inicial, correo, versión) y filas con título + explicación.
- Al abrir la app se selecciona la pestaña del último video reproducido y, dentro, su bloque y capítulo.
- Sin título duplicado ni email en el listado; el correo vive solo en Configuración.
- Up Next: la cuenta regresiva arranca a los 5 s del final.
- Al abrir un curso, el foco va a la primera lección sin completar (con scroll).
- La lección ya no reproduce sola: muestra el poster y un botón "Reproducir".
- La reproducción es a pantalla completa con `AVPlayerViewController` y vuelve al post al terminar.
- Play/Pause del control remoto sobre una fila abre el video directamente.
- "Reproducir" está en el header, a la derecha de "Vista"; la miniatura va arriba del título, centrada, y usa el `stillUrl` original de Kajabi.
- Cerrar sesión ahora borra todo lo local: cookies, contraseña, email y preferencias de reproducción (el progreso de las lecciones lo guarda Kajabi).
- Login: wordmark de Focusarte a 225 pt centrado verticalmente, etiquetas "Correo" y "Contraseña" a la izquierda, `TextField`/`SecureField` de SwiftUI con su apariencia nativa (sin fondo propio, tvOS ya dibuja el campo) y placeholders que el teclado muestra como subtítulo, versión de 14 pt abajo a la izquierda y botón "Iniciar sesión". El foco inicial va a Correo con `@FocusState`, sin abrir el teclado.
- AccentColor global en blanco: el teclado y los controles del sistema usan el tint nativo; el rojo de marca queda solo en `Theme.accent`.

### Fixed
- Aviso sutil en el login: el relleno automático de contraseñas no está disponible en tvOS, se sugiere copiar y pegar desde el iPhone. Explicación en `docs/login-autofill.md`.
- Login: los campos tienen placeholder ("Correo electrónico" y "Contraseña") para que el teclado de tvOS muestre qué campo se está editando, además de las etiquetas de la izquierda.
- Keychain: los ítems ahora son `AfterFirstUnlockThisDeviceOnly` (no salen del dispositivo), se guardan sin sincronizar con iCloud Keychain, con update en lugar de delete+add y `OSStatus` verificado.
- Cerrar sesión podía dejar cookies en Keychain si una escritura estaba en vuelo; ahora se invalida por generación de sesión.
- Ícono de la app: las capas Back del brand asset no tenían canal alfa y tvOS las descartaba, así que el ícono se veía blanco en el app switcher (solo quedaba el wordmark blanco sobre fondo blanco). Ahora exportan RGBA opaco.
- El refresco del curso podía leer progreso viejo antes de que terminara el reporte: ahora espera `progressRevision`.
- Después del auto-avance, el post y el foco siguen a la lección que realmente está sonando (`currentLessonKey`).
- El primer "Reproducir" abría un player vacío y perdía el foco: ahora el cover usa `fullScreenCover(item:)` con el player dentro del item.
- Play del control remoto sobre el botón "Reproducir" también inicia el video.
- Login: `URLSession` seguía los redirects por su cuenta y se perdían los `Set-Cookie` del `302` de login; la sesión quedaba sin cookie y volvía a `/login`. Ahora los redirects se resuelven a mano absorbiendo cookies en cada salto.
- La app no arrancaba en el Apple TV: faltaba `UIApplicationSceneManifest` y `UILaunchScreen` en el `Info.plist`.
- Arranque en tvOS 27: se eliminaron del enlace `PDFKit` y `_AVKit_SwiftUI` (PDFs con Core Graphics; video con `AVPlayerViewController`).
- Login devolvía "Email o contraseña incorrectos" con credenciales válidas: el header `Origin` se enviaba con barra final y Rails respondía 422 (CSRF).
- Controles de login nativos de tvOS (sin fondo/borde propios) y con `textContentType` para el autocompletado desde el iPhone.
- Diagnóstico visible cuando el login falla sin mensaje del servidor (`HTTP · ruta · título · form · remember`) y `Referer` como un navegador.
