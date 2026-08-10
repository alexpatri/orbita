#!/usr/bin/env bash
# defpoll (1s, :run-while media_open) — painel do Player, via MPRIS.
#
# Emite:
# {"ativo":true,"tocando":false,"titulo":"...","sub":"artista · album",
#  "fonte":"firefox","capa":"/caminho.png","pct":16,"pos":"0:34","dur":"3:31",
#  "shuffle_ok":false,"shuffle":false,"loop_ok":false,"loop":"None",
#  "saida":"Áudio interno"}
#
# ── Dois defeitos do MPRIS do Firefox que este script contorna ──────────
#
# 1. A POSICAO NAO CONGELA NA PAUSA: ela segue avancando 1s por segundo com
#    status=Paused (medido: 89, 91, 93, 95, 97). A barra andava com o video
#    parado.
#
# 2. DURANTE UM SEEK a duracao some por um instante — `mpris:length` responde
#    "No player could handle this command". Caindo para zero, a barra colapsava
#    e voltava, o que aparecia como um pulo para o inicio.
#
# A defesa dos dois e a mesma: um cache por faixa em ~/.cache/eww-orbita.
# Leitura invalida nunca zera nada — reaproveita o ultimo valor bom.

export LC_ALL=C.UTF-8
CACHE="$HOME/.cache/eww-orbita/capas"
EST="$HOME/.cache/eww-orbita/player-estado"   # track dur pos epoch

vazio() {
    jq -cn '{ativo:false, tocando:false, titulo:"nada tocando", sub:"", fonte:"",
             capa:"", pct:0, pos:"0:00", dur:"0:00",
             shuffle_ok:false, shuffle:false, loop_ok:false, loop:"None", saida:""}'
}

command -v playerctl >/dev/null 2>&1 || { vazio; exit 0; }
player=$(playerctl -l 2>/dev/null | head -1)
[[ -n "$player" ]] || { vazio; exit 0; }

m() { playerctl -p "$player" metadata "$1" 2>/dev/null; }

status=$(playerctl -p "$player" status 2>/dev/null)
titulo=$(m xesam:title)
artista=$(m xesam:artist)
album=$(m xesam:album)
fonte=${player%%.*}          # "firefox.instance_1_31184" -> "firefox"

# ── capa ─────────────────────────────────────────────────────────────
# file:// no Firefox (png local); http:// no Spotify (CDN), baixado uma vez e
# cacheado pelo hash da URL — sem isso seria um download por segundo.
art=$(m mpris:artUrl)
capa=""
case "$art" in
    file://*) capa=${art#file://}; [[ -r "$capa" ]] || capa="" ;;
    http://*|https://*)
        mkdir -p "$CACHE"
        nome="$CACHE/$(printf '%s' "$art" | md5sum | cut -c1-16)"
        [[ -s "$nome" ]] || curl -fsL --max-time 5 -o "$nome" "$art" 2>/dev/null
        [[ -s "$nome" ]] && capa="$nome"
        ;;
esac

# ── estado anterior ──────────────────────────────────────────────────
track=$(printf '%s|%s' "$player" "$titulo" | md5sum | cut -c1-12)
c_track=""; c_dur=0; c_pos=0; c_ep=0
read -r c_track c_dur c_pos c_ep < <(cat "$EST" 2>/dev/null) || true
[[ "$c_track" == "$track" ]] || { c_dur=0; c_pos=0; c_ep=0; }

# ── duracao ──────────────────────────────────────────────────────────
dur_us=$(m mpris:length)
if [[ "$dur_us" =~ ^[0-9]+$ ]] && ((dur_us > 0)); then
    dur_s=$((dur_us / 1000000))
else
    dur_s=${c_dur:-0}        # leitura falhou (tipico durante seek): mantem
fi

# ── posicao ──────────────────────────────────────────────────────────
pos_raw=$(playerctl -p "$player" position 2>/dev/null)
agora=$(date +%s)

