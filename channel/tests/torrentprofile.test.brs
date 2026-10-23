' Torrent profile unit tests — the table in source/util/TorrentProfile.brs.
'
' The numbers are Stremio's, and they are the whole point of the file: a
' profile that quietly drifted from Stremio's would be a profile with
' Stremio's name on it, which is worse than no profile at all. So they are
' pinned here, one by one, and so are the cycle and the match — the two
' pieces of behaviour that turn the table into something the row can use.

sub Test_TorrentProfile_Table()
    Harness_Suite("Torrent profile table")

    profiles = TorrentProfiles()
    Harness_Equal(profiles.Count(), 4, "there are four profiles")
    Harness_Equal(profiles[0].id, "default", "the first profile is Default")
    Harness_Equal(profiles[1].id, "soft", "the second is Soft")
    Harness_Equal(profiles[2].id, "fast", "the third is Fast")
    Harness_Equal(profiles[3].id, "ultrafast", "the fourth is Ultra fast")
    Harness_Equal(profiles[1].label, "Soft", "Soft is called Soft in the row")
    Harness_Equal(profiles[1].full, "Soft (Conservative)", "and Soft (Conservative) in the panel")
end sub

sub Test_TorrentProfile_DefaultLimits()
    Harness_Suite("Torrent profile: the Default limits")

    values = TorrentProfileById("default").values
    Harness_Equal(values.btMaxConnections, 55, "Default allows 55 connections")
    Harness_Equal(values.btHandshakeTimeout, 20000, "Default waits 20s for a handshake")
    Harness_Equal(values.btRequestTimeout, 4000, "Default waits 4s for a request")
    Harness_Equal(values.btDownloadSpeedSoftLimit, 2621440, "Default's soft limit is 2.5 MB/s")
    Harness_Equal(values.btDownloadSpeedHardLimit, 3670016, "Default's hard limit is 3.5 MB/s")
    Harness_Equal(values.btMinPeersForStable, 5, "Default wants 5 stable peers")
end sub

sub Test_TorrentProfile_SoftLimits()
    Harness_Suite("Torrent profile: the Soft limits")

    values = TorrentProfileById("soft").values
    Harness_Equal(values.btMaxConnections, 35, "Soft allows 35 connections")
    Harness_Equal(values.btHandshakeTimeout, 20000, "Soft waits 20s for a handshake")
    Harness_Equal(values.btRequestTimeout, 4000, "Soft waits 4s for a request")
    Harness_Equal(values.btDownloadSpeedSoftLimit, 1677722, "Soft's soft limit is 1.6 MB/s")
    Harness_Equal(values.btDownloadSpeedHardLimit, 1677722, "Soft's hard limit is 1.6 MB/s too")
    Harness_Equal(values.btMinPeersForStable, 5, "Soft wants 5 stable peers")
end sub

sub Test_TorrentProfile_FastLimits()
    Harness_Suite("Torrent profile: the Fast limits")

    values = TorrentProfileById("fast").values
    Harness_Equal(values.btMaxConnections, 200, "Fast allows 200 connections")
    Harness_Equal(values.btHandshakeTimeout, 20000, "Fast waits 20s for a handshake")
    Harness_Equal(values.btRequestTimeout, 4000, "Fast waits 4s for a request")
    Harness_Equal(values.btDownloadSpeedSoftLimit, 4194304, "Fast's soft limit is 4 MB/s")
    Harness_Equal(values.btDownloadSpeedHardLimit, 39321600, "Fast's hard limit is 37.5 MB/s")
    Harness_Equal(values.btMinPeersForStable, 10, "Fast wants 10 stable peers")
end sub

sub Test_TorrentProfile_UltraFastLimits()
    Harness_Suite("Torrent profile: the Ultra fast limits")

    values = TorrentProfileById("ultrafast").values
    Harness_Equal(values.btMaxConnections, 400, "Ultra fast allows 400 connections")
    Harness_Equal(values.btHandshakeTimeout, 25000, "Ultra fast waits 25s for a handshake")
    Harness_Equal(values.btRequestTimeout, 6000, "Ultra fast waits 6s for a request")
    Harness_Equal(values.btDownloadSpeedSoftLimit, 8388608, "Ultra fast's soft limit is 8 MB/s")
    Harness_Equal(values.btDownloadSpeedHardLimit, 78643200, "Ultra fast's hard limit is 75 MB/s")
    Harness_Equal(values.btMinPeersForStable, 10, "Ultra fast wants 10 stable peers")
