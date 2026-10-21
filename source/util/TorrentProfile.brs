' TorrentProfile — the torrent profiles the streaming server can run under.
'
' Stremio's desktop app has a "Torrent profile" setting under Settings ->
' Streaming. A profile is a named set of six limits for the server's BitTorrent
' engine: how many peers it may connect to, how long it waits for a handshake
' and for a request, how fast it may download (a soft limit it stops peer
' discovery at, and a hard limit it never goes past) and how many peers it
' wants before it calls a stream stable.
'
' The server knows nothing about these names. It stores the six limits in its
' settings file and reads them when it creates a torrent engine, so the
' profile lives here and the client expands one into the six keys before
' writing them to the server's /settings — which is what Stremio's own client
' does with the same settings.
'
' The numbers are Stremio's. Default, Soft (Conservative) and Fast (Aggressive)
' are the sets Stremio published; Ultra fast is the set a Stremio server
' reports once that profile has been selected.
'
' ONE number is not Stremio's verbatim: Soft's speed limits are 1677721.6 in
' Stremio's file, a fraction of a byte per second. The server only accepts
' whole numbers for a speed limit (it checks isPositiveInteger), so a
' fractional limit is silently ignored and the server falls back to its own
' default — the hard limit would come back as 2.5 MB/s instead of 1.6, which
' is not the soft profile at all. The nearest whole number is the same limit
' to within half a byte per second and the server does accept it.
'
' The order of the table is the order the profiles are offered in.

' Every profile, in the order they are offered.
function TorrentProfiles() as object
    profiles = []
    profiles.Push({
        id: "default"
        label: "Default"
        full: "Default"
        values: {
            "btMaxConnections": 55
            "btHandshakeTimeout": 20000
            "btRequestTimeout": 4000
            "btDownloadSpeedSoftLimit": 2621440
            "btDownloadSpeedHardLimit": 3670016
            "btMinPeersForStable": 5
        }
    })
    profiles.Push({
        id: "soft"
        label: "Soft"
        full: "Soft (Conservative)"
        values: {
            "btMaxConnections": 35
            "btHandshakeTimeout": 20000
            "btRequestTimeout": 4000
            "btDownloadSpeedSoftLimit": 1677722
            "btDownloadSpeedHardLimit": 1677722
            "btMinPeersForStable": 5
        }
    })
    profiles.Push({
        id: "fast"
        label: "Fast"
        full: "Fast (Aggressive)"
        values: {
            "btMaxConnections": 200
            "btHandshakeTimeout": 20000
            "btRequestTimeout": 4000
            "btDownloadSpeedSoftLimit": 4194304
            "btDownloadSpeedHardLimit": 39321600
            "btMinPeersForStable": 10
        }
    })
    profiles.Push({
        id: "ultrafast"
        label: "Ultra fast"
        full: "Ultra fast"
        values: {
            "btMaxConnections": 400
            "btHandshakeTimeout": 25000
            "btRequestTimeout": 6000
            "btDownloadSpeedSoftLimit": 8388608
            "btDownloadSpeedHardLimit": 78643200
            "btMinPeersForStable": 10
        }
    })
    return profiles
end function

' The profile with this id, or invalid when there is none.
function TorrentProfileById(id as string) as object
    if id = "" then return invalid
    for each profile in TorrentProfiles()
        if profile.id = id then return profile
    end for
    return invalid
end function

' The short name, for the row's value column.
function TorrentProfileLabel(id as string) as string
    profile = TorrentProfileById(id)
    if profile = invalid then return ""
    return profile.label
end function

' The full name, for the panel.
function TorrentProfileFullLabel(id as string) as string
    profile = TorrentProfileById(id)
    if profile = invalid then return ""
    return profile.full
end function

' The profile after this one, wrapping round to the first.
'
' An id that is not in the table — the server's limits match no profile, so
' there is nothing to advance from — starts the cycle at the first profile,
' which is the way back to a known state.
function TorrentProfileNext(id as string) as string
    profiles = TorrentProfiles()
    for i = 0 to profiles.Count() - 1
        if profiles[i].id = id then return profiles[(i + 1) mod profiles.Count()].id
    end for
    return profiles[0].id
end function

' The profile the server's settings describe, "custom" when they describe
' none of them, and "" when there is nothing to read.
function TorrentProfileMatch(values as object) as string
    if values = invalid then return ""
    for each profile in TorrentProfiles()
        if TorrentProfileValuesMatch(profile.values, values) then return profile.id
    end for
    return "custom"
end function

' Whether the server's settings carry these limits.
'
' The comparison allows a byte per second of slack, because a limit written by
' another client may be a fraction of a byte per second while the numbers
' here are whole ones: Stremio's own Soft profile ships 1677721.6 and the two
' differ by less than one and mean the same limit.
function TorrentProfileValuesMatch(expected as object, actual as object) as boolean
    if expected = invalid or actual = invalid then return false
    for each key in expected
        if not actual.DoesExist(key) then return false
        if not TorrentNumberClose(actual[key], expected[key]) then return false
    end for
    return true
end function

' Two limits the same, to within a byte per second.
'
' A limit that is not a number at all is not a limit: the server's settings
' are read from JSON, so a value that arrived as text is a value this cannot
' compare, and comparing it as a number would be inventing a limit the server
' never had.
function TorrentNumberClose(a as dynamic, b as dynamic) as boolean
    if a = invalid or b = invalid then return false
    if Type(a) = "String" or Type(a) = "roString" then return false
    if Type(b) = "String" or Type(b) = "roString" then return false
    return Abs(a - b) <= 1
end function
