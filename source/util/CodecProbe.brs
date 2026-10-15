' CodecProbe — which codecs to advertise as pass-through to the streaming server.
'
' The HLS2 converter takes `videoCodecs` / `audioCodecs` as its remux
' (pass-through) allow-list: a source stream whose codec is in the list is
' stream-copied, anything else is re-encoded. The server's own defaults are
' ["h264"] and ["aac","mp3"], so today an HEVC file is re-encoded even on a 4K
' Roku that decodes HEVC natively, and an AC3/E-AC3/DTS/FLAC/Opus track is
' re-encoded even when the Roku would take it. The list also REPLACES the
' default, so it has to be complete — advertising `hevc` without `h264` would
' evict H.264 and force it to be re-encoded.
'
' The right list is whatever THIS device reports through roDeviceInfo's
' CanDecodeVideo/CanDecodeAudio — but the raw answer is NOT the list, and this
' module exists to keep that distinction. CanDecode* answers a chip-capability
' question, not "can the HLS player play this": the test Roku answered true for
' both av1 and vp9, and neither can travel in an HLS/fMP4 stream at all (AV1 is
' DASH-only, VP9 is not a Roku video codec). Advertising them would have forced
' a remux the player then cannot decode — a black screen where the old
' transcode at least produced pictures. So the advertised list is an
' INTERSECTION: the codecs HLS can carry AND the device says it decodes. The two
' halves are exactly what this module holds — the candidates and the transport
' flag — and the roDeviceInfo calls themselves live in the component that owns a
' Task scope (components/DeviceCapTask.brs for the spike, StreamResolveTask.brs
' for playback), so this stays runnable under the test interpreter, which has no
' device.
'
' The names below are the SERVER's, i.e. ffprobe's `stream.codec` values, because
' that is the string the converter compares against. Roku's vocabulary is not
' guaranteed to match (its own documentation lists "mpeg4 avc" for H.264), which
' is exactly what the Phase 0 spike measured: the raw reply of a rejected probe
' carries the list of names Roku does know, so a mismatch shows up as data
' instead of as a silently ignored hint. The spike has since run and Roku
' accepted every name below, printing its own vocabulary back only in `raw`.

' Video candidates, in the order they are probed. h264 and hevc are the only two
' video codecs an HLS stream can carry on Roku (HEVC on 4K devices), so only they
' are marked `hls`; the rest are probed so the spike can show what the chip
' claims rather than assume it, and are kept out of any advertised list by that
' flag. Profiles/levels are the highest each codec documents, so a "yes" means
' the codec family at full quality, not just at some lowest common denominator —
' and for HEVC, "main/5.1" is literally Roku's own documented CanPlay4K recipe.
'
' h264 is not merely the first candidate, it is the server's default: dropping it
' from an advertised list would evict the one codec the service could already
' stream-copy, so its place is also pinned by CodecVideoFloor() below.
function CodecVideoCandidates() as object
    return [
        { codec: "h264", hls: true, profile: "high", level: "4.2" },
        { codec: "hevc", hls: true, profile: "main", level: "5.1" },
        { codec: "av1", hls: false, profile: "", level: "" },
        { codec: "vp9", hls: false, profile: "", level: "" },
        { codec: "mpeg4", hls: false, profile: "", level: "" }
    ]
end function

