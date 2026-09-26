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
