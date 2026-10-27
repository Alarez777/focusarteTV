#!/usr/bin/env bash
# Lanza la app en un simulador de tvOS ya booteado y detecta si crashea.
#
# Uso: scripts/sim-smoke.sh <ruta-al-.app> <UDID> [directorio-salida]
set -uo pipefail

APP="${1:?falta la ruta al .app}"
UDID="${2:?falta el UDID del simulador}"
OUT="${3:-build}"
BUNDLE_ID="com.focusartetv.FocusarteTV"
WAIT_SECONDS="${WAIT_SECONDS:-45}"

mkdir -p "$OUT"

echo "== Install =="
xcrun simctl install "$UDID" "$APP"
echo "install_exit=$?"

echo "== Launch (console) =="
# --console-pty se queda adjunto al proceso; si la app crashea, simctl termina.
xcrun simctl launch --console-pty --terminate-running-process "$UDID" "$BUNDLE_ID" \
  > "$OUT/sim-run.log" 2>&1 &
LAUNCH_PID=$!

for _ in $(seq 1 "$WAIT_SECONDS"); do
  kill -0 "$LAUNCH_PID" 2>/dev/null || break
  sleep 1
done

sleep 2
xcrun simctl io "$UDID" screenshot "$OUT/sim-shot.png" >/dev/null 2>&1 || true

STATE="desconocido"
if kill -0 "$LAUNCH_PID" 2>/dev/null; then
  STATE="viva"
  echo "== La app sigue viva después de ${WAIT_SECONDS}s: NO crasheó =="
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  kill "$LAUNCH_PID" 2>/dev/null || true
else
  STATE="terminada"
  wait "$LAUNCH_PID" 2>/dev/null
  echo "== El proceso de launch terminó (código $?): probable crash o salida =="
fi

echo "== Console de la app =="
cat "$OUT/sim-run.log" 2>/dev/null || true

echo "== launchctl =="
xcrun simctl spawn "$UDID" launchctl list 2>/dev/null | grep -i focusarte || echo "(no está corriendo)"

echo "== Diagnósticos del simulador =="
for dir in "$HOME/Library/Logs/DiagnosticReports" "$HOME/Library/Logs/CoreSimulator/$UDID"; do
  [ -d "$dir" ] || continue
  find "$dir" -type f -name '*Focusarte*' -newermt '-15 minutes' -print -exec cat {} \; 2>/dev/null
done

echo "STATE=$STATE"
