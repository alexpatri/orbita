#!/usr/bin/env bash
# defpoll (10s, :run-while net_open) — painel de Rede.
#
# Emite:
# {"radio":true,"n":12,
#  "redes":[{"ssid":"casa_5G","icon":"","meta":"conectado · 192.168.0.14 · 78%",
#            "conectado":true,"seguro":true}, ...],
#  "cabo":{"nome":"enp3s0","icon":"","meta":"192.168.0.10 · 1000 Mb/s","conectado":true}}
#
# Tres desvios do protótipo, todos por falta de fonte de dado honesta:
#
# 1. SINAL EM % E NAO dBm. O `iw` nao esta instalado, e o unico numero
#    disponivel e o SIGNAL do nmcli, que ja e uma curva derivada do dBm.
#    Converter de volta seria inventar precisao que nao temos.
# 2. SSIDs DUPLICADOS sao colapsados no de maior sinal. A mesma rede aparece
#    uma vez por banda e por BSSID — aqui uma delas aparecia 5x.
# 3. REDES OCULTAS (SSID vazio) sao descartadas: nao da para clicar para
#    conectar sem saber o nome.

export LC_ALL=C.UTF-8
source "$(dirname "$0")/icons.sh"

radio=$(nmcli radio wifi 2>/dev/null)
[[ "$radio" == "enabled" ]] && radio=true || radio=false

# Interface que carrega a rota padrao — e ela que ganha o destaque de acento,
# seja wifi ou cabo. No protótipo o destaque e sempre do wifi, mas aqui a
# conexao viva costuma ser o cabo.
rota=$(ip route get 1.1.1.1 2>/dev/null |
       awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')

# SSIDs ja salvos, para marcar "salvo".
salvos=$(nmcli -t -f NAME,TYPE connection show 2>/dev/null |
         awk -F: '$2 == "802-11-wireless" {print $1}')

# SSID vai POR ULTIMO de proposito: o nmcli -t escapa ":" dentro dos valores,
# e deixando o SSID no fim basta cortar nos 3 primeiros campos para pegar o
# nome inteiro, mesmo que ele contenha dois-pontos.
redes="[]"
if [[ "$radio" == true ]]; then
    redes=$(timeout 8 nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list --rescan auto 2>/dev/null |
        awk -F: -v OFS='\t' '{
            uso=$1; sinal=$2; seg=$3;
            ssid=$0; sub(/^[^:]*:[^:]*:[^:]*:/, "", ssid); gsub(/\\:/, ":", ssid);
            if (ssid == "") next;                      # rede oculta
            if (!(ssid in melhor) || sinal+0 > melhor[ssid]+0) {
                melhor[ssid]=sinal; u[ssid]=uso; s[ssid]=seg
            }
        }
        END { for (n in melhor) print u[n], melhor[n], s[n], n }' |
        sort -t$'\t' -k2,2nr |
        jq -Rc --slurp \
           --arg ip "$(ip -o -4 addr show "$rota" 2>/dev/null | awk '{print $4}' | cut -d/ -f1)" \
           --arg rota "$rota" \
           --arg salvos "$salvos" \
           --arg i3 "$IC_WIFI" --arg i2 "$IC_WIFI_2_BAR" --arg i1 "$IC_WIFI_1_BAR" '
            ($salvos | split("\n")) as $sv
            | split("\n") | map(select(length > 0)) | map(split("\t"))
            | map({
                uso:   (.[0] == "*"),
                sinal: (.[1] | tonumber),
                seg:   .[2],
                ssid:  .[3]
              })
            | map(. + {
                icon:      (if .sinal >= 67 then $i3 elif .sinal >= 34 then $i2 else $i1 end),
                seguro:    (.seg != ""),
                conectado: .uso,
                meta: (
                  if .uso then "conectado · " + $ip + " · " + (.sinal|tostring) + "%"
                  elif (.ssid | IN($sv[])) then "salvo · " + (if .seg == "" then "aberta" else .seg end)
                  else (if .seg == "" then "aberta" else .seg end) + " · " + (.sinal|tostring) + "%"
                  end)
              })
            | map({ssid, icon, meta, conectado, seguro})
        ')
fi
[[ -z "$redes" ]] && redes="[]"

# ── cabo ─────────────────────────────────────────────────────────────
# Lido do sysfs, e nao do nmcli: esta interface esta como "unmanaged" no
# NetworkManager, entao `nmcli device status` nao sabe o estado dela.
cabo_if=$(for d in /sys/class/net/*; do
            n=$(basename "$d")
            [[ -e "$d/device" && ! -d "$d/wireless" ]] && { echo "$n"; break; }
          done)
if [[ -n "$cabo_if" && "$(cat /sys/class/net/$cabo_if/carrier 2>/dev/null)" == "1" ]]; then
    cabo_ip=$(ip -o -4 addr show "$cabo_if" 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
    cabo_vel=$(cat /sys/class/net/$cabo_if/speed 2>/dev/null)
    cabo_meta="${cabo_ip:-sem IP} · ${cabo_vel:-?} Mb/s"
    cabo_conn=true
else
    cabo_meta="cabo desconectado"
    cabo_conn=false
fi

jq -cn --argjson radio "$radio" --argjson redes "$redes" \
       --arg cnome "${cabo_if:-—}" --arg cmeta "$cabo_meta" --argjson cconn "$cabo_conn" \
       --arg cicon "$IC_SETTINGS_ETHERNET" --arg rota "$rota" '
  {radio: $radio,
   n: ($redes | length),
   redes: $redes,
   cabo: {nome: $cnome, icon: $cicon, meta: $cmeta,
          conectado: ($cconn and ($rota == $cnome))}}'
