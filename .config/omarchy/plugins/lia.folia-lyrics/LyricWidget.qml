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
  readonly property bool detailPopupEnabled: String(setting("detailPopup", "on")) !== "off"
  // The lyric snapshot always comes from Folia, so an unrelated MPRIS player
  // must not drive the lyric time axis. Empty accepts any player.
  readonly property string playerMatch: String(setting("playerMatch", "folia"))
  readonly property int popupWidth: Math.max(240, Math.min(520, Number(setting("popupWidth", 320)) || 320))
  readonly property int popupHideDelay: Math.max(0, Math.min(2000, Number(setting("popupHideDelay", 250)) || 250))

  property var lyric: null
  property string lyricSignature: ""
  property bool apiAvailable: false
  property string apiError: ""
  property int positionTick: 0
  property bool popupOpen: false

  readonly property var mediaService: bar?.shell?.firstPartyServiceFor("omarchy.media")
  readonly property var mediaPlayers: Mpris.players ? Mpris.players.values : []
  readonly property var fallbackPlayer: findFallbackPlayer()
  readonly property var playerMatchTokens: playerMatch.toLowerCase().split(",")
    .map(function(token) { return token.trim() })
    .filter(function(token) { return token !== "" })
  readonly property var matchedPlayer: playerMatchTokens.length > 0 ? findMatchedPlayer() : null
  readonly property bool otherPlayerPlaying: hasPlayingPlayer(matchedPlayer)
  // The lyric source outranks whatever omarchy.media considers active unless
  // some other player is genuinely playing, so a paused Folia still shows its
  // own lyrics rather than an idle player picked at random.
  readonly property var activePlayer: matchedPlayer && (matchedPlayer.isPlaying === true || !otherPlayerPlaying)
    ? matchedPlayer
    : (mediaService && mediaService.activePlayer
      ? mediaService.activePlayer
      : fallbackPlayer)
  // Lyrics only advance while the player on screen is the one the snapshot
  // describes; otherwise the widget falls back to that player's MPRIS title.
  readonly property bool lyricPlayerActive: playerMatchTokens.length === 0
    || playerMatches(activePlayer)
  readonly property bool playbackRunning: activePlayer !== null && activePlayer.isPlaying === true
  readonly property real playbackPosition: positionTick >= 0 && activePlayer
    ? Number(activePlayer.position)
    : -1
  readonly property var currentLine: mprisOnly || !lyricPlayerActive
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
    && lyricPlayerActive
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
  readonly property string trackLabel: lyric && lyricPlayerActive
    ? [lyric.title || "", lyric.artist || ""].filter(function(value) { return value !== "" }).join(" — ")
    : (activePlayer
      ? [activePlayer.trackTitle || "", activePlayer.trackArtist || ""].filter(function(value) { return value !== "" }).join(" — ")
      : "")

  // Detail popup inputs. These read MPRIS directly rather than going through
  // omarchy.media so the popup keeps working on a bare Quickshell setup where
  // that service is absent.
  readonly property string mprisArtUrl: activePlayer && activePlayer.trackArtUrl
    ? String(activePlayer.trackArtUrl)
    : ""
  readonly property string mprisArtist: activePlayer ? String(activePlayer.trackArtist || "") : ""
  readonly property string mprisAlbum: activePlayer && activePlayer.trackAlbum
    ? String(activePlayer.trackAlbum)
    : ""
  readonly property real trackLength: activePlayer && activePlayer.lengthSupported
    ? Number(activePlayer.length)
    : 0
  readonly property real playbackProgress: trackLength > 0 && playbackPosition >= 0
    ? Math.max(0, Math.min(1, playbackPosition / trackLength))
    : 0
  // The bar shows either the original or the translation; the popup has room
  // for both, so it ignores lyricTextPriority entirely.
  readonly property var popupWords: currentLine && Array.isArray(currentLine.words)
    ? currentLine.words
    : []
  readonly property string popupTranslation: currentLine && currentLine.translation
    ? String(currentLine.translation)
    : ""

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

  // Identity, desktop entry and bus name are all checked because a player only
  // reliably exposes some of them, and which ones differs between builds.
  function playerMatches(player) {
    if (!player) return false

    var tokens = root.playerMatchTokens
    if (tokens.length === 0) return true

    var haystack = [player.identity, player.desktopEntry, player.dbusName]
      .map(function(value) { return String(value || "").toLowerCase() })
      .join("\n")

    for (var i = 0; i < tokens.length; i++) {
      if (haystack.indexOf(tokens[i]) !== -1) return true
    }

    return false
  }

  function hasPlayingPlayer(exclude) {
    var players = mediaPlayers

    for (var i = 0; i < players.length; i++) {
      if (players[i] && players[i] !== exclude && players[i].isPlaying) return true
    }

    return false
  }

  function findMatchedPlayer() {
    var players = mediaPlayers

    for (var i = 0; i < players.length; i++) {
      if (players[i] && players[i].isPlaying && playerMatches(players[i])) return players[i]
    }

    for (var j = 0; j < players.length; j++) {
      if (playerMatches(players[j])) return players[j]
    }

    return null
  }

  function refreshLyrics() {
    if (root.mprisOnly) return
    if (lyricProcess.running) return
    lyricProcess.running = true
  }

  // Transport control talks to MprisPlayer directly. omarchy.media is only
  // consulted for *which* player is active, so the widget behaves the same
  // whether or not that service is installed.
  function togglePlayback() {
    var player = root.activePlayer
    if (!player) return
    if (player.canTogglePlaying) player.togglePlaying()
    else if (player.isPlaying && player.canPause) player.pause()
    else if (!player.isPlaying && player.canPlay) player.play()
  }

  function playerPrevious() {
    var player = root.activePlayer
    if (player && player.canGoPrevious) player.previous()
  }

  function playerNext() {
    var player = root.activePlayer
    if (player && player.canGoNext) player.next()
  }

  // The bar host coordinates popouts by calling close() on whichever owner is
  // currently open, so this name is part of that contract.
  function close() {
    popupOpen = false
  }

  function openDetailPopup() {
    if (!root.detailPopupEnabled || !root.activePlayer) return
    // A hover must never steal the popout from a panel the user clicked open.
    if (root.bar && root.bar.activePopout && root.bar.activePopout !== root) return
    popupHideTimer.stop()
    popupOpen = true
  }

  function scheduleHideDetailPopup() {
    if (!popupOpen) return
    popupHideTimer.restart()
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

  // Shown in the popup's lyric area when there is no synchronized line to
  // display, so the card still explains itself instead of looking broken.
  function lyricStatusText() {
    if (root.mprisOnly) return "MPRIS mode"
    if (!root.lyricPlayerActive) return "Another player is active"
    if (!root.apiAvailable) return "Folia API unavailable"
    if (!root.lyric) return "No lyrics for this track"
    if (root.afterLyrics) return "Lyrics finished"
    return "Waiting for lyrics to start"
  }

  function tooltipText() {
    if (!root.activePlayer) return "Folia Lyrics: no MPRIS player"

    var lines = []
    if (root.trackLabel !== "") lines.push(root.trackLabel)
    if (!root.showingMprisTitle && root.currentText !== "") lines.push(root.currentText)
    if (root.mprisOnly) lines.push("MPRIS mode")
    else if (!root.lyricPlayerActive) lines.push("Another player is active — showing MPRIS title")
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

  onActivePlayerChanged: {
    if (!activePlayer) popupOpen = false
  }

  // The widget hides itself when there is nothing to show. Without this the
  // card would be left open with its trigger gone, and no hover event able to
  // reach it to close it again.
  onHasLineChanged: {
    if (!hasLine) popupOpen = false
  }

  onDetailPopupEnabledChanged: {
    if (!detailPopupEnabled) popupOpen = false
  }

  // The pointer has to cross the gap between the bar and the card, so the
  // close is deferred rather than tied to a single exit event.
  Timer {
    id: popupHideTimer
    interval: root.popupHideDelay
    repeat: false
    onTriggered: {
      if (detailPopup.containsMouse || barHover.containsMouse) return
      root.popupOpen = false
    }
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
        playerMatch: root.playerMatch,
        lyricPlayerActive: root.lyricPlayerActive,
        matchedPlayerIdentity: root.matchedPlayer ? String(root.matchedPlayer.identity || "") : "",
        mprisTitle: root.mprisTitle,
        showingMprisTitle: root.showingMprisTitle,
        showingTranslation: root.showingTranslation,
        wordCount: root.currentWords.length,
        popupEnabled: root.detailPopupEnabled,
        popupOpen: root.popupOpen,
        hasArt: root.mprisArtUrl !== "",
        trackLength: root.trackLength,
        playbackProgress: root.playbackProgress,
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
    id: barHover
    anchors.fill: parent
    enabled: root.hasLine
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    cursorShape: Qt.PointingHandCursor

    // The detail card supersedes the tooltip rather than stacking with it.
    onEntered: {
      if (root.detailPopupEnabled) root.openDetailPopup()
      else if (root.bar) root.bar.showTooltip(root, root.tooltipText())
    }
    onExited: {
      if (root.bar) root.bar.hideTooltip(root)
      root.scheduleHideDetailPopup()
    }
    onClicked: function(mouse) {
      if (mouse.button === Qt.LeftButton) root.togglePlayback()
      else root.refreshLyrics()
    }
  }

  // Hover-triggered detail card. triggerMode "hover" leaves the Hyprland focus
  // grab off, which is what lets the pointer travel from the bar into the card
  // without the popup being dismissed underneath it.
  PopupCard {
    id: detailPopup
    anchorItem: root
    bar: root.bar
    owner: root
    triggerMode: "hover"
    open: root.popupOpen
    contentWidth: detailPopup.fittedContentWidth(Style.space(root.popupWidth))
    contentHeight: detailPopup.fittedContentHeight(popupColumn.implicitHeight)

    onContainsMouseChanged: {
      if (containsMouse) popupHideTimer.stop()
      else root.scheduleHideDetailPopup()
    }

    Column {
      id: popupColumn
      anchors.fill: parent
      spacing: Style.space(10)

      readonly property color popupForeground: root.bar ? root.bar.foreground : Color.foreground
      readonly property string popupFontFamily: root.bar ? root.bar.fontFamily : Style.font.family

      Row {
        id: headerRow
        width: parent.width
        spacing: Style.space(10)

        readonly property int coverSize: Style.space(72)

        BorderSurface {
          width: headerRow.coverSize
          height: headerRow.coverSize
          radius: Style.spacing.labelGap
          color: Style.normalFillFor(popupColumn.popupForeground, Color.accent)
          borderSpec: Border.controlSpec("normal", popupColumn.popupForeground, Color.accent)

          Image {
            id: coverImage
            anchors.fill: parent
            anchors.margins: Style.space(2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            // Art is frequently a full-resolution embedded cover; decoding it
            // at tile size keeps a hover from costing a megabyte of pixmap.
            sourceSize.width: headerRow.coverSize * 2
            sourceSize.height: headerRow.coverSize * 2
            source: root.mprisArtUrl
            visible: source !== "" && status !== Image.Error
          }

          Text {
            anchors.centerIn: parent
            visible: !coverImage.visible
            text: "󰝚"
            color: popupColumn.popupForeground
            font.family: popupColumn.popupFontFamily
            font.pixelSize: Style.font.displayLarge
          }
        }

        Column {
          width: parent.width - headerRow.coverSize - Style.space(10)
          spacing: Style.space(4)

          Text {
            text: root.mprisTitle || root.trackLabel || "Nothing playing"
            color: popupColumn.popupForeground
            font.family: popupColumn.popupFontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
          }

          Text {
            text: root.mprisArtist
            color: Qt.darker(popupColumn.popupForeground, 1.3)
            font.family: popupColumn.popupFontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
            width: parent.width
            visible: text !== ""
          }

          Text {
            text: root.mprisAlbum
            color: Qt.darker(popupColumn.popupForeground, 1.6)
            font.family: popupColumn.popupFontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            width: parent.width
            visible: text !== ""
          }
        }
      }

      Column {
        width: parent.width
        spacing: Style.space(4)
        visible: root.activePlayer !== null

        Rectangle {
          width: parent.width
          height: Style.space(4)
          radius: height / 2
          color: Style.normalFillFor(popupColumn.popupForeground, Color.accent)
          // Players that do not publish a length cannot produce a meaningful
          // ratio, so the track is dropped rather than pinned at zero.
          visible: root.trackLength > 0

          Rectangle {
            width: parent.width * root.playbackProgress
            height: parent.height
            radius: parent.radius
            color: Color.accent
          }
        }

        Item {
          width: parent.width
          height: elapsedText.implicitHeight

          Text {
            id: elapsedText
            anchors.left: parent.left
            text: LyricModel.formatTime(Math.max(0, root.playbackPosition))
            color: Qt.darker(popupColumn.popupForeground, 1.3)
            font.family: popupColumn.popupFontFamily
            font.pixelSize: Style.font.caption
          }

          Text {
            anchors.right: parent.right
            text: LyricModel.formatTime(root.trackLength)
            color: Qt.darker(popupColumn.popupForeground, 1.6)
            font.family: popupColumn.popupFontFamily
            font.pixelSize: Style.font.caption
            visible: root.trackLength > 0
          }
        }
      }

      PanelSeparator {
        foreground: popupColumn.popupForeground
      }

      Column {
        width: parent.width
        spacing: Style.space(4)

        // A Flow rather than a Row: the popup wraps long lines, and the
        // per-word items still need to highlight independently.
        Flow {
          width: parent.width
          spacing: 0
          visible: root.popupWords.length > 0

          Repeater {
            model: root.popupWords

            Text {
              required property var modelData

              readonly property string lyricState: LyricModel.wordState(modelData, root.playbackPosition)

              text: String(modelData.text || "")
              color: popupColumn.popupForeground
              opacity: root.wordOpacity(modelData)
              font.family: popupColumn.popupFontFamily
              font.pixelSize: Style.font.body
              font.bold: lyricState === "current"
              renderType: Text.NativeRendering

              Behavior on opacity {
                NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
              }
            }
          }
        }

        Text {
          width: parent.width
          text: root.popupTranslation
          color: Qt.darker(popupColumn.popupForeground, 1.3)
          font.family: popupColumn.popupFontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.Wrap
          renderType: Text.NativeRendering
          visible: text !== ""
        }

        Text {
          width: parent.width
          text: root.lyricStatusText()
          color: Qt.darker(popupColumn.popupForeground, 1.8)
          font.family: popupColumn.popupFontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.Wrap
          visible: root.popupWords.length === 0
        }
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(6)

        Button {
          iconText: "󰒮"
          foreground: popupColumn.popupForeground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.activePlayer !== null && root.activePlayer.canGoPrevious
          opacity: enabled ? 1.0 : 0.4
          onClicked: root.playerPrevious()
        }

        Button {
          iconText: root.playbackRunning ? "󰏤" : "󰐊"
          foreground: popupColumn.popupForeground
          horizontalPadding: Style.spacing.panelGap
          verticalPadding: Style.spacing.controlPaddingY
          iconSize: Style.font.iconLarge
          enabled: root.activePlayer !== null
            && (root.activePlayer.canTogglePlaying || root.activePlayer.canPlay || root.activePlayer.canPause)
          opacity: enabled ? 1.0 : 0.4
          onClicked: root.togglePlayback()
        }

        Button {
          iconText: "󰒭"
          foreground: popupColumn.popupForeground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.activePlayer !== null && root.activePlayer.canGoNext
          opacity: enabled ? 1.0 : 0.4
          onClicked: root.playerNext()
        }
      }
    }
  }

  Component.onCompleted: {
    if (!root.mprisOnly) root.refreshLyrics()
    Qt.callLater(function() { root.syncScrollAnimation(false) })
  }
}
