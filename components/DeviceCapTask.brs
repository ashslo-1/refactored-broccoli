' DeviceCapTask — read-only device capability spike. TEMPORARY.
'
' It exists to answer one question before any codec hint is ever sent to the
' streaming server: which codec strings does THIS device say it can decode, and
' does Roku's vocabulary match the ffprobe `stream.codec` names the server
' matches against? The converter compares codec names by exact string, so a
' mismatch would either silently do nothing or silently force a transcode — and
' neither shows up as an error anywhere.
'
' Read-only: it calls roDeviceInfo and prints. It never touches playback, the
' streaming server, or any persisted value. Delete this component, the Settings
' row that launches it, and tests/devicecap.test.brs once the mapping is known.
'
' The pure half lives in source/util/CodecProbe.brs (included by the XML) so the
' codec-name lists and the reading of a reply can be unit-tested; the interpreter
' has no roDeviceInfo.

sub init()
    m.top.functionName = "runDeviceCap"
end sub

sub runDeviceCap()
    report = {
        done: false
        device: {}
        video: []
        audio: []
        passthru: []
        summary: "probing…"
    }
    m.top.result = report
    CapSay("--- device capability probe ---")

    di = CapDeviceInfo()
    report.device = CapDeviceFacts(di)
    m.top.result = report
    CapSay("device " + CapDeviceText(report.device))
    if di = invalid then
        report.done = true
        report.summary = "roDeviceInfo unavailable"
        m.top.result = report
        return
    end if

    ' Video first: HEVC is the whole reason this plan exists, so if the run is
    ' cancelled midway the most valuable answer is the one already captured.
    for each candidate in CodecVideoCandidates()
        if m.top.cancelRequested then return
        probe = CapProbeVideo(di, candidate)
        report.video.Push(probe)
        report.summary = CodecSummary(report.video, report.audio)
        m.top.result = report
        CapSay("video " + CapProbeText(probe))
    end for

    for each candidate in CodecAudioCandidates()
        if m.top.cancelRequested then return
        probe = CapProbeAudio(di, candidate, false)
        report.audio.Push(probe)
        report.summary = CodecSummary(report.video, report.audio)
        m.top.result = report
        CapSay("audio " + CapProbeText(probe))
    end for

    ' The same audio codecs again through the HDMI-sink question. Not used by the
    ' locked strategy, but it is the only way to see whether a codec would be
    ' passed through rather than decoded, and it costs one probe loop.
    for each candidate in CodecAudioCandidates()
        if m.top.cancelRequested then return
        probe = CapProbeAudio(di, candidate, true)
        report.passthru.Push(probe)
        m.top.result = report
        CapSay("passthru " + CapProbeText(probe))
    end for

    report.done = true
    report.summary = CodecSummary(report.video, report.audio)
    m.top.result = report
    CapSay("summary " + report.summary)
end sub

' roDeviceInfo is Task-only, hence this component. Failure to create it is
' itself a finding, so it is reported and the run continues to a clean end
' rather than aborting.
function CapDeviceInfo() as object
    di = invalid
    try
        di = CreateObject("roDeviceInfo")
    catch e
        CapSay("roDeviceInfo unavailable: " + CapError(e))
    end try
    return di
end function

' Every field is individually guarded: an old OS that lacks one member should
' still let the rest of the report through. Losing the whole report because
' GetAudioOutputChannel threw would be the diagnostic failing exactly when the
' device is unusual enough to need it.
function CapDeviceFacts(di as object) as object
    facts = { model: "?", type: "?", os: "?", videoMode: "?", audioOut: "?", surround: "?" }
    if di = invalid then return facts
    try
        facts.model = CapText(di.GetModel())
    catch e
    end try
    try
        facts.type = CapText(di.GetModelType())
    catch e
    end try
    try
        version = di.GetOSVersion()
        facts.os = CapText(version.major) + "." + CapText(version.minor) + "." + CapText(version.revision)
    catch e
    end try
    try
        facts.videoMode = CapText(di.GetVideoMode())
    catch e
    end try
    try
        facts.audioOut = CapText(di.GetAudioOutputChannel())
    catch e
    end try
    try
        facts.surround = CapText(di.HasFeature("can_output_5.1_surround_sound"))
    catch e
    end try
    return facts
end function

function CapProbeVideo(di as object, candidate as object) as object
    request = { codec: candidate.codec }
    if candidate.profile <> "" then request.profile = candidate.profile
    if candidate.level <> "" then request.level = candidate.level
    return CapProbe(di, "CanDecodeVideo", candidate.codec, request)
end function

function CapProbeAudio(di as object, candidate as object, passthru as boolean) as object
    request = { codec: candidate.codec }
    if passthru then request.passthru = 1
    return CapProbe(di, "CanDecodeAudio", candidate.codec, request)
end function

' One probe. The whole returned assocarray is kept, not just the boolean: when a
' codec name is wrong, Roku's reply names the ones it does know, and that list is
' the answer to the naming question this spike exists to settle.
function CapProbe(di as object, method as string, codec as string, request as object) as object
    probe = { codec: codec, flag: "", ok: false, raw: "" }
    raw = invalid
    try
        if method = "CanDecodeVideo" then
            raw = di.CanDecodeVideo(request)
        else
            raw = di.CanDecodeAudio(request)
        end if
    catch e
        probe.flag = "threw: " + CapError(e)
        return probe
    end try
    probe.flag = CodecFlag(raw)
    probe.ok = CodecResult(raw)
    probe.raw = CapJson(raw)
    return probe
end function

function CapProbeText(probe as object) as string
    return probe.codec + " -> " + probe.flag + " raw=" + probe.raw
end function

function CapDeviceText(facts as object) as string
    text = "model=" + facts.model + " type=" + facts.type + " os=" + facts.os
    text = text + " videoMode=" + facts.videoMode + " audioOut=" + facts.audioOut + " surround=" + facts.surround
    return text
end function

function CapJson(value as dynamic) as string
    text = ""
    try
        text = FormatJson(value)
    catch e
        text = "unjsonable(" + CapError(e) + ")"
    end try
    return text
end function

function CapError(e as dynamic) as string
    message = ""
    try
        message = e.message
    catch inner
        message = ""
    end try
    return CapText(message)
end function

function CapText(value as dynamic) as string
    if value = invalid then return "?"
    kind = Type(value)
    if kind = "String" or kind = "roString" then return value
    if kind = "Boolean" or kind = "roBoolean" then
        if value then return "true"
        return "false"
    end if
    if kind = "Integer" or kind = "roInt" or kind = "LongInteger" or kind = "Float" or kind = "Double" or kind = "roFloat" or kind = "roDouble" then
        return CapNumber(value)
    end if
    return "[" + kind + "]"
end function

' Str() pads a positive number with a leading space for the sign, which would
' make "14.1.0" print as " 14. 1. 0". Strip it rather than carry the noise into
' every log line.
function CapNumber(value as dynamic) as string
    text = ""
    try
        text = Str(value).Trim()
    catch e
        text = "?"
    end try
    return text
end function

sub CapSay(text as string)
    print "[codeccheck] " + text
end sub
