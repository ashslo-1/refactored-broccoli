' ServerSettingsStore unit tests.
'
' The store is the only thing that talks to the streaming server's /settings
' endpoint, so the two things that can go wrong there are pinned here: the
' request has to reach the right path, and a body the server has to parse as
' JSON has to say that it is JSON. The server parses the body with
' body-parser, which only parses a body whose content type says JSON — a body
' it does not parse is an empty object, so the settings would be saved
' unchanged and the call would still answer success.
'
' And the values are read out of the RAW body, which is the other half of the
' story: the settings file of a server that was written with the lowercase
' key names and then updated with the camelCase ones answers with BOTH, and a
' parsed object — whose keys are case-insensitive — keeps one entry per key,
' with the last spelling parsed winning. The leftovers hold the server's old
' defaults, so a parsed read reports a profile the server is not running. The
' test below is that server, verbatim.

function ServerAddress() as string
    return "http://127.0.0.1:11470"
end function

' The six limits, as the server writes them.
function ServerSettingsBody() as string
    return "{""options"":[],""values"":{""serverVersion"":""4.21.0"",""btMaxConnections"":35,""btHandshakeTimeout"":20000,""btRequestTimeout"":4000,""btDownloadSpeedSoftLimit"":1677721.6,""btDownloadSpeedHardLimit"":1677721.6,""btMinPeersForStable"":5,""remoteHttps"":""""},""baseUrl"":""http://127.0.0.1:11470""}"
end function

' The same server, with the lowercase leftovers of an earlier edit still in
' the file. They hold the OLD defaults, and they are what a parsed read
' returns.
function ServerSettingsBodyWithBothSpellings() as string
    return "{""options"":[],""values"":{""btMaxConnections"":35,""btHandshakeTimeout"":20000,""btRequestTimeout"":4000,""btDownloadSpeedSoftLimit"":1677721.6,""btDownloadSpeedHardLimit"":1677721.6,""btMinPeersForStable"":5,""btProfile"":""default"",""btrequesttimeout"":4000,""btminpeersforstable"":5,""btmaxconnections"":55,""bthandshaketimeout"":20000,""btdownloadspeedsoftlimit"":2621440,""btdownloadspeedhardlimit"":3670016},""baseUrl"":""http://127.0.0.1:11470""}"
end function

sub Test_ServerSettings_Get()
    Harness_Suite("ServerSettingsStore.Get reads the server's settings")

    script = [
        {
            method: "GET"
            url: ServerAddress() + "/settings"
            ok: true
            status: 200
            body: ServerSettingsBody()
            error: ""
        }
    ]
    transport = ScriptedTransport(script)
    store = ServerSettingsStore(transport)
    result = store.Get(ServerAddress())

    Harness_Ok(result.ok, "the read succeeds")
    Harness_Equal(result.error, "", "with nothing to complain about")
    Harness_Equal(result.values.btMaxConnections, 35, "the connection limit comes back")
    Harness_Equal(result.values.btMinPeersForStable, 5, "the peers come back")
    Harness_Equal(transport.log.Count(), 1, "one request was made")
    Harness_Equal(transport.log[0].method, "GET", "it was a GET")
    Harness_Equal(transport.log[0].url, ServerAddress() + "/settings", "it asked the server for its settings")
end sub

' The case that matters: the file carries both spellings of every key, and
' the camelCase ones are the server's. The lowercase leftovers are an older
' edit and hold the old defaults.
sub Test_ServerSettings_GetWithBothSpellings()
    Harness_Suite("ServerSettingsStore.Get reads the server's own spelling")

    script = [
        {
            method: "GET"
            url: ServerAddress() + "/settings"
            ok: true
            status: 200
            body: ServerSettingsBodyWithBothSpellings()
            error: ""
        }
    ]
    transport = ScriptedTransport(script)
    store = ServerSettingsStore(transport)
    result = store.Get(ServerAddress())

    Harness_Ok(result.ok, "the read succeeds")
    Harness_Equal(result.values.btMaxConnections, 35, "the server's own connection limit comes back, not the leftover's")
    Harness_Equal(result.values.btHandshakeTimeout, 20000, "and its handshake timeout")
    Harness_Equal(result.values.btRequestTimeout, 4000, "and its request timeout")
    Harness_Equal(result.values.btMinPeersForStable, 5, "and its peers")
    ' The speed limits are the ones Stremio writes as a fraction of a byte
    ' per second. A byte per second of slack is the whole difference, and the
    ' interpreter cannot hold the fraction at that magnitude, so this asks
    ' for the neighbourhood rather than the number.
    Harness_Ok(Abs(result.values.btDownloadSpeedSoftLimit - 1677721.6) <= 1, "and its soft speed limit")
    Harness_Ok(Abs(result.values.btDownloadSpeedHardLimit - 1677721.6) <= 1, "and its hard speed limit")
end sub

' And the read has to say what the server is running. The leftovers are the
' old defaults, so a read that took them would report the Default profile
' for a server running Soft.
sub Test_ServerSettings_GetWithBothSpellingsIsNotTheLeftovers()
    Harness_Suite("ServerSettingsStore.Get does not report the leftovers")

    script = [
        {
            method: "GET"
            url: ServerAddress() + "/settings"
            ok: true
            status: 200
            body: ServerSettingsBodyWithBothSpellings()
            error: ""
        }
    ]
    transport = ScriptedTransport(script)
    store = ServerSettingsStore(transport)
    result = store.Get(ServerAddress())

    Harness_Ok(result.values.btMaxConnections <> 55, "the leftover's connection limit is not what comes back")
    Harness_Ok(Abs(result.values.btDownloadSpeedSoftLimit - 2621440) > 1, "nor the leftover's speed limit")
end sub

sub Test_ServerSettings_GetWithoutAnAddress()
    Harness_Suite("ServerSettingsStore.Get needs an address")

    transport = ScriptedTransport([])
    store = ServerSettingsStore(transport)
    result = store.Get("")

    Harness_Ok(not result.ok, "there is nothing to read without a server")
    Harness_Equal(result.error, "no streaming server address", "and it says so")
    Harness_Equal(transport.log.Count(), 0, "and it asks nothing")
end sub

sub Test_ServerSettings_GetOnAFailure()
    Harness_Suite("ServerSettingsStore.Get when the server refuses")

    script = [
        {
            method: "GET"
            url: ServerAddress() + "/settings"
            ok: false
            status: 0
            body: ""
            error: "connection refused"
        }
    ]
    transport = ScriptedTransport(script)
    store = ServerSettingsStore(transport)
    result = store.Get(ServerAddress())

    Harness_Ok(not result.ok, "a refused read is not a success")
    Harness_Equal(result.error, "connection refused", "the transport's own wording is kept")
    Harness_Equal(result.values, invalid, "and there are no values")
end sub

sub Test_ServerSettings_GetOnAnEmptyAnswer()
    Harness_Suite("ServerSettingsStore.Get on an empty answer")

    script = [
        {
            method: "GET"
            url: ServerAddress() + "/settings"
            ok: true
            status: 200
            body: ""
            error: ""
        }
    ]
    transport = ScriptedTransport(script)
    store = ServerSettingsStore(transport)
    result = store.Get(ServerAddress())

    Harness_Ok(not result.ok, "an empty answer is not a success")
    Harness_Ok(result.error <> "", "and it says what was missing")
end sub

sub Test_ServerSettings_GetOnAnAnswerWithoutTheLimits()
    Harness_Suite("ServerSettingsStore.Get on an answer without the limits")

    script = [
        {
            method: "GET"
            url: ServerAddress() + "/settings"
            ok: true
            status: 200
            body: "{""options"":[],""values"":{""serverVersion"":""4.21.0""},""baseUrl"":""http://127.0.0.1:11470""}"
            error: ""
        }
    ]
    transport = ScriptedTransport(script)
    store = ServerSettingsStore(transport)
    result = store.Get(ServerAddress())

    Harness_Ok(not result.ok, "an answer without the limits is not a success")
    Harness_Equal(result.error, "the server's settings carried no torrent limits", "and it says which")
end sub

sub Test_ServerSettings_Set()
    Harness_Suite("ServerSettingsStore.Set writes the server's settings")

    script = [
        {
            method: "POST"
            url: ServerAddress() + "/settings"
            ok: true
            status: 200
            json: { success: true }
            error: ""
        }
    ]
    transport = ScriptedTransport(script)
    store = ServerSettingsStore(transport)
    values = {
        btMaxConnections: 200
        btHandshakeTimeout: 20000
        btRequestTimeout: 4000
        btDownloadSpeedSoftLimit: 4194304
        btDownloadSpeedHardLimit: 39321600
        btMinPeersForStable: 10
    }
    result = store.Set(ServerAddress(), values)

    Harness_Ok(result.ok, "the write succeeds")
    Harness_Equal(result.error, "", "with nothing to complain about")
    Harness_Equal(transport.log.Count(), 1, "one request was made")
    Harness_Equal(transport.log[0].method, "POST", "it was a POST")
    Harness_Equal(transport.log[0].url, ServerAddress() + "/settings", "it went to the server's settings")
    Harness_Equal(transport.log[0].body.btMaxConnections, 200, "the body carries the limits")
    Harness_Equal(transport.log[0].body.btMinPeersForStable, 10, "all of them")
    Harness_Equal(transport.log[0].headers["Content-Type"], "application/json", "the body says it is JSON, or the server parses it as an empty object and saves nothing")
end sub

sub Test_ServerSettings_SetWithoutAnAddress()
    Harness_Suite("ServerSettingsStore.Set needs an address")

    transport = ScriptedTransport([])
    store = ServerSettingsStore(transport)
    result = store.Set("", { btMaxConnections: 55 })

    Harness_Ok(not result.ok, "there is nothing to write without a server")
    Harness_Equal(result.error, "no streaming server address", "and it says so")
    Harness_Equal(transport.log.Count(), 0, "and it asks nothing")
end sub

sub Test_ServerSettings_SetWithoutValues()
    Harness_Suite("ServerSettingsStore.Set needs values")

    transport = ScriptedTransport([])
    store = ServerSettingsStore(transport)
    result = store.Set(ServerAddress(), invalid)

    Harness_Ok(not result.ok, "there is nothing to write without values")
    Harness_Equal(result.error, "no settings to write", "and it says so")
    Harness_Equal(transport.log.Count(), 0, "and it asks nothing")
end sub

sub Test_ServerSettings_SetOnAFailure()
    Harness_Suite("ServerSettingsStore.Set when the server refuses")

    script = [
        {
            method: "POST"
            url: ServerAddress() + "/settings"
            ok: false
            status: 500
            json: invalid
            error: "HTTP 500"
        }
    ]
    transport = ScriptedTransport(script)
    store = ServerSettingsStore(transport)
    result = store.Set(ServerAddress(), { btMaxConnections: 55 })

    Harness_Ok(not result.ok, "a refused write is not a success")
    Harness_Equal(result.error, "HTTP 500", "the transport's own wording is kept")
end sub
