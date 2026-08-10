#!/usr/bin/env bash
# Fonte unica da verdade do estado dos paineis.
#
# Cada painel tem DUAS coisas que precisam andar juntas: o defvar que acende o
# chip na barra e a janela eww em si. Se o clique mexesse so no defvar, fechar
# por clique-fora deixaria o chip aceso sem painel. Todo abre/fecha passa aqui.
#
#   panel.sh toggle <var> <janela>
#   panel.sh close-all
#
# Os paineis sao MUTUAMENTE EXCLUSIVOS: abrir um fecha o que estiver aberto.
# Isso contraria o handoff, que diz que os paineis sao independentes e que mais
# de um pode ficar aberto ao mesmo tempo (a tela 2 do protótipo mostra Sistema
# e Player juntos). E decisao de uso, tomada com os paineis ja em pe.
#
# A janela `catcher` e um retangulo transparente que cobre a tela ABAIXO da
# barra e fecha tudo ao ser clicada. Abaixo da barra de proposito: se cobrisse
# a barra tambem, ela ficaria por cima dos chips e impediria abrir um segundo
# painel sem fechar o primeiro.

EWW="$HOME/.local/bin/eww"
CFG="$HOME/.config/eww-orbita"

# var:janela[,janela...] — uma variavel pode comandar mais de uma janela.
# O cal_open abre DUAS: calendario e notificacoes sao janelas separadas de
# proposito. Enquanto estavam na mesma, o picom borrava tambem o vao
# transparente entre os dois cartoes.
PAINEIS="sys_open:panel-sys net_open:panel-net media_open:panel-player audio_open:panel-settings cal_open:panel-cal,panel-notif"
CATCHER="catcher"

e() { "$EWW" --config "$CFG" "$@" >/dev/null 2>&1; }

fechar_tudo() {
    local par w
    for par in $PAINEIS; do
        e update "${par%%:*}=false"
        for w in $(tr ',' ' ' <<<"${par##*:}"); do e close "$w"; done
    done
    e close "$CATCHER"
}

case "$1" in
    toggle)
        var=$2
        win=$3
        [[ -n "$var" && -n "$win" ]] || { echo "uso: panel.sh toggle <var> <janela>" >&2; exit 1; }

        if [[ "$("$EWW" --config "$CFG" get "$var" 2>/dev/null)" == "true" ]]; then
            fechar_tudo
        else
            # Fecha antes de abrir: e o que torna os paineis exclusivos, e de
            # quebra garante que nao sobre catcher nem variavel dessincronizada.
            fechar_tudo
            # catcher ANTES do painel: as duas sao :stacking "fg", entao quem
            # abre depois fica por cima. Invertido, o catcher engoliria os
            # cliques do proprio painel.
            e open "$CATCHER"
            e update "$var=true"
            for w in $(tr ',' ' ' <<<"$win"); do
                # panel-notif nao abre pela geometria do yuck: ele precisa ficar
                # logo abaixo do calendario, cuja altura so se sabe medindo.
                if [[ "$w" == "panel-notif" ]]; then
                    "$(dirname "$0")/notif-posicionar.sh"
                else
                    e open "$w"
                fi
            done
        fi
        ;;

    close-all)
        fechar_tudo
        ;;

    *)
        echo "uso: panel.sh {toggle <var> <janela>|close-all}" >&2
        exit 1
        ;;
esac
