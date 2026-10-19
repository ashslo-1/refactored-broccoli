' StreamResolveTask — resolve a torrent stream to a playable URL off the UI
' thread, and make sure the streaming server will actually serve it.
'
' Direct-URL streams never get here (the screen plays them as-is).
'
' The task owns the wait, and that is the point of it. Building the URL needs no
' request, but the Video node's first request is a cold engine: the server has to
' gather metadata over DHT and trackers before it can answer, and the node's load
' patience is far shorter than ours. A node that cannot load in time reports the
' stream as FINISHED — no error, no message, the buffering indicator simply goes
' away — which is why a first play can die instantly while a second play of the
' same title gets partway, having found the engine already warm.
'
' So the playlist is asked for here, on a worker thread, until the server will
' serve one. The URL is handed over either way when the attempts run out, which
' makes this a floor on how long the player waits and never a reason it cannot
' start: the worst case is today's behaviour plus a delay.
'
' The engine is asked for first, and until it was, the loop above could not do
' its job. Asking the playlist for a torrent the server has not been told to make
' an engine is not a request that takes too long — it is one that never completes,
' which is what six timed-out probes and a 44-second wait turned out to be. So the
' bare torrent route is asked for first, mirroring what Stremio's client does, and
' the engine exists before anything asks it for anything.
'
' Two requests, because one of them was not enough. A HEAD of the bare route gets
' the engine CREATED and returns in milliseconds, so it said nothing about whether
' the engine could then answer — the probe behind it kept finding out the slow
' way. Stremio's client follows that HEAD with a ranged GET of the first 64KB and
' lets it block until the engine has torrent metadata, and the server's log for a
' device that starts cleanly shows exactly that request sitting between the HEAD
' and the /hls.m3u8. So the warm-up does the same two requests, which turns "the
' engine exists" into "the engine can serve" before the probe ever runs.
'
' The probe rides back attached to the result. "How many times was it asked, and
' what did the server say" is the diagnosis if it is still wrong, which is the
' whole reason this file keeps a record instead of only waiting.
'
' The wait policy lives here rather than in PlaybackStore on purpose. Wait()
' aborts the brs interpreter's run and Ticks() does not exist in it, so a wait
' loop in store code would be neither exercised by the suite nor timed; the task
' is the one place whose blocking is expected.

' The wait is bounded by a COUNT of attempts, never by a clock reading. An earlier
' version measured elapsed milliseconds through
' CreateObject("roDateTime").AsMilliseconds() — a method this codebase has never
' put on a device; the only two it does use are ToISOString() and GetYear() — and
' the device answered &hf4, member function not found. Because the throw landed
' inside resolve()'s own try it took the result down with it: a URL that had
' already resolved correctly was thrown away, and every torrent reported "resolve
' FAILED: Member function not found" while direct URLs, which skip this file's
' wait entirely, played fine. Counting attempts needs no platform API at all, and
' a request that stalls ends at the probe's own short timeout rather than at a
' deadline somebody has to poll.

sub init()
    m.top.functionName = "resolve"
end sub

