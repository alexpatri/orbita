# Órbita

Rice de desktop para **Debian 13 + bspwm**, em 1920×1080. Barra flutuante em eww,
cinco painéis dropdown, toasts em dunst e compositing em picom.

Implementação de um handoff de design em HTML — o protótipo é referência visual,
não código: tudo foi recriado em `.yuck`/`.scss`, `dunstrc` e `picom.conf`.

## O que tem

| | |
|---|---|
| **Barra** | workspaces, CPU/RAM/temperatura, rede, mídia (MPRIS), tray, volume/brilho/bateria, relógio |
| **Sistema** | CPU, memória, GPU e disco em cartões, mais tabela de processos |
| **Rede** | lista de Wi-Fi com sinal, conexão por clique, interface cabeada fixa |
| **Settings** | bluetooth, VPN, modo avião, perfil de energia, não perturbe, e sliders de volume/mic/brilho |
| **Calendário + Notificações** | grade navegável, eventos do khal e do systemd, histórico do dunst |
| **Player** | capa, progresso, controles, saída de áudio |

## Instalação

```sh
sudo apt install fonts-jetbrains-mono fonts-ibm-plex rofi playerctl \
     power-profiles-daemon rfkill khal jq
./assets/fontes.sh     # Material Symbols Rounded, não versionada (15 MB)
./install.sh           # cria os symlinks para ~/.config
```

Depois, no `~/.config/bspwm/bspwmrc`:

```sh
. "$HOME/.config/bspwm/orbita.sh"
```

E gere o `dunstrc`: `~/.config/dunst/scripts/colors.sh`.

## Como está organizado

```
config/eww-orbita/
├── eww.yuck            includes
├── eww.scss            imports
├── modules/            um .yuck por janela  (bar, sistema, rede, settings,
│                       calendario, player, panels, icons)
├── styles/             _tokens.scss + _bar.scss + _panel.scss
└── scripts/            uma fonte de dado por script, saída JSON de uma linha
```

O padrão é sempre o mesmo: **um script por fonte de dado**, emitindo JSON de uma
linha, lido campo a campo no yuck. Os scripts pesados usam `:run-while`, então
nada roda com o painel fechado.

## Arquivos gerados — não edite

| gerado | fonte |
|---|---|
| `~/.config/dunst/dunstrc` | `config/dunst/dunstrc.template` |
| `modules/icons.yuck`, `scripts/icons.sh` | `scripts/gen-icons.sh` + `assets/*.codepoints` |

O `dunstrc` é reescrito toda vez que o `colors.sh` roda: editar ele direto é
perder o trabalho na próxima execução.
