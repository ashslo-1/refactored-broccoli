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
' CanDecodeVideo/CanDecodeAudio. That is model-agnostic by construction, where a
' model table would rot the day a new chip ships. This module is the pure half —
' the codec names to ask about and the safe reading of the answers. The
' roDeviceInfo calls themselves live in components/DeviceCapTask.brs so this
' stays runnable under the test interpreter, which has no device.
'
' The names below are the SERVER's, i.e. ffprobe's `stream.codec` values, because
' that is the string the converter compares against. Roku's vocabulary is not
' guaranteed to match (its own documentation lists "mpeg4 avc" for H.264), which
' is exactly what the Phase 0 spike measures: the raw reply of a rejected probe
' carries the list of names Roku does know, so a mismatch shows up as data
' instead of as a silently ignored hint.

' Video candidates, in the order they are probed. h264 and hevc are the only two
' HLS video codecs Roku decodes at all (HEVC on 4K devices); the rest are here so
' the spike can show they are rejected rather than assume it. Profiles/levels are
' the highest each codec documents, so a "yes" means the codec family at full
' quality, not just at some lowest common denominator.
function CodecVideoCandidates() as object
    return [
        { codec: "h264", profile: "high", level: "4.2" },
        { codec: "hevc", profile: "main", level: "5.1" },
        { codec: "av1", profile: "", level: "" },
        { codec: "vp9", profile: "", level: "" },
        { codec: "mpeg4", profile: "", level: "" }
    ]
end function

' Audio candidates. aac and mp3 are the server's existing defaults and must always
' come back true; the Dolby and lossless families are the headroom. Channel count
' is deliberately NOT probed here — the plan keeps maxAudioChannels at 2, so the
' question is only whether the codec can be decoded at all.
function CodecAudioCandidates() as object
    return [
        { codec: "aac" },
        { codec: "mp3" },
        { codec: "ac3" },
        { codec: "eac3" },
        { codec: "dts" },
        { codec: "flac" },
        { codec: "alac" },
        { codec: "opus" },
        { codec: "vorbis" }
    ]
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
' Kept separate from the summary so a caller that only needs the list (the request
' builder in a later phase) does not have to own the display format.
function CodecSupportedList(probes as object) as string
    names = []
    for each probe in probes
        if probe.ok then names.Push(probe.codec)
    end for
    return CodecJoin(names, ",")
end function

' The compact line the Settings row shows: which video and audio codecs the device
' reports, or "(none)" when a probe list is empty or all-no. The passthru probes
' are deliberately not part of it — the locked audio strategy keys off the plain
' answer, and a second, contradictory line would invite reading too much into it.
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
