' Cache size unit tests — the helpers in source/util/CacheSize.brs and the
' cache size the ServerSettingsStore reads and writes.
'
' Bodies mirror the official server verbatim: options are an array of option
' objects, the cacheSize one holds {name, val} selections, its unlimited
' choice is JSON null, and values.cacheSize carries the number back.

function CacheSizeRealBody() as string
    body = "{""options"":[{""id"":""localAddonEnabled"",""type"":""checkbox""},{""id"":""cacheSize"",""label"":""CACHING"",""type"":""select"",""selections"":[{""name"":""no caching"",""val"":0},{""name"":""2GB"",""val"":2147483648},{""name"":""5GB"",""val"":5368709120},{""name"":""10GB"",""val"":10737418240},{""name"":""INFINITY"",""val"":null}]}],""values"":{""cacheSize"":2147483648,""btMaxConnections"":35,""btHandshakeTimeout"":20000,""btRequestTimeout"":4000,""btDownloadSpeedSoftLimit"":1677721.6,""btDownloadSpeedHardLimit"":1677721.6,""btMinPeersForStable"":5},""baseUrl"":""http://127.0.0.1:11470""}"
    return body
end function

sub Test_CacheSize_Choices()
    Harness_Suite("Cache size: choices from the server's options")

    choices = CacheSizeChoices(ParseJson(CacheSizeRealBody()).options)
    Harness_Equal(choices.Count(), 5, "all five selections are offered")
    Harness_Equal(choices[0].label, "no caching", "the server's own name is kept")
    Harness_Equal(choices[0].value, 0, "no caching is 0")
    Harness_Equal(choices[1].label, "2GB", "2GB labeled plainly")
    Harness_Equal(choices[2].value, 5368709120, "5GB carries its value")
    Harness_Equal(choices[3].value, 10737418240, "10GB survives past 32 bits")
    Harness_Ok(choices[4].value = invalid, "the unlimited choice has no number")
    Harness_Equal(choices[4].label, "INFINITY", "and the server's own name for it")
end sub

sub Test_CacheSize_ChoicesWithoutOptions()
    Harness_Suite("Cache size: a server that offers nothing")

    Harness_Equal(CacheSizeChoices(invalid).Count(), 0, "no options, no choices")
    Harness_Equal(CacheSizeChoices([]).Count(), 0, "an empty option list has no choices")
    Harness_Equal(CacheSizeChoices([{ id: "remoteHttps" }]).Count(), 0, "no cacheSize option, no choices")
    Harness_Equal(CacheSizeChoices([{ id: "cacheSize" }]).Count(), 0, "a cacheSize option without selections has no choices")
end sub

sub Test_CacheSize_ChoicesFilterUnusable()
    Harness_Suite("Cache size: unusable selections are skipped")

    ' A nameless selection takes the bytes-to-label fallback; a text val, a
    ' missing val and a negative one are not choices.
    options = [{ id: "cacheSize", selections: [{ val: 2147483648 }, { name: "", val: 5368709120 }, { name: "x", val: "big" }, { name: "y" }, { name: "z", val: -1 }, { val: 1048576 }] }]
    choices = CacheSizeChoices(options)
    Harness_Equal(choices.Count(), 3, "only usable selections survive")
    Harness_Equal(choices[0].label, "2 GB", "a nameless selection is labeled from its bytes")
    Harness_Equal(choices[1].label, "5 GB", "an empty name falls back to the label")
    Harness_Equal(choices[2].label, "1 MB", "small sizes label in MB")
end sub

sub Test_CacheSize_Index()
    Harness_Suite("Cache size: where the current value stands")

    choices = CacheSizeChoices(ParseJson(CacheSizeRealBody()).options)
    Harness_Equal(CacheSizeIndexForValue(choices, 2147483648), 1, "2GB is choice 1")
    Harness_Equal(CacheSizeIndexForValue(choices, 10737418240.0), 3, "10GB matches across a float")
    Harness_Equal(CacheSizeIndexForValue(choices, 999999), -1, "an unknown size is nowhere")
    Harness_Equal(CacheSizeIndexForValue(choices, -1), 4, "a null size is the unlimited choice")
    Harness_Equal(CacheSizeIndexForValue(choices, invalid), -1, "no value matches nothing")
end sub

sub Test_CacheSize_NextIndex()
    Harness_Suite("Cache size: the cycle")

    choices = CacheSizeChoices(ParseJson(CacheSizeRealBody()).options)
    Harness_Equal(CacheSizeNextIndex(choices, 0), 1, "one moves on")
    Harness_Equal(CacheSizeNextIndex(choices, 4), 0, "unlimited wraps to the first")
    Harness_Equal(CacheSizeNextIndex(choices, -1), 0, "custom starts at the first choice")
