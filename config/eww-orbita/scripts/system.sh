#!/usr/bin/env bash
# deflisten (2s, :run-while sys_open) — todos os cartoes do painel Sistema.
#
# deflisten e nao defpoll porque CPU% e I/O de disco exigem o delta entre duas
# leituras — precisa guardar a leitura anterior entre os ciclos.
#
# Emite um unico JSON:
# {"uptime":"1d 08:41:50",
#  "cpu":{"nome":"i7-12700H","pct":32,"freq":"4,2 GHz","temp":62},
#  "mem":{"pct":48,"usada":"7,8","total":"16","swap":"0,2"},
#  "gpu":{"nome":"RTX 3050","pct":18,"usada":"1,1","total":"4","temp":54},
#  "disco":{"nome":"nvme0n1","pct":71,"usado":"338","total":"476","le":"12","esc":"3"}}

export LC_ALL=C.UTF-8
INTERVAL=2

# ── descobertas feitas uma vez, nao a cada ciclo ──────────────────────
ZONE=""
for z in /sys/class/thermal/thermal_zone*; do
    [[ "$(cat "$z/type" 2>/dev/null)" == "x86_pkg_temp" ]] && { ZONE="$z/temp"; break; }
done
[[ -z "$ZONE" ]] && ZONE=/sys/class/thermal/thermal_zone0/temp

# "12th Gen Intel(R) Core(TM) i7-12700H" -> "i7-12700H", como o "Ryzen 5 5600"
# do protótipo. Pega o ultimo campo depois do ultimo espaco.
CPU_NOME=$(awk -F': ' '/^model name/{n=split($2,a," "); print a[n]; exit}' /proc/cpuinfo)
[[ -z "$CPU_NOME" ]] && CPU_NOME="cpu"

# "NVIDIA GeForce RTX 3050 Laptop GPU" -> "RTX 3050"
GPU_NOME=""
if command -v nvidia-smi >/dev/null 2>&1; then
    GPU_NOME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null |
               sed -E 's/.*(RTX|GTX|RX) ([0-9]+).*/\1 \2/; s/NVIDIA //')
fi

# Disco raiz e o device pai (nvme0n1p2 -> nvme0n1), que e quem aparece no
# /proc/diskstats com os contadores agregados.
ROOT_DEV=$(findmnt -no SOURCE / 2>/dev/null)
ROOT_BASE=$(basename "$ROOT_DEV")
DISCO=$(lsblk -no PKNAME "$ROOT_DEV" 2>/dev/null | head -1)
[[ -z "$DISCO" ]] && DISCO="$ROOT_BASE"

virg() { tr '.' ','; }

# ── leituras que dependem de delta ────────────────────────────────────
ler_cpu() {
    local _ u n s i w irq sirq st
    read -r _ u n s i w irq sirq st _ < /proc/stat
    cpu_total=$((u + n + s + i + w + irq + sirq + st))
    cpu_idle=$((i + w))
}

ler_disco() {
    # campo 6 = setores lidos, campo 10 = setores escritos; setor = 512 bytes
    read -r d_le d_esc < <(awk -v d="$DISCO" '$3 == d {print $6, $10; exit}' /proc/diskstats)
    : "${d_le:=0}" "${d_esc:=0}"
}

ler_cpu;   p_total=$cpu_total; p_idle=$cpu_idle
ler_disco; p_le=$d_le;         p_esc=$d_esc

