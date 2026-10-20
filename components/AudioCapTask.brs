' AudioCapTask — the codecs the attached HDMI device takes.
'
' The Roku's own Dolby/DTS passthrough setting, read through the platform: the
' passthru filter asks about the sink rather than the Roku, and a codec the
' Roku cannot decode but the receiver can is exactly the passthrough case.
'
' It is also the gate that keeps a request playable. The platform accepts a
' stream whose audio is in this set and refuses one that is not — an E-AC-3
' track the sink never claimed came back as "not playable on this device" —
' so this is what the switch offers and nothing more.
'
' roDeviceInfo is Task-only, hence the component. A failure answers "no",
' which is the same answer a sink that claims nothing gives.
sub init()
    m.top.functionName = "probeAudio"
end sub

sub probeAudio()
    codecs = []
    di = invalid
    try
        di = CreateObject("roDeviceInfo")
    catch e
        di = invalid
    end try
    if di <> invalid then
        for each candidate in CodecPassthruCandidates()
            if CapPassthru(di, candidate) then codecs.Push(candidate.codec)
        end for
    end if
    m.top.result = { codecs: codecs, done: true }
end sub

' One probe. The passthru filter is the whole question; a failure is a "no",
' because a sink that cannot be asked claims nothing.
function CapPassthru(di as object, candidate as object) as boolean
    raw = invalid
    try
        raw = di.CanDecodeAudio({ codec: candidate.codec, passthru: 1 })
    catch e
        return false
    end try
    return CodecResult(raw)
end function
