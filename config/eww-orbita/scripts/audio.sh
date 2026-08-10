#!/usr/bin/env bash
# deflisten — volume do sink padrao, reagindo a eventos do PipeWire.
# Emite: {"pct":75,"muted":false,"icon":""}

source "$(dirname "$0")/icons.sh"

# C.UTF-8, e nao C: sob pt_BR o awk le "0.95" como 0 (espera virgula decimal),
# mas o C puro quebra a saida de texto acentuado — o notify-send falhava com
# "Invalid byte sequence". C.UTF-8 da as duas coisas: numero com ponto e UTF-8.
export LC_ALL=C.UTF-8

emit() {
    local raw pct muted icon
    raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)   # "Volume: 0.75 [MUTED]"
    if [[ -z "$raw" ]]; then
        printf '{"pct":0,"muted":true,"icon":"%s"}\n' "$IC_VOLUME_OFF"
        return
    fi

    pct=$(awk '{printf "%d", $2 * 100 + 0.5}' <<<"$raw")
    if [[ "$raw" == *MUTED* ]]; then
        muted=true
    else
        muted=false
    fi

    if [[ "$muted" == true ]] || ((pct == 0)); then
        icon=$IC_VOLUME_OFF
    elif ((pct < 50)); then
        icon=$IC_VOLUME_DOWN
    else
        icon=$IC_VOLUME_UP
    fi

    printf '{"pct":%d,"muted":%s,"icon":"%s"}\n' "$pct" "$muted" "$icon"
}

emit
# pactl subscribe cobre PipeWire via pipewire-pulse; filtra so o que mexe no sink.
pactl subscribe 2>/dev/null | grep --line-buffered -E "on (sink|server)" | while read -r _; do
    emit
done
