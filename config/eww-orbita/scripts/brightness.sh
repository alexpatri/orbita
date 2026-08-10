#!/usr/bin/env bash
# defpoll (1s) — brilho da tela.
# Emite: {"pct":95,"icon":""}
#
# Le direto do sysfs em vez de chamar `brightnessctl`: e um fork a menos por
# ciclo, e o valor e o mesmo. `actual_brightness` (e nao `brightness`) reflete
# o que o hardware realmente aplicou.

source "$(dirname "$0")/icons.sh"

BL=""
for d in /sys/class/backlight/*; do
    [[ -r "$d/actual_brightness" ]] && { BL="$d"; break; }
done

if [[ -z "$BL" ]]; then
    printf '{"pct":0,"icon":"%s"}\n' "$IC_BRIGHTNESS_LOW"
    exit 0
fi

cur=$(<"$BL/actual_brightness")
max=$(<"$BL/max_brightness")
((max > 0)) || max=1
pct=$(( (cur * 100 + max / 2) / max ))

if   ((pct < 34)); then icon=$IC_BRIGHTNESS_LOW
elif ((pct < 67)); then icon=$IC_BRIGHTNESS_MEDIUM
else                    icon=$IC_BRIGHTNESS_HIGH
fi

printf '{"pct":%d,"icon":"%s"}\n' "$pct" "$icon"
