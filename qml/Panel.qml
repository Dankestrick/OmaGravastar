import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "Api.js" as Api

// The big window, a floating window like OmaPandora's full player. The
// Buttons view has the button list on the left, the mouse picture with
// numbered markers in the middle and the actions on the right. The Macros
// view (MacroView.qml) edits macros.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property var service: null
  property bool opened: false
  property bool closingFromHost: false
  property int selected: 1
  property string view: "buttons"

  readonly property string pluginId: manifest && manifest.id
    ? String(manifest.id) : "io.github.dankestrick.omagravastar"
  readonly property color fg: Color.foreground
  readonly property color dim: Qt.darker(Color.foreground, 1.4)
  readonly property color accent: Color.accent
  readonly property string fontFamily: Style.font.family
  // Markers take the mouse's own Fixed Color (Lighting tab), so they match
  // the mouse. Falls back to the theme accent until the color is known.
  readonly property color markerColor: s.lighting && s.lighting.color ? s.lighting.color : Color.accent
  readonly property color markerText: (0.299 * markerColor.r + 0.587 * markerColor.g + 0.114 * markerColor.b) > 0.6
    ? "#000000" : "#ffffff"

  readonly property var s: service && service.mouseSettings ? service.mouseSettings : ({})
  readonly property var buttonList: s.buttons || []
  readonly property bool canEdit: !!(service && service.connected && service.awake && s.buttons)
  readonly property int leftClickCount: {
    var n = 0
    for (var i = 0; i < buttonList.length; i++) if (buttonList[i].action === "Left Click") n++
    return n
  }
  readonly property var current: buttonList[selected - 1] || ({ action: "" })
  readonly property var macroNames: {
    var names = []
    var list = service ? service.macros : []
    for (var i = 0; i < list.length; i++) names.push(list[i].name)
    return names
  }
  // Button groups plus a Macro group listing the saved macros.
  readonly property var groups: Api.BUTTON_GROUPS.concat([{ value: "Firepower Button", actions: [] },
                                                           { value: "Macro", actions: macroNames }])
  readonly property string currentAction: current.group === 6 && current.macro ? current.macro.name : current.action
  readonly property string currentGroup: current.group === 6 ? "Macro" : current.group === 4 ? "Firepower Button"
    : Api.groupOf(current.action)
  property int fireTimes: 0
  property int fireInterval: 50
  onCurrentChanged: if (current.firepower) { fireTimes = current.firepower.times; fireInterval = current.firepower.interval }

  function applyFirepower() {
    if (!service || !canEdit || currentLocked) return
    service.change(["firepower", String(selected), String(fireTimes), String(fireInterval)], "button " + selected)
    browseGroup = ""
  }
  property string browseGroup: ""
  readonly property string shownGroup: browseGroup !== "" ? browseGroup : currentGroup
  readonly property bool currentLocked: current.action === "Left Click" && leftClickCount <= 1

  readonly property string topPhoto: Qt.resolvedUrl("../assets/mouse-top.png")
  readonly property string bottomPhoto: Qt.resolvedUrl("../assets/mouse-bottom.png")

  function open(payloadJson) {
    closingFromHost = false
    var monitor = Hyprland.focusedMonitor
    for (var i = 0; i < Quickshell.screens.length; i++)
      if (monitor && Quickshell.screens[i].name === monitor.name) window.screen = Quickshell.screens[i]
    try {
      var payload = JSON.parse(payloadJson || "{}")
      if (payload.button >= 1 && payload.button <= 6) selected = payload.button
      view = payload.view === "macros" ? "macros" : "buttons"
    } catch (e) {}
    browseGroup = ""
    opened = true
    if (service) service.windowOpen = true
  }

  function close() {
    closingFromHost = true
    opened = false
    if (service) service.windowOpen = false
    closingFromHost = false
  }

  function requestClose() {
    if (shell && typeof shell.hide === "function") shell.hide(pluginId)
    else close()
  }

  // Back to the bar dropdown on this window's monitor.
  function showMini() {
    if (service) service.showMini(window.screen ? window.screen.name : "")
    requestClose()
  }

  function select(number) {
    selected = number
    browseGroup = ""
  }

  function assign(action) {
    if (!service || !canEdit || currentLocked) return
    if (shownGroup === "Macro") {
      var i = service.macroIndex(action)
      if (i >= 0) service.assignMacro(selected, service.macros[i])
    } else {
      service.change(["button", String(selected), action], "button " + selected)
    }
    browseGroup = ""
  }

  function groupActions(group) {
    for (var i = 0; i < groups.length; i++) if (groups[i].value === group) return groups[i].actions
    return []
  }

  function restoreDefaults() {
    if (!service || !canEdit) return
    for (var i = 0; i < 6; i++)
      service.change(["button", String(i + 1), Api.DEFAULT_BUTTONS[i]], "button " + (i + 1))
  }

  FloatingWindow {
    id: window
    visible: root.opened
    title: "OmaGravastar"
    color: Color.background
    implicitWidth: 1440
    implicitHeight: 840
    minimumSize: Qt.size(1200, 720)

    onVisibleChanged: {
      if (!visible && root.opened && !root.closingFromHost) root.requestClose()
    }

    FocusScope {
      anchors.fill: parent
      focus: true
      Keys.onReleased: function(event) {
        if (root.view === "macros" && macroView.handleKey(event, false)) event.accepted = true
      }
      Keys.onPressed: function(event) {
        // While recording, every key belongs to the macro.
        if (root.view === "macros" && macroView.handleKey(event, true)) { event.accepted = true; return }
        if (event.key === Qt.Key_Escape) { root.requestClose(); event.accepted = true }
        else if (root.view === "macros") return
        else if (event.key === Qt.Key_M) { root.showMini(); event.accepted = true }
        else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) { root.select(Math.min(6, root.selected + 1)); event.accepted = true }
        else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) { root.select(Math.max(1, root.selected - 1)); event.accepted = true }
        else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_6) { root.select(event.key - Qt.Key_0); event.accepted = true }
      }

      Item {
        anchors.fill: parent
        anchors.margins: Style.space(24)

        // ---------- Header ----------
        Item {
          id: header
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          height: Math.max(title.implicitHeight, closeButton.implicitHeight)

          Row {
            id: title
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(12)

            Text {
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              text: "󰍽"
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }

            Column {
              anchors.verticalCenter: parent.verticalCenter
              Text {
                textFormat: Text.PlainText
                text: "Mercury X Pro · " + (root.view === "macros" ? "Macros" : "Buttons")
                color: root.fg
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
                font.bold: true
              }
              Text {
                textFormat: Text.PlainText
                text: (root.service ? root.service.batteryText : "").toUpperCase()
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.2
              }
            }
          }

          Row {
            anchors.right: profileMenu.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(8)
            Button {
              text: "Export"
              bordered: true
              enabled: root.canEdit
              foreground: root.fg
              fontFamily: root.fontFamily
              tooltipText: "Save this profile to a file"
              onClicked: root.service.exportProfile()
            }
            Button {
              text: "Import"
              bordered: true
              enabled: root.canEdit
              foreground: root.fg
              fontFamily: root.fontFamily
              tooltipText: "Load a profile file into this profile"
              onClicked: root.service.importProfile()
            }
          }

          Dropdown {
            id: profileMenu
            anchors.right: miniSwitch.left
            anchors.rightMargin: Style.space(16)
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(140)
            showLabel: false
            enabled: root.canEdit
            options: Api.PROFILES
            value: root.service && root.service.status.profile ? "Profile " + root.service.status.profile : ""
            fontFamily: root.fontFamily
            onChanged: function(v) {
              if (root.service) root.service.change(["set", "profile", v.replace("Profile ", "")])
            }
          }

          ButtonGroup {
            anchors.left: title.right
            anchors.leftMargin: Style.space(28)
            anchors.verticalCenter: parent.verticalCenter
            options: ["Buttons", "Macros"]
            value: root.view === "macros" ? "Macros" : "Buttons"
            focusable: false
            foreground: root.fg
            fontFamily: root.fontFamily
            onChanged: function(v) { root.view = v === "Macros" ? "macros" : "buttons" }
          }

          ToggleSwitch {
            id: miniSwitch
            anchors.right: closeButton.left
            anchors.rightMargin: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            checked: false
            foreground: root.fg
            onToggled: root.showMini()

            PanelToolTip {
              visible: miniSwitch.containsMouse
              text: "Show mini panel · M"
              fontFamily: root.fontFamily
            }
          }

          PanelActionButton {
            id: closeButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            iconText: "󰅖"
            tooltipText: "Close"
            foreground: root.fg
            fontFamily: root.fontFamily
            onClicked: root.requestClose()
          }
        }

        PanelSeparator {
          id: headerRule
          anchors.top: header.bottom
          anchors.topMargin: Style.space(16)
          anchors.left: parent.left
          anchors.right: parent.right
          foreground: root.fg
        }

        Text {
          textFormat: Text.PlainText
          anchors.top: headerRule.bottom
          anchors.topMargin: Style.space(10)
          anchors.right: parent.right
          visible: !!root.service && root.service.notice !== ""
          text: root.service ? root.service.notice : ""
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Text {
          id: sleepNote
          textFormat: Text.PlainText
          anchors.top: headerRule.bottom
          anchors.topMargin: Style.space(10)
          visible: !!root.service && root.service.connected && !root.service.awake
          text: "The mouse is asleep. Move it to change buttons."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        // ---------- Left: button list ----------
        Column {
          id: buttonColumn
          visible: root.view === "buttons"
          anchors.top: headerRule.bottom
          anchors.topMargin: Style.space(40)
          anchors.left: parent.left
          width: Style.space(280)
          spacing: Style.space(8)

          PanelSectionHeader { text: "BUTTONS"; foreground: root.fg; fontFamily: root.fontFamily }

          Repeater {
            model: root.buttonList
            delegate: CursorSurface {
              id: row
              required property var modelData
              required property int index
              width: buttonColumn.width
              implicitHeight: rowContent.implicitHeight + Style.spacing.rowPaddingX
              foreground: root.fg
              current: root.selected === index + 1
              hasCursor: rowMouse.containsMouse

              MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.select(row.index + 1)
              }

              Row {
                id: rowContent
                anchors.left: parent.left
                anchors.leftMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(12)

                NumberBadge {
                  anchors.verticalCenter: parent.verticalCenter
                  number: row.index + 1
                  active: row.current
                }

                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  Text {
                    textFormat: Text.PlainText
                    text: Api.BUTTON_NAMES[row.index] || ""
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                  Text {
                    textFormat: Text.PlainText
                    text: row.modelData.group === 6 && row.modelData.macro ? "Macro: " + row.modelData.macro.name
                      : row.modelData.firepower ? "Firepower: " + (row.modelData.firepower.times === 0 ? "while held"
                        : row.modelData.firepower.times + "×") + " every " + row.modelData.firepower.interval + " ms"
                      : row.modelData.action
                    color: root.fg
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                  }
                }
              }
            }
          }
        }

        // ---------- Right: actions ----------
        Item {
          id: actionColumn
          visible: root.view === "buttons"
          anchors.top: headerRule.bottom
          anchors.topMargin: Style.space(40)
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          width: Style.space(410)

          Column {
            id: actionHeader
            width: parent.width
            spacing: Style.space(4)

            PanelSectionHeader {
              text: "BUTTON " + root.selected + " · " + (Api.BUTTON_NAMES[root.selected - 1] || "").toUpperCase()
              foreground: root.fg
              fontFamily: root.fontFamily
            }

            Text {
              textFormat: Text.PlainText
              width: parent.width
              wrapMode: Text.WordWrap
              visible: root.currentLocked || root.currentGroup === "" || (root.shownGroup === "Macro" && root.macroNames.length === 0)
              text: root.currentLocked
                ? "Must keep left key. Set another button to Left Click first."
                : root.currentGroup === "" ? "This button uses " + root.current.action + ", which is set in Gravastar's web driver."
                : "No macros yet. Make one in the Macros view."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }

          Row {
            anchors.top: actionHeader.bottom
            anchors.topMargin: Style.space(12)
            anchors.bottom: restoreButton.top
            anchors.bottomMargin: Style.space(12)
            width: parent.width
            spacing: Style.space(10)
            enabled: root.canEdit && !root.currentLocked
            opacity: enabled ? 1 : 0.5

            // Groups, like the first column of the web driver's menu.
            ListView {
              width: Style.space(205)
              height: parent.height
              clip: true
              spacing: Style.space(4)
              model: root.groups
              delegate: Button {
                required property var modelData
                width: ListView.view.width
                leftAlign: true
                text: modelData.value
                selected: root.shownGroup === modelData.value
                foreground: root.fg
                fontFamily: root.fontFamily
                onClicked: {
                  if (modelData.value !== "Macro" && modelData.actions.length === 1) root.assign(modelData.actions[0])
                  else root.browseGroup = modelData.value
                }
              }
            }

            // Firepower: times and interval instead of a list.
            Column {
              visible: root.shownGroup === "Firepower Button"
              width: parent.width - Style.space(215)
              spacing: Style.space(10)

              Row {
                spacing: Style.space(10)
                Text { anchors.verticalCenter: parent.verticalCenter; width: Style.space(135); text: "Times (0-3)"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.body }
                NumberField {
                  anchors.verticalCenter: parent.verticalCenter
                  from: 0; to: 3; value: root.fireTimes
                  foreground: root.fg; fontFamily: root.fontFamily
                  onModified: function(v) { root.fireTimes = v }
                }
              }
              Row {
                spacing: Style.space(10)
                Text { anchors.verticalCenter: parent.verticalCenter; width: Style.space(135); text: "Interval (10-255)"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.body }
                NumberField {
                  anchors.verticalCenter: parent.verticalCenter
                  from: 10; to: 255; value: root.fireInterval
                  foreground: root.fg; fontFamily: root.fontFamily
                  onModified: function(v) { root.fireInterval = v }
                }
              }
              Text {
                textFormat: Text.PlainText
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Clicks the left button this many times, this many ms apart. When the number of times is set to 0, the key will keep sending signals when pressed and stop when released."
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
              Button {
                text: root.current.group === 4 ? "Update Firepower" : "Use Firepower"
                bordered: true
                foreground: root.fg
                fontFamily: root.fontFamily
                onClicked: root.applyFirepower()
              }
            }

            // Actions in the group.
            ListView {
              visible: root.shownGroup !== "Firepower Button"
              width: parent.width - Style.space(215)
              height: parent.height
              clip: true
              spacing: Style.space(4)
              model: root.groupActions(root.shownGroup)
              ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
              delegate: Button {
                required property string modelData
                width: ListView.view.width
                leftAlign: true
                text: modelData
                bordered: root.currentAction === modelData && root.shownGroup === root.currentGroup
                selected: root.currentAction === modelData && root.shownGroup === root.currentGroup
                foreground: root.fg
                fontFamily: root.fontFamily
                onClicked: root.assign(modelData)
              }
            }
          }

          Button {
            id: restoreButton
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            text: "Restore default buttons"
            bordered: true
            enabled: root.canEdit
            foreground: root.fg
            fontFamily: root.fontFamily
            onClicked: root.restoreDefaults()
          }
        }

        MacroView {
          id: macroView
          visible: root.view === "macros"
          anchors.top: headerRule.bottom
          anchors.topMargin: Style.space(40)
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          service: root.service
          fg: root.fg
          dim: root.dim
          markerColor: root.markerColor
          fontFamily: root.fontFamily
          canEdit: root.canEdit
        }

        // ---------- Middle: mouse picture with markers ----------
        Item {
          id: pictureArea
          visible: root.view === "buttons"
          anchors.top: headerRule.bottom
          anchors.topMargin: Style.space(24)
          anchors.bottom: parent.bottom
          anchors.left: buttonColumn.right
          anchors.leftMargin: Style.space(20)
          anchors.right: actionColumn.left
          anchors.rightMargin: Style.space(20)

          Image {
            id: topImage
            anchors.fill: parent
            anchors.margins: Style.space(10)
            source: root.topPhoto
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
          }

          Text {
            textFormat: Text.PlainText
            anchors.centerIn: parent
            visible: topImage.status !== Image.Ready
            width: parent.width * 0.8
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Mouse picture goes here.\nClick a button on the left to change it."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }

          // Markers sit on the painted image, not the whole area.
          Item {
            x: topImage.x + (topImage.width - topImage.paintedWidth) / 2
            y: topImage.y + (topImage.height - topImage.paintedHeight) / 2
            width: topImage.paintedWidth
            height: topImage.paintedHeight
            visible: topImage.status === Image.Ready

            Repeater {
              model: Api.BUTTON_SPOTS
              delegate: NumberBadge {
                required property var modelData
                required property int index
                visible: modelData.photo === "top"
                x: modelData.x * parent.width - width / 2
                y: modelData.y * parent.height - height / 2
                number: index + 1
                active: root.selected === index + 1
                large: true
                onPicked: root.select(index + 1)
              }
            }

            // Button 6 lives under the wheel: show it in a round inset of the
            // underside photo, like the web driver.
            Item {
              id: inset
              readonly property var spot: Api.BUTTON_SPOTS[5]
              width: Math.min(parent.width, parent.height) * 0.36
              height: width
              x: parent.width - width * 0.85
              y: parent.height - height * 0.75
              visible: bottomImage.status === Image.Ready

              // The photo is already cut to a circle with a clear outside.
              Image {
                id: bottomImage
                anchors.fill: parent
                source: root.bottomPhoto
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
              }

              Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: 2
                border.color: root.selected === 6 ? root.markerColor : Util.alpha(root.markerColor, 0.45)
              }

              NumberBadge {
                x: inset.spot.x * inset.width - width / 2
                y: inset.spot.y * inset.height - height / 2
                number: 6
                active: root.selected === 6
                large: true
                onPicked: root.select(6)
              }
            }
          }
        }
      }
    }
  }

  // Round numbered marker, used in the list and on the picture.
  component NumberBadge: Rectangle {
    id: badge
    property int number: 1
    property bool active: false
    property bool large: false
    signal picked()
    width: Style.space(large ? 30 : 24)
    height: width
    radius: width / 2
    color: active ? root.markerColor : Util.alpha(Color.background, 0.85)
    border.width: 2
    border.color: root.markerColor
    scale: badgeMouse.containsMouse ? 1.12 : 1.0
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }

    Text {
      textFormat: Text.PlainText
      anchors.centerIn: parent
      text: String(badge.number)
      color: badge.active ? root.markerText : root.fg
      font.family: root.fontFamily
      font.pixelSize: badge.large ? Style.font.body : Style.font.caption
      font.bold: true
    }

    MouseArea {
      id: badgeMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: badge.picked()
    }
  }
}
