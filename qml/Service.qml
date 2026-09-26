import QtQuick
import Quickshell
import Quickshell.Io
import "Api.js" as Api

// Headless half of OmaGravastar. One instance for the whole shell, so battery
// polling and low battery alerts happen once no matter how many monitors show
// the bar. The bar widget reads everything from here.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property var settings: ({})

  // Last reply from `omagravastarctl status` (or from a change, which returns
  // the same shape). `mouseSettings` keeps the last values we read while the
  // mouse was awake, so the panel still shows them when it dozes off.
  property var status: ({})
  property var mouseSettings: null
  property string lastError: ""
  property bool panelOpen: false
  property bool windowOpen: false

  // The Buttons window asks the bar dropdown on its screen to take over.
  // Sent a moment after the window closes: hiding the plugin also closes its
  // dropdown, so the dropdown has to open after that.
  signal miniRequested(string screenName)
  property string miniScreen: ""
  function showMini(screenName) {
    miniScreen = String(screenName || "")
    miniHandoff.restart()
  }

  Timer {
    id: miniHandoff
    interval: 250
    onTriggered: root.miniRequested(root.miniScreen)
  }

  readonly property string helper: Api.helperPath(Qt.resolvedUrl("../helpers/omagravastarctl"))
  readonly property bool connected: !!(status && status.connected)
  readonly property bool awake: !!(status && status.awake)
  readonly property bool busy: actionProc.running || pending.length > 0
  readonly property int battery: status && status.battery !== undefined ? Number(status.battery) : -1
  readonly property bool charging: !!(status && status.charging)
  readonly property string batteryText: Api.batteryText(status)

  // Export / import. The file picker and the confirm step run here, not in
  // the dropdown, so they keep going if the dropdown closes behind them.
  property string notice: ""
  property string pickerStep: ""
  property string importPath: ""
  readonly property string profileFolder: (Quickshell.env("HOME") || "") + "/Documents/OmaGravastar"
  readonly property int profileNumber: status && status.profile ? Number(status.profile) : 1

  function exportProfile() {
    if (picker.running) return
    pickerStep = "export"
    picker.command = ["sh", "-c", 'mkdir -p "$1" && zenity --file-selection --save --confirm-overwrite '
      + '--title="Export mouse profile" --filename="$1/$2" --file-filter="Mouse profile (.bin) | *.bin"',
      "sh", profileFolder, "Mercury X Pro - Profile " + profileNumber + ".bin"]
    picker.running = true
  }

  function importProfile() {
    if (picker.running) return
    pickerStep = "import"
    picker.command = ["sh", "-c", 'mkdir -p "$1" && zenity --file-selection --title="Import mouse profile" '
      + '--filename="$1/" --file-filter="Mouse profile (.bin) | *.bin"', "sh", profileFolder]
    picker.running = true
  }

  Process {
    id: picker
    stdout: StdioCollector { id: pickerOut; waitForEnd: true }
    onExited: function(code) {
      var path = String(pickerOut.text || "").trim()
      var step = root.pickerStep
      root.pickerStep = ""
      if (step === "confirm") {
        if (code === 0) {
          root.notice = "Importing into Profile " + root.profileNumber + "…"
          root.change(["import", root.importPath], "import")
        }
        return
      }
      if (code !== 0 || path === "") return
      if (step === "export") {
        if (!/\.bin$/.test(path)) path += ".bin"
        root.notice = "Exporting Profile " + root.profileNumber + "…"
        root.change(["export", path], "export")
      } else if (step === "import") {
        root.importPath = path
        root.pickerStep = "confirm"
        picker.command = ["zenity", "--question", "--title=Import mouse profile",
          "--ok-label=Import", "--cancel-label=Cancel",
          "--text=Import " + path.split("/").pop() + " into Profile " + root.profileNumber
            + "?\n\nIts current settings are replaced. A backup is saved first."]
        picker.running = true
      }
    }
  }

  // ---- Macro list -------------------------------------------------------
  // Gravastar's web driver keeps its macro list in the browser; the mouse
  // only stores macros that are on a button. This list is ours, saved to
  // ~/.config/omagravastar/macros.json.
  property var macros: []
  readonly property string macroFile: (Quickshell.env("XDG_CONFIG_HOME") || ((Quickshell.env("HOME") || "") + "/.config"))
    + "/omagravastar/macros.json"

  function macroIndex(name) {
    for (var i = 0; i < macros.length; i++) if (macros[i].name === name) return i
    return -1
  }

  function saveMacros(list) {
    macros = list
    macroStore.setText(JSON.stringify(list, null, 2) + "\n")
  }

  // Macros already on the mouse's buttons join the list so they can be edited.
  function adoptMouseMacros(settings) {
    var buttons = settings && settings.buttons ? settings.buttons : []
    var list = macros.slice(), changed = false
    for (var i = 0; i < buttons.length; i++) {
      var m = buttons[i].macro
      if (!m || !m.name || macroIndex(m.name) >= 0) continue
      var known = false
      for (var j = 0; j < list.length; j++) if (list[j].name === m.name) known = true
      if (known) continue
      list.push({ name: m.name, method: buttons[i].method || 1, events: m.events })
      changed = true
    }
    if (changed) saveMacros(list)
  }

  // Put a macro on a button (1-6).
  function assignMacro(button, macro) {
    change(["macro", String(button), JSON.stringify({ name: macro.name, method: macro.method || 1, events: macro.events })],
      "button " + button)
  }

  FileView {
    id: macroStore
    path: root.macroFile
    printErrors: false
    atomicWrites: true
    onLoaded: {
      var data = Api.parseJson(text())
      root.macros = data instanceof Array ? data : []
    }
    onLoadFailed: root.macros = []
  }

  // Changes wait here while another command runs. Keyed by setting so a slider
  // drag only sends its final value.
  property var pending: []

  readonly property int lowBattery: 25
  readonly property int criticalBattery: 15
  property int alertedLevel: 101

  function refresh() {
    if (!statusProc.running && !actionProc.running)
      statusProc.running = true
  }

  // args: e.g. ["light", "brightness", "5"]. `key` groups repeat changes.
  function change(args, key) {
    var next = []
    var id = key || args.slice(0, 2).join(" ")
    for (var i = 0; i < pending.length; i++)
      if (pending[i].key !== id) next.push(pending[i])
    next.push({ key: id, args: args })
    pending = next
    runNext()
  }

  function runNext() {
    if (actionProc.running || statusProc.running || pending.length === 0) return
    var job = pending[0]
    pending = pending.slice(1)
    actionProc.command = [root.helper].concat(job.args)
    actionProc.running = true
  }

  function accept(data) {
    if (!data) return
    // Asleep replies carry no battery reading; keep the last one we saw.
    if (data.connected && !data.awake && data.battery === undefined && status && status.battery !== undefined)
      data = Object.assign({}, data, { battery: status.battery, charging: status.charging })
    status = data
    if (data.settings) {
      mouseSettings = data.settings
      if (data.awake) adoptMouseMacros(data.settings)
    }
    checkBattery()
  }

  function checkBattery() {
    if (battery < 0) return
    if (charging || battery > lowBattery + 5) { alertedLevel = 101; return }
    if (battery <= criticalBattery && alertedLevel > criticalBattery) {
      alertedLevel = criticalBattery
      Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "OmaGravastar",
        "Mouse battery critical", battery + "% left. Plug in your Mercury X Pro."])
    } else if (battery <= lowBattery && alertedLevel > lowBattery) {
      alertedLevel = lowBattery
      Quickshell.execDetached(["notify-send", "-a", "OmaGravastar",
        "Mouse battery low", battery + "% left."])
    }
  }

  Process {
    id: statusProc
    command: [root.helper, "status"]
    stdout: StdioCollector { id: statusOut; waitForEnd: true }
    stderr: StdioCollector { id: statusErr; waitForEnd: true }
    onExited: function(code) {
      var data = Api.parseJson(statusOut.text)
      if (data) {
        root.accept(data)
        if (data.connected) root.lastError = ""
      } else if (code !== 0) {
        root.lastError = String(statusErr.text || "Could not read the mouse.").trim()
      }
      root.runNext()
    }
  }

  Process {
    id: actionProc
    stdout: StdioCollector { id: actionOut; waitForEnd: true }
    stderr: StdioCollector { id: actionErr; waitForEnd: true }
    onExited: function(code) {
      var data = Api.parseJson(actionOut.text)
      if (code === 0 && data) {
        root.lastError = ""
        if (data.file) root.notice = "Saved " + String(data.file).split("/").pop()
        else if (data.backup) root.notice = "Imported. The old settings were backed up to " + data.backup
        root.accept(data)
      } else {
        root.lastError = data && data.error ? String(data.error)
          : String(actionErr.text || "The mouse did not take that change.").trim()
        if (code === 3) root.status = Object.assign({}, root.status, { awake: false })
      }
      if (root.pending.length > 0) root.runNext()
      else root.refresh()
    }
  }

  // Poll often while the panel is open, rarely otherwise; the bar only needs
  // battery and awake state.
  Timer {
    interval: root.panelOpen || root.windowOpen ? 3000 : 60000
    repeat: true
    running: true
    onTriggered: root.refresh()
  }

  onPanelOpenChanged: if (panelOpen) refresh()
  onWindowOpenChanged: if (windowOpen) refresh()
  Component.onCompleted: {
    Quickshell.execDetached(["mkdir", "-p", macroFile.replace(/\/[^/]*$/, "")])
    refresh()
  }
}