end sub

sub Test_CacheSize_Body()
    Harness_Suite("Cache size: the write body")

    choices = CacheSizeChoices(ParseJson(CacheSizeRealBody()).options)
    Harness_Equal(CacheSizeBody(choices[1]), "{""cacheSize"":2147483648}", "a size posts as its number")
    Harness_Equal(CacheSizeBody(choices[4]), "{""cacheSize"":null}", "unlimited posts a JSON null")
    Harness_Equal(CacheSizeBody(choices[0]), "{""cacheSize"":0}", "no caching posts zero")
end sub

sub Test_ServerSettings_GetCacheSize()
    Harness_Suite("ServerSettingsStore.Get reads the cache size")

    script = [
        {
            method: "GET"
            url: "http://127.0.0.1:11470/settings"
            ok: true
            status: 200
            body: CacheSizeRealBody()
            error: ""
        }
    ]
    result = ServerSettingsStore(ScriptedTransport(script)).Get("http://127.0.0.1:11470")

    Harness_Ok(result.ok, "the read succeeds")
    Harness_Ok(result.options <> invalid, "and carries the options for the choices")
    Harness_Equal(result.cacheSize, 2147483648, "the current size, read from the raw body")
end sub

sub Test_ServerSettings_GetCacheSizeNullAndBig()
    Harness_Suite("ServerSettingsStore.Get reads null and big sizes exactly")

    body = "{""options"":[],""values"":{""cacheSize"":null,""btMaxConnections"":35,""btHandshakeTimeout"":20000,""btRequestTimeout"":4000,""btDownloadSpeedSoftLimit"":1677721.6,""btDownloadSpeedHardLimit"":1677721.6,""btMinPeersForStable"":5},""baseUrl"":""http://127.0.0.1:11470""}"
    script = [
        {
            method: "GET"
            url: "http://127.0.0.1:11470/settings"
            ok: true
            status: 200
            body: body
            error: ""
        }
    ]
    result = ServerSettingsStore(ScriptedTransport(script)).Get("http://127.0.0.1:11470")
    Harness_Equal(result.cacheSize, -1, "a null size is the unlimited sentinel")

    body = "{""options"":[],""values"":{""cacheSize"":10737418240,""btMaxConnections"":35,""btHandshakeTimeout"":20000,""btRequestTimeout"":4000,""btDownloadSpeedSoftLimit"":1677721.6,""btDownloadSpeedHardLimit"":1677721.6,""btMinPeersForStable"":5},""baseUrl"":""http://127.0.0.1:11470""}"
    script = [
        {
            method: "GET"
            url: "http://127.0.0.1:11470/settings"
            ok: true
            status: 200
            body: body
            error: ""
        }
    ]
    result = ServerSettingsStore(ScriptedTransport(script)).Get("http://127.0.0.1:11470")
    Harness_Equal(result.cacheSize, 10737418240, "10GB is not clamped to 32 bits")
end sub

sub Test_ServerSettings_GetCacheSizeAfterValues()
    Harness_Suite("ServerSettingsStore.Get reads the values' cache size, not the options'")

    ' The options array says "cacheSize" too; the read must take the one in
    ' values, which is what the server runs with.
    script = [
        {
            method: "GET"
            url: "http://127.0.0.1:11470/settings"
            ok: true
            status: 200
            body: CacheSizeRealBody()
            error: ""
        }
    ]
    result = ServerSettingsStore(ScriptedTransport(script)).Get("http://127.0.0.1:11470")
    Harness_Equal(result.cacheSize, 2147483648, "values won, not the option's id")
end sub

sub Test_ServerSettings_SetRawBody()
    Harness_Suite("ServerSettingsStore.Set posts a raw body as text")

    script = [
        {
            method: "POST"
            url: "http://127.0.0.1:11470/settings"
            ok: true
            status: 200
            body: "{""success"":true}"
            error: ""
        }
    ]
    transport = ScriptedTransport(script)
    result = ServerSettingsStore(transport).Set("http://127.0.0.1:11470", "{""cacheSize"":null}")

    Harness_Ok(result.ok, "the write succeeds")
    Harness_Equal(transport.log[0].body, "{""cacheSize"":null}", "the body reaches the transport as text")
    Harness_Equal(transport.log[0].headers["Content-Type"], "application/json", "and says it is JSON")
end sub
