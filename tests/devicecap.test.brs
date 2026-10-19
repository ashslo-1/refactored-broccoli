' Codec probe unit tests — the pure half of source/util/CodecProbe.brs.
'
' The roDeviceInfo calls live in components/DeviceCapTask.brs and are deliberately
' NOT exercised here: the interpreter has no device, so a test that called
' CanDecodeVideo would only prove the mock agrees with itself. What is tested is
' everything that decides WHAT is asked and how the answer is read, which is the
' part that could silently be wrong on every device.

sub Test_CodecProbe_Candidates()
    Harness_Suite("Codec probe candidate lists")

    video = CodecVideoCandidates()
    Harness_Ok(video.Count() > 0, "there is at least one video candidate")
    Harness_Ok(CodecListHas(video, "h264"), "h264 is asked about — it is the server's default and must never be dropped")
    Harness_Ok(CodecListHas(video, "hevc"), "hevc is asked about — it is the whole reason this spike exists")
    Harness_Ok(not CodecListHas(video, "aac"), "a video list does not carry an audio codec")

    audio = CodecAudioCandidates()
    Harness_Ok(audio.Count() > 0, "there is at least one audio candidate")
    Harness_Ok(CodecListHas(audio, "aac"), "aac is asked about — it is a server default")
    Harness_Ok(CodecListHas(audio, "mp3"), "mp3 is asked about — it is a server default")
    Harness_Ok(CodecListHas(audio, "ac3") and CodecListHas(audio, "eac3"), "the Dolby family is asked about")
    Harness_Ok(not CodecListHas(audio, "hevc"), "an audio list does not carry a video codec")
end sub

sub Test_CodecProbe_CandidateShape()
    Harness_Suite("Codec probe candidate shape")

    ' Both families at once: a missing or duplicated codec name would make the
    ' probe request malformed or the supported list ambiguous.
    for each list in [CodecVideoCandidates(), CodecAudioCandidates()]
        seen = {}
        for each entry in list
            Harness_Ok(entry.codec <> invalid and entry.codec <> "", "candidate has a codec name")
            Harness_Ok(not seen.DoesExist(entry.codec), "candidate " + entry.codec + " is not duplicated")
            seen[entry.codec] = true
        end for
    end for

    ' A video candidate carries profile and level keys (possibly empty) so the
    ' probe builder never reads an absent member.
    for each entry in CodecVideoCandidates()
        Harness_Ok(entry.profile <> invalid and entry.level <> invalid, "video candidate " + entry.codec + " carries profile/level keys")
    end for
end sub

sub Test_CodecProbe_Flag()
    Harness_Suite("Codec probe reply interpretation")

    Harness_Equal(CodecFlag(invalid), "invalid", "an invalid reply is named invalid")
    Harness_Equal(CodecFlag(5), "not-object", "a non-object reply is named not-object")
    Harness_Equal(CodecFlag({}), "absent", "a reply with no result is named absent")
    Harness_Equal(CodecFlag({ result: true }), "true", "an explicit true reads as true")
    Harness_Equal(CodecFlag({ result: false }), "false", "an explicit false reads as false")
    Harness_Equal(CodecFlag({ result: 1 }), "non-bool", "a non-boolean result is named non-bool")
    Harness_Equal(CodecFlag({ result: true, updated: "codec" }), "true", "an extra key like updated does not change the reading")
    Harness_Equal(CodecFlag({ result: false, codec: ["hevc"] }), "false", "a rejection that lists supported codecs is still a false")
end sub

sub Test_CodecProbe_Result()
    Harness_Suite("Codec probe actionable result")

    Harness_Ok(CodecResult({ result: true }), "a true reply is playable")
    Harness_Ok(not CodecResult({ result: false }), "a false reply is not playable")
    Harness_Ok(not CodecResult(invalid), "an invalid reply is not playable")
    Harness_Ok(not CodecResult({}), "a missing result is not playable")
    Harness_Ok(not CodecResult({ result: 1 }), "a non-boolean result is not playable")
end sub

sub Test_CodecProbe_Join()
    Harness_Suite("Codec probe join")

    Harness_Equal(CodecJoin([], ","), "", "no parts joins to empty")
    Harness_Equal(CodecJoin(["a"], ","), "a", "one part has no separator")
    Harness_Equal(CodecJoin(["a", "b", "c"], ","), "a,b,c", "parts are separated in order")
    Harness_Equal(CodecJoin(["a", "b"], ""), "ab", "an empty glue concatenates")
end sub

sub Test_CodecProbe_SupportedList()
    Harness_Suite("Codec probe supported list")

    probes = [
        { codec: "h264", ok: true },
        { codec: "hevc", ok: true },
        { codec: "av1", ok: false }
    ]
    Harness_Equal(CodecSupportedList(probes), "h264,hevc", "only the yes probes are listed, in order")
    Harness_Equal(CodecSupportedList([]), "", "no probes is an empty list")
    Harness_Equal(CodecSupportedList([{ codec: "h264", ok: false }]), "", "an all-no list is empty")
end sub

sub Test_CodecProbe_Summary()
    Harness_Suite("Codec probe summary")

    video = [{ codec: "h264", ok: true }, { codec: "hevc", ok: true }]
    audio = [{ codec: "aac", ok: true }, { codec: "ac3", ok: false }]
    Harness_Equal(CodecSummary(video, audio), "video: h264,hevc  audio: aac", "the summary lists both families")

    Harness_Equal(CodecSummary([], []), "video: (none)  audio: (none)", "empty probes read as none")
    Harness_Equal(CodecSummary(video, []), "video: h264,hevc  audio: (none)", "a missing audio list reads as none")
end sub

' True when the candidate list names this codec. Kept local so the assertions
' read as one claim about the list rather than a hand-rolled loop each time.
function CodecListHas(list as object, name as string) as boolean
    for each entry in list
        if entry.codec = name then return true
    end for
    return false
end function
