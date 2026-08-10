#!/usr/bin/env bash
# deflisten — desktops do bspwm no monitor focado.
# Emite: [{"name":"1","focused":true,"occupied":false,"urgent":false}, ...]

emit() {
    local mon focused out first d id occupied urgent is_focused
    mon=$(bspc query -M -m focused)
    focused=$(bspc query -D -d focused --names)
    out="["
    first=1
    for d in $(bspc query -D -m "$mon" --names); do
        occupied=false
        urgent=false
        is_focused=false
        [[ "$d" == "$focused" ]] && is_focused=true
        [[ -n "$(bspc query -N -d "$d" -n .window 2>/dev/null)" ]] && occupied=true
        [[ -n "$(bspc query -N -d "$d" -n .urgent 2>/dev/null)" ]] && urgent=true
        [[ $first -eq 0 ]] && out+=","
        out+="{\"name\":\"$d\",\"focused\":$is_focused,\"occupied\":$occupied,\"urgent\":$urgent}"
        first=0
    done
    echo "$out]"
}

emit
bspc subscribe report node_add node_remove node_transfer \
     desktop_focus desktop_add desktop_remove node_flag | while read -r _; do
    emit
done