sub resolve()
    try
        ' Stop-aware, and the check has to be here rather than trusting the node
        ' to be gone: AsyncTask_Reap unobserves and removes the node, but removing
        ' a running Task does not kill its worker thread (AsyncTask.bs says so),
        ' so the worker has to notice the stop for itself. SubtitleLoaderTask and
        ' LinkStremioTask guard the same hazard.
        '
        ' It matters more here than in either sibling, because what this worker
        ' would keep doing is remote, not local. The warm-up is the request that
        ' creates the torrent engine on the streaming server, and the requests to
        ' that route are the stream activity the server's idle timers watch. A
        ' backing-out does not leave a torrent running forever — the server pauses
        ' an idle swarm and then destroys the engine on its own — but an abandoned
        ' worker keeps resetting that idle clock, so the companion keeps downloading
        ' for as long as this worker keeps asking. Nothing else in the app can cut
        ' that window short.
        '
        ' The signal is the state field, not control. control is WRITE_ONLY — it
        ' only "requests a change in the run state" — and the field to inquire with
        ' is state (READ_ONLY), whose values Roku documents as lowercase: "init",
        ' "stop", "run", "done". control answers that same lowercase "stop"
        ' wherever it leaks through, and a case-sensitive = equates only "stop", so
        ' comparing control to "STOP" could never match.
        '
        ' Returning without a result is correct, not a dropped answer: the observer
        ' is already gone, so there is no one left to read it.
        if m.top.state = "stop" then return
        http = Transport()
        store = PlaybackStore(http)
        stream = m.top.stream
        ' The device's codec answer, read HERE because roDeviceInfo is Task-only.
        ' The store cannot ask for it: it runs in whatever component includes it
        ' (five of them) and only this one is guaranteed a Task scope. Nothing in
        ' this call touches the network, so a failure costs nothing — an empty
        ' profile simply leaves the legacy URL in place.
        profile = ResolveCodecProfile()
        resolved = store.ResolvePlayback(m.top.serverAddress, m.top.stream, m.top.season, m.top.episode, profile)
        ' The probe gets its own try, and this is the other half of the fix
        ' described above. It is a diagnostic: its job is to ADD what is known,
        ' and a throw in here must not be able to remove the answer. Sharing the
        ' catch below meant any fault in the wait loop reported as a failed
        ' resolve, which is worse than having no probe at all — it looks like a
        ' server refusing a stream it was never asked about.
        if resolved.ok and store.IsTorrent(m.top.stream) then
            ' The engine is asked for before the playlist is, and the order is the
            ' whole point: a playlist request to a server that has not been told
            ' to make an engine is not a request that is slow, it is one that
            ' hangs. Stremio opens the same way and the server logs the engine
            ' appearing on the back of its first request.
            '
            ' Its own try, for the same reason the probe has one below. A warm-up
            ' that throws is a lost optimisation, and folding it into the probe's
            ' catch would report the fault as a probe that gave up — describing a
            ' request the server was never sent as one it refused.
            '
            ' Checked again here, not only at the top of the worker: a stop that
            ' lands while ResolvePlayback runs (it makes no request, but it does
            ' build the URL first) must not START a warm-up. This is the request
            ' that creates the engine, so making it after the user has left is the
            ' one thing in this file that can set the companion downloading from a
            ' play nobody is watching.
            if m.top.state = "stop" then return
            try
                engineUrl = store.EngineUrl(m.top.serverAddress, m.top.stream, m.top.season, m.top.episode)
                if engineUrl <> "" then
                    resolved.warmup = store.WarmEngine(engineUrl)
                    ' What the engine was handed, not what it answered. A cold engine
                    ' with trackers is a wait measured in seconds and one with none
                    ' has DHT alone to find metadata, which is minutes — and no
                    ' timeout on this side can tell those two apart from the outside.
                    resolved.warmup.trackers = store.StreamTrackers(m.top.stream).Count()
                    resolved.warmup.fileIdx = store.DirectFileIdx(m.top.stream)
                end if
            catch e
                resolved.warmup = { ok: false, status: 0, error: e.message }
            end try

            try
                resolved.probe = WaitForPlaylist(store, resolved.url, resolved.fallbackUrl)
                ' The probe can move off the direct HLS2 route, so the URL handed
                ' to the Video node has to be the one the probe settled on — see
                ' WaitForPlaylist. Guarded on the field's type rather than assumed,
                ' because the fallback probe object built below carries no url.
                if resolved.probe.url <> invalid then resolved.url = resolved.probe.url
            catch e
                resolved.probe = {
                    ok: false
                    status: 0
                    attempts: 0
                    firstError: e.message
                    body: ""
                    gaveUp: true
                    url: resolved.url
                }
            end try
        end if
        ' A stop that landed inside the probe loop leaves a probe object built
        ' from fewer than four attempts. Publishing it is pointless at best — its
        ' observer is already gone — and writing a result onto a node nobody is
        ' watching is the exact hazard the sibling tasks note, so this does not
        ' publish at all. Nothing is lost: the caller cancelled, so there is no
        ' one left to read it.
        if m.top.state = "stop" then return
        m.top.result = resolved
    catch e
        m.top.result = { ok: false, url: "", error: e.message }
    end try
