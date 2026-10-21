' addonsync tests — the store-side adoption and the wire format of the
' addonCollectionGet call the AddonSyncTask makes. The Task itself runs on a
' worker thread with its own Transport (like LinkStremioTask), so its HTTP
' call cannot be injected here; these tests pin the store adoption rules and
' the request/response shape the task depends on.
'
' Wire format (verified live + stremio-core): POST /api/addonCollectionGet
' with body carrying the type tag — {"type":"AddonCollectionGet","authKey":...,
' "update":true} — and every response envelope-wrapped:
' {"result":{"addons":[...],"lastModified":...}}.

function DescriptorFixture(id as string, name as string, transportUrl = "https://addon.example.com/manifest.json" as string) as object
    return {
        transportUrl: transportUrl
        manifest: {
            id: id
            name: name
            version: "2.1.0"
            types: ["movie", "series"]
            catalogs: [ { type: "movie", id: "top", name: "Top" } ]
            resources: [ "catalog", { name: "meta", types: ["movie"], idPrefixes: ["tt"] }, "stream" ]
        }
    }
end function

sub Test_AddonSync_InstallsDescriptorIntoRecord()
    Harness_Suite("InstallFromDescriptor builds and registers a record")
    addons = AddonsStore(ScriptedTransport([]), invalid, "stremio")
    desc = DescriptorFixture("com.test.addon", "Test Addon")
    outcome = addons.InstallFromDescriptor(desc.transportUrl, desc.manifest)
    Harness_Ok(outcome.ok, "install succeeds")
    Harness_Equal(outcome.id, "com.test.addon", "id set")
    addon = addons.Get("com.test.addon")
    Harness_Ok(addon <> invalid, "addon resolves after install")
    Harness_Equal(addon.name, "Test Addon", "name correct")
    Harness_Equal(addon.version, "2.1.0", "version correct")
    Harness_Equal(addon.address, "https://addon.example.com", "address stripped of /manifest.json")
    Harness_Equal(addon.builtin, false, "not marked builtin")
    Harness_Equal(addon.resources.Count(), 3, "resources normalized to three descriptors")
    Harness_Equal(addon.resources[0].name, "catalog", "short string resource keeps its name")
    Harness_Equal(addon.resources[0].short, true, "short string resource flagged as short")
    Harness_Equal(addon.resources[1].name, "meta", "object resource keeps its name")
    Harness_Equal(addon.resources[1].short, false, "object resource flagged as full")
    Harness_Equal(addon.resources[1].types[0], "movie", "object resource types preserved")
    Harness_Equal(addon.resources[1].idPrefixes[0], "tt", "object resource idPrefixes preserved")
    Harness_Equal(addon.resources[2].name, "stream", "third resource")
    Harness_Equal(addon.types.Count(), 2, "types preserved")
    Harness_Equal(addon.catalogs.Count(), 1, "catalogs preserved")
end sub

sub Test_AddonSync_PreservesQueryArgsInAddress()
    Harness_Suite("InstallFromDescriptor keeps query args in address")
    addons = AddonsStore(ScriptedTransport([]), invalid, "stremio")
    desc = DescriptorFixture("com.test.qa", "QA Addon", "https://addon.example.com/manifest.json?token=abc123")
    outcome = addons.InstallFromDescriptor(desc.transportUrl, desc.manifest)
    Harness_Ok(outcome.ok, "install succeeds")
    addon = addons.Get("com.test.qa")
    Harness_Ok(addon <> invalid, "addon resolves")
    Harness_Equal(addon.address, "https://addon.example.com?token=abc123", "query args preserved in address")
end sub

sub Test_AddonSync_DuplicateSkipped()
    Harness_Suite("InstallFromDescriptor skips a duplicate id")
    addons = AddonsStore(ScriptedTransport([]), invalid, "stremio")
    desc = DescriptorFixture("com.test.dup", "Dup Addon")
    first = addons.InstallFromDescriptor(desc.transportUrl, desc.manifest)
    Harness_Ok(first.ok, "first install succeeds")
    second = addons.InstallFromDescriptor(desc.transportUrl, desc.manifest)
    Harness_Ok(not second.ok, "second install fails")
    Harness_Equal(second.error, "addon already installed", "duplicate error message")
    Harness_Equal(addons.GetAll().Count(), 1, "only one addon registered")
end sub

