#!/usr/bin/env bash
# deflisten (2s) — chip de sistema da barra.
# Emite: {"cpu":32,"mem":"7,8 GB","temp":62}
#
# E deflisten e nao defpoll porque o percentual de CPU exige o delta entre duas
# leituras de /proc/stat — precisa guardar a leitura anterior entre os ciclos.

# C.UTF-8, e nao C: sob pt_BR o awk le "0.95" como 0 (espera virgula decimal),
# mas o C puro quebra a saida de texto acentuado — o notify-send falhava com
# "Invalid byte sequence". C.UTF-8 da as duas coisas: numero com ponto e UTF-8.
export LC_ALL=C.UTF-8

INTERVAL=2

# Zona termica do pacote da CPU; cai para a primeira zona se nao existir.
ZONE=""
for z in /sys/class/thermal/thermal_zone*; do
    if [[ "$(cat "$z/type" 2>/dev/null)" == "x86_pkg_temp" ]]; then
        ZONE="$z/temp"
        break
    fi
done
[[ -z "$ZONE" ]] && ZONE=/sys/class/thermal/thermal_zone0/temp

read_cpu() {
    local _ u n s i w irq sirq st
    read -r _ u n s i w irq sirq st _ < /proc/stat
    total=$((u + n + s + i + w + irq + sirq + st))
    idle=$((i + w))
}

# Primeira leitura so alimenta o delta — sem ela o primeiro valor seria a media
# de CPU desde o boot, nao o uso instantaneo.
read_cpu
prev_total=$total
prev_idle=$idle

while :; do
    sleep "$INTERVAL"

    read_cpu
    dt=$((total - prev_total))
    di=$((idle - prev_idle))
    if ((dt > 0)); then
        cpu=$(((100 * (dt - di) + dt / 2) / dt))
    else
        cpu=0
    fi
    prev_total=$total
    prev_idle=$idle

    # Usada = MemTotal - MemAvailable, em GB com virgula decimal (pt-BR).
    mem=$(awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{printf "%.1f", (t-a)/1048576}' \
          /proc/meminfo | tr '.' ',')

    temp=$(($(cat "$ZONE" 2>/dev/null || echo 0) / 1000))

    printf '{"cpu":%d,"mem":"%s GB","temp":%d}\n' "$cpu" "$mem" "$temp"
done
