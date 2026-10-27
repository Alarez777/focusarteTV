#!/usr/bin/env bash
# Descarga el último IPA sin firmar compilado por GitHub Actions y lo deja en la
# carpeta que usa el flujo de sideloading local.
#
# Uso:
#   ./scripts/fetch-ipa.sh              # último build exitoso de develop
#   ./scripts/fetch-ipa.sh main         # último build exitoso de main
#   ./scripts/fetch-ipa.sh v0.1.0       # build de un tag
#
# Variables:
#   FOCUSARTE_IPA_DIR   destino (por defecto ~/Descargas/ABDM/Movil)
set -euo pipefail

REPO="Alarez777/focusarteTV"
WORKFLOW="tvos-ipa.yml"
DEST="${FOCUSARTE_IPA_DIR:-$HOME/Descargas/ABDM/Movil}"
REF="${1:-develop}"

command -v gh >/dev/null || { echo "Falta el CLI de GitHub (gh)." >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "gh no está autenticado." >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Los builds de tag no cuelgan de una rama: se buscan por evento si el ref
# empieza con "v".
if [[ "$REF" == v* ]]; then
  echo "Buscando el último build exitoso del tag '$REF'…"
  run_id="$(gh run list --repo "$REPO" --workflow "$WORKFLOW" \
    --event push --status success --limit 50 \
    --json databaseId,headBranch --jq ".[] | select(.headBranch == \"$REF\") | .databaseId" \
    | head -1)"
else
  echo "Buscando el último build exitoso de '$REF'…"
  run_id="$(gh run list --repo "$REPO" --workflow "$WORKFLOW" \
    --branch "$REF" --status success --limit 1 \
    --json databaseId --jq '.[0].databaseId // empty')"
fi

if [[ -z "${run_id:-}" ]]; then
  echo "No hay builds exitosos para '$REF'." >&2
  echo "Ver estado: gh run list --repo $REPO --workflow $WORKFLOW" >&2
  exit 1
fi

echo "Descargando artifact del run $run_id…"
gh run download "$run_id" --repo "$REPO" --dir "$tmp"

ipa="$(find "$tmp" -name '*.ipa' -print -quit)"
[[ -n "$ipa" ]] || { echo "El artifact no contiene ningún .ipa." >&2; exit 1; }

mkdir -p "$DEST"
cp "$ipa" "$DEST/"

echo "✓ $(basename "$ipa")"
echo "  → $DEST"