sub Test_AddonSync_MissingManifestIdentity()
    Harness_Suite("InstallFromDescriptor rejects manifest missing id or name")
    addons = AddonsStore(ScriptedTransport([]), invalid, "stremio")

    missingId = addons.InstallFromDescriptor("https://addon.example.com/manifest.json", { name: "No Id", version: "1", types: [], catalogs: [], resources: [] })
    Harness_Ok(not missingId.ok, "missing id rejected")
    Harness_Equal(missingId.error, "manifest missing id or name", "correct error for missing id")

    missingName = addons.InstallFromDescriptor("https://addon.example.com/manifest.json", { id: "com.test.noname", version: "1", types: [], catalogs: [], resources: [] })
    Harness_Ok(not missingName.ok, "missing name rejected")
    Harness_Equal(missingName.error, "manifest missing id or name", "correct error for missing name")
end sub

sub Test_AddonSync_RejectsNonHttpTransport()
    Harness_Suite("InstallFromDescriptor rejects non-http(s) transports")
    addons = AddonsStore(ScriptedTransport([]), invalid, "stremio")
    outcome = addons.InstallFromDescriptor("stremio://some-host/addon/manifest.json", { id: "com.stremio.test", name: "Stremio Test", version: "1", types: [], catalogs: [], resources: [] })
    Harness_Ok(not outcome.ok, "stremio:// transport rejected")
    Harness_Equal(outcome.error, "unsupported addon transport", "error names the unsupported transport")
end sub

sub Test_AddonSync_NamelessCatalogGetsFallbackName()
    Harness_Suite("InstallFromDescriptor fills a missing catalog name")
    desc = DescriptorFixture("com.test.nameless", "Nameless Addon")
    desc.manifest.catalogs = [
        { type: "movie", id: "top" }
        { type: "series", id: "videos" }
    ]
    addons = AddonsStore(ScriptedTransport([]), invalid, "stremio")
    outcome = addons.InstallFromDescriptor(desc.transportUrl, desc.manifest)
    Harness_Ok(outcome.ok, "install succeeds")
    addon = addons.Get("com.test.nameless")
    Harness_Ok(addon <> invalid, "addon resolves")
    Harness_Equal(addon.catalogs[0].name, "Nameless Addon", "first catalog named from addon name")
    Harness_Equal(addon.catalogs[1].name, "Nameless Addon", "second catalog named from addon name")
    Harness_Equal(addon.catalogs[0].id, "top", "catalog id preserved")
    Harness_Equal(addon.catalogs[0].type, "movie", "catalog type preserved")
end sub

sub Test_AddonSync_CatalogNameFallsBackToId()
    Harness_Suite("NormalizeCatalogNames falls back to the catalog id when the addon name is blank")
    addons = AddonsStore(ScriptedTransport([]), invalid, "stremio")
    catalogs = addons.NormalizeCatalogNames([ { type: "movie", id: "publicdomainmovies" } ], "")
    Harness_Equal(catalogs[0].name, "publicdomainmovies", "catalog named from its id")
end sub

sub Test_AddonSync_NamedCatalogUnchanged()
    Harness_Suite("InstallFromDescriptor leaves present catalog names untouched")
    desc = DescriptorFixture("com.test.named", "Named Addon")
    addons = AddonsStore(ScriptedTransport([]), invalid, "stremio")
    outcome = addons.InstallFromDescriptor(desc.transportUrl, desc.manifest)
    Harness_Ok(outcome.ok, "install succeeds")
    addon = addons.Get("com.test.named")
    Harness_Ok(addon <> invalid, "addon resolves")
    Harness_Equal(addon.catalogs[0].name, "Top", "catalog keeps its own name")
    Harness_Equal(addon.catalogs[0].id, "top", "catalog id kept")
end sub

sub Test_AddonSync_ApiRequestCarriesTypeTag()
    Harness_Suite("addonCollectionGet POST carries the type tag and authKey")
    script = [
        {
            method: "POST"
            url: "https://api.strem.io/api/addonCollectionGet"
            ok: true
            status: 200
            json: { result: { addons: [], lastModified: 1750000000000 } }
        }
    ]
    http = ScriptedTransport(script)
    res = http.Post("https://api.strem.io/api/addonCollectionGet", { type: "AddonCollectionGet", authKey: "sk_test_key", update: true })
    Harness_Ok(res.ok, "request succeeds")
    Harness_Equal(http.log.Count(), 1, "one request logged")
    Harness_Equal(http.log[0].body.type, "AddonCollectionGet", "request carries the type tag")
    Harness_Equal(http.log[0].body.authKey, "sk_test_key", "request carries the authKey")
    Harness_Equal(http.log[0].body.update, true, "request sends update:true")