if ! [[ "$pos_raw" =~ ^[0-9.]+$ ]]; then
    pos_s=${c_pos:-0}        # leitura falhou: mantem a ultima boa
elif [[ "$status" == "Playing" ]]; then
    pos_s=$pos_raw
else
    # Pausado: congela. A comparacao e contra a DERIVA esperada, e nao contra o
    # valor cru — so assim da para separar o bug do Firefox de um seek real.
    # Se o lido se afasta mais de 2s do que a deriva explicaria, foi seek.
    if ((c_ep > 0)); then
        esperado=$(awk -v p="$c_pos" -v e="$c_ep" -v a="$agora" 'BEGIN{printf "%.3f", p + (a - e)}')
        if awk -v l="$pos_raw" -v x="$esperado" 'BEGIN{exit !((l-x > 2) || (x-l > 2))}'; then
            pos_s=$pos_raw   # seek de verdade
        else
            pos_s=$c_pos     # congelado
            agora=$c_ep      # preserva a ancora, senao a deriva reinicia
        fi
    else
        pos_s=$pos_raw
    fi
fi

mkdir -p "$(dirname "$EST")"
printf '%s %s %s %s\n' "$track" "$dur_s" "$pos_s" "$agora" > "$EST"

mmss() { awk -v s="${1:-0}" 'BEGIN{s=int(s); printf "%d:%02d", s/60, s%60}'; }
pct=0
((dur_s > 0)) && pct=$(awk -v p="$pos_s" -v d="$dur_s" 'BEGIN{v=p*100/d; printf "%d", (v>100?100:(v<0?0:v))}')

# ── shuffle e loop ───────────────────────────────────────────────────
# O Firefox nao implementa nenhum dos dois: responde "No player could handle
# this command". Nesse caso o botao aparece apagado, em vez de mentir estado.
sh_raw=$(playerctl -p "$player" shuffle 2>&1)
if [[ "$sh_raw" == "true" || "$sh_raw" == "false" ]]; then
    shuffle_ok=true; shuffle=$sh_raw
else
    shuffle_ok=false; shuffle=false
fi
lp_raw=$(playerctl -p "$player" loop 2>&1)
case "$lp_raw" in
    None|Track|Playlist) loop_ok=true;  loop=$lp_raw ;;
    *)                   loop_ok=false; loop="None" ;;
esac

# ── saida de audio ───────────────────────────────────────────────────
atual=$(pactl get-default-sink 2>/dev/null)
saida=$(pactl list sinks 2>/dev/null | awk -v alvo="$atual" '
    /^Sink #/ { id = $2 }
    /^\tName:/ { nome = $2 }
    /^\tDescription:/ { $1=""; sub(/^ /,""); if (nome == alvo) { print; exit } }')
for suf in " Estéreo analógico" " Analog Stereo" " Digital Stereo (HDMI)"; do
    saida="${saida%"$suf"}"
done

# Album vem vazio em video do YouTube: mostra so o artista, sem separador solto.
if [[ -n "$album" ]]; then sub="$artista · $album"; else sub="$artista"; fi
[[ "$status" == "Playing" ]] && tocando=true || tocando=false

jq -cn --arg t "$titulo" --arg s "$sub" --arg f "$fonte" --arg c "$capa" \
       --arg pos "$(mmss "$pos_s")" --arg dur "$(mmss "$dur_s")" --argjson pct "$pct" \
       --argjson toc "$tocando" --argjson sok "$shuffle_ok" --argjson sh "$shuffle" \
       --argjson lok "$loop_ok" --arg lp "$loop" --arg saida "${saida:-—}" '
  {ativo:true, tocando:$toc, titulo:$t, sub:$s, fonte:$f, capa:$c,
   pct:$pct, pos:$pos, dur:$dur,
   shuffle_ok:$sok, shuffle:$sh, loop_ok:$lok, loop:$lp, saida:$saida}'
