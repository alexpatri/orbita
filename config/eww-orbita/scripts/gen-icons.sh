#!/usr/bin/env bash
# Gera modules/icons.yuck e scripts/icons.sh a partir do arquivo .codepoints
# oficial da Material Symbols Rounded, instalado junto com a fonte.
#
# Glifos literais em PUA, e nao ligaduras: GTK3/Pango nao garante `liga` para
# essa fonte. Nomes com underscore porque o yuck lê hífen como subtração.
set -euo pipefail

CP="$HOME/.local/share/fonts/MaterialSymbolsRounded.codepoints"
DIR="$(cd "$(dirname "$0")/.." && pwd)"

NAMES="memory database device_thermostat
       wifi wifi_off lan
       expand_more expand_less
       graphic_eq music_off
       monitoring chevron_right
       wifi_2_bar wifi_1_bar lock settings settings_ethernet
       vpn_lock airplanemode_active eco notifications_paused mic brightness_6
       chevron_left
       shuffle shuffle_on skip_previous skip_next repeat repeat_on repeat_one_on
       pause play_arrow speaker album
       bluetooth bluetooth_disabled cloud_sync shield
       volume_up volume_down volume_off
       brightness_low brightness_medium brightness_high
       battery_full battery_charging_full
       battery_0_bar battery_1_bar battery_2_bar battery_3_bar
       battery_4_bar battery_5_bar battery_6_bar
       power_settings_new"

[[ -r "$CP" ]] || { echo "codepoints nao encontrado: $CP" >&2; exit 1; }

{
  echo ';; GERADO por scripts/gen-icons.sh — nao editar a mao.'
  echo ';; Glifos literais em PUA; ligaduras nao sao confiaveis no GTK3/Pango.'
  echo
  for n in $NAMES; do
    hex=$(grep -m1 "^$n " "$CP" | cut -d' ' -f2) || { echo "glifo ausente: $n" >&2; exit 1; }
    printf '(defvar ic_%s "%b")   ;; U+%s\n' "$n" "\\u$hex" "$(tr 'a-f' 'A-F' <<<"$hex")"
  done
} > "$DIR/modules/icons.yuck"

{
  echo '#!/usr/bin/env bash'
  echo '# GERADO por scripts/gen-icons.sh — nao editar a mao.'
  echo '# Para os scripts que emitem o icone junto do dado.'
  echo
  for n in $NAMES; do
    hex=$(grep -m1 "^$n " "$CP" | cut -d' ' -f2)
    printf 'IC_%s="%b"\n' "$(tr 'a-z' 'A-Z' <<<"$n")" "\\u$hex"
  done
} > "$DIR/scripts/icons.sh"

echo "gerados: $(grep -c defvar "$DIR/modules/icons.yuck") glifos"
