# plasma-sysbar

A Plasma 6 panel widget (`io.github.aethryl.sysbar`): CPU, RAM and GPU meters and network rates in the bar; its notch has history graphs, per-core load and top processes.

## Install

```sh
git clone git@github.com:Aethryl/plasma-sysbar.git
cd plasma-sysbar
./install.sh
```

`install.sh` symlinks `plasmoid/` into `${XDG_DATA_HOME:-~/.local/share}/plasma/plasmoids/`, so edits are live. After a QML change run `systemctl --user restart plasma-plasmashell`.

Then add it to a panel: right-click the panel, Edit Mode, Add Widgets, "sysbar". In my setup the panel order is sysbar, claudebar, mural, system tray.

## Requirements

- Plasma 6 (tested on 6.7.5)

## Licence

MIT, see `LICENSE`.
