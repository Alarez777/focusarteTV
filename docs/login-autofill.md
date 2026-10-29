# Relleno automático de contraseñas en tvOS

Estado: **no funciona y no se puede arreglar desde la app**.

## Qué falta

Para que tvOS entregue a la app una credencial guardada en el iPhone (Apple
Passwords o un gestor de terceros) hacen falta **dos** cosas:

1. **Asociación de dominio.** El sitio debe publicar
   `https://<dominio>/.well-known/apple-app-site-association` con una sección
   `webcredentials` que liste el App ID de la app:

   ```json
   { "webcredentials": { "apps": ["TEAMID.com.focusartetv.FocusarteTV"] } }
   ```

2. **App firmada con ese Team ID** y el entitlement
   `com.apple.developer.associated-domains` con `webcredentials:www.focusarte.com`.

## Estado actual

- `https://www.focusarte.com/.well-known/apple-app-site-association` responde
  **404**: Kajabi no publica el archivo y no está bajo nuestro control.
- El `.ipa` se distribuye **sin firmar**, así que no lleva Team ID ni
  entitlements efectivos.

Por eso el iPhone muestra la credencial (el picker aparece), pero al elegirla
no se escribe nada en el Apple TV. Se probó con Apple Passwords y con un gestor
de terceros: falla en ambos casos.

## Qué sí está implementado

- `LoginView` usa `TextField`/`SecureField` con `.textContentType(.username)` y
  `.textContentType(.password)`, que es lo que Apple documenta.
- Las sugerencias de correo que aparecen en el teclado de tvOS son del sistema
  (correos ya usados), no de la app.

## Alternativa

Copiar la contraseña desde el gestor en el iPhone y pegarla con el teclado del
iPhone (app Remote). El login muestra ese aviso.
