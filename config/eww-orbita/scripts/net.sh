#!/usr/bin/env bash
# deflisten (2s) — chip de rede da barra.
# Emite: {"icon":"","label":"casa_5G","down":"1,2 MB/s","up":"240 KB/s","up_ok":true}
#
# deflisten e nao defpoll: throughput e delta de bytes entre duas leituras.

source "$(dirname "$0")/icons.sh"

# C.UTF-8, e nao C: sob pt_BR o awk le "0.95" como 0 (espera virgula decimal),
# mas o C puro quebra a saida de texto acentuado — o notify-send falhava com
# "Invalid byte sequence". C.UTF-8 da as duas coisas: numero com ponto e UTF-8.
export LC_ALL=C.UTF-8
INTERVAL=2

# Formata bytes/s em pt-BR, mesma escala do protótipo (MB/s com uma decimal).
fmt_rate() {
    local b=$1
    if ((b >= 1048576)); then
        awk -v b="$b" 'BEGIN{printf "%.1f MB/s", b/1048576}' | tr '.' ','
    elif ((b >= 1024)); then
        awk -v b="$b" 'BEGIN{printf "%d KB/s", b/1024}'
    else
        printf '%d B/s' "$b"
    fi
}

read_bytes() {
    rx=$(cat "/sys/class/net/$1/statistics/rx_bytes" 2>/dev/null || echo 0)
    tx=$(cat "/sys/class/net/$1/statistics/tx_bytes" 2>/dev/null || echo 0)
}

prev_if=""
prev_rx=0
prev_tx=0

while :; do
    # Interface que realmente carrega o trafego de saida.
    iface=$(ip route get 1.1.1.1 2>/dev/null |
            awk '{for (i = 1; i <= NF; i++) if ($i == "dev") {print $(i+1); exit}}')

    if [[ -z "$iface" ]]; then
        printf '{"icon":"%s","label":"sem rede","down":"—","up":"—","up_ok":false}\n' "$IC_WIFI_OFF"
        prev_if=""
        sleep "$INTERVAL"
        continue
    fi

    if [[ -d "/sys/class/net/$iface/wireless" ]]; then
        icon=$IC_WIFI
        label=$(nmcli -t -f active,ssid dev wifi 2>/dev/null |
                awk -F: '$1 == "sim" || $1 == "yes" {print $2; exit}')
        [[ -z "$label" ]] && label=$(iw dev "$iface" link 2>/dev/null |
                                    awk '/SSID:/{$1=""; sub(/^ /,""); print; exit}')
        [[ -z "$label" ]] && label=$iface
    else
        icon=$IC_LAN
        label=$iface
    fi

    read_bytes "$iface"
    if [[ "$iface" == "$prev_if" ]]; then
        d=$(((rx - prev_rx) / INTERVAL))
        u=$(((tx - prev_tx) / INTERVAL))
        ((d < 0)) && d=0
        ((u < 0)) && u=0
        down=$(fmt_rate "$d")
        up=$(fmt_rate "$u")
    else
        # Primeiro ciclo nesta interface: sem base de comparacao ainda.
        down="0 B/s"
        up="0 B/s"
    fi
    prev_if=$iface
    prev_rx=$rx
    prev_tx=$tx

    printf '{"icon":"%s","label":"%s","down":"%s","up":"%s","up_ok":true}\n' \
           "$icon" "$label" "$down" "$up"

    sleep "$INTERVAL"
done
