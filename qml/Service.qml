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
    if (data.settings) mouseSettings = data.settings
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
  Component.onCompleted: refresh()
}
