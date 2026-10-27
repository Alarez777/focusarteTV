# FocusarteTV

Cliente nativo de tvOS para [Focusarte](https://www.focusarte.com) (Historia del Arte Clásico).

La web de Focusarte corre sobre **Kajabi** y es server-rendered. La app no usa un backend
propio: habla HTTP directamente contra el sitio con la sesión del miembro, parsea el HTML,
resuelve los videos de Wistia a HLS y reporta el progreso a los endpoints de Kajabi.

## Estado

Scaffold inicial. Todavía no hay login ni contenido.

## Requisitos

- Apple TV 4K (2022) o cualquier equipo con tvOS 17+
- No hace falta Mac para compilar: el `.ipa` se genera en GitHub Actions
- Para probar el núcleo en local: Docker (`swift:6.2`)

## Compilar

El proyecto Xcode **no se versiona**: se genera en CI con XcodeGen.

```bash
cd apps/tvos
xcodegen generate
xcodebuild -project FocusarteTV.xcodeproj -scheme FocusarteTV \
  -configuration Release -destination 'generic/platform=tvOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

## Obtener el IPA

Cada push a `develop` compila un `.ipa` sin firmar y lo publica como artifact.
Para bajarlo a la carpeta de sideloading:

```bash
./scripts/fetch-ipa.sh            # último build de develop
./scripts/fetch-ipa.sh main       # último build de main
```

Destino por defecto: `~/Descargas/ABDM/Movil` (override con `FOCUSARTE_IPA_DIR`).

## Documentación

- [`docs/kajabi-protocol.md`](docs/kajabi-protocol.md) — protocolo real de Focusarte/Kajabi
  (login, sesión, parseo, video, progreso)
- [`AGENTS.md`](AGENTS.md) — convenciones para trabajar en el repo
