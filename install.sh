#!/usr/bin/env bash
# Liga este repo ao ~/.config por symlinks.
#
# Symlink, e nao copia: assim editar em ~/.config e editar o repo. Com copia
# daria para editar num lugar, esquecer do outro, e o repo passar a mentir.
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"

liga() {  # liga <origem no repo> <destino no ~>
    local src="$REPO/$1" dst="$HOME/$2"
    mkdir -p "$(dirname "$dst")"
    if [[ -e "$dst" && ! -L "$dst" ]]; then
        mv "$dst" "$dst.antes-do-orbita"
        echo "  guardou o antigo em $dst.antes-do-orbita"
    fi
    ln -sfn "$src" "$dst"
    printf '  %-38s -> %s\n' "~/$2" "$1"
}

echo "Ligando arquivos:"
liga config/eww-orbita            .config/eww-orbita
liga config/dunst/dunstrc.template .config/dunst/dunstrc.template
liga config/picom/picom.conf       .config/picom/picom.conf
liga config/bspwm/orbita.sh        .config/bspwm/orbita.sh
liga config/khal/config            .config/khal/config

echo
echo "Falta fazer a mao:"
echo "  1. assets/fontes.sh                      (baixa a Material Symbols)"
echo "  2. adicionar ao ~/.config/bspwm/bspwmrc: . \"\$HOME/.config/bspwm/orbita.sh\""
echo "  3. ~/.config/dunst/scripts/colors.sh     (gera o dunstrc do template)"
echo "  4. sudo apt install fonts-jetbrains-mono fonts-ibm-plex rofi playerctl \\"
echo "       power-profiles-daemon rfkill khal jq"
