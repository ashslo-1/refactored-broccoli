' Codec-hint unit tests — the pure half of source/util/CodecProbe.brs that
' decides WHAT the streaming server is told.
'
' Everything here is the part that could be wrong on every device while looking
' perfectly right in a log: the intersection of the transport's valid codecs with
' the device's answer, the server's floors surviving the replacement rule, and
' the channel cap. The roDeviceInfo calls that produce the answers live in
' components/StreamResolveTask.brs (and the spike) and are deliberately not
' exercised: the interpreter has no device, so a test that called CanDecodeVideo
' would only prove the mock agrees with itself.

sub Test_CodecHints_FloorAlwaysPresent()
    Harness_Suite("Codec hints keep the server's floors")

    ' No device answer at all: the request must still carry the codecs the server
    ' would have copied on its own. An advertised list REPLACES the defaults, so a
    ' list that dropped h264/aac/mp3 would turn the service's one sure stream-copy
    ' into a re-encode — and a transcode is a valid response, so nothing would say
    ' so.
    Harness_Equal(CodecJoin(CodecHints(CodecVideoFloor(), CodecVideoCandidates(), []), ","), "h264", "an empty video answer still advertises h264")
    Harness_Equal(CodecJoin(CodecHints(CodecAudioFloor(), CodecAudioCandidates(), []), ","), "aac,mp3", "an empty audio answer still advertises aac and mp3")

    ' The floor also survives an all-no answer, which is the shape a device that
    ' answered every probe with false produces.
    denied = [{ codec: "h264", ok: false }, { codec: "hevc", ok: false }]
    Harness_Equal(CodecJoin(CodecHints(CodecVideoFloor(), CodecVideoCandidates(), denied), ","), "h264", "a rejected h264 is still advertised by the floor")
end sub

sub Test_CodecHints_AddsOnlyCarriableAccepted()
    Harness_Suite("Codec hints add only device-accepted, HLS-carriable codecs")

    ' The trap the Phase 0 run exposed: the test stick answered true for av1 and
    ' vp9, neither of which an HLS stream can carry. Advertising them would force
    ' a remux the player cannot open — a black screen — so an accepted candidate
    ' with hls false must stay out.
    video = [
        { codec: "h264", ok: true },
        { codec: "hevc", ok: true },
        { codec: "av1", ok: true },
        { codec: "vp9", ok: true },
        { codec: "mpeg4", ok: true }
    ]
    Harness_Equal(CodecJoin(CodecHints(CodecVideoFloor(), CodecVideoCandidates(), video), ","), "h264,hevc", "accepted av1/vp9/mpeg4 are not advertised — HLS cannot carry them")

    ' The same on the audio side, where the lossless and DTS families are chip
    ' capabilities the fragmented-MP4 output cannot hold.
    audio = [
        { codec: "aac", ok: true },
        { codec: "dts", ok: true },
        { codec: "flac", ok: true },
        { codec: "ac3", ok: true }
    ]
    Harness_Equal(CodecJoin(CodecHints(CodecAudioFloor(), CodecAudioCandidates(), audio), ","), "aac,mp3,ac3", "accepted dts/flac are not advertised — fMP4 cannot carry them")

    ' An accepted but unadvertised candidate must not appear even when the probe
    ' list is the only source of names.
    only = CodecHints([], CodecVideoCandidates(), [{ codec: "vp9", ok: true }])
    Harness_Equal(CodecJoin(only, ","), "", "nothing is advertised when the only accepted codec is unadvertisable")
end sub

sub Test_CodecHints_OrderAndDuplicates()
    Harness_Suite("Codec hints order and duplicates")

    ' h264 is both the floor and an accepted candidate. It must appear once, and
    ' the floor must come first so a request reads defaults-then-additions.
    video = [{ codec: "h264", ok: true }, { codec: "hevc", ok: true }]
    Harness_Equal(CodecJoin(CodecHints(CodecVideoFloor(), CodecVideoCandidates(), video), ","), "h264,hevc", "the floor is not duplicated by an accepted candidate of the same name")

    ' An accepted codec not present in the candidate list cannot be named — the
    ' list is built from the candidates, so a stray name is simply not there.
    stray = CodecHints([], CodecVideoCandidates(), [{ codec: "theora", ok: true }])
    Harness_Equal(CodecJoin(stray, ","), "", "a name with no candidate entry is not advertised")
