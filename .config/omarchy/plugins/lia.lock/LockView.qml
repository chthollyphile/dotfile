import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Item {
  id: root

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false
  property string quoteText: "私は虚無の先  筆の限界"
  property string hoursText: "00"
  property string minutesText: "00"
  property real detectedDisplayScale: 0

  readonly property string home: Quickshell.env("HOME")
  readonly property string quoteScript: root.home + "/.config/hypr/get_hitokoto.sh"
  readonly property string runtimeScreenName: Screen.name || ""
  readonly property real pangoPointScale: 96 / 72
  // Qt rounds a 1.6 fractional output scale up to a 2x buffer DPR. Hyprlock
  // geometry is expressed in physical output pixels, so query Hyprland's
  // exact monitor scale and convert it into QML's logical coordinates.
  readonly property real displayScale: root.detectedDisplayScale > 0
    ? root.detectedDisplayScale
    : Math.max(1, Screen.devicePixelRatio || 1)
  readonly property string placeholderText: "as the Nights Reincarnation..."
  readonly property real fieldWidth: 650 / root.displayScale
  readonly property real fieldHeight: 100 / root.displayScale
  readonly property real fieldYOffset: 280 / root.displayScale
  readonly property real outlineThickness: 3 / root.displayScale
  // Hyprlock renders its placeholder at one quarter of the field height and
  // passes that value to Pango as points, not pixels.
  readonly property real fieldFontSize: 25 * root.pangoPointScale / root.displayScale
  readonly property real passwordDotSize: 25 / root.displayScale
  readonly property real passwordDotSpacing: 5 / root.displayScale
  readonly property real timeFontSize: 160 * 1.2 * root.pangoPointScale / root.displayScale
  // Space to keep clear on each side of the field for the fingerprint icon
  // (icon width plus a gap) so the centered dots never run under it.
  readonly property real fingerprintReserve: fingerprintConfigured ? Math.round(fingerprintIcon.implicitWidth + 12) : 0
  // Shrink the dots to fit once the password outgrows the field, matching
  // Hyprlock's centered dots without allowing them under the field edges.
  readonly property real passwordDotScale: passwordInput.text.length > 0
    ? Math.min(1, (passwordInput.width + root.passwordDotSpacing) /
        (passwordInput.text.length * (root.passwordDotSize + root.passwordDotSpacing)))
    : 1
  readonly property bool showPasswordCursor: inputEnabled && !authenticatingPassword && failureMessage.length === 0
  readonly property bool errorState: failureMessage.length > 0
  readonly property var inputBorderSpec: Border.flat(Color.accent, root.outlineThickness)

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  // Cache-busts the lock background by appending `?v=`. Adding a query
  // string keeps Image's loader happy while forcing it to reload when the
  // user picks a new background mid-session.
  function fileUrl(path) {
    if (!path) return ""
    var encoded = String(path).split("/").map(encodeURIComponent).join("/")
    return "file://" + encoded + "?v=" + backgroundVersion
  }

  function updateClock() {
    var now = new Date()
    hoursText = now.getHours() < 10 ? "0" + now.getHours() : "" + now.getHours()
    minutesText = now.getMinutes() < 10 ? "0" + now.getMinutes() : "" + now.getMinutes()
  }

  function refreshQuote() {
    if (!root.loadBackground || quoteProc.running) return
    quoteProc.running = true
  }

  function refreshDisplayScale() {
    if (!monitorScaleProc.running) monitorScaleProc.running = true
  }

  function revealInputField() {
    inputReveal.restart()
  }

  function syncPasswordDots(length) {
    while (passwordDotModel.count < length) passwordDotModel.append({})
    while (passwordDotModel.count > length) passwordDotModel.remove(passwordDotModel.count - 1)
  }

  function forcePasswordFocus() {
    passwordInput.forceActiveFocus()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  onPasswordTextChanged: syncPasswordText()
  onInputEnabledChanged: {
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }
  onLoadBackgroundChanged: {
    if (loadBackground) {
      updateClock()
      refreshDisplayScale()
      Qt.callLater(revealInputField)
      Qt.callLater(refreshQuote)
    } else {
      inputFieldContainer.opacity = 0
      inputFieldContainer.scale = 0.94
    }
  }
  onFailureMessageChanged: {
    if (failureMessage.length > 0) inputFailureShake.restart()
  }
  Component.onCompleted: {
    syncPasswordText()
    updateClock()
    refreshDisplayScale()
    if (loadBackground) refreshQuote()
    if (loadBackground) Qt.callLater(revealInputField)
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }

  Timer {
    id: clockTimer
    interval: 1000
    repeat: true
    running: root.loadBackground
    onTriggered: root.updateClock()
  }

  Timer {
    id: quoteTimer
    interval: 10000
    repeat: true
    running: root.loadBackground
    onTriggered: root.refreshQuote()
  }

  Process {
    id: monitorScaleProc
    command: ["hyprctl", "-j", "monitors"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var monitors = JSON.parse(String(text || "[]"))
          for (var i = 0; i < monitors.length; ++i) {
            if (monitors[i].name === root.runtimeScreenName && Number(monitors[i].scale) > 0) {
              root.detectedDisplayScale = Number(monitors[i].scale)
              return
            }
          }
        } catch (error) {
          // Keep Qt's DPR fallback if Hyprland IPC is temporarily unavailable.
        }
      }
    }
  }

  Process {
    id: quoteProc
    command: ["bash", root.quoteScript]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var next = String(text || "").trim()
        if (next.length > 0) root.quoteText = next
      }
    }
  }

  Rectangle {
    anchors.fill: parent
    color: Color.background

    Image {
      id: wallpaper
      anchors.fill: parent
      source: root.loadBackground ? root.fileUrl(root.backgroundPath) : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: false
      sourceSize.width: width
      sourceSize.height: height
    }

    MultiEffect {
      anchors.fill: wallpaper
      source: wallpaper
      autoPaddingEnabled: false
      blurEnabled: root.loadBackground && wallpaper.status === Image.Ready
      blur: 1.0
      // The old Hyprlock background used blur_passes=3 and blur_size=7.
      // Use a moderately stronger blur while preserving the wallpaper shape;
      // the stock shell's 128px blur remains substantially stronger.
      blurMax: 32
      blurMultiplier: 1.0
    }

    // These elements mirror the layout in
    // ~/coding/dotfile/.config/hypr/hyprlock.conf. Hyprlock positions are
    // physical pixels, so values are divided by the current output scale.
    Text {
      id: quoteLabel
      width: Math.max(1, parent.width - 80 / root.displayScale)
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      // Hyprlock uses a bottom-left coordinate system: negative Y moves down.
      anchors.verticalCenterOffset: 500 / root.displayScale
      text: root.quoteText
      color: Qt.rgba(200 / 255, 200 / 255, 200 / 255, 0.9)
      font.family: "CaskaydiaMono Nerd Font"
      font.pixelSize: 20 * root.pangoPointScale / root.displayScale
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
      z: 2
    }

    Text {
      id: hoursShadow
      width: parent.width
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      anchors.horizontalCenterOffset: 1 / root.displayScale
      anchors.verticalCenterOffset: (-400 + 1) / root.displayScale
      text: root.hoursText
      textFormat: Text.PlainText
      color: Qt.rgba(94 / 255, 94 / 255, 94 / 255, 0.5)
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: root.timeFontSize
      font.bold: true
      horizontalAlignment: Text.AlignHCenter
      z: 2
    }

    Text {
      id: hoursLabel
      width: parent.width
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: -400 / root.displayScale
      text: root.hoursText
      textFormat: Text.PlainText
      color: "white"
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: root.timeFontSize
      font.bold: true
      horizontalAlignment: Text.AlignHCenter
      z: 3
    }

    Text {
      id: minutesShadow
      width: parent.width
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      anchors.horizontalCenterOffset: 1 / root.displayScale
      anchors.verticalCenterOffset: (-200 + 1) / root.displayScale
      text: root.minutesText
      textFormat: Text.PlainText
      color: Qt.rgba(94 / 255, 94 / 255, 94 / 255, 0.5)
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: root.timeFontSize
      font.bold: true
      horizontalAlignment: Text.AlignHCenter
      z: 2
    }

    Text {
      id: minutesLabel
      width: parent.width
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: -200 / root.displayScale
      text: root.minutesText
      textFormat: Text.PlainText
      color: "white"
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: root.timeFontSize
      font.bold: true
      horizontalAlignment: Text.AlignHCenter
      z: 3
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
      onPositionChanged: root.wakeRequested()
    }

    Item {
      id: inputFieldContainer
      width: root.fieldWidth
      height: root.fieldHeight
      anchors.horizontalCenter: parent.horizontalCenter
      // Keep the input field in the lower-half position selected in preview.
      y: (parent.height - height) / 2 + root.fieldYOffset
      opacity: 0
      scale: 0.94
      transformOrigin: Item.Center
      z: 4

      BorderSurface {
        id: inputField
        anchors.fill: parent
        color: Qt.rgba(255 / 255, 255 / 255, 255 / 255, 0.1)
        borderSpec: root.inputBorderSpec
        radius: 22 / root.displayScale
        clip: true
        transformOrigin: Item.Center
        transform: Translate {
          id: inputShake
          x: 0
        }

        TextInput {
          id: passwordInput
          anchors.fill: parent
          anchors.topMargin: inputField.borderTop
          // Reserve the fingerprint icon's width on both sides so the centered
          // dots stay symmetric and never slide under it as they grow.
          anchors.rightMargin: inputField.borderRight + 18 / root.displayScale + root.fingerprintReserve
          anchors.bottomMargin: inputField.borderBottom
          anchors.leftMargin: inputField.borderLeft + 18 / root.displayScale + root.fingerprintReserve
          verticalAlignment: TextInput.AlignVCenter
          horizontalAlignment: TextInput.AlignHCenter
          activeFocusOnPress: true
          clip: true
          enabled: root.inputEnabled && !root.authenticatingPassword
          readOnly: root.authenticatingPassword
          echoMode: TextInput.Password
          passwordCharacter: "\u25CF"
          passwordMaskDelay: 0
          color: "transparent"
          selectionColor: "transparent"
          selectedTextColor: "transparent"
          font.family: "CaskaydiaMono Nerd Font"
          font.pixelSize: root.fieldFontSize
          cursorVisible: false
          cursorDelegate: Item {
            width: 0
            visible: false
          }

          onTextChanged: {
            root.syncPasswordDots(text.length)
            if (!root.syncingPasswordText) {
              root.passwordTextEdited(text)
            }
            if (text.length > 0) root.wakeRequested()
            if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
          }

          onAccepted: {
            var submitted = root.passwordText
            root.passwordTextEdited("")
            if (submitted.length > 0) root.submitPassword(submitted)
          }

          Keys.onPressed: function(event) {
            root.wakeRequested()
            if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
              root.passwordTextEdited("")
              event.accepted = true
            }
          }
        }

        ListModel {
          id: passwordDotModel
        }

        Row {
          id: passwordDots
          anchors.centerIn: passwordInput
          spacing: root.passwordDotSpacing * root.passwordDotScale
          visible: passwordInput.text.length > 0
          z: 2

          Repeater {
            model: passwordDotModel

            delegate: Rectangle {
              id: passwordDot
              width: root.passwordDotSize * root.passwordDotScale
              height: width
              radius: width / 2
              color: Color.foreground
              opacity: 0

              Component.onCompleted: dotAppear.start()

              NumberAnimation {
                id: dotAppear
                target: passwordDot
                property: "opacity"
                from: 0
                to: 1
                duration: 520
                easing.type: Easing.OutCubic
              }
            }
          }
        }

        Text {
          anchors.fill: passwordInput
          text: root.authenticatingPassword ? "Checking…" : (root.failureMessage.length > 0 ? root.failureMessage : root.placeholderText)
          visible: passwordInput.text.length === 0
          color: Color.foreground
          font.family: "CaskaydiaMono Nerd Font"
          font.pixelSize: root.fieldFontSize
          font.italic: !root.authenticatingPassword && root.failureMessage.length > 0
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          elide: Text.ElideRight
        }

        // Fingerprint hint pinned inside the field's right edge when a sensor
        // is enrolled, matching Hyprlock's indicator placement.
        Text {
          id: fingerprintIcon
          objectName: "fingerprintIndicator"
          anchors.right: parent.right
          anchors.rightMargin: inputField.borderRight + 18 / root.displayScale
          anchors.verticalCenter: parent.verticalCenter
          visible: root.fingerprintConfigured
          text: "󰈷"
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Math.round(root.fieldFontSize * 1.1)
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
      }

      ParallelAnimation {
        id: inputReveal
        NumberAnimation {
          target: inputFieldContainer
          property: "opacity"
          from: 0
          to: 1
          duration: 240
          easing.type: Easing.OutCubic
        }
        NumberAnimation {
          target: inputFieldContainer
          property: "scale"
          from: 0.94
          to: 1
          duration: 320
          easing.type: Easing.OutBack
        }
      }

      SequentialAnimation {
        id: inputFailureShake
        NumberAnimation { target: inputShake; property: "x"; to: -12 / root.displayScale; duration: 45 }
        NumberAnimation { target: inputShake; property: "x"; to: 12 / root.displayScale; duration: 70 }
        NumberAnimation { target: inputShake; property: "x"; to: -8 / root.displayScale; duration: 60 }
        NumberAnimation { target: inputShake; property: "x"; to: 8 / root.displayScale; duration: 60 }
        NumberAnimation { target: inputShake; property: "x"; to: 0; duration: 70; easing.type: Easing.OutCubic }
      }
    }
  }
}
