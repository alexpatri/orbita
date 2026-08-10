#!/usr/bin/env bash
# defpoll (5s) — os tres icones do tray da barra.
# Emite: {"bt":true,"bt_icon":"","vpn":true}
#
# bt  = adaptador ligado (bluetoothctl)
# vpn = malha tailscale ativa  -> icone shield
#
# O cloud_sync do protótipo foi removido da barra: nao havia fonte de dado real.

source "$(dirname "$0")/icons.sh"

bt=false
if command -v bluetoothctl >/dev/null 2>&1; then
    bluetoothctl show 2>/dev/null | grep -q "Powered: yes" && bt=true
fi
if [[ "$bt" == true ]]; then
    bt_icon=$IC_BLUETOOTH
else
    bt_icon=$IC_BLUETOOTH_DISABLED
fi

vpn=false
if command -v tailscale >/dev/null 2>&1; then
    [[ "$(tailscale status --json 2>/dev/null | jq -r '.BackendState' 2>/dev/null)" == "Running" ]] && vpn=true
fi

printf '{"bt":%s,"bt_icon":"%s","vpn":%s}\n' "$bt" "$bt_icon" "$vpn"
