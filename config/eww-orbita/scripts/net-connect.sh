#!/usr/bin/env bash
# Conecta a uma rede wifi pelo SSID. Chamado ao clicar numa linha do painel.
#
# Rede salva ou aberta conecta direto. Rede nova com senha nao tem como: o
# painel nao tem campo de texto, entao o nmcli falha e o usuario recebe um
# toast dizendo o porque, em vez de um clique que nao faz nada.

ssid="$1"
[[ -n "$ssid" ]] || exit 1

if saida=$(nmcli device wifi connect "$ssid" 2>&1); then
    notify-send -a Órbita "Wi-Fi" "conectado a $ssid"
else
    case "$saida" in
        *[Ss]ecrets*|*[Pp]assword*|*[Ss]enha*)
            notify-send -a Órbita -u critical "Wi-Fi" \
                "$ssid exige senha — conecte pela primeira vez por fora do painel" ;;
        *)  notify-send -a Órbita -u critical "Wi-Fi" "falha ao conectar a $ssid" ;;
    esac
fi
