' AddonsWriteTask — push the account's whole add-on collection to Stremio.
'
' A single addonCollectionSet through StremioApiStore and nothing else — the
' request stremio-core itself makes on every add-on add or remove (the legacy
' addonCollectionPut endpoint answers an unverified {} and must not be used).
' The collection set REPLACES the account's list (the API has no per-add-on
' write or delete), so one serialized worker serves every write-back kind —
' the pipeline must never run two sets, or a slower earlier snapshot would
' land after a newer one and resurrect what the newer one deleted. The payload
' carries the account's own normalized entries (AddonsStore's mirror), never
' the device's interpreted list, which would delete account add-ons Roku
' cannot drive; the mirror lives in the store and this worker only carries the
' array it hands over. The wire format and envelope rules are the store's (and
' are unit-tested there).

sub init()
    m.top.functionName = "push"
end sub

sub push()
    try
        store = StremioApiStore(Transport(), m.top.authKey)
        payload = m.top.payload
        m.top.result = store.AddonCollectionSet(payload.addons)
    catch e
        m.top.result = { ok: false, error: e.message, revokedSession: false }
    end try
end sub
