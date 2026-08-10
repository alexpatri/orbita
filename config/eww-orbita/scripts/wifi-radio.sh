#!/usr/bin/env bash
# Liga/desliga o radio wifi a partir do interruptor do painel.
#
# O `nmcli radio wifi on|off` leva 0,10-0,29s (medido). O que parecia
# travamento era o defpoll de 10s da lista de redes: o interruptor so
# redesenhava no ciclo seguinte, ate 10s depois do clique.
#
# Ordem aqui: pinta primeiro, age depois, reconcilia no fim.
#   1. empurra o estado novo para a eww -> o interruptor mexe na hora
#   2. executa o nmcli
#   3. le o estado real e corrige, caso o comando tenha falhado
#   4. so entao recarrega a lista de redes, que e a parte cara (ate 8s de scan)

alvo=$1
[[ "$alvo" == "on" || "$alvo" == "off" ]] || { echo "uso: wifi-radio.sh {on|off}" >&2; exit 1; }

DIR="$(dirname "$0")"
EWW="$HOME/.local/bin/eww"
CFG="$HOME/.config/eww-orbita"
e() { "$EWW" --config "$CFG" "$@" >/dev/null 2>&1; }

[[ "$alvo" == "on" ]] && otimista=enabled || otimista=disabled
e update "radio=$otimista"

nmcli radio wifi "$alvo" >/dev/null 2>&1

e update "radio=$(nmcli radio wifi 2>/dev/null)"
e update "wifi=$("$DIR/wifi.sh")"
