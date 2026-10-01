# Working on OmaGravastar

## Layout

| Path | What it is |
| --- | --- |
| `manifest.json` | Omarchy plugin manifest (service + bar widget) |
| `qml/Service.qml` | Runs the helper, keeps the mouse state and the macro list |
| `qml/BarWidget.qml` | Bar icon |
| `qml/Panel.qml` | Dropdown with the settings tabs |
| `qml/MacroView.qml` | Buttons and Macros window |
| `qml/Api.js` | Shared helpers for the QML |
| `helpers/omagravastarctl` | Python helper that talks to the dongle. `--help` lists every command |
| `udev/70-gravastar-mouse.rules` | The udev rule users install once |
| `assets/` | Photos of the mouse for the Buttons window |
| `scripts/` | Developer install, uninstall and checks |
| `research/` | Scripts and settings dumps used to map the mouse's protocol |

## Developer install

`scripts/install.sh` copies `manifest.json`, `qml/`, `helpers/`, `assets/` and
`udev/` into `~/.config/omarchy/plugins/io.github.dankestrick.omagravastar/`.
Use it while hacking, not as the public install.

It only replaces a folder it created itself that still holds exactly what it
put there: the `.omagravastar-dev-install` marker lists each installed file
with its SHA-256. If the folder has any other file, a changed file, or came
from `omarchy plugin add`, it stops without changing anything. Remove that copy
first with `omarchy plugin remove io.github.dankestrick.omagravastar`.

From a checkout of this repository:

```bash
./scripts/install.sh
omarchy restart shell
```

The shell keeps the old QML loaded until it restarts, so run
`omarchy restart shell` after QML changes. Helper changes apply right away.

## Checks

```bash
./scripts/validate.sh
```

It runs `omarchy plugin validate`, `qmllint` on every QML file, checks that
every `Text` sets `textFormat`, checks the helper's syntax, and fails on
symlinks in the plugin tree.