while :; do
    sleep "$INTERVAL"

    # ── uptime "1d 08:41:50" ─────────────────────────────────────────
    up=${EPOCHSECONDS:-0}
    up=$(cut -d' ' -f1 /proc/uptime); up=${up%.*}
    d=$((up / 86400)); h=$(((up % 86400) / 3600)); m=$(((up % 3600) / 60)); s=$((up % 60))
    if ((d > 0)); then
        uptime_fmt=$(printf '%dd %02d:%02d:%02d' "$d" "$h" "$m" "$s")
    else
        uptime_fmt=$(printf '%02d:%02d:%02d' "$h" "$m" "$s")
    fi

    # ── CPU ──────────────────────────────────────────────────────────
    ler_cpu
    dt=$((cpu_total - p_total)); di=$((cpu_idle - p_idle))
    if ((dt > 0)); then cpu_pct=$(((100 * (dt - di) + dt / 2) / dt)); else cpu_pct=0; fi
    p_total=$cpu_total; p_idle=$cpu_idle

    # Frequencia: media dos nucleos, em GHz. scaling_cur_freq vem em kHz.
    cpu_freq=$(awk '{t+=$1; n++} END{if(n) printf "%.1f", t/n/1000000; else print "0.0"}' \
               /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null | virg)
    [[ -z "$cpu_freq" ]] && cpu_freq="0,0"
    cpu_temp=$(($(cat "$ZONE" 2>/dev/null || echo 0) / 1000))

    # ── memoria ──────────────────────────────────────────────────────
    read -r mem_pct mem_usada mem_total mem_swap < <(awk '
        /^MemTotal:/{t=$2} /^MemAvailable:/{a=$2}
        /^SwapTotal:/{st=$2} /^SwapFree:/{sf=$2}
        END{ u=t-a; printf "%d %.1f %.0f %.1f", (t?u*100/t:0), u/1048576, t/1048576, (st-sf)/1048576 }
    ' /proc/meminfo)
    mem_usada=${mem_usada/./,}; mem_swap=${mem_swap/./,}

    # ── GPU ──────────────────────────────────────────────────────────
    gpu_pct=0; gpu_usada="0,0"; gpu_total="0"; gpu_temp=0
    if [[ -n "$GPU_NOME" ]]; then
        read -r gpu_pct gpu_temp g_mu g_mt < <(
            nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total \
                       --format=csv,noheader,nounits 2>/dev/null | tr -d ',')
        : "${gpu_pct:=0}" "${gpu_temp:=0}" "${g_mu:=0}" "${g_mt:=1}"
        gpu_usada=$(awk -v v="$g_mu" 'BEGIN{printf "%.1f", v/1024}' | virg)
        gpu_total=$(awk -v v="$g_mt" 'BEGIN{printf "%.0f", v/1024}')
    fi

    # ── disco ────────────────────────────────────────────────────────
    read -r dsk_pct dsk_usado dsk_total < <(df -B1 --output=pcent,used,size / | tail -1 |
        awk '{gsub(/%/,"",$1); printf "%d %.0f %.0f", $1, $2/1000000000, $3/1000000000}')

    ler_disco
    le_bs=$(((d_le  - p_le)  * 512 / INTERVAL))
    es_bs=$(((d_esc - p_esc) * 512 / INTERVAL))
    ((le_bs < 0)) && le_bs=0; ((es_bs < 0)) && es_bs=0
    p_le=$d_le; p_esc=$d_esc
    dsk_le=$(awk -v b="$le_bs" 'BEGIN{printf "%.1f", b/1048576}' | virg)
    dsk_esc=$(awk -v b="$es_bs" 'BEGIN{printf "%.1f", b/1048576}' | virg)

    printf '{"uptime":"%s",' "$uptime_fmt"
    printf '"cpu":{"nome":"%s","pct":%d,"freq":"%s GHz","temp":%d},' \
           "$CPU_NOME" "$cpu_pct" "$cpu_freq" "$cpu_temp"
    printf '"mem":{"pct":%d,"usada":"%s","total":"%s","swap":"%s"},' \
           "$mem_pct" "$mem_usada" "$mem_total" "$mem_swap"
    printf '"gpu":{"nome":"%s","pct":%d,"usada":"%s","total":"%s","temp":%d},' \
           "${GPU_NOME:-sem GPU}" "$gpu_pct" "$gpu_usada" "$gpu_total" "$gpu_temp"
    printf '"disco":{"nome":"%s","pct":%d,"usado":"%s","total":"%s","le":"%s","esc":"%s"}}\n' \
           "$DISCO" "$dsk_pct" "$dsk_usado" "$dsk_total" "$dsk_le" "$dsk_esc"
done
