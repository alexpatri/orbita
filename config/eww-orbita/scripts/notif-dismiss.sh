#!/usr/bin/env bash
# Dispensa UMA notificacao do painel, pelo clique nela.
#
# O dunst nao oferece apagar um item do historico — `history-clear` apaga tudo
# e `history-pop` devolve para a tela. Entao o descarte individual e nosso: o
# ID vai para uma lista de ocultas que o notif.sh filtra.
#
# A lista e podada a cada uso, mantendo so IDs que ainda existem no historico.
# Sem isso ela cresceria para sempre e, pior, IDs reciclados depois de um
# restart do dunst poderiam esconder notificacoes novas.

id="$1"
[[ "$id" =~ ^[0-9]+$ ]] || exit 1

DIR="$(cd "$(dirname "$0")" && pwd)"
OCULTAS="$HOME/.cache/eww-orbita/notif-ocultas"
mkdir -p "$(dirname "$OCULTAS")"

vivos=$(dunstctl history 2>/dev/null | jq -r '.data[0][]?.id.data' 2>/dev/null)
{ echo "$id"; cat "$OCULTAS" 2>/dev/null; } |
    grep -xF "${vivos:-}" 2>/dev/null | sort -un > "$OCULTAS.tmp"
grep -qxF "$id" "$OCULTAS.tmp" 2>/dev/null || echo "$id" >> "$OCULTAS.tmp"
sort -un "$OCULTAS.tmp" > "$OCULTAS"; rm -f "$OCULTAS.tmp"

exec "$DIR/notif-refresh.sh"
