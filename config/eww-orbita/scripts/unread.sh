#!/usr/bin/env bash
# defpoll (5s) — quantas notificacoes chegaram depois da ultima vez que o
# painel foi aberto. E o que acende o ponto ambar do relogio.
#
# Substitui o provisorio `dunstctl count displayed + waiting`, que so acendia
# enquanto o toast estava na tela. Agora usa o historico persistido e o mesmo
# marcador do cartao de Notificacoes, entao o ponto apaga ao abrir o painel,
# como o design pede.
#
# O timestamp do dunst e monotonico desde o boot, em microssegundos — daí a
# soma do instante do boot antes de comparar.

export LC_ALL=C.UTF-8
lidas=$(cat "$HOME/.cache/eww-orbita/notif-lidas" 2>/dev/null || echo 0)
boot=$(awk -v n="$(date +%s)" '{printf "%d", n - $1}' /proc/uptime)

hist=$(dunstctl history 2>/dev/null |
       jq --argjson b "$boot" --argjson l "$lidas" \
          '[.data[0][]? | select(($b + (.timestamp.data / 1000000)) > $l)] | length' 2>/dev/null)

# Toast ainda na tela tambem conta: ele nem chegou ao historico.
na_tela=$(dunstctl count displayed 2>/dev/null || echo 0)

echo $(( ${hist:-0} + ${na_tela:-0} ))
