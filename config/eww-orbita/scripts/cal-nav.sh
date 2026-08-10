#!/usr/bin/env bash
# Navegacao de mes do calendario.
#   cal-nav.sh prev | next | reset
#
# O offset vive num ARQUIVO, e nao numa variavel da eww, porque o comando de
# um `defpoll` e uma string estatica — ele nao consegue interpolar variavel
# ("Tried to reference variable, but we cannot access variables here").
# O clique atualiza o arquivo e ja empurra o resultado, sem esperar o poll.

ARQ="$HOME/.cache/eww-orbita/cal-off"
DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$(dirname "$ARQ")"
off=$(cat "$ARQ" 2>/dev/null || echo 0)
[[ "$off" =~ ^-?[0-9]+$ ]] || off=0

case "$1" in
    prev)  off=$((off - 1)) ;;
    next)  off=$((off + 1)) ;;
    reset) off=0 ;;
esac
echo "$off" > "$ARQ"

# `reset` NAO recarrega: ele so roda no momento em que o painel esta abrindo, e
# o defpoll com :run-while ja busca o calendario nesse instante. Recarregar aqui
# somava ~420ms ao handler do clique do relogio, que entao estourava o tempo e
# nem chegava a abrir o painel.
[[ "$1" == "reset" ]] && exit 0

"$HOME/.local/bin/eww" --config "$HOME/.config/eww-orbita" \
    update "calendario=$("$DIR/calendario.sh")" >/dev/null 2>&1
