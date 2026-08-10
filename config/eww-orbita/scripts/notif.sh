#!/usr/bin/env bash
# defpoll (5s, :run-while cal_open) — cartao de Notificacoes.
#
# Emite: {"n":5,"pausado":false,
#         "grupos":[{"dia":"HOJE","itens":[{"titulo":"...","corpo":"...","hora":"18:22",
#                                           "app":"Órbita","nova":true}]}]}
#
# O timestamp do dunst NAO e epoch: e tempo monotonico desde o boot, em
# microssegundos. Sem somar o instante do boot, o agrupamento HOJE/ONTEM e as
# horas sairiam todos errados. (Descoberto comparando com `date`: o valor era
# ~14000, da ordem do uptime, e nao ~1.7e9.)
#
# "nova" = chegou depois da ultima vez que o painel foi aberto. O marcador
# fica em ~/.cache/eww-orbita/notif-lidas, gravado por notif-marcar.sh.

export LC_ALL=C.UTF-8
MARCA="$HOME/.cache/eww-orbita/notif-lidas"
OCULTAS="$HOME/.cache/eww-orbita/notif-ocultas"
lidas=$(cat "$MARCA" 2>/dev/null || echo 0)

# IDs dispensados um a um pelo clique. O dunst nao tem "apagar uma do
# historico" — so history-clear, que apaga tudo — entao o descarte individual
# e nosso: guardamos os IDs e filtramos aqui.
ocultas=$(sort -u "$OCULTAS" 2>/dev/null | jq -Rc --slurp 'split("\n") | map(select(length>0) | tonumber)' 2>/dev/null)
[[ -n "$ocultas" ]] || ocultas="[]"

# ── teto de itens ────────────────────────────────────────────────────
# A janela cresce com o conteudo e nao encolhe sozinha, entao sem teto ela
# passa da borda de baixo da tela.
#
# O teto e CALCULADO, e nao fixo: ele depende de onde a janela comeca, que
# depende da altura do cartao do calendario — e essa altura varia (medi 513 e
# 537 com o mesmo conteudo). Com teto fixo em 6 o painel terminava em y=1089,
# nove pixels fora da tela.
#
# Alturas medidas: cabecalho 65px, cada item 65px, e cada rotulo de dia
# ("HOJE", "ONTEM") 23px. Reservo dois rotulos, que e o caso comum.
TELA_ALT=1080
MARGEM=12
CABECALHO=65
ITEM=65
ROTULOS=46          # 2 x 23

topo=$(xwininfo -root -children 2>/dev/null |
       awk '/"Eww - panel-cal"/ {for (i=1;i<=NF;i++)
              if ($i ~ /^[0-9]+x[0-9]+\+/) {split($i, a, /[x+]/); print a[4] + a[2] + 12; exit}}')
[[ "$topo" =~ ^[0-9]+$ ]] || topo=611     # calendario fechado: usa o pior caso ja visto

MAX=$(( (TELA_ALT - MARGEM - topo - CABECALHO - ROTULOS) / ITEM ))
((MAX < 1)) && MAX=1
((MAX > 12)) && MAX=12

boot=$(awk -v n="$(date +%s)" '{printf "%d", n - $1}' /proc/uptime)
pausado=$(dunstctl is-paused 2>/dev/null); [[ "$pausado" == "true" ]] || pausado=false

dunstctl history 2>/dev/null | jq -c \
    --argjson boot "$boot" --argjson lidas "$lidas" --argjson pausado "$pausado" \
    --argjson ocultas "$ocultas" --argjson max "$MAX" \
    --arg hoje "$(date +%Y-%m-%d)" --arg ontem "$(date -d yesterday +%Y-%m-%d)" '
    ([.data[0][]?
      | select((.id.data | IN($ocultas[])) | not)
      | ($boot + (.timestamp.data / 1000000) | floor) as $ep
      | {
          id:     .id.data,
          titulo: .summary.data,
          corpo:  .body.data,
          app:    .appname.data,
          ep:     $ep,
          dia:    ($ep | strflocaltime("%Y-%m-%d")),
          hora:   ($ep | strflocaltime("%H:%M")),
          nova:   ($ep > $lidas)
        }] | sort_by(.ep) | reverse | .[0:$max]) as $itens
    | {
        n: ($itens | length),
        pausado: $pausado,
        grupos: (
          $itens
          | group_by(.dia)
          | sort_by(.[0].dia) | reverse
          | map({
              dia: (if .[0].dia == $hoje then "HOJE"
                    elif .[0].dia == $ontem then "ONTEM"
                    else (.[0].dia | strptime("%Y-%m-%d") | mktime | strflocaltime("%d/%m")) end),
              itens: (. | sort_by(.ep) | reverse | map({id, titulo, corpo, hora, app, nova}))
            })
        )
      }' 2>/dev/null || echo '{"n":0,"pausado":false,"grupos":[]}'
