import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui
import "LyricModel.js" as LyricModel

// A small bar widget for Folia's local v1 lyric snapshot API.
//
// Folia supplies the lyric time axis, while MPRIS supplies the current
// playback position. The latter is necessary because the Folia API is a
// snapshot API and deliberately does not expose playback state.
BarWidget {
  id: root
  moduleName: "lia.folia-lyrics"

  readonly property string apiUrl: String(setting("apiUrl", "http://127.0.0.1:32109/v1/lyric"))
  readonly property int maxWidth: Math.max(120, Math.min(640, Number(setting("maxWidth", 280)) || 280))
  readonly property int pollInterval: Math.max(500, Math.min(5000, Number(setting("pollInterval", 750)) || 750))
  readonly property bool glowEnabled: String(setting("glow", "on")) !== "off"
  readonly property string displayMode: String(setting("displayMode", "auto")).toLowerCase()
  readonly property bool mprisOnly: displayMode === "mpris"
  readonly property string lyricTextPriority: String(setting("lyricTextPriority", "original")).toLowerCase()
  readonly property bool preferTranslation: lyricTextPriority === "translation"

  property var lyric: null
  property string lyricSignature: ""
  property bool apiAvailable: false
  property string apiError: ""
  property int positionTick: 0

  readonly property var mediaService: bar?.shell?.firstPartyServiceFor("omarchy.media")
  readonly property var mediaPlayers: Mpris.players ? Mpris.players.values : []
  readonly property var fallbackPlayer: findFallbackPlayer()
  readonly property var activePlayer: mediaService && mediaService.activePlayer
    ? mediaService.activePlayer
    : fallbackPlayer
  readonly property bool playbackRunning: activePlayer !== null && activePlayer.isPlaying === true
  readonly property real playbackPosition: positionTick >= 0 && activePlayer
    ? Number(activePlayer.position)
    : -1
  readonly property var currentLine: mprisOnly
    ? null
    : LyricModel.findActiveLine(lyric, playbackPosition)
  readonly property string mprisTitle: activePlayer
    ? String(activePlayer.trackTitle || activePlayer.trackArtist || "").replace(/^\s+/, "")
    : ""
  readonly property bool showingMprisTitle: currentLine === null && mprisTitle !== ""
  readonly property bool showingTranslation: currentLine !== null
    && preferTranslation
    && Array.isArray(currentLine.translationWords)
    && currentLine.translationWords.length > 0
  readonly property bool afterLyrics: lyric !== null
    && Array.isArray(lyric.lines)
    && lyric.lines.length > 0
    && playbackPosition >= lyric.lines[lyric.lines.length - 1].endTime
  readonly property var mprisTitleWords: showingMprisTitle
    ? [{ text: mprisTitle, startTime: 0, endTime: 0, isMprisTitle: true }]
    : []
  readonly property var currentWords: currentLine && Array.isArray(currentLine.words)
    ? (showingTranslation ? currentLine.translationWords : currentLine.words)
    : mprisTitleWords
  readonly property bool hasLine: currentWords.length > 0
  readonly property string currentText: currentLine
    ? String(showingTranslation ? currentLine.translation : (currentLine.text || ""))
    : (showingMprisTitle ? mprisTitle : "")
  readonly property string trackLabel: lyric
    ? [lyric.title || "", lyric.artist || ""].filter(function(value) { return value !== "" }).join(" — ")
    : (activePlayer
      ? [activePlayer.trackTitle || "", activePlayer.trackArtist || ""].filter(function(value) { return value !== "" }).join(" — ")
      : "")

  visible: hasLine
  implicitWidth: root.vertical
    ? root.barSize
    : (root.hasLine ? Math.min(root.maxWidth, lyricRow.implicitWidth) + Style.space(14) : 0)
  implicitHeight: root.barSize

  function findFallbackPlayer() {
    var players = mediaPlayers

    for (var i = 0; i < players.length; i++) {
      var candidate = players[i]
      if (candidate && candidate.isPlaying && (candidate.trackTitle || candidate.trackArtist)) return candidate
    }

    for (var j = 0; j < players.length; j++) {
      var fallback = players[j]
      if (fallback && (fallback.trackTitle || fallback.trackArtist)) return fallback
    }

    return null
  }

  function refreshLyrics() {
    if (root.mprisOnly) return
    if (lyricProcess.running) return
    lyricProcess.running = true
  }

  function togglePlayback() {
    if (root.mediaService) {
      var targetKey = root.activePlayer
        ? root.mediaService.playerKey(root.activePlayer)
        : ""
      root.mediaService.runAction("playPause", false, targetKey)
      return
    }

    var player = root.activePlayer
    if (!player) return
    if (player.canTogglePlaying) player.togglePlaying()
    else if (player.isPlaying && player.canPause) player.pause()
    else if (!player.isPlaying && player.canPlay) player.play()
  }

  function syncScrollAnimation(resetPosition) {
    if (!scrollAnimation || !lyricRow || !horizontalViewport) return

    var shouldScroll = lyricRow.needsScroll && root.hasLine && !root.vertical
    if (resetPosition) {
      scrollAnimation.stop()
      lyricRow.x = 0
    }

    if (!shouldScroll) {
      scrollAnimation.stop()
      lyricRow.x = 0
      return
    }

    if (!root.playbackRunning) {
      if (scrollAnimation.running && !scrollAnimation.paused) scrollAnimation.pause()
      else if (!scrollAnimation.running) lyricRow.x = 0
      return
    }

    if (!scrollAnimation.running) scrollAnimation.start()
    else if (scrollAnimation.paused) scrollAnimation.resume()
  }

  function acceptResponse(raw) {
    var parsed
    try {
      parsed = JSON.parse(String(raw || "").trim())
    } catch (error) {
      markUnavailable("invalid JSON")
      return
    }

    var normalized = LyricModel.normalizeResponse(parsed)
    var nextSignature = LyricModel.signature(normalized)
    apiAvailable = true
    apiError = ""

    if (nextSignature !== lyricSignature) {
      lyricSignature = nextSignature
      lyric = normalized
    }
  }

  function markUnavailable(reason) {
    apiAvailable = false
    apiError = reason || "connection failed"
    lyricSignature = ""
    lyric = null
  }

  function foregroundColor() {
    return root.bar ? root.bar.barForeground : Color.foreground
  }

  function activeColor() {
    return root.bar ? root.bar.urgent : Color.urgent
  }

  function wordColor(word) {
    return root.foregroundColor()
  }

  function wordOpacity(word) {
    if (word && word.isMprisTitle) return 1.0
    var state = LyricModel.wordState(word, root.playbackPosition)
    if (state === "current") return 1.0
    if (state === "past") return 0.72
    return 0.30
  }

  function tooltipText() {
    if (!root.activePlayer) return "Folia Lyrics: no MPRIS player"

    var lines = []
    if (root.trackLabel !== "") lines.push(root.trackLabel)
    if (!root.showingMprisTitle && root.currentText !== "") lines.push(root.currentText)
    if (root.mprisOnly) lines.push("MPRIS mode")
    else if (!root.apiAvailable) lines.push("Folia API unavailable — showing MPRIS title")
    else if (!root.lyric) lines.push("No lyrics — showing MPRIS title")
    return lines.join("\n") || "Folia Lyrics"
  }

  onCurrentLineChanged: {
    Qt.callLater(function() { root.syncScrollAnimation(true) })
  }


  onMprisTitleChanged: Qt.callLater(function() { root.syncScrollAnimation(true) })
  onShowingTranslationChanged: Qt.callLater(function() { root.syncScrollAnimation(true) })
  onPlaybackRunningChanged: Qt.callLater(function() { root.syncScrollAnimation(false) })
  onVerticalChanged: Qt.callLater(function() { root.syncScrollAnimation(false) })

  onMprisOnlyChanged: {
    if (!mprisOnly) refreshLyrics()
  }

  Timer {
    id: lyricTimer
    interval: root.pollInterval
    repeat: true
    running: !root.mprisOnly
    onTriggered: root.refreshLyrics()
  }

  Timer {
    id: positionTimer
    interval: 80
    repeat: true
    running: root.activePlayer !== null && root.activePlayer.isPlaying === true
    onTriggered: {
      // MprisPlayer.position is intentionally lazy. Emitting its change
      // signal makes the binding above sample the current DBus position.
      try {
        if (root.activePlayer) root.activePlayer.positionChanged()
      } catch (error) {
        // Some players expose position but do not implement active updates.
      }
      root.positionTick += 1
    }
  }

  Process {
    id: lyricProcess
    command: [
      "curl",
      "--silent",
      "--show-error",
      "--fail",
      "--connect-timeout", "1",
      "--max-time", "2",
      "--header", "Cache-Control: no-cache",
      root.apiUrl
    ]

    stdout: StdioCollector {
      id: lyricOutput
      waitForEnd: true
    }

    stderr: StdioCollector {
      id: lyricErrorOutput
      waitForEnd: true
    }

    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.markUnavailable("curl exited " + exitCode)
        return
      }
      root.acceptResponse(lyricOutput.text)
    }
  }

  IpcHandler {
    target: "lia.folia-lyrics"

    function refresh(): void { root.broadcast("refreshLyrics") }

    function status(): string {
      return JSON.stringify({
        displayMode: root.displayMode,
        lyricTextPriority: root.lyricTextPriority,
        apiAvailable: root.apiAvailable,
        hasLyric: root.lyric !== null,
        lyricOffsetMs: root.lyric ? Number(root.lyric.offset || 0) : 0,
        afterLyrics: root.afterLyrics,
        hasPlayer: root.activePlayer !== null,
        playerIdentity: root.activePlayer ? String(root.activePlayer.identity || "") : "",
        playerPlaying: root.activePlayer ? root.activePlayer.isPlaying === true : false,
        mprisTitle: root.mprisTitle,
        showingMprisTitle: root.showingMprisTitle,
        showingTranslation: root.showingTranslation,
        wordCount: root.currentWords.length,
        visible: root.visible,
        scrollX: lyricRow.x,
        contentWidth: lyricRow.implicitWidth,
        viewportWidth: horizontalViewport.width,
        scrollRunning: scrollAnimation.running,
        scrollPaused: scrollAnimation.paused
      })
    }
  }

  Item {
    id: horizontalViewport
    visible: !root.vertical && root.hasLine
    width: Math.min(root.maxWidth, lyricRow.implicitWidth)
    height: root.barSize
    anchors.centerIn: parent
    clip: true

    Row {
      id: glowRow
      z: 0
      x: lyricRow.x
      height: parent.height
      spacing: 0
      anchors.verticalCenter: parent.verticalCenter

      Repeater {
        model: root.currentWords

        Item {
          id: glowWord
          required property var modelData
          readonly property bool current: !modelData.isMprisTitle
            && LyricModel.wordState(modelData, root.playbackPosition) === "current"

          width: textMetrics.implicitWidth
          height: glowRow.height

          Text {
            id: textMetrics
            visible: false
            text: String(glowWord.modelData.text || "")
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
          }

          Text {
            anchors.centerIn: parent
            text: textMetrics.text
            color: root.activeColor()
            opacity: root.glowEnabled && glowWord.current ? 0.20 : 0
            scale: 1.10
            font: textMetrics.font
            renderType: Text.NativeRendering

            Behavior on opacity {
              NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
          }

          Text {
            anchors.centerIn: parent
            text: textMetrics.text
            color: root.activeColor()
            opacity: root.glowEnabled && glowWord.current ? 0.08 : 0
            scale: 1.24
            font: textMetrics.font
            renderType: Text.NativeRendering

            Behavior on opacity {
              NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
          }
        }
      }
    }

    Row {
      id: lyricRow
      z: 1
      height: parent.height
      spacing: 0
      anchors.verticalCenter: parent.verticalCenter

      readonly property bool needsScroll: implicitWidth > horizontalViewport.width

      onNeedsScrollChanged: Qt.callLater(function() { root.syncScrollAnimation(false) })

      SequentialAnimation {
        id: scrollAnimation
        loops: Animation.Infinite

        PauseAnimation { duration: 1000 }
        NumberAnimation {
          target: lyricRow
          property: "x"
          from: 0
          to: horizontalViewport.width - lyricRow.implicitWidth
          duration: Math.max(3000, (lyricRow.implicitWidth - horizontalViewport.width) * 42)
          easing.type: Easing.Linear
        }
        PauseAnimation { duration: 1200 }
      }

      Repeater {
        model: root.currentWords

        Text {
          required property var modelData

          readonly property string lyricState: modelData.isMprisTitle
            ? "title"
            : LyricModel.wordState(modelData, root.playbackPosition)

          text: String(modelData.text || "")
          color: root.wordColor(modelData)
          opacity: root.wordOpacity(modelData)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
          font.bold: lyricState === "current"
          font.strikeout: root.activePlayer !== null && !root.playbackRunning
          renderType: Text.NativeRendering
          verticalAlignment: Text.AlignVCenter
          height: lyricRow.height
          scale: lyricState === "current" ? 1.04 : 1.0

          Behavior on color {
            enabled: !root.bar || root.bar.foregroundAnimationEnabled
            ColorAnimation { duration: 100 }
          }

          Behavior on opacity {
            NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
          }

          Behavior on scale {
            NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
          }
        }
      }
    }
  }

  Text {
    visible: root.vertical && root.hasLine
    anchors.centerIn: parent
    text: "♫"
    color: root.activeColor()
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.body
    renderType: Text.NativeRendering
  }

  MouseArea {
    anchors.fill: parent
    enabled: root.hasLine
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    cursorShape: Qt.PointingHandCursor

    onEntered: if (root.bar) root.bar.showTooltip(root, root.tooltipText())
    onExited: if (root.bar) root.bar.hideTooltip(root)
    onClicked: function(mouse) {
      if (mouse.button === Qt.LeftButton) root.togglePlayback()
      else root.refreshLyrics()
    }
  }

  Component.onCompleted: {
    if (!root.mprisOnly) root.refreshLyrics()
    Qt.callLater(function() { root.syncScrollAnimation(false) })
  }
}
