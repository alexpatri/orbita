#!/usr/bin/env bash
# defpoll (60s, :run-while cal_open) — cartao do Calendario.
#   uso: calendario.sh [offset_de_meses]   (sem argumento, le de
#        ~/.cache/eww-orbita/cal-off, gravado pelo cal-nav.sh — o comando de um
#        defpoll e string estatica e nao interpola variavel da eww)
#
# Emite grade do mes + lista de eventos:
# {"titulo":"AGOSTO 2026","dias":[{"n":"27","fora":true,"hoje":false,"evento":false},...],
#  "eventos":[{"titulo":"...","quando":"...","sistema":false}, ...]}
#
# Duas origens de evento, as duas cores que o design preve:
#   - khal  -> eventos do usuario, ciano
#   - timers do systemd + cron -> "do sistema", ambar
#
# Sobre o cron: so entram as linhas que REALMENTE disparam nesta maquina. A
# maioria dos /etc/cron.d do Debian e fallback para sistemas sem systemd,
# guardado por `! -d /run/systemd/system` — listar isso seria mostrar evento
# que nunca acontece.

export LC_ALL=C.UTF-8
OFF=${1:-$(cat "$HOME/.cache/eww-orbita/cal-off" 2>/dev/null || echo 0)}
[[ "$OFF" =~ ^-?[0-9]+$ ]] || OFF=0

MESES=(JANEIRO FEVEREIRO MARÇO ABRIL MAIO JUNHO JULHO AGOSTO SETEMBRO OUTUBRO NOVEMBRO DEZEMBRO)
mes_pt=(jan fev mar abr mai jun jul ago set out nov dez)

# Primeiro dia do mes alvo. O dia 1 evita o classico erro de "mes + 1" em 31.
base=$(date -d "$(date +%Y-%m-01) $OFF month" +%Y-%m-01)
ano=$(date -d "$base" +%Y)
mnum=$(date -d "$base" +%m)
mes_nome="${MESES[10#$mnum - 1]}"
hoje=$(date +%Y-%m-%d)
agora=$(date +%s)

# ── eventos ──────────────────────────────────────────────────────────
tmp_ev=$(mktemp); trap 'rm -f "$tmp_ev"' EXIT

