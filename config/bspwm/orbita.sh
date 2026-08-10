#!/bin/sh
# Parte Órbita do autostart do bspwm.
#
# Vive separado do bspwmrc de propósito: o bspwmrc tem coisa específica desta
# máquina (topologia de monitores DP-2/DP-0, ID do dispositivo no xinput,
# caminho do wallpaper) que não faz sentido versionar no repo do rice.
# O bspwmrc apenas carrega este arquivo.

# ── Barra: eww "Órbita" (substituiu a polybar) ────────────────────────
# top_padding 54 e NAO 68 como diz o handoff: o bspwm SOMA o window_gap ao
# top_padding, entao o 68 do README (14+42+12) rendia um vao de 24px em vez
# de 12. Conta certa: topo(12) + altura(42) + vao(12) - window_gap(12) = 54.
bspc config top_padding 54

# Caminho absoluto: ~/.local/bin nao esta garantido no PATH da sessao.
EWW="${HOME}/.local/bin/eww"
EWW_CFG="${HOME}/.config/eww-orbita"

# O kill torna o bloco idempotente — sem ele, `bspc wm -r` deixaria um
# daemon velho para tras.
"$EWW" --config "$EWW_CFG" kill        > /dev/null 2>&1
# O `kill` acima fala pelo socket. Um daemon que perdeu o socket sobrevive a
# ele e continua desenhando a barra — foi assim que apareceram duas barras
# identicas sobrepostas, indistinguiveis a olho. O pkill pega os orfaos.
# O padrao usa [e] para nao casar com a propria linha de comando deste script.
pkill -f "[e]ww --config ${EWW_CFG}"   > /dev/null 2>&1
"$EWW" --config "$EWW_CFG" daemon      > /dev/null 2>&1
sleep 1
"$EWW" --config "$EWW_CFG" open bar    > /dev/null 2>&1 &

# A polybar continua instalada e configurada em ~/.config/polybar/grayblocks;
# para voltar a ela, comente o bloco acima, restaure `top_padding 0` e
# descomente a linha abaixo.
# ${HOME}/.config/polybar/grayblocks/launch.sh &
