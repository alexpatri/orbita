#!/usr/bin/env bash
# defpoll (3s, :run-while audio_open) — painel Settings.
#
# Emite um JSON com os cinco botoes e os tres sliders:
# {"bt":{"on":true,"txt":"ligado"}, "vpn":{...}, "aviao":{...}, "energia":{...},
#  "dnd":{...}, "vol":45, "mic":80, "bri":95,
#  "saida":{"nome":"Áudio interno","id":"58"}}
#
# C.UTF-8, e nao C: o awk le "0.45" como 0 sob pt_BR e o pactl traduz os
# proprios rotulos de campo (Name: -> Nome:), mas o C puro quebra texto
# acentuado na saida. C.UTF-8 resolve os dois sem quebrar o terceiro.

export LC_ALL=C.UTF-8
source "$(dirname "$0")/icons.sh"

j() { jq -Rn --arg t "$2" --argjson o "$1" '{on:$o, txt:$t}'; }

# ── bluetooth ────────────────────────────────────────────────────────
if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
    bt=$(j true "ligado")
else
    bt=$(j false "desligado")
fi

# ── VPN (tailscale no lugar do wg0 do protótipo) ─────────────────────
if [[ "$(tailscale status --json 2>/dev/null | jq -r '.BackendState' 2>/dev/null)" == "Running" ]]; then
    vpn=$(j true "tailscale · on")
else
    vpn=$(j false "tailscale · off")
fi

# ── modo aviao ───────────────────────────────────────────────────────
# Ligado = TODOS os radios bloqueados. Se so um estiver, nao e modo aviao.
mapfile -t bloq < <(/usr/sbin/rfkill -n -o SOFT list 2>/dev/null | tr -d ' ')
if ((${#bloq[@]} > 0)) && ! printf '%s\n' "${bloq[@]}" | grep -qx "unblocked"; then
    aviao=$(j true "ligado")
else
    aviao=$(j false "desligado")
fi

# ── perfil de energia ────────────────────────────────────────────────
# Sempre "ativo" no acento, como no protótipo: um perfil esta sempre em vigor.
perfil=$(powerprofilesctl get 2>/dev/null)
case "$perfil" in
    performance) ptxt="desempenho" ;;
    power-saver) ptxt="economia" ;;
    balanced)    ptxt="balanceado" ;;
    *)           ptxt="${perfil:-—}" ;;
esac
energia=$(jq -Rn --arg t "$ptxt" --arg p "$perfil" '{on:true, txt:$t, perfil:$p}')

# ── nao perturbe ─────────────────────────────────────────────────────
if [[ "$(dunstctl is-paused 2>/dev/null)" == "true" ]]; then
    dnd=$(j true "pausado")
else
    dnd=$(j false "dunst ativo")
fi

# ── sliders ──────────────────────────────────────────────────────────
pct() { wpctl get-volume "$1" 2>/dev/null | awk '{printf "%d", $2 * 100 + 0.5}'; }
vol=$(pct @DEFAULT_AUDIO_SINK@); : "${vol:=0}"
mic=$(pct @DEFAULT_AUDIO_SOURCE@); : "${mic:=0}"

bri=0
for d in /sys/class/backlight/*; do
    [[ -r "$d/actual_brightness" ]] || continue
    bri=$(( $(<"$d/actual_brightness") * 100 / $(<"$d/max_brightness") ))
    break
done

# ── saida de audio atual ─────────────────────────────────────────────
# O sufixo de perfil ("Estéreo analógico") e cortado: o protótipo mostra so o
# nome curto do aparelho.
atual=$(pactl get-default-sink 2>/dev/null)
read -r sid snome < <(pactl list sinks 2>/dev/null | awk -v alvo="$atual" '
    /^Sink #/      { id = substr($2, 2) }
    /^\tName:/     { nome = $2 }
    /^\tDescription:/ { $1=""; sub(/^ /,""); if (nome == alvo) { print id, $0; exit } }')
# Remocao LITERAL do sufixo, e nao regex: sob LC_ALL=C o "é" vale dois bytes e
# uma classe como [ée] deixa de casar. `${var%sufixo}` compara bytes e nao se
# importa com locale.
snome="${snome:-—}"
for suf in " Estéreo analógico" " Analog Stereo" " Digital Stereo (HDMI)" " Estéreo digital (HDMI)"; do
    snome="${snome%"$suf"}"
done

jq -cn --argjson bt "$bt" --argjson vpn "$vpn" --argjson aviao "$aviao" \
       --argjson energia "$energia" --argjson dnd "$dnd" \
       --argjson vol "${vol:-0}" --argjson mic "${mic:-0}" --argjson bri "${bri:-0}" \
       --arg snome "$snome" --arg sid "${sid:-}" '
  {bt:$bt, vpn:$vpn, aviao:$aviao, energia:$energia, dnd:$dnd,
   vol:$vol, mic:$mic, bri:$bri,
   saida:{nome:$snome, id:$sid}}'
