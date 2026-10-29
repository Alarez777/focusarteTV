# AGENTS.md — FocusarteTV

Guía para agentes de IA (y humanos) que trabajen en este repo. Leer antes de tocar código.

## Qué es esto

Cliente nativo de tvOS para Focusarte. No hay backend propio ni credenciales en el repo.
La app inicia sesión contra `www.focusarte.com` (Kajabi), parsea HTML server-rendered,
resuelve los videos de Wistia a HLS y reporta progreso a los endpoints de Kajabi.

El protocolo completo y verificado está en [`docs/kajabi-protocol.md`](docs/kajabi-protocol.md).
**Leerlo antes de modificar la capa de red o de parseo.**

## Entorno

- **No hay Mac.** El proyecto se compila en GitHub Actions (`macos-15`) y el `.ipa` sin
  firmar se descarga con `scripts/fetch-ipa.sh`.
- El proyecto Xcode se genera con **XcodeGen** desde `apps/tvos/project.yml`.
  **No commitear `.xcodeproj`.**
- El núcleo (`apps/tvos/FocusarteCore`) es un Swift Package solo-Foundation: se compila y
  testea en Linux con Docker, sin esperar al CI.

```bash
# tests del núcleo, rápido y local
docker run --rm -v "$PWD/apps/tvos/FocusarteCore:/pkg" -w /pkg swift:6.2 swift test
```

## Estructura

```
apps/tvos/
  project.yml              # fuente de verdad del proyecto Xcode
  FocusarteCore/           # Swift Package testeable en Linux (red, parseo, modelos)
  FocusarteTV/Sources/     # app SwiftUI (UI, AVPlayer, PDFKit)
.github/workflows/         # build + IPA + release
scripts/fetch-ipa.sh       # artifact → carpeta local de sideloading
docs/                      # protocolo y notas
```

Mantener la lógica fuera de las vistas: si algo se puede testear sin UIKit/SwiftUI,
va en `FocusarteCore`.

## Reglas

1. **Nunca commitear credenciales, cookies ni HTML de la cuenta.** Los fixtures se
   anonimizan: fuera `remember_member_token`, `_kjb_session`, `X-CSRF-Token`, el JWT de
   progreso y cualquier dato del miembro (nombre, avatar, id).
2. **No hay WebKit en tvOS.** El HTML de las lecciones se renderiza con un conversor
   propio; no intentar `WKWebView` ni `NSAttributedString(html:)`.
3. **Los videos son HLS efímeros.** Resolver la URL en el momento de reproducir; no
   persistirla en disco.
4. **Sesión:** `_kjb_session` dura ~1 día. Ante `302 → /login` o `401`, re-loguear en
   silencio con las credenciales de Keychain.
5. **CSRF obligatorio** en los POST de tracking: header `X-CSRF-Token` leído del
   `<meta name="csrf-token">` de cualquier página autenticada.
6. **Parseo frágil por diseño.** Aislar selectores en `KajabiParsers` y cubrirlos con
   tests sobre fixtures. Si Kajabi cambia el markup, se arregla ahí y nada más.
7. **Sin Ruby** en el proyecto (nada de `xcodeproj` gem). XcodeGen o Swift.
8. **Commits en español o inglés, pero consistentes.** Mensajes en imperativo.
9. **CHANGELOG sin wraps.** Una entrada por línea; no cortar el texto a mano,
   el visor hace el wrap.

## Flujo de ramas

- `main` — releases. Se actualiza desde `develop` al publicar y se etiqueta con `vX.Y.Z`.
- `develop` — integración. Cada push compila un IPA.
- **Desde v1.0.0, ningún cambio de la app va directo a `develop`.** Cada cambio se hace
  en su propia rama (`feature/…`, `fix/…`), se compila su IPA y se prueba en el Apple TV.
  Se mergea a `develop` recién cuando el usuario confirma que funciona.
- Los cambios de documentación o CI que no tocan la app pueden ir directo a `develop`.
- Release: tag `vX.Y.Z` sobre `main` → el workflow valida que coincida con
  `MARKETING_VERSION` y publica el IPA en el release con las notas de `CHANGELOG.md`.

## Versionado

`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` viven en `apps/tvos/project.yml`.
El workflow de release valida que el tag coincida con `MARKETING_VERSION` y usa la
sección correspondiente de `CHANGELOG.md` como notas.