end sub

sub Test_CodecChannelLimit_Signals()
    Harness_Suite("Codec channel limit")

    ' Surround output is decisive on its own.
    Harness_Equal(CodecChannelLimit([], true), 6, "a surround-capable sink lifts the cap to 6")
    ' So is a passthru answer, which is the only positive signal the test stick
    ' gives: it reports Stereo output and surround=false while bitstreaming AC-3.
    passthru = [{ codec: "aac", ok: true, passthru: false }, { codec: "ac3", ok: true, passthru: true }]
    Harness_Equal(CodecChannelLimit(passthru, false), 6, "a passthru codec lifts the cap to 6")
    ' Neither signal: the cap stays at the bridge's old value, which downmixes 5.1
    ' to stereo AAC rather than sending channels the sink never advertised.
    Harness_Equal(CodecChannelLimit([], false), 2, "no signal keeps the cap at 2")
    decodeOnly = [{ codec: "ac3", ok: true, passthru: false }]
    Harness_Equal(CodecChannelLimit(decodeOnly, false), 2, "mere decoding does not lift the cap — only rendering or bitstreaming does")
end sub

sub Test_CodecFingerprint_ShapeAndVariance()
    Harness_Suite("Codec fingerprint")

    ' Readable, path-safe, and a function of everything the converter id has to
    ' change with. The server keys its converter cache by the id, so two different
    ' hint sets sharing a fingerprint would serve the first set's converter and
    ' silently ignore the second's hints.
    Harness_Equal(CodecFingerprint(["h264"], ["aac", "mp3"], 2), "vh264.aaac-mp3.c2", "the fingerprint names both lists and the cap")

    a = CodecFingerprint(["h264"], ["aac", "mp3"], 2)
    b = CodecFingerprint(["h264", "hevc"], ["aac", "mp3"], 2)
    c = CodecFingerprint(["h264"], ["aac", "mp3", "ac3"], 2)
    d = CodecFingerprint(["h264"], ["aac", "mp3"], 6)
    Harness_Ok(a <> b, "a different video list changes the fingerprint")
    Harness_Ok(a <> c, "a different audio list changes the fingerprint")
    Harness_Ok(a <> d, "a different channel cap changes the fingerprint")
end sub

sub Test_CodecCandidates_CarriableFlags()
    Harness_Suite("Codec candidates carry the transport flag")

    ' The flag is what separates "the chip can do this" from "this request may ask
    ' for it", and it is the only thing standing between a device that answers true
    ' for AV1/VP9 and a request that offers them.
    for each entry in CodecVideoCandidates()
        expected = (entry.codec = "h264" or entry.codec = "hevc")
        Harness_Equal(entry.hls, expected, "video candidate " + entry.codec + " carriable = " + HintsFlag(expected))
    end for

    for each entry in CodecAudioCandidates()
        expected = (entry.codec = "aac" or entry.codec = "mp3" or entry.codec = "ac3" or entry.codec = "eac3")
        Harness_Equal(entry.hls, expected, "audio candidate " + entry.codec + " carriable = " + HintsFlag(expected))
    end for
end sub

sub Test_CodecListContains_Finds()
    Harness_Suite("Codec list containment")

    Harness_Ok(CodecListContains(["a", "b"], "a"), "a present entry is found")
    Harness_Ok(not CodecListContains(["a", "b"], "c"), "an absent entry is not found")
    Harness_Ok(not CodecListContains([], "a"), "nothing is found in an empty list")
end sub

' A stable "true"/"false" for the flag assertions, because Harness_Equal's
' message would otherwise print the interpreter's own rendering of a boolean.
function HintsFlag(value as boolean) as string
    if value then return "true"
    return "false"
end function
