# Changelog

## 0.2.1

- `scripts/install.sh` no longer copies over whatever is at the plugin path.
  It only replaces a folder it created itself that still holds exactly the
  files it installed (listed with SHA-256 in `.omagravastar-dev-install`), and
  leaves an `omarchy plugin add` checkout or any folder with other or changed
  files untouched.
- Macros: if `~/.config/omagravastar/macros.json` exists but can't be read, the
  macro list is not saved over it, and the dropdown says so. Before, a damaged
  file was replaced the next time the mouse reported a macro on a button.
  The Macros window now says "Not saved." and keeps your draft instead of
  showing "Saved." when that happens. The warning clears by itself once the
  file can be read again.
- Developer install steps moved from the README to `CONTRIBUTING.md`.

## 0.2.0

- Buttons window: a larger floating window with a photo of the mouse and numbered, clickable buttons, opened from the Buttons tab. A switch (or `M`) goes back to the dropdown on the same monitor.
- Button actions: Button, DPI Switch, Scroll, 18 Multimedia keys, light toggles, Polling rate switch, Profile switch, Disable, Firepower Button and DPI Lock. One button always stays on Left Click.
- Macros window: macro list, key list with delays, recording (keys and mouse clicks), auto or fixed delay, Insert command, execution method, and Put on button. The list is kept in `~/.config/omagravastar/macros.json`.
- Profiles: switch between the mouse's 4 onboard profiles. Export and Import a profile in Gravastar's web driver `.bin` format, with a backup before every import.
- Button markers use the mouse's Fixed Color.
- Key Response Time is capped at the mouse's 15 ms.
- Fixed: writes longer than 10 bytes are split into the mouse's packet size.

## 0.1.0

First version.

- Bar icon with a battery tooltip (charging and asleep shown), and low battery alerts at 25% and 15%.
- Dropdown with Overview, DPI, Lighting, Settings and Device tabs, built from the Omarchy shell's own controls so it follows the active theme.
- DPI stages and colors, active stage, stage count, polling rate, Select mode, LOD, Highest performance and timer, Ripple Control, Angle snapping, Motion sync.
- Lighting effect, brightness, speed, lights off when moving, and a color picker with presets.
- Mouse Sleep Time, Key Response Time, Long distance mode (asks first).
- Shows the last known settings while the mouse sleeps.