end sub

sub Test_AddonSync_DescriptorsParsedFromEnvelope()
    Harness_Suite("addonCollectionGet response descriptors are parsed correctly")
    script = [
        {
            method: "POST"
            url: "https://api.strem.io/api/addonCollectionGet"
            ok: true
            status: 200
            json: {
                result: {
                    addons: [
                        { transportUrl: "https://cinemeta.strem.io/manifest.json", manifest: { id: "com.linvo.cinemeta", name: "Cinemeta", version: "3.0.0", types: ["movie", "series"], catalogs: [ { type: "movie", id: "top", name: "Top" } ], resources: [ "catalog", "meta" ] } },
                        { transportUrl: "https://opensubtitles.strem.io/manifest.json", manifest: { id: "org.stremio.opensubtitles", name: "OpenSubtitles", version: "1.0.0", types: ["movie", "series"], catalogs: [], resources: [ "subtitles" ] } }
                    ]
                    lastModified: 1750000000000
                }
            }
        }
    ]
    http = ScriptedTransport(script)
    res = http.Post("https://api.strem.io/api/addonCollectionGet", { type: "AddonCollectionGet", authKey: "sk_abc", update: true })
    Harness_Ok(res.ok, "request succeeds")
    result = res.json.result
    Harness_Ok(result <> invalid, "result envelope present")
    Harness_Equal(result.addons.Count(), 2, "two addons in the collection")
    addons = AddonsStore(ScriptedTransport([]), invalid, "stremio")
    for each entry in result.addons
        addons.InstallFromDescriptor(entry.transportUrl, entry.manifest)
    end for
    Harness_Ok(addons.Get("com.linvo.cinemeta") <> invalid, "cinemeta registered from collection")
    Harness_Equal(addons.Get("com.linvo.cinemeta").address, "https://cinemeta.strem.io", "cinemeta address correct")
    Harness_Equal(addons.Get("com.linvo.cinemeta").version, "3.0.0", "cinemeta version from manifest")
    Harness_Ok(addons.Get("org.stremio.opensubtitles") <> invalid, "opensubtitles registered from collection")
    Harness_Equal(addons.Get("org.stremio.opensubtitles").resources.Count(), 1, "opensubtitles resources normalized")
    Harness_Equal(addons.GetAll().Count(), 2, "both addons in GetAll")
end sub

sub Test_AddonSync_ApiErrorEnvelope()
    Harness_Suite("addonCollectionGet error envelope yields empty descriptors")
    script = [
        {
            method: "POST"
            url: "https://api.strem.io/api/addonCollectionGet"
            ok: true
            status: 200
            json: { error: { code: 1, message: "Session does not exist" } }
        }
    ]
    http = ScriptedTransport(script)
    res = http.Post("https://api.strem.io/api/addonCollectionGet", { type: "AddonCollectionGet", authKey: "bad-key", update: true })
    Harness_Ok(res.ok, "HTTP request succeeds (error envelope)")
    Harness_Equal(res.json.result, invalid, "no result in error envelope")
    Harness_Equal(res.json.error.message, "Session does not exist", "error message surfaced")
end sub

sub Test_AddonSync_StremioSessionPersistsToRegistryKey()
    Harness_Suite("InstallFromDescriptor in stremio session writes to stremio_addons key")
    registry = MockRegistry()
    addons = AddonsStore(ScriptedTransport([]), registry, "stremio")
    desc = DescriptorFixture("com.test.persists", "Persist Addon")
    outcome = addons.InstallFromDescriptor(desc.transportUrl, desc.manifest)
    Harness_Ok(outcome.ok, "install succeeds")
    Harness_Equal(addons.GetAll().Count(), 1, "one addon present")
    rawStremio = registry.Read("stremio_addons")
    Harness_Ok(rawStremio <> "", "stremio_addons key written")
    parsed = ParseJson(rawStremio)
    Harness_Ok(parsed <> invalid and parsed["com.test.persists"] <> invalid, "record stored under stremio key")
    rawGuest = registry.Read("addons")
    Harness_Equal(rawGuest, "", "guest addons key untouched")
end sub

