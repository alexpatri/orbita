#!/usr/bin/env bash
# defpoll (10s) — bateria e tomada.
# Emite: {"pct":100,"status":"Full","plugged":true,"icon":""}

source "$(dirname "$0")/icons.sh"

# Descoberto pelo `type` do sysfs, e nao fixado em BAT1/ACAD: os nomes variam
# entre maquinas (BAT0 e o mais comum; esta usa BAT1) e o repo e publico.
BAT=""; AC=""
for d in /sys/class/power_supply/*; do
    case "$(cat "$d/type" 2>/dev/null)" in
        Battery) [[ -z "$BAT" ]] && BAT="$d" ;;
        Mains)   [[ -z "$AC"  ]] && AC="$d"  ;;
    esac
done

if [[ ! -d "$BAT" ]]; then
    printf '{"pct":0,"status":"Unknown","plugged":false,"icon":"%s"}\n' "$IC_BATTERY_FULL"
    exit 0
fi

pct=$(<"$BAT/capacity")
status=$(<"$BAT/status")

plugged=false
[[ "$(cat "$AC/online" 2>/dev/null)" == "1" ]] && plugged=true

if [[ "$status" == "Charging" ]]; then
    icon=$IC_BATTERY_CHARGING_FULL
elif ((pct >= 95)); then
    icon=$IC_BATTERY_FULL
else
    # Rampa de 0 a 6 barras conforme a carga.
    ramp=("$IC_BATTERY_0_BAR" "$IC_BATTERY_1_BAR" "$IC_BATTERY_2_BAR" "$IC_BATTERY_3_BAR"
          "$IC_BATTERY_4_BAR" "$IC_BATTERY_5_BAR" "$IC_BATTERY_6_BAR")
    idx=$((pct * 6 / 100))
    ((idx > 6)) && idx=6
    icon=${ramp[$idx]}
fi

printf '{"pct":%d,"status":"%s","plugged":%s,"icon":"%s"}\n' \
       "$pct" "$status" "$plugged" "$icon"
