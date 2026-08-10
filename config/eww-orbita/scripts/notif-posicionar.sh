#!/usr/bin/env bash
# Abre a janela de notificacoes logo abaixo da do calendario, MEDINDO a altura
# real desta em vez de confiar numa constante.
#
# Eu tinha fixado y=587 com base numa medicao de 513px do cartao do
# calendario. Errado: com exatamente o mesmo conteudo ele mediu 537 noutra
# hora, e as duas janelas passaram a se sobrepor. A altura depende de detalhes
# de layout do GTK que nao valem perseguir — medir e mais barato e nao mente.

EWW="$HOME/.local/bin/eww"
CFG="$HOME/.config/eww-orbita"
X=1468        # 1920 - 12 de margem - 440 de largura
VAO=12

ler_geo() {
    xwininfo -root -children 2>/dev/null |
        awk '/"Eww - panel-cal"/ {for (i=1;i<=NF;i++) if ($i ~ /^[0-9]+x[0-9]+\+/) {print $i; exit}}'
}

# ESPERA A ALTURA ESTABILIZAR antes de medir. Logo depois do `eww open` a
# janela ja existe mas ainda esta crescendo — na primeira tentativa peguei
# 121px em vez de 513, e as notificacoes foram parar no meio do calendario.
# Estavel = duas leituras iguais seguidas.
ant=""; geo=""
for _ in $(seq 1 40); do
    geo=$(ler_geo)
    [[ -n "$geo" && "$geo" == "$ant" ]] && break
    ant=$geo
    sleep 0.1
done

if [[ "$geo" =~ ^[0-9]+x([0-9]+)\+[0-9]+\+([0-9]+) ]]; then
    y=$(( BASH_REMATCH[2] + BASH_REMATCH[1] + VAO ))
else
    y=587     # so cai aqui se o calendario nao estiver aberto
fi

"$EWW" --config "$CFG" open panel-notif --pos "${X}x${y}" >/dev/null 2>&1
