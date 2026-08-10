#!/usr/bin/env bash
# Marca todas as notificacoes como lidas, gravando o instante atual.
# Chamado quando o painel de Notificacoes e aberto — e o que apaga o ponto
# ambar do relogio, como o design pede.
mkdir -p "$HOME/.cache/eww-orbita"
date +%s > "$HOME/.cache/eww-orbita/notif-lidas"
