# FocusarteTV

> **Proyecto no oficial.** FocusarteTV no está afiliado, asociado ni respaldado por
> Focusarte ni por Kajabi. Es un cliente independiente hecho para uso personal.
> “Focusarte”, su contenido y sus marcas pertenecen a sus respectivos dueños.

Cliente nativo de tvOS para [Focusarte](https://www.focusarte.com) (Historia del Arte
Clásico).

La web de Focusarte corre sobre **Kajabi** y es server-rendered. La app no usa un backend
propio: habla HTTP directamente contra el sitio con la sesión del miembro, parsea el HTML,
resuelve los videos de Wistia a HLS y reporta el progreso a los endpoints de Kajabi.

## Estado

App funcional, en desarrollo activo:

- Login contra focusarte.com con Keychain y re-login silencioso.
- Biblioteca con una pestaña por curso: bloques, carrusel de lecciones y progreso.
- Reproducción HLS a pantalla completa con PiP, autoplay y tarjeta Up Next.
- Foco que sigue la lección actual y recuerda la posición de cada bloque.
- Visor de PDFs a pantalla completa para las descargas de cada lección (Core Graphics,
  sin PDFKit): se abre desde el botón de descarga y Menú vuelve al post.
- Cache de imágenes y precarga de miniaturas de todo el curso en segundo plano.

### Limitaciones conocidas

- El **relleno automático de contraseñas** de tvOS no entrega credenciales a esta app
  porque falta la asociación de dominio (`apple-app-site-association` en focusarte.com) y
  el `.ipa` se distribuye sin firmar. Hay que copiar y pegar desde el iPhone. Detalle en
  [`docs/login-autofill.md`](docs/login-autofill.md).
- Las credenciales se guardan en el Keychain privado de la app (solo este dispositivo)
  para poder re-loguear en silencio cuando expira la sesión de Kajabi.

## Requisitos

- Apple TV 4K (2022) o cualquier equipo con tvOS 17+
- No hace falta Mac para compilar: el `.ipa` se genera en GitHub Actions
- Para probar el núcleo en local: Docker (`swift:6.2`)

## Compilar

El proyecto Xcode **no se versiona**: `apps/tvos/project.yml` es la fuente de verdad y
XcodeGen genera el proyecto.

En CI, cada push a `develop` compila y publica un `.ipa` sin firmar. En local, si tenés un
Mac:

```bash
cd apps/tvos
xcodegen generate
xcodebuild -project FocusarteTV.xcodeproj -scheme FocusarteTV \
  -configuration Release -destination 'generic/platform=tvOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO archive \
  -archivePath build/FocusarteTV.xcarchive
```

Los tests del núcleo corren sin Mac:

```bash
docker run --rm -v "$PWD/apps/tvos/FocusarteCore:/pkg" -w /pkg swift:6.2 swift test
```

## Obtener el IPA

Cada push a `develop` compila un `.ipa` sin firmar y lo publica como artifact.
Para bajarlo a la carpeta de sideloading:

```bash
./scripts/fetch-ipa.sh          # último build exitoso de develop
./scripts/fetch-ipa.sh main     # último build exitoso de main
```

También acepta un tag (`./scripts/fetch-ipa.sh v0.1.0`).

Destino por defecto: `~/Descargas/ABDM/Movil` (override con `FOCUSARTE_IPA_DIR`).

## Documentación

- [`docs/kajabi-protocol.md`](docs/kajabi-protocol.md) — protocolo real de Focusarte/Kajabi
  (login, sesión, parseo, video, progreso)
- [`docs/login-autofill.md`](docs/login-autofill.md) — por qué el relleno automático de
  contraseñas no funciona y qué haría falta
- [`AGENTS.md`](AGENTS.md) — convenciones para trabajar en el repo