end sub

sub Test_TorrentProfile_EveryProfileCarriesTheSixKeys()
    Harness_Suite("Torrent profile: the shape of a profile")

    for each profile in TorrentProfiles()
        values = profile.values
        Harness_Ok(values <> invalid, profile.id + " carries its limits")
        for each key in ["btMaxConnections", "btHandshakeTimeout", "btRequestTimeout", "btDownloadSpeedSoftLimit", "btDownloadSpeedHardLimit", "btMinPeersForStable"]
            Harness_Ok(values.DoesExist(key), profile.id + " carries " + key)
        end for
    end for
end sub

sub Test_TorrentProfile_Cycle()
    Harness_Suite("Torrent profile: the cycle")

    Harness_Equal(TorrentProfileNext("default"), "soft", "Default advances to Soft")
    Harness_Equal(TorrentProfileNext("soft"), "fast", "Soft advances to Fast")
    Harness_Equal(TorrentProfileNext("fast"), "ultrafast", "Fast advances to Ultra fast")
    Harness_Equal(TorrentProfileNext("ultrafast"), "default", "Ultra fast wraps round to Default")

    ' Nothing to advance from: the server's limits match no profile, or the
    ' server could not be asked. Either way the cycle starts at the first
    ' profile, which is the way back to a known state.
    Harness_Equal(TorrentProfileNext("custom"), "default", "custom advances to Default")
    Harness_Equal(TorrentProfileNext("unknown"), "default", "unknown advances to Default")
    Harness_Equal(TorrentProfileNext(""), "default", "an empty id advances to Default")
end sub

sub Test_TorrentProfile_Match()
    Harness_Suite("Torrent profile: matching the server's limits")

    for each profile in TorrentProfiles()
        Harness_Equal(TorrentProfileMatch(profile.values), profile.id, profile.id + " is recognised from its own limits")
    end for

    ' A server configured by Stremio itself carries the same limits to within
    ' a fraction of a byte per second, and the two must still be one profile.
    soft = TorrentProfileById("soft").values
    fractional = {
        btMaxConnections: soft.btMaxConnections
        btHandshakeTimeout: soft.btHandshakeTimeout
        btRequestTimeout: soft.btRequestTimeout
        btDownloadSpeedSoftLimit: 1677721
        btDownloadSpeedHardLimit: 1677721
        btMinPeersForStable: soft.btMinPeersForStable
    }
    Harness_Equal(TorrentProfileMatch(fractional), "soft", "limits a byte per second apart are the same profile")

    ' Limits nobody here knows are "custom", not "unknown": the server
    ' answered, and what it answered is not a profile.
    custom = {
        btMaxConnections: 77
        btHandshakeTimeout: 12345
        btRequestTimeout: 1234
        btDownloadSpeedSoftLimit: 999999
        btDownloadSpeedHardLimit: 888888
        btMinPeersForStable: 7
    }
    Harness_Equal(TorrentProfileMatch(custom), "custom", "limits that match no profile are custom")

    ' A missing key is not a match: the server was never configured with
    ' these limits, so it is not running this profile.
    partial = { btMaxConnections: 55 }
    Harness_Equal(TorrentProfileMatch(partial), "custom", "limits that are only half there are custom")

    ' Nothing to read is nothing to match.
    Harness_Equal(TorrentProfileMatch(invalid), "", "no values match nothing")
end sub

sub Test_TorrentProfile_Labels()
    Harness_Suite("Torrent profile: names")

    Harness_Equal(TorrentProfileLabel("default"), "Default", "Default has a short name")
    Harness_Equal(TorrentProfileLabel("ultrafast"), "Ultra fast", "Ultra fast has a short name")
    Harness_Equal(TorrentProfileFullLabel("fast"), "Fast (Aggressive)", "Fast has a full name")
    Harness_Equal(TorrentProfileLabel("nonsense"), "", "an unknown profile has no name")
    Harness_Equal(TorrentProfileFullLabel("nonsense"), "", "and no full name either")
    Harness_Equal(TorrentProfileById("nonsense"), invalid, "and no profile")
end sub