# khal: pode nao estar instalado ou nao ter calendario configurado.
if command -v khal >/dev/null 2>&1; then
    # --day-format '' suprime as linhas de cabecalho de dia ("Today, 07/08/2026"),
    # que senao entrariam na lista como se fossem eventos.
    # A data vem no dateformat configurado (dd/mm/aaaa) porque o khal 0.11 nao
    # aceita strftime dentro do --format — testado, da traceback.
    khal list --day-format '' --format '{start-date}|{title}|{start-time}' today 60d 2>/dev/null |
        grep -E '^[0-9]{2}[/.-][0-9]{2}[/.-][0-9]{4}\|' |
        while IFS='|' read -r d t h; do
            iso=$(sed -E 's|^([0-9]{2})[/.-]([0-9]{2})[/.-]([0-9]{4}).*|\3-\2-\1|' <<<"$d")
            # Evento de dia inteiro nao traz hora: ancora as 00:00 e exibe
            # "dia todo" em vez de um horario inventado.
            if [[ "$h" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then hora=$h; else hora=""; fi
            ep=$(date -d "$iso ${hora:-00:00}" +%s 2>/dev/null) || continue
            printf '%s\t%s\t%s\t%s\tfalse\n' "$ep" "$iso" "$t" "${hora:-dia todo}"
        done >> "$tmp_ev"
fi

# timers do systemd: `next` vem em epoch de microssegundos no json.
systemctl list-timers --all -o json --no-pager 2>/dev/null |
    jq -r '.[] | select(.next != null and .next > 0)
           | "\(.next/1000000 | floor)\t\(.unit)"' 2>/dev/null |
    while IFS=$'\t' read -r epoch unit; do
        printf '%s\t%s\t%s\t%s\ttrue\n' \
               "$epoch" "$(date -d "@$epoch" +%Y-%m-%d)" "${unit%.timer}" "$(date -d "@$epoch" +%H:%M)"
    done >> "$tmp_ev"

# cron.d: so o que nao esta guardado por "somente sem systemd".
for f in /etc/cron.d/*; do
    [[ -r "$f" ]] || continue
    grep -hvE '^\s*#|^\s*$|^[A-Z_]+=' "$f" 2>/dev/null |
        grep -vF '/run/systemd/system' |
        while read -r m h _ _ _ _; do
            [[ "$m" =~ ^[0-9]+$ && "$h" =~ ^[0-9]+$ ]] || continue
            # Se o horario de hoje ja passou, o proximo disparo e amanha.
            # +86400 no epoch, e NAO `date -d "... +1 day"`: com uma hora na
            # string o date le o "+1" como FUSO HORARIO, e 05:56 virava 01:56.
            q=$(date -d "$hoje $h:$m" +%s)
            ((q < agora)) && q=$((q + 86400))
            printf '%s\t%s\t%s\t%s\ttrue\n' \
                   "$q" "$(date -d "@$q" +%Y-%m-%d)" "cron · $(basename "$f")" "$(date -d "@$q" +%H:%M)"
        done >> "$tmp_ev"
done

# ── grade do mes ─────────────────────────────────────────────────────
# 42 celulas (6 semanas), comecando no domingo da semana do dia 1.
dow=$(date -d "$base" +%w)
# Meio-dia, e nao meia-noite: somar 86400 a partir do meio-dia sobrevive a
# qualquer salto de horario de verao sem virar o dia.
#
# O recuo ate o domingo e feito em ARITMETICA de epoch, e nao com
# `date -d "... 12:00 -6 day"`: com uma hora na string o date le o "-6" como
# FUSO HORARIO. Mesmo bug que ja tinha aparecido no rollover do cron.
ini_ep=$(( $(date -d "$base 12:00" +%s) - dow * 86400 ))

# Um unico jq monta as 42 celulas. Antes era um laco de 42 iteracoes com dois
# `date` e um `cut|grep` em cada uma — ~170 forks e 250ms. Com o painel aberto
# isso roda a cada 60s, e no clique estourava o tempo do handler.
dias=$(jq -c -n \
    --argjson ini "$ini_ep" --arg mnum "$mnum" --arg hoje "$hoje" \
    --argjson comev "$(cut -f2 "$tmp_ev" | sort -u | jq -Rc --slurp 'split("\n") | map(select(length>0))')" '
    [ range(42)
      | ($ini + (. * 86400)) as $ep
      | ($ep | strflocaltime("%Y-%m-%d")) as $d
      | { n:      ($ep | strflocaltime("%-d")),
          fora:   (($ep | strflocaltime("%m")) != $mnum),
          hoje:   ($d == $hoje),
          evento: ($comev | index($d) != null) } ]
    | [_nwise(7)]')

# ── lista: os proximos 6, em ordem ───────────────────────────────────
# Filtra pelo INSTANTE, nao pelo dia: um cron das 05:56 nao e "proximo
# evento" as 12h. Ordena por epoch.
#
# SEMPRE 4 EVENTOS, nem mais nem menos. O numero fixo e o que torna a altura
# deste cartao deterministica — e e isso que permite o cartao de Notificacoes
# ser uma JANELA SEPARADA, posicionada logo abaixo. Enquanto os dois estavam na
# mesma janela, o picom borrava tambem o vao transparente entre eles.
#
# Teto de 2 do sistema: sao 10 timers de manutencao (logrotate, man-db...)
# contra poucos eventos do usuario, e sem o teto eles tomavam quase todas as
# vagas. Se sobrar espaco depois dos eventos do usuario, o restante e
# preenchido com sistema — sempre ha timer suficiente para completar 4.
eventos=$(awk -F'\t' -v agora="$agora" '$1 >= agora' "$tmp_ev" |
    sort -t$'\t' -k1,1n |
    awk -F'\t' 'BEGIN{OFS=FS} $5 == "true" { sis[++ns] = $0; next } { print; ++nu }
                 END { for (i = 1; i <= ns && nu + i <= 4; i++) print sis[i] }' |
    sort -t$'\t' -k1,1n |
    head -4 |
    jq -Rc --slurp --arg hoje "$hoje" --arg meses "${mes_pt[*]}" '
      ($meses | split(" ")) as $m
      | split("\n") | map(select(length>0)) | map(split("\t"))
      | map({
          titulo: .[2],
          sistema: (.[4] == "true"),
          quando: (
            (.[1] | split("-")) as $d
            | (if .[1] == $hoje then "hoje" else ($d[2] + " " + $m[($d[1]|tonumber)-1]) end)
              + " " + .[3])
        })')

# `semanas` em vez de lista plana: o eww não tem grid, então a grade vira um
# box por semana com sete células dentro.
jq -cn --arg m "$mes_nome" --arg a "$ano" --argjson sem "$dias" --argjson e "${eventos:-[]}" \
   '{mes:$m, ano:$a, semanas:$sem, eventos:$e}'
