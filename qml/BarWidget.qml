import QtQuick
import qs.Commons
import qs.Ui
import "Api.js" as Api

// Bar icon plus the settings dropdown. Every color and font comes from the
// bar and the shell theme, so the panel follows whatever Omarchy theme is set.
Panel {
  id: root
  moduleName: "io.github.dankestrick.omagravastar"
  // The service is shared by every monitor's bar; no per-instance IPC target.
  manageIpc: false

  readonly property var mouse: bar && bar.shell
    ? bar.shell.serviceFor("io.github.dankestrick.omagravastar") : null
  readonly property var status: mouse ? mouse.status : ({})
  readonly property var s: mouse && mouse.mouseSettings ? mouse.mouseSettings : ({})
  readonly property var light: s.lighting || ({})
  readonly property bool connected: !!(mouse && mouse.connected)
  readonly property bool awake: !!(mouse && mouse.awake)
  // Settings have been read at least once (live or from the helper's cache).
  readonly property bool known: s.pollingHz !== undefined
  readonly property bool canEdit: connected && awake && known

  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(fg, 1.4)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property var tabs: ["Overview", "DPI", "Lighting", "Settings", "Device"]
  property string tab: "Overview"
  property bool confirmLongDistance: false

  readonly property string effect: Api.effectValue(light.effect)
  readonly property int activeStage: s.activeStage || 1
  readonly property var stageList: s.dpiStages || []
  readonly property var colorList: s.dpiColors || []

  readonly property string statusLine: {
    if (!mouse) return "Starting"
    if (!connected) return "Dongle not found"
    var parts = []
    if (mouse.battery >= 0) parts.push(mouse.battery + "%")
    if (mouse.charging) parts.push("Charging")
    if (!awake) parts.push("Asleep")
    return parts.join(" · ")
  }

  function send(args) {
    if (mouse && canEdit) mouse.change(args)
  }

  function onOff(value) { return value ? "on" : "off" }

  onOpenedChanged: if (mouse) mouse.panelOpen = opened

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰍽"
    dimmed: !root.connected
    tooltipText: root.mouse ? "Mercury X Pro · " + root.mouse.batteryText : "Mercury X Pro"
    onPressed: function(b) {
      if (b === Qt.LeftButton) root.toggle()
      else if (root.mouse) root.mouse.refresh()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: effectMenu.popupOpen || sleepMenu.popupOpen || timerMenu.popupOpen
        || countMenu.popupOpen || root.confirmLongDistance
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) {
        if (dx === 0) return
        var i = root.tabs.indexOf(root.tab) + dx
        root.tab = root.tabs[(i + root.tabs.length) % root.tabs.length]
      }

      Column {
        id: column
        anchors.fill: parent
        spacing: Style.space(12)

        // ---------- Hero: mouse · battery ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "󰍽"
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            opacity: root.awake ? 1.0 : 0.5
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              textFormat: Text.PlainText
              text: "Mercury X Pro"
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              textFormat: Text.PlainText
              text: root.statusLine.toUpperCase()
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }
        }

        ButtonGroup {
          width: parent.width
          options: root.tabs
          value: root.tab
          focusable: false
          foreground: root.fg
          fontFamily: root.fontFamily
          onChanged: function(v) { root.tab = v }
        }

        Text {
          textFormat: Text.PlainText
          visible: root.connected && !root.awake
          width: parent.width
          wrapMode: Text.WordWrap
          text: "The mouse is asleep. Move it to change settings."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Text {
          textFormat: Text.PlainText
          visible: !!root.mouse && root.mouse.lastError !== "" && root.connected
          width: parent.width
          wrapMode: Text.WordWrap
          text: root.mouse ? root.mouse.lastError : ""
          color: root.bar ? root.bar.urgent : Color.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        PanelSeparator { foreground: root.fg }

        Text {
          textFormat: Text.PlainText
          visible: root.connected && !root.known && root.tab !== "Device"
          width: parent.width
          wrapMode: Text.WordWrap
          text: "Move the mouse once so OmaGravastar can read its settings."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }

        // ---------- Overview ----------
        Column {
          visible: root.tab === "Overview" && root.known
          width: parent.width
          spacing: Style.space(8)

          InfoRow { label: "DPI"; value: root.s.dpi ? String(root.s.dpi) : "—" }
          InfoRow { label: "Polling Rate"; value: root.s.pollingHz ? root.s.pollingHz + "Hz" : "—" }
          InfoRow { label: "LOD"; value: root.s.lod || "—" }
          InfoRow { label: "Key Response Time"; value: root.s.keyResponseMs !== undefined ? root.s.keyResponseMs + "ms" : "—" }
          InfoRow { label: "Configuration"; value: root.status.profile ? "Profile " + root.status.profile : "—" }
          InfoRow { label: "Battery"; value: root.mouse ? root.mouse.batteryText : "—" }
        }

        // ---------- DPI ----------
        Column {
          visible: root.tab === "DPI" && root.known
          width: parent.width
          spacing: Style.space(10)

          Item {
            width: parent.width
            implicitHeight: countMenu.implicitHeight

            PanelSectionHeader {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "DPI SETTING"
              foreground: root.fg
              fontFamily: root.fontFamily
            }

            Dropdown {
              id: countMenu
              anchors.right: parent.right
              width: Style.space(90)
              showLabel: false
              enabled: root.canEdit
              options: ["1", "2", "3", "4", "5", "6", "7", "8"]
              value: String(root.stageList.length || "")
              fontFamily: root.fontFamily
              onChanged: function(v) { root.send(["set", "stage-count", v]) }
            }
          }

          Flow {
            width: parent.width
            spacing: Style.space(6)

            Repeater {
              model: root.stageList
              delegate: Column {
                id: stage
                required property var modelData
                required property int index
                spacing: Style.space(3)

                Button {
                  width: Style.space(58)
                  text: String(stage.modelData)
                  bordered: true
                  selected: stage.index + 1 === root.activeStage
                  enabled: root.canEdit
                  foreground: root.fg
                  fontFamily: root.fontFamily
                  tooltipText: "Use stage " + (stage.index + 1)
                  onClicked: root.send(["set", "active-stage", String(stage.index + 1)])
                }

                Rectangle {
                  width: Style.space(58)
                  height: Style.space(3)
                  radius: height / 2
                  color: root.colorList[stage.index] || root.dim
                }
              }
            }
          }

          Item {
            width: parent.width
            implicitHeight: dpiField.implicitHeight

            PanelSlider {
              id: dpiSlider
              bar: root.bar
              anchors.left: parent.left
              anchors.right: dpiField.left
              anchors.rightMargin: Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              minimum: 50
              maximum: 26000
              step: 50
              integer: true
              enabled: root.canEdit
              value: root.s.dpi || 800
              onReleased: function(v) {
                root.send(["set", "dpi-stage", String(root.activeStage), String(Math.round(v / 50) * 50)])
              }
            }

            NumberField {
              id: dpiField
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              from: 50
              to: 26000
              stepSize: 50
              enabled: root.canEdit
              value: dpiSlider.dragging ? Math.round(dpiSlider.liveValue / 50) * 50 : (root.s.dpi || 800)
              foreground: root.fg
              fontFamily: root.fontFamily
              onModified: function(v) {
                root.send(["set", "dpi-stage", String(root.activeStage), String(Math.round(v / 50) * 50)])
              }
            }
          }

          PanelSeparator { foreground: root.fg }
          PanelSectionHeader { text: "POLLING RATE (Hz)"; foreground: root.fg; fontFamily: root.fontFamily }

          ButtonGroup {
            width: parent.width
            options: Api.POLLING_CHOICES
            value: String(root.s.pollingHz || "")
            focusable: false
            enabled: root.canEdit
            foreground: root.fg
            fontFamily: root.fontFamily
            onChanged: function(v) { root.send(["set", "polling", v]) }
          }

          PanelSeparator { foreground: root.fg }
          PanelSectionHeader { text: "SENSOR SETTING"; foreground: root.fg; fontFamily: root.fontFamily }

          LabeledRow {
            label: "Select mode"
            ButtonGroup {
              options: ["LP", "HP"]
              value: (root.s.pollingHz || 0) > 1000 ? "" : (root.s.sensorMode || "")
              focusable: false
              enabled: root.canEdit && (root.s.pollingHz || 0) <= 1000
              foreground: root.fg
              fontFamily: root.fontFamily
              onChanged: function(v) { root.send(["set", "sensor-mode", v.toLowerCase()]) }
            }
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            wrapMode: Text.WordWrap
            text: (root.s.pollingHz || 0) > 1000
              ? "Corded (ultra-performance) is on automatically above 1000Hz."
              : "LP: normal mode. HP: high-performance mode."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          LabeledRow {
            label: "LOD"
            ButtonGroup {
              options: ["0.7mm", "1mm", "2mm"]
              value: root.s.lod || ""
              focusable: false
              enabled: root.canEdit
              foreground: root.fg
              fontFamily: root.fontFamily
              onChanged: function(v) { root.send(["set", "lod", v]) }
            }
          }

          Toggle {
            width: parent.width
            label: "Highest performance"
            description: "The sensor LED lights up and the sensor runs in its highest-performance mode."
            checked: !!root.s.performance
            enabled: root.canEdit
            foreground: root.fg
            fontFamily: root.fontFamily
            onClicked: root.send(["set", "performance", root.onOff(!root.s.performance)])
          }

          LabeledRow {
            label: "Highest performance timer"
            Dropdown {
              id: timerMenu
              width: Style.space(110)
              showLabel: false
              enabled: root.canEdit && !!root.s.performance
              opacity: enabled ? 1 : 0.5
              options: Api.TIME_CHOICES
              value: root.s.performanceTimer || ""
              fontFamily: root.fontFamily
              onChanged: function(v) { root.send(["set", "performance-timer", v]) }
            }
          }

          Toggle {
            width: parent.width
            label: "Ripple Control"
            description: "Smooths tiny jitters in the sensor's tracking at high DPI."
            checked: !!root.s.ripple
            enabled: root.canEdit
            foreground: root.fg
            fontFamily: root.fontFamily
            onClicked: root.send(["set", "ripple", root.onOff(!root.s.ripple)])
          }

          Toggle {
            width: parent.width
            label: "Angle snapping"
            description: "Straightens slightly wobbly lines when you move the mouse."
            checked: !!root.s.angleSnap
            enabled: root.canEdit
            foreground: root.fg
            fontFamily: root.fontFamily
            onClicked: root.send(["set", "angle-snap", root.onOff(!root.s.angleSnap)])
          }

          Toggle {
            width: parent.width
            label: "Motion sync"
            description: "Lines up sensor readings with polling for steadier tracking, adding a tiny bit of delay."
            checked: !!root.s.motionSync
            enabled: root.canEdit
            foreground: root.fg
            fontFamily: root.fontFamily
            onClicked: root.send(["set", "motion-sync", root.onOff(!root.s.motionSync)])
          }
        }

        // ---------- Lighting ----------
        Column {
          visible: root.tab === "Lighting" && root.known
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader { text: "DISPLAY LIGHT EFFECTS"; foreground: root.fg; fontFamily: root.fontFamily }

          Dropdown {
            id: effectMenu
            width: parent.width
            showLabel: false
            enabled: root.canEdit
            options: Api.EFFECTS
            value: root.effect
            fontFamily: root.fontFamily
            onChanged: function(v) { root.send(["light", "effect", v]) }
          }

          LevelRow {
            label: "Brightness"
            level: root.light.brightness || 1
            active: root.effect !== "off"
            onPicked: function(v) { root.send(["light", "brightness", String(v)]) }
          }

          LevelRow {
            label: "Speed"
            level: root.light.speed || 1
            active: Api.effectUsesSpeed(root.effect)
            onPicked: function(v) { root.send(["light", "speed", String(v)]) }
          }

          Toggle {
            width: parent.width
            label: "Turn off decorative lights when moving."
            checked: !!root.light.offWhenMoving
            enabled: root.canEdit
            foreground: root.fg
            fontFamily: root.fontFamily
            onClicked: root.send(["light", "off-when-moving", root.onOff(!root.light.offWhenMoving)])
          }

          // Color picker, only for effects that use one color.
          Column {
            visible: Api.effectUsesColor(root.effect)
            width: parent.width
            spacing: Style.space(10)

            PanelSeparator { foreground: root.fg }
            PanelSectionHeader { text: "CUSTOM COLOR"; foreground: root.fg; fontFamily: root.fontFamily }

            Rectangle {
              id: hueBar
              width: parent.width
              height: Style.space(22)
              radius: Style.cornerRadius
              opacity: root.canEdit ? 1 : 0.5
              gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#ff0000" }
                GradientStop { position: 1 / 6; color: "#ffff00" }
                GradientStop { position: 2 / 6; color: "#00ff00" }
                GradientStop { position: 3 / 6; color: "#00ffff" }
                GradientStop { position: 4 / 6; color: "#0000ff" }
                GradientStop { position: 5 / 6; color: "#ff00ff" }
                GradientStop { position: 1.0; color: "#ff0000" }
              }

              MouseArea {
                anchors.fill: parent
                enabled: root.canEdit
                cursorShape: Qt.PointingHandCursor
                onClicked: function(m) {
                  root.send(["light", "color", Api.hueHex(Math.max(0, Math.min(0.9999, m.x / width)))])
                }
              }
            }

            Item {
              width: parent.width
              implicitHeight: Math.max(preview.height, channels.implicitHeight)

              Rectangle {
                id: preview
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(64)
                height: Style.space(64)
                radius: Style.cornerRadius
                color: root.light.color || "#000000"
                border.width: 1
                border.color: Util.alpha(root.fg, 0.25)
              }

              Column {
                id: channels
                anchors.left: preview.right
                anchors.leftMargin: Style.space(14)
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(4)

                Repeater {
                  model: ["R", "G", "B"]
                  delegate: Row {
                    id: channel
                    required property string modelData
                    required property int index
                    spacing: Style.space(8)

                    Text {
                      textFormat: Text.PlainText
                      anchors.verticalCenter: parent.verticalCenter
                      width: Style.space(18)
                      text: channel.modelData + ":"
                      color: root.fg
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                    }

                    NumberField {
                      anchors.verticalCenter: parent.verticalCenter
                      from: 0
                      to: 255
                      enabled: root.canEdit
                      value: Api.hexChannels(root.light.color)[channel.index]
                      foreground: root.fg
                      fontFamily: root.fontFamily
                      onModified: function(v) {
                        var rgb = Api.hexChannels(root.light.color)
                        rgb[channel.index] = v
                        root.send(["light", "color", Api.rgbHex(rgb[0], rgb[1], rgb[2])])
                      }
                    }
                  }
                }
              }
            }

            PanelSectionHeader { text: "PRESET"; foreground: root.fg; fontFamily: root.fontFamily }

            Grid {
              columns: 7
              spacing: Style.space(8)

              Repeater {
                model: Api.PRESET_COLORS
                delegate: Rectangle {
                  required property string modelData
                  width: Style.space(40)
                  height: Style.space(24)
                  radius: Style.cornerRadius
                  color: modelData
                  opacity: root.canEdit ? 1 : 0.5
                  border.width: String(root.light.color).toLowerCase() === modelData ? 2 : 1
                  border.color: String(root.light.color).toLowerCase() === modelData ? root.fg : Util.alpha(root.fg, 0.2)

                  MouseArea {
                    anchors.fill: parent
                    enabled: root.canEdit
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.send(["light", "color", modelData])
                  }
                }
              }
            }
          }
        }

        // ---------- Settings ----------
        Column {
          visible: root.tab === "Settings" && root.known
          width: parent.width
          spacing: Style.space(10)

          LabeledRow {
            label: "Mouse Sleep Time"
            Dropdown {
              id: sleepMenu
              width: Style.space(110)
              showLabel: false
              enabled: root.canEdit
              options: Api.TIME_CHOICES
              value: root.s.sleep || ""
              fontFamily: root.fontFamily
              onChanged: function(v) { root.send(["set", "sleep", v]) }
            }
          }

          LabeledRow {
            label: "Key Response Time (ms)"
            NumberField {
              from: 0
              to: 30
              enabled: root.canEdit
              value: root.s.keyResponseMs || 0
              foreground: root.fg
              fontFamily: root.fontFamily
              onModified: function(v) { root.send(["set", "key-response", String(v)]) }
            }
          }

          Toggle {
            width: parent.width
            label: "Long distance mode"
            description: "Stronger signal and anti-interference at range. Battery life will be shorter."
            checked: !!root.s.longDistance
            enabled: root.canEdit
            foreground: root.fg
            fontFamily: root.fontFamily
            onClicked: {
              if (root.s.longDistance) root.send(["set", "long-distance", "off"])
              else root.confirmLongDistance = true
            }
          }
        }

        // ---------- Device ----------
        Column {
          visible: root.tab === "Device"
          width: parent.width
          spacing: Style.space(8)

          InfoRow { label: "Receiver Firmware version"; value: root.status.receiverFirmware || "—" }
          InfoRow { label: "Mouse Firmware version"; value: root.status.firmware || "—" }
          InfoRow { label: "Configuration"; value: root.status.profile ? "Profile " + root.status.profile : "—" }
          InfoRow { label: "Battery voltage"; value: root.status.batteryMv ? (root.status.batteryMv / 1000).toFixed(2) + " V" : "—" }
          InfoRow { label: "Dongle"; value: root.status.device || "Not found" }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            wrapMode: Text.WordWrap
            topPadding: Style.space(6)
            text: "Pairing and restoring factory settings are in Gravastar's web driver."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }

      ConfirmDialog {
        anchors.fill: parent
        z: 10
        opened: root.confirmLongDistance
        message: "In long-distance mode, when the distance is farther, the anti-interference ability and current power will be stronger, and the battery life will shorten."
        confirmText: "OK"
        foreground: root.fg
        fontFamily: root.fontFamily
        onCanceled: root.confirmLongDistance = false
        onConfirmed: {
          root.confirmLongDistance = false
          root.send(["set", "long-distance", "on"])
        }
      }
    }
  }

  // Label on the left, value on the right.
  component InfoRow: Item {
    property string label: ""
    property string value: ""
    width: parent ? parent.width : 0
    implicitHeight: Math.max(labelText.implicitHeight, valueText.implicitHeight)

    Text {
      id: labelText
      textFormat: Text.PlainText
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: parent.label
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }

    Text {
      id: valueText
      textFormat: Text.PlainText
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: parent.value
      color: root.fg
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
    }
  }

  // Label on the left, one control on the right.
  component LabeledRow: Item {
    id: labeled
    property string label: ""
    default property alias control: slot.data
    width: parent ? parent.width : 0
    implicitHeight: Math.max(rowLabel.implicitHeight, slot.childrenRect.height)

    Text {
      id: rowLabel
      textFormat: Text.PlainText
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: labeled.label
      color: root.fg
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }

    Item {
      id: slot
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: childrenRect.width
      height: childrenRect.height
    }
  }

  // A 1-10 slider with its number, matching the web driver's lighting sliders.
  component LevelRow: Item {
    id: levelRow
    property string label: ""
    property int level: 1
    property bool active: true
    signal picked(int value)
    width: parent ? parent.width : 0
    implicitHeight: levelLabel.implicitHeight + Style.space(4) + levelSlider.implicitHeight
    opacity: active && root.canEdit ? 1 : 0.5

    Text {
      id: levelLabel
      textFormat: Text.PlainText
      anchors.left: parent.left
      anchors.top: parent.top
      text: levelRow.label
      color: root.fg
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }

    PanelSlider {
      id: levelSlider
      bar: root.bar
      anchors.left: parent.left
      anchors.right: levelValue.left
      anchors.rightMargin: Style.space(12)
      anchors.top: levelLabel.bottom
      anchors.topMargin: Style.space(4)
      minimum: 1
      maximum: 10
      step: 1
      integer: true
      tickCount: 10
      enabled: levelRow.active && root.canEdit
      value: levelRow.level
      onReleased: function(v) { levelRow.picked(Math.round(v)) }
    }

    Text {
      id: levelValue
      textFormat: Text.PlainText
      anchors.right: parent.right
      anchors.verticalCenter: levelSlider.verticalCenter
      width: Style.space(20)
      horizontalAlignment: Text.AlignRight
      text: String(Math.round(levelSlider.dragging ? levelSlider.liveValue : levelRow.level))
      color: root.fg
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }
  }
}
