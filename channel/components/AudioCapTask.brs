' AudioCapTask — the codecs the attached HDMI device takes, and the ones this
' Roku takes.
'
' Two questions, one task, two probe loops. The passthru filter is what
' separates them: 1 asks about the HDMI device (the sound system that
' decodes a passthrough), 0 asks about the Roku itself (the decoder that would
' decode a copy the server does not re-encode).
'
' roDeviceInfo is Task-only, hence the component. A failure answers "no",
' which is the same answer a device that claims nothing gives.
sub init()
    m.top.functionName = "probeAudio"
end sub

sub probeAudio()
    passthru = []
    transmux = []
    di = invalid
    try
        di = CreateObject("roDeviceInfo")
    catch e
        di = invalid
    end try
    if di <> invalid then
        for each candidate in CodecDolbyCandidates()
            if CapProbeFilter(di, candidate, 1) then passthru.Push(candidate.codec)
        end for
        for each candidate in CodecDolbyCandidates()
            if CapProbeFilter(di, candidate, 0) then transmux.Push(candidate.codec)
        end for
    end if
    m.top.result = { passthru: passthru, transmux: transmux, done: true }
end sub

' One probe through one filter. The filter is the question: 1 is the attached
' HDMI device, 0 is the Roku itself.
function CapProbeFilter(di as object, candidate as object, filter as integer) as boolean
    raw = invalid
    try
        raw = di.CanDecodeAudio({ codec: candidate.codec, passthru: filter })
    catch e
        return false
    end try
    return CodecResult(raw)
end function
