# Protocolo de Focusarte / Kajabi

Notas verificadas contra el sitio real (cuenta de miembro activa) el 2026-10-26.
Todo lo de acá se probó con `curl`/Python, sin navegador.

> **Privacidad:** este documento no incluye cookies, tokens ni datos de la cuenta.

## Resumen

Focusarte corre sobre **Kajabi**, server-rendered:

- No hay SPA ni API JSON para la web del miembro.
- La web usa formularios Rails clásicos + Turbo.
- Los videos son **Wistia**, resueltos a **HLS sin DRM**.
- El progreso se reporta con JWT por lección a `/tracking/*`.

Sitio: `https://www.focusarte.com` · `site_id = 2147585745`

## 1. Login y sesión

```http
GET  /login                     → formulario + <meta name="csrf-token">
POST /login                     Content-Type: application/x-www-form-urlencoded

authenticity_token=<token>
member[email]=<email>
member[password]=<password>
member[remember_me]=1
```

> **Ojo con `Origin`:** Rails valida el origen si el header está presente. Mandar
> `Origin: https://www.focusarte.com/` (con barra final) devuelve **422 CSRF inválido**
> aunque el token sea correcto. El valor válido es `scheme://host[:port]` sin barra.

> **Ojo con los redirects:** el login exitoso responde `302` y las cookies de sesión
> (`_kjb_session`, `remember_member_token`) vienen en **ese** `Set-Cookie`. Si el cliente
> HTTP sigue el redirect automáticamente (como hace `URLSession` por defecto), pierde
> esas cookies y el request siguiente vuelve a `/login`. Hay que seguir los redirects
> a mano, absorbiendo cookies en cada salto.

Respuesta correcta: `302` al destino + cookies. Credenciales inválidas: `200` con
`Inválido correo electrónico o contraseña.`

Cookies relevantes:

| Cookie | Vida | Uso |
|---|---|---|
| `_kjb_session` | ~1 día | sesión activa |
| `remember_member_token` | ~2 semanas (rolling) | re-login automático |
| `_csrf_token` | 1 año | CSRF |
| `__cf_bm`, `AWSALB*` | corto | Cloudflare / balanceo |

Con `_kjb_session` alcanza para todas las requests. Guardar credenciales en Keychain y
re-loguear cuando el sitio devuelva `302 → /login`.

## 2. Biblioteca y estructura del curso

```http
GET /library
```

Devuelve las tarjetas de cursos. Los productos enlazan a `/products/{slug}`:

- `historia-del-arte-clasico` — 9 bloques, 97 lecciones
- `recorridos-por-el-thyssen` — 2 bloques, 8 lecciones

```http
GET /products/{slug}
```

El outline completo viene en el HTML:

```html
<h3 class="product-outline-category">
  <a href="/products/{slug}/categories/{category_id}">Bloque 1 …</a>
</h3>

<a href="/products/{slug}/categories/{cid}/posts/{post_id}"
   class="product-outline-post">
  <div class="progress-icon progress-icon-100">   <!-- 100 = completa, si no el % -->
  <div class="media-body">Título de la lección</div>
</a>
```

Notas:

- El tipo de contenido **no** está en el outline. Se descubre al pedir la lección.
- `progress-icon-{n}` da el porcentaje visto (0-100).
- El header muestra `NN% COMPLETADO` por producto.

## 3. Lección

```http
GET /products/{slug}/categories/{cid}/posts/{pid}
```

Contenido dentro de `.post-body`. Puede combinar varios tipos:

| Tipo | Cómo se detecta |
|---|---|
| Video | `wistia_async_{mediaId}` en el HTML |
| Texto | HTML en `.post-body` (p, strong, em, ul, img, hr) |
| PDF/descarga | `href` a `/courses/downloads/{fileId}/{nombre}` |
| Audio | contenedor `.audio` (no observado en Focusarte) |

Elementos de control:

```html
<div id="wistia_03929lqadx"
     class="wistia_embed wistia_async_03929lqadx"
     data-track-progress="<JWT>"
     data-tracked-percent="2"></div>

<a data-post-completion-toggle="true"
   data-token="<JWT>"
   data-complete-text="Completar lección"
   data-incomplete-text="¡Lección completa!">
```

El JWT (`HS256`) codifica `{actor_type, actor_id, product_id, post_id}` y **viene en la
página**, así que no hay que generarlo: se re-parsea junto con la lección.

## 4. Video (Wistia)

```http
GET https://fast.wistia.com/embed/medias/{mediaId}.json     # público, sin cookies
```

Devuelve `media.assets[]` con MP4 (224p→1080p), `still_image`, `storyboard` y
`media.hls_enabled`. El master HLS:

```http
GET https://fast.wistia.com/embed/medias/{mediaId}.m3u8
```

- 5 renditions (224p, 360p, 540p, 720p, **1080p**).
- **Sin `EXT-X-KEY`**: no hay cifrado ni DRM.
- `media.protected == false`, `media.duration` en segundos.

`sitll_image` sirve como poster. Si en el futuro un video devuelve `protected: true`,
mandar `Referer: https://www.focusarte.com/` y caer al MP4 de `assets`.

## 5. Progreso

```http
POST /tracking/completion
X-CSRF-Token: <meta csrf-token>
Content-Type: application/x-www-form-urlencoded

token=<JWT>                         # marcar completa
token=<JWT>&_method=DELETE          # desmarcar
```

```http
POST /tracking/progress
X-CSRF-Token: <meta csrf-token>
Content-Type: application/x-www-form-urlencoded

token=<JWT>&progress_seconds=<n>&progress_percent=<p>
```

Reglas del player web (a replicar):

- Auto-completa al **≥ 90 %** de la duración.
- Solo reporta progreso si el porcentaje **supera** el ya guardado.
- El servidor solo expone `data-tracked-percent` (no los segundos), así que la posición
  exacta de reanudación hay que guardarla local (o estimar `percent × duration`).

## 6. PDFs

```http
GET /courses/downloads/{fileId}/{slug}   # con cookie → application/pdf
                                        # sin cookie → 302 /login
```

Tamaño de muestra: 1.1 MB, 8 páginas. Descargar a `Caches`, mostrar con PDFKit y borrar
al salir.

## 7. Lo que NO se usa

`https://app.kajabi.com/api/v1/*` (JSON:API del app móvil oficial) existe y responde
`401`, pero:

- `app.kajabi.com/login` devuelve **403** a clientes que no son la app.
- No hay endpoint de login JSON descubrible (`customer_sessions`, `sessions`, `tokens`,
  `oauth/token`, `login`, `auth` → `404`).
- Requeriría ingeniería inversa del binario iOS.

Por eso la app usa HTML scraping, que es estable y no depende de la app móvil.
