// The public Folia v1 contract is intentionally converted to a small, stable
// shape before it reaches QML. This keeps malformed optional fields from
// making a bar delegate fail while it is being rendered.

function numberOr(value, fallback) {
    var number = Number(value)
    return isFinite(number) ? number : fallback
}

function textOr(value, fallback) {
    if (value === undefined || value === null) return fallback
    return String(value)
}

function normalizeWord(value, fallbackStart, fallbackEnd, offsetSeconds) {
    if (!value || typeof value !== "object") return null

    var text = textOr(value.text, "")
    if (text.length === 0) return null

    var rawStartTime = numberOr(value.startTime, fallbackStart)
    var rawEndTime = numberOr(value.endTime, fallbackEnd)
    if (rawEndTime < rawStartTime) rawEndTime = rawStartTime

    return {
        text: text,
        startTime: rawStartTime + offsetSeconds,
        endTime: rawEndTime + offsetSeconds
    }
}

function normalizeLine(value, offsetSeconds) {
    if (!value || typeof value !== "object") return null

    // A few lyric sources encode line indentation in the first token. It is
    // not meaningful in a one-line bar and otherwise looks like the marquee
    // has stopped before the lyric begins.
    var text = textOr(value.text, "").replace(/^\s+/, "")
    var rawStartTime = numberOr(value.startTime, 0)
    var rawEndTime = numberOr(value.endTime, rawStartTime)
    if (rawEndTime < rawStartTime) rawEndTime = rawStartTime
    var startTime = rawStartTime + offsetSeconds
    var endTime = rawEndTime + offsetSeconds

    var words = []
    var sourceWords = Array.isArray(value.words) ? value.words : []
    for (var i = 0; i < sourceWords.length; i++) {
        var word = normalizeWord(sourceWords[i], rawStartTime, rawEndTime, offsetSeconds)
        if (word && words.length === 0) word.text = word.text.replace(/^\s+/, "")
        if (word) words.push(word)
    }

    // Folia normally supplies words even for line-timed sources. Keep a
    // graceful fallback for older or incomplete responses.
    if (words.length === 0 && text.length > 0) {
        words.push({
            text: text,
            startTime: startTime,
            endTime: endTime
        })
    }

    var line = {
        text: text,
        startTime: startTime,
        endTime: endTime,
        words: words
    }

    var translation = textOr(value.translation, "").replace(/^\s+/, "")
    if (translation.length > 0) {
        line.translation = translation
        // Translations have line timing but no reliable word timing. Store a
        // stable one-item model so QML can switch text priority without
        // rebuilding the delegate on every playback-position update.
        line.translationWords = [{
            text: translation,
            startTime: startTime,
            endTime: endTime,
            isTranslation: true
        }]
    }

    return line
}

function normalizeResponse(value) {
    if (value === null) return null
    if (!value || typeof value !== "object" || Array.isArray(value)) return null
    if (!Array.isArray(value.lines)) return null

    // Compatible providers may supply a signed global offset in
    // milliseconds, while line and word timings remain in seconds.
    var offsetMs = numberOr(value.offset, 0)
    var offsetSeconds = offsetMs / 1000
    var lines = []
    for (var i = 0; i < value.lines.length; i++) {
        var line = normalizeLine(value.lines[i], offsetSeconds)
        if (line && line.text.length > 0 && line.endTime >= line.startTime) lines.push(line)
    }

    lines.sort(function(a, b) { return a.startTime - b.startTime })
    if (lines.length === 0) return null

    var result = {
        lines: lines,
        wordByWord: value.wordByWord === true,
        offset: offsetMs
    }

    var title = textOr(value.title, "")
    if (title.length > 0) result.title = title

    var artist = textOr(value.artist, "")
    if (artist.length > 0) result.artist = artist

    return result
}

function findActiveLine(response, position) {
    var currentTime = numberOr(position, -1)
    if (!response || !Array.isArray(response.lines) || currentTime < 0) return null

    for (var i = 0; i < response.lines.length; i++) {
        var line = response.lines[i]
        if (currentTime < line.startTime) break

        // Keep a finished line on screen during an inter-line timing gap. The
        // final line remains after its word timing ends; the caller replaces
        // the lyric snapshot when the track changes.
        var displayEnd = i + 1 < response.lines.length
            ? response.lines[i + 1].startTime
            : Infinity
        if (currentTime >= line.startTime && currentTime < displayEnd) return line
    }

    return null
}

function wordState(word, position) {
    var currentTime = numberOr(position, -1)
    if (!word || currentTime < 0) return "future"
    if (currentTime >= word.endTime) return "past"
    if (currentTime >= word.startTime) return "current"
    return "future"
}

// MPRIS reports track position and length in seconds. The detail popup shows
// them as mm:ss, so an hour-long track deliberately reads as "72:14" rather
// than growing an hours field that would misalign the shorter common case.
function formatTime(seconds) {
    var total = Math.floor(numberOr(seconds, 0))
    if (!(total >= 0)) total = 0

    var minutes = Math.floor(total / 60)
    var rest = total % 60
    return minutes + ":" + String(rest).padStart(2, "0")
}

function signature(response) {
    return response === null ? "null" : JSON.stringify(response)
}

// QML imports each function directly. The CommonJS export is only for the
// optional host-side tests and is ignored by the QML JavaScript engine.
if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        normalizeResponse: normalizeResponse,
        findActiveLine: findActiveLine,
        wordState: wordState,
        formatTime: formatTime,
        signature: signature
    }
}