' Audio candidates. aac and mp3 are the server's existing defaults and must
' always come back true; the Dolby pair is the headroom this plan is about.
'
' The `hls` flag is what keeps the rest out of a request. The HLS2 path produces
' fragmented MP4, not MPEG-TS, and an fMP4 audio track can only hold what a
' Fragmented-MP4 sample entry names — AAC, AC-3 and E-AC-3. DTS, FLAC, ALAC,
' Opus and Vorbis are probed because the chip reports on them, but no answer,
' however true, makes them carriable on this transport: a `dts` in the hint list
' would tell the server to copy a track the player then cannot open. So they stay
' probed (the spike's whole output) and unadvertised (the request's).
'
' mp3 is marked carriable to match the server's own default. It is the one entry
' here whose fMP4 handling is uncertain, but it is uncertain TODAY too — the
' service already stream-copies mp3 — so carrying it in the list preserves the
' existing behaviour instead of changing it in either direction.
function CodecAudioCandidates() as object
    return [
        { codec: "aac", hls: true },
        { codec: "mp3", hls: true },
        { codec: "ac3", hls: true },
        { codec: "eac3", hls: true },
        { codec: "dts", hls: false },
        { codec: "flac", hls: false },
        { codec: "alac", hls: false },
        { codec: "opus", hls: false },
        { codec: "vorbis", hls: false }
    ]
end function

' The server's own default pass-through lists, and the floor of every advertised
' one. They matter because an advertised list REPLACES the defaults rather than
' extending them: a request that dropped h264, aac or mp3 would not fall back to
' the server's copy rule for them, it would turn the service's one sure
' stream-copy into a re-encode on every file — silently, since a transcode is a
' valid response.
function CodecVideoFloor() as object
    return ["h264"]
end function

function CodecAudioFloor() as object
    return ["aac", "mp3"]
end function

' The list to advertise: the floor, plus every candidate the device accepted that
' this transport can actually carry. Order follows the candidate list, and the
' floor comes first so a glance at a request reads the defaults before the
' additions.
'
' The two conditions are not redundant. `accepted` is the device's answer;
' `candidate.hls` is the transport's. Only both together are a promise the
' server can keep — the chips that answered true for av1/vp9/dts are the ones
' that would otherwise be handed a stream the HLS player cannot open.
function CodecHints(floor as object, candidates as object, probes as object) as object
    accepted = {}
    for each probe in probes
        if probe.ok then accepted[probe.codec] = true
    end for

    hints = []
    for each name in floor
        if not CodecListContains(hints, name) then hints.Push(name)
    end for
    for each candidate in candidates
        if candidate.hls and accepted.DoesExist(candidate.codec) then
            if not CodecListContains(hints, candidate.codec) then hints.Push(candidate.codec)
        end if
    end for
    return hints
end function

' How many audio channels the request may keep: 6 when this device or the sink on
' the other end of its HDMI can render or bitstream more than stereo, else 2.
'
' This is the one lever that decides whether a Dolby torrent is copied or
' re-encoded, because the server's audio rule is `codec not in list OR channels >
' maxAudioChannels`. On the test stick the list already carried ac3 and a 5.1
' track still transcoded — purely because the old bridge pinned the cap at 2, so
' `6 > 2` fired. Raising it is what turns a DD 5.1 track into a copy.
'
' The two signals are ORed because neither is complete. `passthru` is the direct
' question ("can this go down the wire undecoded") but only answers per codec and
' only when the sink asked for it; the surround feature answers for the sink as a
' whole. Roku exposes no channel count for the sink — the probe reports
' audioOut=Stereo and surround=false while passing AC-3 through — so 6 is the
' honest ceiling for "can take Dolby", not a measurement of the speakers. If the
' sink really is stereo the platform downmixes, and the DTS case (which cannot be
' carried and so never reaches this decision intact) is the one to watch.
function CodecChannelLimit(probes as object, surroundCapable as boolean) as integer
    if surroundCapable then return 6
    for each probe in probes
        if probe.passthru then return 6
    end for
    return 2
end function

' The converter id's discriminator: a readable fingerprint of everything the id
' has to change with. It exists because the server caches a converter BY ID and
' only builds one when the id is new — so reusing an id with new hints does not
' apply the new hints, it silently serves the cached converter built from the old
' ones. Two devices, or one device after an HDMI change, must therefore not share
' an id. Charset is alnum plus "-" and "." so the result is safe as a path
' segment without escaping.
function CodecFingerprint(videoCodecs as object, audioCodecs as object, maxAudioChannels as integer) as string
    return "v" + CodecJoin(videoCodecs, "-") + ".a" + CodecJoin(audioCodecs, "-") + ".c" + maxAudioChannels.ToStr()
end function

' Whether a list of names holds this one. Local for the same reason CodecJoin
' is: components do not share function scope, and the hint builder must not
' depend on a neighbour's helper.
function CodecListContains(list as object, name as string) as boolean
    for each entry in list
        if entry = name then return true
    end for
    return false
end function

' One word for what a CanDecode* reply said. A probe is only "true" when the reply
' is a real assocarray whose `result` is exactly boolean true; every other shape —
' invalid, the wrong type, a reply with no `result` — is reported distinctly so
' the console log says WHY it was not a yes instead of flattening every failure
' to "false". NetDiag learned the same lesson: a diagnostic that cannot tell one
' failure from another is not a measurement.
function CodecFlag(raw as dynamic) as string
    if raw = invalid then return "invalid"
    if Type(raw) <> "roAssociativeArray" then return "not-object"
    if not raw.DoesExist("result") then return "absent"
    value = raw.result
    kind = Type(value)
    if kind = "Boolean" or kind = "roBoolean" then
        if value then return "true"
        return "false"
    end if
    return "non-bool"
end function

' The actionable form: true only for an explicit yes.
function CodecResult(raw as dynamic) as boolean
    return CodecFlag(raw) = "true"
end function

' Comma-joined names of the probes that said yes, empty string when none did.
' Kept separate from the summary so a caller that only needs the list does not
' have to own the display format.
function CodecSupportedList(probes as object) as string
    names = []
    for each probe in probes
        if probe.ok then names.Push(probe.codec)
    end for
    return CodecJoin(names, ",")
end function

' The compact line the Settings row shows: which video and audio codecs the device
' reports, or "(none)" when a probe list is empty or all-no. The passthru probes
' are deliberately not part of it: the summary is the spike's at-a-glance chip
' answer, and the strategy's use of passthru (see CodecChannelLimit) is a separate
' question that a second, contradictory line here would only muddy.
function CodecSummary(videoProbes as object, audioProbes as object) as string
    video = CodecSupportedList(videoProbes)
    audio = CodecSupportedList(audioProbes)
    if video = "" then video = "(none)"
    if audio = "" then audio = "(none)"
    return "video: " + video + "  audio: " + audio
end function

' Plain join for BrightScript string arrays. The device-side component cannot use
' whichever Join the NetDiag component defines — components do not share function
' scope — so this module owns its own rather than depending on a neighbour.
function CodecJoin(parts as object, glue as string) as string
    out = ""
    for each part in parts
        if out <> "" then out = out + glue
        out = out + part
    end for
    return out
end function
