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

# ESPERA A ALTURA ESTABILIZAR antes de medir.
#
# O painel do calendario nasce CURTO e cresce: medido, ele aparece com 121px
# aos ~360ms e so vira ~507px aos ~560ms, quando o calendario.sh retorna e
# preenche a grade. Sao ~200ms com o cartao pela metade.
#
# A versao anterior aceitava DUAS leituras iguais a 100ms — exatamente 200ms,
# que cabe dentro dessa janela ruim. Dava para amostrar 121 duas vezes e
# declarar estavel, e as notificacoes iam parar em cima do calendario.
#
# Duas defesas agora:
#   - PISO DE ALTURA: o cartao sempre tem a grade de 6 semanas, entao nunca
#     fica abaixo de ~500. Leitura menor que MIN_ALT e "ainda enchendo".
#   - TRES leituras iguais seguidas, e nao duas: 300ms de estabilidade, mais
#     do que a transicao dura.
MIN_ALT=400
ESTAVEIS=3

ant=""; iguais=0; geo=""; bom=""
for _ in $(seq 1 50); do
    geo=$(ler_geo)
    if [[ "$geo" =~ ^[0-9]+x([0-9]+)\+ ]] && (( BASH_REMATCH[1] >= MIN_ALT )); then
        bom=$geo
        if [[ "$geo" == "$ant" ]]; then
            iguais=$(( iguais + 1 ))
            (( iguais >= ESTAVEIS - 1 )) && break
        else
            iguais=0
        fi
    else
        iguais=0
    fi
    ant=$geo
    sleep 0.1
done
geo=$bom

if [[ "$geo" =~ ^[0-9]+x([0-9]+)\+[0-9]+\+([0-9]+) ]]; then
    y=$(( BASH_REMATCH[2] + BASH_REMATCH[1] + VAO ))
else
    # Chega aqui se o calendario nao abriu ou nunca passou do piso (khal
    # travado, por exemplo). 587 e um valor tipico: no pior caso sobra um vao
    # maior, que e menos ruim do que sobrepor o cartao.
    y=587
fi

"$EWW" --config "$CFG" open panel-notif --pos "${X}x${y}" >/dev/null 2>&1
