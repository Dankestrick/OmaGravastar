# OmaGravastar

**Gravastar Mercury X Pro controls in the Omarchy bar, not a web app.**

OmaGravastar is a Quickshell plugin: a mouse icon on the bar that shows your
battery when you hover it, and a dropdown with every setting from Gravastar's
web driver. It talks to the mouse through its 2.4G dongle, works offline, and
follows your Omarchy theme.

![OmaGravastar DPI tab with stages, polling rate and sensor settings](docs/screenshots/DPI.png)

Plugin id: `io.github.dankestrick.omagravastar`

## What it does

| Tab | Settings |
| --- | --- |
| **Overview** | DPI, polling rate, LOD, key response time, profile, battery |
| **Buttons** | Opens a larger window: pick any of the 6 buttons from the list or the picture, then choose its action (buttons, DPI switch, scroll, 18 multimedia keys, light toggles, polling rate switch, disable) |
| **DPI** | Number of DPI stages, each stage's DPI, active stage, polling rate (125Hz to 8000Hz), Select mode (LP / HP), LOD (0.7mm / 1mm / 2mm), Highest performance and its timer, Ripple Control, Angle snapping, Motion sync |
| **Lighting** | Effect (Off, Rainbow, Single Color Breath, Fixed Color, Neon, Rainbow Breath, Fixed Rainbow), Brightness, Speed, turn off lights when moving, color picker with presets |
| **Settings** | Mouse Sleep Time, Key Response Time, Long distance mode |
| **Device** | Receiver and mouse firmware versions, battery voltage |

The bar icon's tooltip shows the battery, for example `Mercury X Pro · 45%`,
plus **Charging** or **Asleep** when that applies. You get a notification when
the battery drops to 25% and again at 15%.

| Overview | Lighting | Settings |
| --- | --- | --- |
| ![Overview tab](docs/screenshots/Overview.png) | ![Lighting tab with the color picker](docs/screenshots/Lighting.png) | ![Settings tab](docs/screenshots/Settings.png) |

### When the mouse is asleep

The mouse sleeps after a few seconds without moving, and it can't answer while
it sleeps. The panel keeps showing your last settings, greyed out, and asks you
to move the mouse to change them.

## Install

You need [Omarchy](https://omarchy.org) 4, a Gravastar Mercury X Pro with its
2.4G dongle plugged in, and Python 3 (Omarchy already has it).

**1. Let your session talk to the dongle.** Linux only lets root use the
mouse's settings channel until you add this udev rule. It gives your logged-in
session access to the Gravastar dongle (`3554:f54b`) and no other device.

```bash
echo 'SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3554", ATTRS{idProduct}=="f54b", TAG+="uaccess"' | sudo tee /etc/udev/rules.d/70-gravastar-mouse.rules
sudo udevadm control --reload-rules && sudo udevadm trigger
```

**2. Add the plugin.**

```bash
omarchy plugin add https://github.com/Dankestrick/OmaGravastar.git --enable
```

That clones into `~/.config/omarchy/plugins/io.github.dankestrick.omagravastar/`
and places the icon on the **right** of the bar. To move it:

```bash
omarchy bar move io.github.dankestrick.omagravastar --section right
```

**3. Make the Buttons window float.** Add this to `~/.config/hypr/hyprland.lua`
so the Buttons window opens as a centered floating window instead of a tiled
one:

```lua
o.window({ title = "^OmaGravastar$" }, {
  float = true,
  size = { 1440, 840 },
  center = true,
})
```

Do not symlink a git checkout into the plugins folder. Omarchy rejects a
plugin tree that is a symlink.

## Use

| Action | What happens |
| --- | --- |
| Hover the bar icon | Battery, charging and asleep state |
| Left-click the bar icon | Open or close the settings dropdown |
| Right-click the bar icon | Read the mouse again |
| `←` / `→` in the dropdown | Switch tabs |
| `Esc` | Close the dropdown |

Changes go to the mouse right away. OmaGravastar reads each one back to make
sure the mouse kept it, so the dropdown always shows what the mouse really has.

Turning on **Long distance mode** asks first, like the web driver, because it
shortens battery life.

Pairing, restoring factory settings, macros, combo keys, Firepower and DPI
Lock are not in OmaGravastar yet. Use Gravastar's web driver for those.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| "Dongle not found" | Plug the dongle in. Check that `lsusb` lists `3554:f54b`. |
| "No permission to open /dev/hidraw…" | Install the udev rule above, then unplug and replug the dongle. |
| Settings are greyed out | The mouse is asleep. Move it. |

The helper also works from a terminal, which helps when reporting a problem:

```bash
~/.config/omarchy/plugins/io.github.dankestrick.omagravastar/helpers/omagravastarctl status
```

## Remove

```bash
omarchy plugin remove io.github.dankestrick.omagravastar --yes
```

That removes the plugin files and the bar icon. Omarchy keeps a backup copy
named `~/.config/omarchy/plugins/.io.github.dankestrick.omagravastar.bak.<date>`,
which you can delete. It leaves the udev rule and the settings cache. To
remove those too:

```bash
sudo rm -f /etc/udev/rules.d/70-gravastar-mouse.rules
sudo udevadm control --reload-rules && sudo udevadm trigger
rm -rf ~/.cache/omagravastar
```

Your mouse keeps whatever settings you last chose. They are stored on the
mouse, not in the plugin.

## Develop from a clone

`scripts/install.sh` copies `manifest.json`, `qml/` and `helpers/` into the
live plugin folder. Use it while hacking, not as the public install.

```bash
git clone https://github.com/Dankestrick/OmaGravastar.git
cd OmaGravastar
./scripts/install.sh
omarchy restart shell
./scripts/validate.sh
```

The shell keeps the old QML loaded until it restarts, so run
`omarchy restart shell` after QML changes. Helper changes apply right away.

`research/` holds the scripts and settings dumps used to map the mouse's
protocol. `helpers/omagravastarctl --help` lists every command.

## Credits

The mouse speaks the same CompX protocol as VGN, VXE and ATK mice.
[OpenMouse](https://github.com/OpenMouse-Project/openmouse) documented its
commands and settings layout, which made this plugin possible. Lighting, sleep
time, long distance mode and Select mode were mapped on a real Mercury X Pro by
comparing its settings before and after each change in Gravastar's web driver.

The pictures in `assets/` are photos of Dankestrick's own Mercury X Pro
and are covered by this repo's MIT license.

The bar icon and dropdown layout follow
[omarchy-wlmouse](https://github.com/LarsLarkin/omarchy-wlmouse).

## License

[MIT](LICENSE) © 2026 Dankestrick.
