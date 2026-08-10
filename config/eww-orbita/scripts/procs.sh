#!/usr/bin/env bash
# defpoll (3s, :run-while sys_open) — tabela de processos do painel Sistema.
# Emite: [{"pid":"1842","usr":"alex","mem":"12,1%","cpu":"4,2%","cmd":"..."}, ...]
#
# Usa `args` e nao `comm`: o protótipo mostra a linha de comando inteira
# ("/usr/lib/firefox/firefox", "picom --config picom.conf"), nao so o nome.
# O README sugeria `comm`, mas ai a coluna COMANDO perderia o que ela mostra.
#
# jq -R faz o escape de JSON: linha de comando pode conter aspas e barras.
#
# O proprio `ps` e filtrado da lista: ele nasce no instante da medicao e o
# kernel o reporta a ~100% de CPU, entao apareceria SEMPRE no topo, empurrando
# os processos reais para baixo. Por isso pega 12 linhas e corta para 8 depois
# do filtro — senao o descarte encolheria a tabela.

export LC_ALL=C.UTF-8

ps -eo pid=,user=,pmem=,pcpu=,args= --sort=-pcpu 2>/dev/null |
    head -12 |
    jq -Rc --slurp '
        split("\n")
        | map(select(length > 0))
        | map(capture("^\\s*(?<pid>\\d+)\\s+(?<usr>\\S+)\\s+(?<mem>[\\d.]+)\\s+(?<cpu>[\\d.]+)\\s+(?<cmd>.*)$"))
        | map(select(.cmd | startswith("ps -eo pid=") | not))
        | .[0:8]
        | map({
            pid: .pid,
            usr: .usr,
            mem: ((.mem | sub("\\."; ",")) + "%"),
            cpu: ((.cpu | sub("\\."; ",")) + "%"),
            cmd: .cmd
          })
    '
