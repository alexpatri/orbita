#!/usr/bin/env bash
# "limpar tudo": esvazia o historico do dunst E a lista de dispensadas.
#
# A lista de ocultas precisa ir junto: sem historico ela nao filtra mais nada,
# e IDs reciclados depois de um restart do dunst poderiam esconder notificacao
# nova por engano.

DIR="$(cd "$(dirname "$0")" && pwd)"
dunstctl history-clear 2>/dev/null
: > "$HOME/.cache/eww-orbita/notif-ocultas"
"$DIR/notif-refresh.sh"

# Com zero notificacoes a janela vira um retangulo vazio grande, porque ela nao
# encolhe sozinha. Aqui FECHAR e melhor que mostrar a caixa vazia — e como e
# so fechar, sem reabrir, nao ha o piscar da reconstrucao. Ela volta no proximo
# clique no relogio, ja no tamanho certo.
exec "$HOME/.local/bin/eww" --config "$HOME/.config/eww-orbita" close panel-notif