' A synced descriptor can be malformed too (it is external JSON, whatever its
' source), and this path stores what it validates: `transportUrl` is put through
' string methods and becomes the record's address, so a non-text one is refused
' rather than throwing, and a non-text manifest identity is refused rather than
' stored.
sub Test_AddonSync_RejectsNonTextDescriptor()
    Harness_Suite("InstallFromDescriptor refuses a descriptor whose identity or URL is not text")
    addons = AddonsStore(ScriptedTransport([]), invalid, "stremio")

    numericId = addons.InstallFromDescriptor("https://addon.example.com/manifest.json", { id: 1234, name: "Numeric", version: "1", types: [], catalogs: [], resources: [] })
    Harness_Ok(not numericId.ok, "numeric manifest id rejected")
    Harness_Equal(numericId.error, "manifest missing id or name", "error names the missing identity")

    numericName = addons.InstallFromDescriptor("https://addon.example.com/manifest.json", { id: "com.test.numeric", name: 1234, version: "1", types: [], catalogs: [], resources: [] })
    Harness_Ok(not numericName.ok, "numeric manifest name rejected")

    numericUrl = addons.InstallFromDescriptor(8.1, { id: "com.test.numeric", name: "Numeric", version: "1", types: [], catalogs: [], resources: [] })
    Harness_Ok(not numericUrl.ok, "numeric transport URL rejected")
    Harness_Equal(numericUrl.error, "no addon address", "error names the missing address")

    Harness_Equal(addons.GetAll().Count(), 0, "nothing installed in the stremio session")
end sub
' ---- the account mirror -------------------------------------------------------
'
' Every collection set REPLACES the account's whole addon list, so the mirror
' (the account's entries in the official wire shape, as the last pull handed
' them over) is the only thing that can legally be its payload. These tests
' pin the mirror's mutation rules and the refusal answers a partial store
' gives: put nothing on an unknown collection, ever — Local Files and other
' non-http transports die that way.

function MirrorCollection() as object
    return [
        { manifest: { id: "com.a", name: "A" }, transportUrl: "https://a.example.com/manifest.json", flags: { official: true, protected: false } }
        { manifest: { id: "org.b", name: "B" }, transportUrl: "https://b.example.com/manifest.json", flags: { official: false, protected: false } }
    ]
end function

sub Test_AddonSync_MirrorAdoptsRawCollection()
    Harness_Suite("SyncAccountCollection adopts the official entries verbatim and bumps the stamp")
    addons = AddonsStore(ScriptedTransport([]), invalid, "stremio")
    Harness_Ok(addons.AccountPutAddons() = invalid, "fresh store answers no put payload")
    before = addons.CurrentAccountStamp()
    raw = MirrorCollection()
    addons.SyncAccountCollection(raw)
    Harness_Equal(addons.CurrentAccountStamp(), before + 1, "adoption bumped the stamp")
    payload = addons.AccountPutAddons()
    Harness_Ok(payload <> invalid, "adopted store answers a put payload")
    Harness_Equal(payload.Count(), 2, "both entries carried")
    Harness_Equal(payload[0].flags.official, true, "flags survive verbatim")
    Harness_Equal(payload[0].manifest.id, "com.a", "manifests verbatim")
end sub

sub Test_AddonSync_MirrorUnknownRefusesEverything()
    Harness_Suite("A store that never synced answers unknown/invalid so callers push nothing")
    addons = AddonsStore(ScriptedTransport([]), invalid, "stremio")
    Harness_Ok(addons.AccountPutAddons() = invalid, "no put payload without a mirror")
    removed = addons.AccountRemoveAddon("com.a")
    Harness_Equal(removed.reason, "unknown", "removal refused on unknown mirror")
    added = addons.AccountAddAddon("https://a.example.com/manifest.json", { id: "com.a", name: "A" })
    Harness_Equal(added.reason, "unknown", "append refused on unknown mirror")
end sub

sub Test_AddonSync_RemoveFromMirrorRewritesPayload()
    Harness_Suite("AccountRemoveAddon drops one entry, bumps the stamp, and answers done")
    addons = AddonsStore(ScriptedTransport([]), invalid, "stremio")
    addons.SyncAccountCollection(MirrorCollection())
    before = addons.CurrentAccountStamp()
    outcome = addons.AccountRemoveAddon("org.b")
    Harness_Equal(outcome.reason, "done", "a known id is removed")
    Harness_Equal(outcome.addons.Count(), 1, "payload carries the rest")
    Harness_Equal(outcome.addons[0].manifest.id, "com.a", "surviving entry verbatim")
    Harness_Equal(outcome.addons[0].flags.official, true, "surviving entry's flags intact")
    Harness_Equal(addons.CurrentAccountStamp(), before + 1, "mutation bumped the stamp")

    again = addons.AccountRemoveAddon("org.b")
    Harness_Equal(again.reason, "absent", "the entry is already gone")
    Harness_Equal(addons.CurrentAccountStamp(), before + 1, "absent answered without a write")

    stranger = addons.AccountRemoveAddon("com.never.here")
    Harness_Equal(stranger.reason, "absent", "an id the account never had changes nothing")
