#!/usr/bin/env bash
# defpoll (20s) — relogio da barra, formato "sáb, 01 ago" + "18:30".
# Emite: {"date":"sáb, 01 ago","time":"18:30"}
#
# Os nomes de dia e mes sao tabelados aqui de proposito: nao ha garantia de que
# o locale pt_BR.UTF-8 esteja gerado nesta maquina, e `date +%a` cairia no ingles.

dias=(dom seg ter qua qui sex sáb)
meses=(jan fev mar abr mai jun jul ago set out nov dez)

read -r dow day mon time <<<"$(date '+%w %d %m %H:%M')"

# 10# forca base decimal — "08" e "09" seriam octal invalido.
mes=${meses[10#$mon - 1]}

printf '{"date":"%s, %s %s","time":"%s"}\n' "${dias[10#$dow]}" "$day" "$mes" "$time"
