#!/usr/bin/env bash
# Acoes do painel Settings.
#
#   settings-action.sh bt | vpn | aviao | energia | dnd
#   settings-action.sh vol|mic|bri <0-100>
#
# Os toggles usam o padrao otimista validado no wifi-radio.sh: pinta primeiro,
# age depois, reconcilia no fim. Sem isso o botao so mudava no proximo ciclo do
# defpoll (3s) e o clique parecia sem resposta.
#
# Os sliders repintam o numero na hora, mas NAO reconciliam: o :onchange do
# scale dispara varias vezes por segundo enquanto se arrasta, e rodar o
# settings.sh inteiro a cada evento entupiria o daemon. O poll de 3s corrige.
# Sem o repinte a porcentagem ao lado da barra so mudava no proximo ciclo,
# e parecia que o slider e o numero estavam dessincronizados.

export LC_ALL=C.UTF-8
DIR="$(cd "$(dirname "$0")" && pwd)"
EWW="$HOME/.local/bin/eww"
CFG="$HOME/.config/eww-orbita"
RFKILL=/usr/sbin/rfkill          # fica fora do PATH do daemon eww

e() { "$EWW" --config "$CFG" "$@" >/dev/null 2>&1; }
estado() { "$EWW" --config "$CFG" get settings 2>/dev/null; }

# Repinta um campo do JSON na hora, antes de a acao rodar.
otimista() { # $1 = filtro jq
    local atual; atual=$(estado)
    [[ -n "$atual" ]] || return 0
    e update "settings=$(jq -c "$1" <<<"$atual" 2>/dev/null)"
}
reconciliar() { e update "settings=$("$DIR/settings.sh")"; }

case "$1" in
    bt)
        if [[ "$(jq -r .bt.on <<<"$(estado)")" == "true" ]]; then alvo=off; else alvo=on; fi
        otimista ".bt.on = $([[ $alvo == on ]] && echo true || echo false)"
        bluetoothctl power "$alvo" >/dev/null 2>&1
        reconciliar ;;

    vpn)
        # ATENCAO: o tailscale sai com codigo 0 MESMO quando nega a operacao
        # ("Access denied: prefs write access denied"), entao testar $? nao
        # adianta — e preciso olhar a saida. Sem isso o botao ficava mudo.
        #
        # Escrever prefs exige root ou operador definido. Uma vez, com sudo:
        #     sudo tailscale set --operator=$USER
        if [[ "$(jq -r .vpn.on <<<"$(estado)")" == "true" ]]; then
            otimista '.vpn.on = false | .vpn.txt = "tailscale · off"'
            saida=$(tailscale down 2>&1)
        else
            otimista '.vpn.on = true | .vpn.txt = "tailscale · on"'
            saida=$(tailscale up 2>&1)
        fi
        if grep -qiE "access denied|permission" <<<"$saida"; then
            notify-send -a Órbita -u critical "VPN" \
                "sem permissão para mudar o tailscale — rode uma vez: sudo tailscale set --operator=$USER"
        fi
        reconciliar ;;

    aviao)
        if [[ "$(jq -r .aviao.on <<<"$(estado)")" == "true" ]]; then acao=unblock; else acao=block; fi
        otimista ".aviao.on = $([[ $acao == block ]] && echo true || echo false)"
        "$RFKILL" "$acao" all >/dev/null 2>&1
        reconciliar ;;

    energia)
        # cicla performance -> balanced -> power-saver -> performance
        case "$(powerprofilesctl get 2>/dev/null)" in
            performance) prox=balanced ;;
            balanced)    prox=power-saver ;;
            *)           prox=performance ;;
        esac
        powerprofilesctl set "$prox" >/dev/null 2>&1
        reconciliar ;;

    dnd)
        dunstctl set-paused toggle >/dev/null 2>&1
        reconciliar ;;

    vol) otimista ".vol = $2"; wpctl set-volume @DEFAULT_AUDIO_SINK@   "$2%" -l 1.0 >/dev/null 2>&1 ;;
    mic) otimista ".mic = $2"; wpctl set-volume @DEFAULT_AUDIO_SOURCE@ "$2%"        >/dev/null 2>&1 ;;
    bri) otimista ".bri = $2"; brightnessctl -q set "$2%" >/dev/null 2>&1 ;;

    *) echo "uso: settings-action.sh {bt|vpn|aviao|energia|dnd|vol N|mic N|bri N}" >&2; exit 1 ;;
esac
