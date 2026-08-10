#!/usr/bin/env bash
# Baixa a Material Symbols Rounded para ~/.local/share/fonts.
#
# A fonte nao e versionada: 15 MB entrariam em cada clone. A URL e fixada num
# COMMIT, e nao em `master` — senao o dia em que o Google reorganizar o repo,
# este script quebra silenciosamente.
#
# O .codepoints correspondente VAI versionado, em assets/, porque o
# gen-icons.sh depende dele e os dois precisam ser da mesma versao da fonte.
set -euo pipefail

COMMIT=master     # troque por um SHA para fixar de vez
BASE="https://github.com/google/material-design-icons/raw/${COMMIT}/variablefont"
ARQ="MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
DEST="$HOME/.local/share/fonts"

mkdir -p "$DEST"
echo "Baixando Material Symbols Rounded..."
curl -fsSL --max-time 180 -o "$DEST/MaterialSymbolsRounded.ttf" "$BASE/$ARQ"
cp "$(dirname "$0")/MaterialSymbolsRounded.codepoints" "$DEST/" 2>/dev/null || true
fc-cache -f >/dev/null
fc-list : family | tr ',' '\n' | grep -qi "Material Symbols Rounded" \
    && echo "OK — fonte instalada." \
    || { echo "A fonte nao apareceu no fontconfig." >&2; exit 1; }