end sub

' Ask the streaming server for the playlist until it will serve one or the
' attempts run out, and report the whole attempt: { ok, status, attempts,
' firstError, body, gaveUp, url, fellBack }.
'
' No elapsed time is recorded because none is measured: the bound is four
' attempts with a pause between, and a stalled request is cut off by the probe's
' own timeout rather than by a deadline. `gaveUp` is set from the loop's own
' exit rather than inferred by the reader.
'
' `url` is the URL the loop ended on, which is what the caller must hand over —
' it starts on the direct HLS2 route and can move to the legacy one, so the
' caller cannot keep its own copy and stay in step.
'
' The one response that moves it is a 404 on the direct route. The server
' predates /hlsv2, so every attempt against that path would 404 forever; the
' legacy route serves the same file through the same converter and is where the
' client was before the hints existed. A 404 is the discriminator because it is
' the only failure that means "no such route" — a cold engine does not refuse the
' request, it HOLDS it, so the failure there is a timeout (status 0) and must
' keep waiting. Advancing on anything else would abandon a legitimate wait the
' first time a cold engine was slow.
'
' Four attempts, not six, and the probe's timeout went from 4s to 8s to pay for
' it: 6 x (4000 + 4000) and 4 x (8000 + 4000) are both 44s. The server's log
' showed why that trade is the right way round — a cold engine took ~8.4s from
' creation to a served playlist, so every one of the old six attempts was
' guaranteed to expire against a request the server was still legitimately
' working on. Four longer attempts can finish on the first ask; six short ones
' could not finish on any ask. Fewer attempts, each one long enough to actually
' wait out a cold engine, for the identical worst case.
function WaitForPlaylist(store as object, url as string, fallbackUrl = "" as string) as object
    probe = {
        ok: false
        status: 0
        attempts: 0
        firstError: ""
        body: ""
        gaveUp: false
        url: url
        fellBack: false
    }
    ' The count is a literal rather than a computed bound so the ceiling is
    ' readable in one place. It is also only ever a floor on how long the player
    ' waits, never a reason it cannot start: the URL is handed over either way.
    for attempt = 1 to 4
        ' At the TOP of every attempt, not once before the loop: the stop can land
        ' while this worker is inside the 4s interval below, and only a check here
        ' can see it before the next request goes out. Exits the loop rather than
        ' returning a probe so the caller decides whether to publish at all — see
        ' the guard before m.top.result in resolve().
        if m.top.state = "stop" then exit for
        probe.attempts = attempt
        answer = store.ProbePlaylist(probe.url)
        probe.status = answer.status
        probe.body = answer.body
        if answer.ok
            probe.ok = true
            exit for
        end if
        if probe.firstError = "" then probe.firstError = answer.error
        if answer.status = 404 and fallbackUrl <> "" and probe.url <> fallbackUrl then
            ' Not a wait: this route does not exist here. Swap and ask again on
            ' the next attempt without spending the interval on a 404 that came
            ' back as fast as it was sent.
            probe.url = fallbackUrl
            probe.fellBack = true
        else
            ' Interval: 4s. Long enough not to hammer a server still starting an
            ' engine, short enough that a warm one is noticed within one poll. Two
            ' arguments because that is the signature BrighterScript checks against
            ' (BS1002); an invalid port is Roku's own one-argument Wait. Skipped on
            ' the last attempt, where it would only be a pause before giving up.
            if attempt < 4 then Wait(4000, invalid)
        end if
    end for
    if not probe.ok then probe.gaveUp = true
    return probe
