#!/usr/bin/env bash
# Atualiza a variavel `notif`. E SO.
#
# Antes isto fechava e reabria a janela para ela encolher, porque janela GTK
# cresce mas nao encolhe sozinha. So que reabrir faz o eww DESTRUIR e recriar a
# janela X11 — e era isso que piscava na tela a cada clique.
#
# Sem a reconstrucao, a janela mantem a altura ate a proxima vez que o painel
# for aberto. Nao fica um vao borrado no lugar: o cartao preenche a janela e a
# area que sobra exibe o fundo dele, rgb(9,14,18) — medido. Parece um cartao
# com mais espaco embaixo, e nao um buraco.

DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$HOME/.local/bin/eww" --config "$HOME/.config/eww-orbita" \
     update "notif=$("$DIR/notif.sh")"
