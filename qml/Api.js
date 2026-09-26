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

// ---- Macros -----------------------------------------------------------------
// Event: { down: bool, type: 1 keyboard (USB HID usage) | 4 mouse, code, delay }

var MOUSE_NAMES = { 1: "Left Click", 2: "Right Click", 4: "Middle Click", 8: "Backward", 16: "Forward" }

// USB HID usage -> label.
var HID_NAMES = (function() {
  var t = {}
  var letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  for (var i = 0; i < 26; i++) t[4 + i] = letters[i]
  var digits = "1234567890"
  for (var d = 0; d < 10; d++) t[30 + d] = digits[d]
  var named = { 40: "Enter", 41: "Esc", 42: "Backspace", 43: "Tab", 44: "Space", 45: "-", 46: "=",
    47: "[", 48: "]", 49: "\\", 51: ";", 52: "'", 53: "`", 54: ",", 55: ".", 56: "/", 57: "Caps Lock",
    70: "Print Screen", 71: "Scroll Lock", 72: "Pause", 73: "Insert", 74: "Home", 75: "Page Up",
    76: "Delete", 77: "End", 78: "Page Down", 79: "Right", 80: "Left", 81: "Down", 82: "Up",
    83: "Num Lock", 84: "Num /", 85: "Num *", 86: "Num -", 87: "Num +", 88: "Num Enter", 99: "Num .",
    101: "Menu", 224: "Left Ctrl", 225: "Left Shift", 226: "Left Alt", 227: "Left Super",
    228: "Right Ctrl", 229: "Right Shift", 230: "Right Alt", 231: "Right Super" }
  for (var k in named) t[k] = named[k]
  for (var f = 0; f < 12; f++) t[58 + f] = "F" + (f + 1)
  for (var n = 0; n < 9; n++) t[89 + n] = "Num " + (n + 1)
  t[98] = "Num 0"
  return t
})()

// Linux evdev key code -> USB HID usage, for recording. On Wayland Qt reports
// the xkb keycode as nativeScanCode, which is evdev + 8.
var EVDEV_TO_HID = (function() {
  var t = { 1: 41, 14: 42, 15: 43, 28: 40, 57: 44, 12: 45, 13: 46, 26: 47, 27: 48, 43: 49, 39: 51,
    40: 52, 41: 53, 51: 54, 52: 55, 53: 56, 58: 57, 99: 70, 70: 71, 119: 72, 110: 73, 102: 74,
    104: 75, 111: 76, 107: 77, 109: 78, 106: 79, 105: 80, 108: 81, 103: 82, 69: 83, 98: 84, 55: 85,
    74: 86, 78: 87, 96: 88, 83: 99, 127: 101, 29: 224, 42: 225, 56: 226, 125: 227, 97: 228,
    54: 229, 100: 230, 126: 231, 87: 68, 88: 69 }
  var rows = [[16, "QWERTYUIOP"], [30, "ASDFGHJKL"], [44, "ZXCVBNM"]]
  for (var r = 0; r < rows.length; r++)
    for (var i = 0; i < rows[r][1].length; i++)
      t[rows[r][0] + i] = 4 + rows[r][1].charCodeAt(i) - 65
  for (var d = 0; d < 10; d++) t[2 + d] = 30 + d          // 1..9, 0
  for (var f = 0; f < 10; f++) t[59 + f] = 58 + f         // F1..F10
  var pad = { 71: 95, 72: 96, 73: 97, 75: 92, 76: 93, 77: 94, 79: 89, 80: 90, 81: 91, 82: 98 }
  for (var p in pad) t[p] = pad[p]
  return t
})()

function hidFromScanCode(scanCode) {
  var hid = EVDEV_TO_HID[scanCode - 8]
  return hid === undefined ? -1 : hid
}

function eventLabel(e) {
  if (!e) return ""
  if (e.type === 4) return MOUSE_NAMES[e.code] || ("Mouse " + e.code)
  return HID_NAMES[e.code] || ("Key " + e.code)
}

// Execution method, stored on the button: 1-252 times, 254/255/253 cycles.
var METHODS = [
  { value: 254, label: "Cycle until this key is released." },
  { value: 255, label: "Cycle until any key is pressed." },
  { value: 253, label: "Cycle until this key is pressed again." },
  { value: 1, label: "Cycle Times" }
]

function methodLabel(method) {
  if (method >= 1 && method <= 252) return method === 1 ? "Once" : method + " times"
  for (var i = 0; i < METHODS.length; i++) if (METHODS[i].value === method) return METHODS[i].label
  return ""
}

var INSERT_COMMANDS = ["Key Press", "Key Release", "Left Click", "Right Click", "Middle Click", "Forward", "Backward"]
var INSERT_MOUSE = { "Left Click": 1, "Right Click": 2, "Middle Click": 4, "Forward": 16, "Backward": 8 }