end sub

sub Test_AddonSync_AddToMirrorAppendsDescriptor()
    Harness_Suite("AccountAddAddon appends a new descriptor and refuses what the account already carries")
    addons = AddonsStore(ScriptedTransport([]), invalid, "stremio")
    addons.SyncAccountCollection(MirrorCollection())
    before = addons.CurrentAccountStamp()
    outcome = addons.AccountAddAddon("https://c.example.com/manifest.json", { id: "io.c", name: "C" })
    Harness_Equal(outcome.reason, "done", "a new id is appended")
    Harness_Equal(outcome.addons.Count(), 3, "payload carries the account's entries plus the new one")
    Harness_Equal(outcome.addons[2].transportUrl, "https://c.example.com/manifest.json", "descriptor rides verbatim")
    Harness_Equal(outcome.addons[2].manifest.id, "io.c", "manifest rides verbatim")
    Harness_Equal(outcome.addons[2].flags.official, false, "locally added entries default to non-official flags")
    Harness_Equal(addons.CurrentAccountStamp(), before + 1, "mutation bumped the stamp")

    dupe = addons.AccountAddAddon("https://c.other/manifest.json", { id: "io.c", name: "C again" })
    Harness_Equal(dupe.reason, "absent", "the account already carries that id")

    naked = addons.AccountAddAddon("https://c.other/manifest.json", { name: "no id" })
    Harness_Equal(naked.reason, "absent", "an unusable manifest is refused without writing")

    numbered = addons.AccountAddAddon(8.1, { id: "io.m", name: "Bad url" })
    Harness_Equal(numbered.reason, "absent", "a non-text transport URL is refused without writing")
end sub

sub Test_AddonSync_PruneRemovesIdsAbsentOnAccount()
    Harness_Suite("PruneAddonsOutOfAccount removes installed non-built-ins the pull never mentioned")
    addons = AddonsStore(ScriptedTransport([]), invalid, "stremio")
    addons.InstallFromDescriptor("https://a.example.com/manifest.json", { id: "com.a", name: "A", version: "1", types: [], catalogs: [], resources: [] })
    addons.InstallFromDescriptor("https://b.example.com/manifest.json", { id: "org.b", name: "B", version: "1", types: [], catalogs: [], resources: [] })
    Harness_Equal(addons.GetAll().Count(), 2, "two records installed")
    count = addons.PruneAddonsOutOfAccount(["com.a"])
    Harness_Equal(count, 1, "one record pruned")
    Harness_Equal(addons.GetAll().Count(), 1, "the survivor stays")
    Harness_Ok(addons.Get("com.a") <> invalid, "the id the account keeps stays installed")
    Harness_Ok(addons.Get("org.b") = invalid, "the id the account never mentions is gone")
    Harness_Equal(addons.PruneAddonsOutOfAccount(["com.a"]), 0, "a second prune is a no-op")
end sub

sub Test_AddonSync_PruneNeverTouchesBuiltIns()
    Harness_Suite("PruneAddonsOutOfAccount spares built-ins no matter what the pull said")
    addons = AddonsStore(ScriptedTransport([]), MockRegistry(), "guest")
    outcome = addons.InstallFromDescriptor("https://cinemeta.example.com/manifest.json", { id: "com.linvo.cinemeta", name: "Cinemeta clone", version: "1", types: [], catalogs: [], resources: [] })
    Harness_Ok(outcome.ok, "builtin-id clone installed")
    count = addons.PruneAddonsOutOfAccount([])
    Harness_Equal(count, 0, "nothing pruned")
    Harness_Ok(addons.Get("com.linvo.cinemeta") <> invalid, "the clone-builtin record survives")
end sub

sub Test_AddonSync_PruneGuardsAgainstNonTextKeepIds()
    Harness_Suite("PruneAddonsOutOfAccount compares only text ids — no numeric-vs-string fallout")
    addons = AddonsStore(ScriptedTransport([]), invalid, "stremio")
    addons.InstallFromDescriptor("https://a.example.com/manifest.json", { id: "com.a", name: "A", version: "1", types: [], catalogs: [], resources: [] })
    count = addons.PruneAddonsOutOfAccount(["com.a", 4711, invalid])
    Harness_Equal(count, 0, "non-text keep ids answered nothing and pruned nothing")
end sub
