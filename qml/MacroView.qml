import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "Api.js" as Api

// The Macros view of the big window, laid out like Gravastar's web driver:
// Macro List on the left, Key List in the middle, recording and options on
// the right. Macros live in the service's list (macros.json); "Put on
// button" writes one to a mouse button.
Item {
  id: view

  property var service: null
  property color fg: Color.foreground
  property color dim: Qt.darker(Color.foreground, 1.4)
  property color markerColor: Color.accent
  property string fontFamily: Style.font.family
  property bool canEdit: false

  readonly property var macros: service ? service.macros : []
  property int macroIndex: 0
  property int eventIndex: -1
  // A working copy of the selected macro; Save puts it back in the list.
  property var draft: null
  property bool dirty: false

  property bool recording: false
  property bool recordMouse: false
  property bool autoDelay: true
  property int defaultDelay: 10
  property double lastEventAt: 0
  property string waitingFor: ""      // "Key Press" / "Key Release" while inserting
  property int targetButton: 6
  property string renameText: ""
  property bool renaming: false
  property string message: ""

  readonly property var events: draft ? draft.events : []

  function loadDraft() {
    var m = macros[macroIndex]
    draft = m ? JSON.parse(JSON.stringify(m)) : null
    if (draft && !draft.method) draft.method = 1
    eventIndex = -1
    dirty = false
    recording = false
    waitingFor = ""
  }

  onMacrosChanged: if (!dirty) loadDraft()
  Component.onCompleted: loadDraft()

  function setDraft(next) {
    draft = next
    dirty = true
  }

  function copyDraft() { return JSON.parse(JSON.stringify(draft)) }

  function uniqueName(base) {
    var name = base, n = 2
    while (service && service.macroIndex(name) >= 0) name = base + " " + n++
    return name
  }

  function newMacro() {
    if (!service) return
    var list = macros.slice()
    list.push({ name: uniqueName("Macro"), method: 1, events: [] })
    dirty = false
    service.saveMacros(list)
    macroIndex = list.length - 1
    loadDraft()
    renameText = draft.name
    renaming = true
  }

  function deleteMacro() {
    if (!service || !macros[macroIndex]) return
    var list = macros.slice()
    list.splice(macroIndex, 1)
    dirty = false
    service.saveMacros(list)
    macroIndex = Math.max(0, Math.min(macroIndex, list.length - 1))
    loadDraft()
  }

  function save() {
    if (!service || !draft) return
    if (renaming) finishRename()
    var list = macros.slice()
    var clash = service.macroIndex(draft.name)
    if (clash >= 0 && clash !== macroIndex) { message = "There is already a macro with the same name."; return }
    list[macroIndex] = copyDraft()
    dirty = false
    service.saveMacros(list)
    message = "Saved."
    // Buttons already running this macro get the new version.
    var buttons = service.mouseSettings && service.mouseSettings.buttons ? service.mouseSettings.buttons : []
    for (var i = 0; i < buttons.length; i++)
      if (buttons[i].macro && buttons[i].macro.name === macros[macroIndex].name && canEdit)
        service.assignMacro(i + 1, draft)
  }

  function finishRename() {
    var name = renameText.trim().substring(0, 30)
    renaming = false
    if (!name || !draft || name === draft.name) return
    var next = copyDraft()
    next.name = name
    setDraft(next)
  }

  function putOnButton() {
    if (!service || !draft || !canEdit) return
    if (draft.events.length === 0) { message = "Record or insert some keys first."; return }
    if (dirty) save()
    service.assignMacro(targetButton, draft)
    message = "Put " + draft.name + " on button " + targetButton + "."
  }

  // ---- Events -----------------------------------------------------------
  function addEvent(e) {
    if (!draft) return
    var next = copyDraft()
    if (next.events.length >= 70) { message = "The number of macro keys has reached the upper limit."; return }
    var now = Date.now()
    // The delay belongs to the event before this one: how long to wait
    // before the next event.
    if (next.events.length > 0) {
      var prev = next.events[next.events.length - 1]
      prev.delay = autoDelay && lastEventAt > 0 ? Math.max(1, Math.min(65535, now - lastEventAt)) : defaultDelay
    }
    e.delay = defaultDelay
    var at = eventIndex >= 0 && !recording ? eventIndex + 1 : next.events.length
    next.events.splice(at, 0, e)
    lastEventAt = now
    setDraft(next)
    eventIndex = at
  }

  function deleteEvent() {
    if (!draft || eventIndex < 0) return
    var next = copyDraft()
    next.events.splice(eventIndex, 1)
    setDraft(next)
    eventIndex = Math.min(eventIndex, next.events.length - 1)
  }

  function setDelay(index, ms) {
    var next = copyDraft()
    next.events[index].delay = ms
    setDraft(next)
  }

  function toggleRecording() {
    if (!draft) return
    recording = !recording
    waitingFor = ""
    lastEventAt = 0
    message = recording ? "Recording. Type keys" + (recordMouse ? " or click the Key List" : "") + ", then Stop recording (or Esc)." : ""
    if (recording) keyCatcher.forceActiveFocus()
  }

  // While recording or waiting for a key, all keys come here first, so a
  // focused button or field can't swallow the key presses.
  Item {
    id: keyCatcher
    width: 0
    height: 0
    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_Escape && !event.isAutoRepeat) {
        view.recording = false
        view.waitingFor = ""
        view.message = ""
      } else {
        view.handleKey(event, true)
      }
      event.accepted = true
    }
    Keys.onReleased: function(event) {
      if (event.key !== Qt.Key_Escape) view.handleKey(event, false)
      event.accepted = true
    }
  }

  function insertCommand(command) {
    if (!draft) return
    if (Api.INSERT_MOUSE[command] !== undefined) {
      var code = Api.INSERT_MOUSE[command]
      lastEventAt = 0
      addEvent({ down: true, type: 4, code: code })
      addEvent({ down: false, type: 4, code: code })
      return
    }
    waitingFor = command
    message = "Press the key for " + command + "."
    keyCatcher.forceActiveFocus()
  }

  // Called by the window for every key while this view is showing.
  function handleKey(event, down) {
    if (event.isAutoRepeat) return false
    if (!recording && waitingFor === "") return false
    var hid = Api.hidFromScanCode(event.nativeScanCode)
    if (hid < 0) { message = "That key can't be recorded."; return true }
    if (waitingFor !== "") {
      if (!down) return true
      addEvent({ down: waitingFor === "Key Press", type: 1, code: hid })
      waitingFor = ""
      message = ""
      return true
    }
    addEvent({ down: down, type: 1, code: hid })
    return true
  }

  // Dank's mouse photo behind the view, like the Buttons view, dimmed so the
  // lists on top stay readable.
  Image {
    anchors.centerIn: parent
    width: parent.width * 0.72
    height: parent.height * 0.95
    z: -1
    source: Qt.resolvedUrl("../assets/mouse-top.png")
    fillMode: Image.PreserveAspectFit
    smooth: true
    mipmap: true
    opacity: 0.35
  }

  // ---------- Left: Macro List ----------
  Column {
    id: listColumn
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: Style.space(280)
    spacing: Style.space(8)

    PanelSectionHeader { text: "MACRO LIST"; foreground: view.fg; fontFamily: view.fontFamily }

    ListView {
      id: macroList
      width: parent.width
      height: parent.height - Style.space(110)
      clip: true
      spacing: Style.space(4)
      model: view.macros
      delegate: CursorSurface {
        id: macroRow
        required property var modelData
        required property int index
        width: ListView.view.width
        implicitHeight: Style.spacing.controlHeight + Style.space(6)
        foreground: view.fg
        current: view.macroIndex === index
        hasCursor: macroMouse.containsMouse

        MouseArea {
          id: macroMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: { view.macroIndex = macroRow.index; view.loadDraft() }
          onDoubleClicked: { view.renameText = macroRow.modelData.name; view.renaming = true }
        }

        Text {
          anchors.left: parent.left
          anchors.leftMargin: Style.space(12)
          anchors.verticalCenter: parent.verticalCenter
          visible: !(view.renaming && macroRow.current)
          textFormat: Text.PlainText
          text: macroRow.current && view.draft ? view.draft.name + (view.dirty ? " •" : "") : macroRow.modelData.name
          color: view.fg
          font.family: view.fontFamily
          font.pixelSize: Style.font.body
        }

        TextField {
          anchors.fill: parent
          anchors.margins: Style.space(2)
          visible: view.renaming && macroRow.current
          text: view.renameText
          foreground: view.fg
          font.family: view.fontFamily
          onVisibleChanged: if (visible) forceActiveFocus()
          onTextChanged: view.renameText = text
          onAccepted: view.finishRename()
        }
      }
    }

    Text {
      visible: view.macros.length === 0
      width: parent.width
      wrapMode: Text.WordWrap
      text: "No macros yet. Make one with New Macro."
      color: view.dim
      font.family: view.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    Row {
      spacing: Style.space(8)
      Button { text: "New Macro"; bordered: true; foreground: view.fg; fontFamily: view.fontFamily; onClicked: view.newMacro() }
      Button {
        text: "Rename"; bordered: true; enabled: !!view.draft; foreground: view.fg; fontFamily: view.fontFamily
        onClicked: { view.renameText = view.draft.name; view.renaming = true }
      }
      Button { text: "Delete"; bordered: true; enabled: !!view.draft; foreground: view.fg; fontFamily: view.fontFamily; onClicked: view.deleteMacro() }
    }
  }

  // ---------- Middle: Key List ----------
  Column {
    id: keyColumn
    anchors.left: listColumn.right
    anchors.leftMargin: Style.space(28)
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: Style.space(430)
    spacing: Style.space(8)

    PanelSectionHeader { text: "KEY LIST"; foreground: view.fg; fontFamily: view.fontFamily }

    Item {
      width: parent.width
      height: parent.height - Style.space(110)

      ListView {
        id: keyList
        anchors.fill: parent
        clip: true
        spacing: Style.space(2)
        model: view.events
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        onCountChanged: if (view.recording) positionViewAtEnd()
        delegate: CursorSurface {
          id: eventRow
          required property var modelData
          required property int index
          width: ListView.view.width
          implicitHeight: Style.spacing.controlHeight + Style.space(4)
          foreground: view.fg
          current: view.eventIndex === index
          hasCursor: eventMouse.containsMouse

          MouseArea {
            id: eventMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: !view.recording || !view.recordMouse
            onClicked: view.eventIndex = eventRow.index
          }

          Row {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(14)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(16)
              text: eventRow.modelData.down ? "↓" : "↑"
              color: view.dim
              font.family: view.fontFamily
              font.pixelSize: Style.font.body
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(170)
              textFormat: Text.PlainText
              elide: Text.ElideRight
              text: Api.eventLabel(eventRow.modelData)
              color: view.fg
              font.family: view.fontFamily
              font.pixelSize: Style.font.body
            }
          }

          NumberField {
            anchors.right: parent.right
            anchors.rightMargin: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            fieldWidth: Style.space(110)
            from: 1
            to: 65535
            value: eventRow.modelData.delay
            foreground: view.fg
            fontFamily: view.fontFamily
            onModified: function(v) { view.setDelay(eventRow.index, v) }
          }
        }
      }

      // With Mouse Button on, clicks here during recording become events.
      MouseArea {
        anchors.fill: parent
        visible: view.recording && view.recordMouse
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton
        cursorShape: Qt.CrossCursor
        function code(b) {
          return b === Qt.LeftButton ? 1 : b === Qt.RightButton ? 2 : b === Qt.MiddleButton ? 4
            : b === Qt.BackButton ? 8 : 16
        }
        onPressed: function(m) { view.addEvent({ down: true, type: 4, code: code(m.button) }) }
        onReleased: function(m) { view.addEvent({ down: false, type: 4, code: code(m.button) }) }
      }

      Text {
        anchors.centerIn: parent
        visible: !!view.draft && view.events.length === 0 && !view.recording
        width: parent.width * 0.8
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: "Start recording and type, or use Insert command."
        color: view.dim
        font.family: view.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
    }

    Row {
      spacing: Style.space(8)
      Button { text: "Delete"; bordered: true; enabled: view.eventIndex >= 0 && !view.recording; foreground: view.fg; fontFamily: view.fontFamily; onClicked: view.deleteEvent() }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: view.events.length + " / 70 events · delay is the wait after each event (ms)"
        color: view.dim
        font.family: view.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  // ---------- Right: recording and options ----------
  Flickable {
    anchors.left: keyColumn.right
    anchors.leftMargin: Style.space(28)
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    contentHeight: optionColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: optionColumn
      width: parent.width
      spacing: Style.space(10)
      enabled: !!view.draft

      Button {
        width: parent.width
        text: view.recording ? "■  Stop recording" : "●  Start recording"
        bordered: true
        selected: view.recording
        foreground: view.recording ? view.markerColor : view.fg
        fontFamily: view.fontFamily
        onClicked: view.toggleRecording()
      }

      Toggle {
        width: parent.width
        label: "Mouse Button"
        description: "Also record clicks made on the Key List while recording."
        checked: view.recordMouse
        foreground: view.fg
        fontFamily: view.fontFamily
        onClicked: view.recordMouse = !view.recordMouse
      }

      ButtonGroup {
        options: ["Auto insert delay", "Default delay"]
        value: view.autoDelay ? "Auto insert delay" : "Default delay"
        focusable: false
        foreground: view.fg
        fontFamily: view.fontFamily
        onChanged: function(v) { view.autoDelay = v === "Auto insert delay" }
      }

      Row {
        spacing: Style.space(10)
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "Default delay (ms)"
          color: view.fg
          font.family: view.fontFamily
          font.pixelSize: Style.font.body
        }
        NumberField {
          anchors.verticalCenter: parent.verticalCenter
          from: 1
          to: 65535
          value: view.defaultDelay
          foreground: view.fg
          fontFamily: view.fontFamily
          onModified: function(v) { view.defaultDelay = v }
        }
      }

      PanelSeparator { foreground: view.fg }
      PanelSectionHeader { text: "EXECUTION METHOD"; foreground: view.fg; fontFamily: view.fontFamily }

      Repeater {
        model: Api.METHODS
        delegate: Button {
          required property var modelData
          width: optionColumn.width
          leftAlign: true
          text: modelData.label
          selected: view.draft ? (modelData.value === 1 ? view.draft.method >= 1 && view.draft.method <= 252
                                                        : view.draft.method === modelData.value) : false
          foreground: view.fg
          fontFamily: view.fontFamily
          onClicked: {
            var next = view.copyDraft()
            next.method = modelData.value === 1 ? Math.max(1, Math.min(252, next.method <= 252 ? next.method : 1)) : modelData.value
            view.setDraft(next)
          }
        }
      }

      Row {
        spacing: Style.space(10)
        visible: !!view.draft && view.draft.method >= 1 && view.draft.method <= 252
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "Cycle Times"
          color: view.fg
          font.family: view.fontFamily
          font.pixelSize: Style.font.body
        }
        NumberField {
          anchors.verticalCenter: parent.verticalCenter
          from: 1
          to: 252
          value: view.draft ? view.draft.method : 1
          foreground: view.fg
          fontFamily: view.fontFamily
          onModified: function(v) { var next = view.copyDraft(); next.method = v; view.setDraft(next) }
        }
      }

      PanelSeparator { foreground: view.fg }
      PanelSectionHeader { text: "INSERT COMMAND"; foreground: view.fg; fontFamily: view.fontFamily }

      Row {
        spacing: Style.space(8)
        Dropdown {
          id: insertMenu
          width: Style.space(180)
          showLabel: false
          options: Api.INSERT_COMMANDS
          value: "Key Press"
          fontFamily: view.fontFamily
        }
        Button {
          text: "Insert"
          bordered: true
          enabled: !view.recording
          foreground: view.fg
          fontFamily: view.fontFamily
          onClicked: view.insertCommand(insertMenu.value)
        }
      }

      PanelSeparator { foreground: view.fg }

      Row {
        spacing: Style.space(8)
        Button {
          text: "Save"
          bordered: true
          enabled: view.dirty
          foreground: view.fg
          fontFamily: view.fontFamily
          onClicked: view.save()
        }
        Dropdown {
          width: Style.space(120)
          showLabel: false
          options: ["1", "2", "3", "4", "5", "6"]
          value: String(view.targetButton)
          fontFamily: view.fontFamily
          onChanged: function(v) { view.targetButton = Number(v) }
        }
        Button {
          text: "Put on button"
          bordered: true
          enabled: view.canEdit && !!view.draft && view.events.length > 0
          foreground: view.fg
          fontFamily: view.fontFamily
          tooltipText: "Write this macro to the chosen mouse button"
          onClicked: view.putOnButton()
        }
      }

      Text {
        visible: view.message !== ""
        width: parent.width
        wrapMode: Text.WordWrap
        text: view.message
        color: view.dim
        font.family: view.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
    }
  }
}
