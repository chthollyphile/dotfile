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

  readonly property string home: Quickshell.env("HOME")
  readonly property string quoteScript: root.home + "/.config/hypr/get_hitokoto.sh"
  readonly property real displayScale: Math.max(1, Screen.devicePixelRatio || 1)
  readonly property string placeholderText: "as the Nights Reincarnation..."
  readonly property real fieldWidth: 650 / root.displayScale
  readonly property real fieldHeight: 100 / root.displayScale
  readonly property real outlineThickness: 3 / root.displayScale
  readonly property real fieldFontSize: 16 / root.displayScale
  readonly property real passwordDotFontSize: 16 / root.displayScale
  readonly property real passwordDotLetterSpacing: 3 / root.displayScale
  // Space to keep clear on each side of the field for the fingerprint icon
  // (icon width plus a gap) so the centered dots never run under it.
  readonly property real fingerprintReserve: fingerprintConfigured ? Math.round(fingerprintIcon.implicitWidth + 12) : 0
  // Shrink the dots to fit once the password outgrows the field, so every
  // keystroke stays visible — otherwise long passwords clip with no feedback.
  readonly property real passwordDotScale: dotMetrics.advanceWidth > 0
    ? Math.min(1, (passwordInput.width - 4) / dotMetrics.advanceWidth)
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
      Qt.callLater(refreshQuote)
    }
  }
  Component.onCompleted: {
    syncPasswordText()
    updateClock()
    if (loadBackground) refreshQuote()
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

  // Measures the masked password at full size; passwordDotScale compares this
  // against the field width to decide how far the dots must shrink to fit.
  TextMetrics {
    id: dotMetrics
    font.family: "CaskaydiaMono Nerd Font"
    font.pixelSize: root.passwordDotFontSize
    font.letterSpacing: root.passwordDotLetterSpacing
    text: "●".repeat(passwordInput.text.length)
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
      blurMax: 128
      blurMultiplier: 1.25
      contrast: -0.08
    }

    // These elements mirror the layout in
    // ~/coding/dotfile/.config/hypr/hyprlock.conf. Hyprlock positions are
    // physical pixels, so values are divided by the current output scale.
    Text {
      id: quoteLabel
      width: Math.max(1, parent.width - 80 / root.displayScale)
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: -500 / root.displayScale
      text: root.quoteText
      color: Qt.rgba(200 / 255, 200 / 255, 200 / 255, 0.9)
      font.family: "CaskaydiaMono Nerd Font"
      font.pixelSize: 20 / root.displayScale
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
      z: 2
    }

    Text {
      id: hoursShadow
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: 520 / root.displayScale
      x: 1 / root.displayScale
      y: 1 / root.displayScale
      text: "<b><big> " + root.hoursText + " </big></b>"
      textFormat: Text.RichText
      color: Qt.rgba(94 / 255, 94 / 255, 94 / 255, 0.5)
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: 160 / root.displayScale
      z: 2
    }

    Text {
      id: hoursLabel
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: 520 / root.displayScale
      text: "<b><big> " + root.hoursText + " </big></b>"
      textFormat: Text.RichText
      color: "white"
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: 160 / root.displayScale
      z: 3
    }

    Text {
      id: minutesShadow
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: 320 / root.displayScale
      x: 1 / root.displayScale
      y: 1 / root.displayScale
      text: "<b><big> " + root.minutesText + " </big></b>"
      textFormat: Text.RichText
      color: Qt.rgba(94 / 255, 94 / 255, 94 / 255, 0.5)
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: 160 / root.displayScale
      z: 2
    }

    Text {
      id: minutesLabel
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: 320 / root.displayScale
      text: "<b><big> " + root.minutesText + " </big></b>"
      textFormat: Text.RichText
      color: "white"
      font.family: "JetBrainsMono Nerd Font Propo"
      font.pixelSize: 160 / root.displayScale
      z: 3
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
      onPositionChanged: root.wakeRequested()
    }

    BorderSurface {
      id: inputField
      width: root.fieldWidth
      height: root.fieldHeight
      anchors.horizontalCenter: parent.horizontalCenter
      y: (parent.height - height) / 2 - 350 / root.displayScale
      color: Qt.rgba(255 / 255, 255 / 255, 255 / 255, 0.1)
      borderSpec: root.inputBorderSpec
      radius: 22 / root.displayScale
      clip: true
      z: 4

      TextInput {
        id: passwordInput
        anchors.fill: parent
        anchors.topMargin: inputField.borderTop
        // Reserve the fingerprint icon's width on both sides so the centered
        // dots stay symmetric and never slide under the icon as they grow.
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
        color: Color.foreground
        selectionColor: Color.accent
        selectedTextColor: Color.foreground
        font.family: "CaskaydiaMono Nerd Font"
        font.pixelSize: text.length > 0 ? Math.max(1, Math.floor(root.passwordDotFontSize * root.passwordDotScale)) : root.fieldFontSize
        font.letterSpacing: text.length > 0 ? root.passwordDotLetterSpacing * root.passwordDotScale : 0
        cursorVisible: activeFocus && root.showPasswordCursor && text.length > 0
        cursorDelegate: Rectangle {
          width: 2
          color: Color.foreground
          visible: passwordInput.cursorVisible
        }

        onTextChanged: {
          if (!root.syncingPasswordText) root.passwordTextEdited(text)
          if (text.length > 0) {
            root.wakeRequested()
          }
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

      // Fingerprint hint pinned inside the field's right edge when a sensor is
      // enrolled, so the user knows they can touch to unlock instead of typing.
      // Matches hyprlock, which draws its fingerprint icon in the same spot.
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
  }
}
