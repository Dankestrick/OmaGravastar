.pragma library

// Shared helpers for OmaGravastar's QML. Keep this free of QML imports.

var EFFECTS = [
  { value: "off", label: "Off" },
  { value: "rainbow", label: "Rainbow" },
  { value: "single-color-breath", label: "Single Color Breath" },
  { value: "fixed-color", label: "Fixed Color" },
  { value: "neon", label: "Neon" },
  { value: "rainbow-breath", label: "Rainbow Breath" },
  { value: "fixed-rainbow", label: "Fixed Rainbow" }
]

var TIME_CHOICES = ["10sec", "30sec", "1min", "2min", "3min", "5min", "10min", "15min"]

var POLLING_CHOICES = [
  { value: "125", label: "125" },
  { value: "250", label: "250" },
  { value: "500", label: "500" },
  { value: "1000", label: "1K" },
  { value: "2000", label: "2K" },
  { value: "4000", label: "4K" },
  { value: "8000", label: "8K" }
]

// Gravastar's web driver presets, in its order. Values are close matches
// read from its swatches; the mouse stores whatever RGB is sent.
var PRESET_COLORS = [
  "#ff0000", "#00ffff", "#00ff00", "#ff00ff", "#ffff00", "#ff4500", "#0000ff",
  "#e4007f", "#2ea7e0", "#601986", "#ffffff", "#8fc31f", "#ff9933", "#d56fac"
]

function helperPath(url) {
  return decodeURIComponent(String(url || "").replace(/^file:\/\//, ""))
}

function parseJson(text) {
  try {
    var data = JSON.parse(String(text || "").trim() || "null")
    return data && typeof data === "object" ? data : null
  } catch (error) {
    return null
  }
}

function effectValue(label) {
  for (var i = 0; i < EFFECTS.length; i++)
    if (EFFECTS[i].label === label) return EFFECTS[i].value
  return "off"
}

// Effects whose look depends on the chosen color.
function effectUsesColor(value) {
  return value === "fixed-color" || value === "single-color-breath"
}

// The web driver greys out Speed for effects that do not move.
function effectUsesSpeed(value) {
  return value !== "off" && value !== "fixed-color" && value !== "fixed-rainbow"
}

function hexByte(n) {
  var s = Math.max(0, Math.min(255, Math.round(n))).toString(16)
  return s.length < 2 ? "0" + s : s
}

function rgbHex(r, g, b) {
  return "#" + hexByte(r) + hexByte(g) + hexByte(b)
}

function hexChannels(hex) {
  var s = String(hex || "#000000").replace("#", "")
  return [parseInt(s.substr(0, 2), 16) || 0, parseInt(s.substr(2, 2), 16) || 0, parseInt(s.substr(4, 2), 16) || 0]
}

// Hue 0..1 at full saturation and value, for the Custom Color bar.
function hueHex(h) {
  var x = (h % 1 + 1) % 1 * 6
  var i = Math.floor(x), f = x - i
  var rgb = [[1, f, 0], [1 - f, 1, 0], [0, 1, f], [0, 1 - f, 1], [f, 0, 1], [1, 0, 1 - f]][i % 6]
  return rgbHex(rgb[0] * 255, rgb[1] * 255, rgb[2] * 255)
}

function batteryText(status) {
  if (!status || !status.connected) return "Dongle not found"
  if (!status.awake && status.battery === undefined) return "Asleep"
  var text = status.battery !== undefined ? status.battery + "%" : "Battery unknown"
  if (status.charging) text += " · Charging"
  if (!status.awake) text += " · Asleep"
  return text
}

// Button actions, in the web driver's menu order. Must match ACTIONS in
// helpers/omagravastarctl.
var BUTTON_GROUPS = [
  { value: "Button", actions: ["Left Click", "Right Click", "Wheel Click", "Backward", "Forward"] },
  { value: "Polling rate switch", actions: ["Polling rate switch"] },
  { value: "Disable", actions: ["Disable"] },
  { value: "Profile switch", actions: ["Profile switch"] },
  { value: "Scroll Left/Right", actions: ["Scroll Left", "Scroll Right"] },
  { value: "Scroll Up/Down", actions: ["Scroll Up", "Scroll Down"] },
  { value: "DPI Switch", actions: ["DPI loop", "DPI +", "DPI -"] },
  { value: "Multimedia", actions: ["Media player", "Play/Pause", "Next Track", "Previous Track",
    "Stop Playback", "Mute", "Volume+", "Volume-", "Email", "Calculator", "My Computer",
    "Homepage", "Search", "Next page", "Previous page", "Stop page", "Refresh page", "Favorites"] },
  { value: "Toggle Decorative Lights", actions: ["Toggle All Decorative Lights",
    "Toggle DPI Indicator Light", "Toggle Light Strip", "Cycle Light Strip Effects"] }
]

// Where each button sits on the mouse, in the web driver's numbering.
var BUTTON_NAMES = ["Left button", "Right button", "Wheel button", "Front side button",
  "Rear side button", "Button under the wheel"]

var DEFAULT_BUTTONS = ["Left Click", "Right Click", "Wheel Click", "Forward", "Backward", "DPI loop"]

function groupOf(action) {
  for (var i = 0; i < BUTTON_GROUPS.length; i++)
    if (BUTTON_GROUPS[i].actions.indexOf(action) >= 0) return BUTTON_GROUPS[i].value
  return ""
}

function groupActions(group) {
  for (var i = 0; i < BUTTON_GROUPS.length; i++)
    if (BUTTON_GROUPS[i].value === group) return BUTTON_GROUPS[i].actions
  return []
}

// Marker positions on the photos, as fractions of the painted image.
// Buttons 1-5 sit on the top photo; button 6 is on the underside inset.
// Tuned to Dank's photos in assets/.
var BUTTON_SPOTS = [
  { photo: "top", x: 0.380, y: 0.610 },
  { photo: "top", x: 0.170, y: 0.350 },
  { photo: "top", x: 0.240, y: 0.480 },
  { photo: "top", x: 0.612, y: 0.653 },
  { photo: "top", x: 0.757, y: 0.505 },
  { photo: "bottom", x: 0.500, y: 0.500 }
]

var PROFILES = ["Profile 1", "Profile 2", "Profile 3", "Profile 4"]