end function

' The codec hints for this device: what to advertise as pass-through.
'
' This is the production half of the spike in components/DeviceCapTask.brs, built
' for a request rather than for a report — no raw reply is kept, because the
' naming question that needed it has been answered. The split is the same and for
' the same reason: the codec names and the reading of an answer live in
' source/util/CodecProbe.brs where the suite can reach them, and only the
' roDeviceInfo calls live here, where a Task scope exists.
'
' VIDEO ONLY, and deliberately so. An audio half was built and then dropped on
' device evidence: with `ac3` advertised the server stream-copied the AC-3 5.1
' track and the Roku played the video with NO audio — and the same content
' streamed straight to the Roku as a raw MKV, with nothing remuxing it, was just
' as silent. So it is not this transport and not a transcoding choice: the sink
' reports AC-3 over HDMI and does not reproduce it, and no CanDecodeAudio reply
' distinguishes that case from a device that does. The audio list is therefore
' the server's own floor, and the cap the bridge's hardcoded 2 — both unchanged
' from before this work; they are named locals rather than literals so the
' fingerprint below still describes the FINAL values rather than the defaults.
' Re-enabling the audio half is a deliberate change (see reference/hls2.md), not
' something a probe should be able to switch back on.
'
' Every failure answers "no". An unanswerable probe, a missing member, an old OS
' — all of them leave the floor in place, so the worst case is the server's own
' defaults, which is where this started. The one thing that must never happen is
' assuming a yes: a wrong "yes" buys a remux the device may not be able to show,
' and it fails quietly — no video, or no sound, and no error either way.
function ResolveCodecProfile() as object
    profile = {
        videoCodecs: CodecVideoFloor()
        audioCodecs: CodecAudioFloor()
        maxAudioChannels: 2
        fingerprint: CodecFingerprint(CodecVideoFloor(), CodecAudioFloor(), 2)
    }
    di = ResolveDeviceInfo()
    if di = invalid then return profile

    videoProbes = []
    for each candidate in CodecVideoCandidates()
        videoProbes.Push(ResolveProbeVideo(di, candidate))
    end for

    videoCodecs = CodecHints(CodecVideoFloor(), CodecVideoCandidates(), videoProbes)
    audioCodecs = CodecAudioFloor()
    channels = 2
    profile.videoCodecs = videoCodecs
    profile.audioCodecs = audioCodecs
    profile.maxAudioChannels = channels
    profile.fingerprint = CodecFingerprint(videoCodecs, audioCodecs, channels)
    return profile
end function

' roDeviceInfo is Task-only, hence this file. Failure to create it is not an
' error to report — it is simply "no hints", which the floor already covers.
function ResolveDeviceInfo() as object
    di = invalid
    try
        di = CreateObject("roDeviceInfo")
    catch e
    end try
    return di
end function

function ResolveProbeVideo(di as object, candidate as object) as object
    request = { codec: candidate.codec }
    if candidate.profile <> "" then request.profile = candidate.profile
    if candidate.level <> "" then request.level = candidate.level
    return ResolveProbe(di, candidate.codec, request)
end function

' One probe, reduced to the only two facts a request needs: which codec, and
' whether the reply was an explicit yes. The raw reply is deliberately dropped —
' it was the spike's whole point and is not a request's. Video-only now: the
' audio probe went with the audio half (see ResolveCodecProfile), so a
' can-decode-audio branch here would be a path nothing calls.
function ResolveProbe(di as object, codec as string, request as object) as object
    result = { codec: codec, ok: false }
    raw = invalid
    try
        raw = di.CanDecodeVideo(request)
    catch e
        return result
    end try
    result.ok = CodecResult(raw)
    return result
end function

