#!/usr/bin/env bash
# deflisten — titulo da midia (modulo central da barra), via MPRIS.
# Emite: {"active":true,"status":"Playing","text":"Boards of Canada — Dayvan Cowboy"}

idle() {
    printf '{"active":false,"status":"Stopped","text":"nada tocando"}\n'
}

if ! command -v playerctl >/dev/null 2>&1; then
    idle
    exit 0
fi

idle

while :; do
    # --follow emite uma linha a cada mudanca de metadado ou de status.
    # Sai quando o ultimo player some; o laco externo espera um novo aparecer.
    playerctl --follow metadata \
              --format '{{status}}'$'\x1f''{{artist}}'$'\x1f''{{title}}' 2>/dev/null |
    while IFS=$'\x1f' read -r status artist title; do
        if [[ -z "$title" && -z "$artist" ]]; then
            idle
            continue
        fi
        if [[ -n "$artist" && -n "$title" ]]; then
            text="$artist — $title"
        else
            text="${artist}${title}"
        fi
        # jq -R faz o escape de JSON de aspas/barras no nome da faixa.
        printf '%s' "$text" |
            jq -Rc --arg st "${status:-Playing}" '{active:true, status:$st, text:.}'
    done

    idle
    sleep 2
done
