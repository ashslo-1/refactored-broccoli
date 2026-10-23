' AddonJson — the boundary normalizer's unit tests.
'
' Fixtures go through ParseJson(FormatJson({...})) rather than being handed over
' as literals: the normalizer's job is what a PARSED add-on payload looks like,
' and the round trip is what makes an identity like 4021 arrive as a JSON number
' instead of a BrightScript literal the interpreter already agrees with. (The
' reason is the same one helpers.test.brs parses its fixtures for — see also
' tests/deeplinkstore.test.brs, which builds hostile payloads with FormatJson.)
'
' What these assertions cannot show is the crash they exist to prevent:
' @rokucommunity/brs evaluates `8.1 = ""` to false where a device throws "Type
' Mismatch. Operator '=' can't be applied to 'roFloat' and 'String'". So the
' suite pins the ARRANGEMENT the device depends on — the field is text by the
' time a store reads it — and checkAddonJsonContract() in tests/run.js is the
' static half that catches a read the table has stopped covering.

sub Test_AddonJson_CoercesListedTextFields()
    Harness_Suite("AddonJson coerces the fields the app reads as text")
    meta = ParseJson(FormatJson({ id: "tt1", imdbRating: 8.1, runtime: 141, name: 4021 }))
    NormalizeAddonJson(meta)

    Harness_Equal(meta.imdbRating, "8.1", "a numeric rating becomes its text")
    Harness_Equal(meta.runtime, "141", "a numeric runtime becomes its text")
    Harness_Equal(meta.name, "4021", "a numeric name becomes its text")
    Harness_Equal(meta.id, "tt1", "a string is left alone")
end sub

sub Test_AddonJson_LeavesNumbersAlone()
    Harness_Suite("AddonJson leaves numeric fields as numbers")
    ' The opt-in half of the contract. season/episode reach EpisodesStore's season
    ' arithmetic and fileIdx reaches Int() in DirectFileIdx, so textifying them
    ' would break playback — the pass must not touch what it was not told to.
    payload = ParseJson(FormatJson({ videos: [{ season: 1, episode: 2, name: "Pilot" }] }))
    NormalizeAddonJson(payload)

    video = payload.videos[0]
    Harness_Equal(video.season, 1, "season stays a number")
    Harness_Equal(video.episode, 2, "episode stays a number")
    Harness_Equal(video.name, "Pilot", "the video name is text")
end sub

sub Test_AddonJson_LeavesUnlistedFieldsExactlyAsTheyCame()
    Harness_Suite("AddonJson passes an add-on's own keys through untouched")
    payload = ParseJson(FormatJson({ customScore: 8.1, customFlag: true, customList: [1, 2], customObj: { deep: 9 } }))
    NormalizeAddonJson(payload)

    Harness_Equal(payload.customScore, 8.1, "an unlisted number is not touched")
    Harness_Equal(payload.customFlag, true, "an unlisted boolean is not touched")
    Harness_Equal(payload.customList.Count(), 2, "an unlisted array keeps its shape")
    Harness_Equal(payload.customObj.deep, 9, "an unlisted object is not coerced")
end sub

sub Test_AddonJson_RecursesIntoContainers()
    Harness_Suite("AddonJson recurses into arrays and objects")
    payload = ParseJson(FormatJson({ catalogs: [{ type: "movie", name: 4021, genres: [8, "Action"] }] }))
    NormalizeAddonJson(payload)

    Harness_Equal(payload.catalogs[0].name, "4021", "a nested catalog name becomes text")
    Harness_Equal(payload.catalogs[0].genres[0], "8", "a nested genre element becomes text")
    Harness_Equal(payload.catalogs[0].genres[1], "Action", "a text genre element is left alone")
end sub

sub Test_AddonJson_WalksATopLevelArray()
    Harness_Suite("AddonJson normalizes a bare payload array of rows")
    ' CatalogStore.Catalog hands the metas ARRAY to the normalizer (its payload is
    ' the rows, not the envelope), so the entry point has to walk one.
    metas = ParseJson(FormatJson([{ id: "tt1", name: 4021 }, { id: "tt2", name: "Two" }]))
    NormalizeAddonJson(metas)

    Harness_Equal(metas[0].name, "4021", "the first row is normalized")
    Harness_Equal(metas[1].name, "Two", "the second row is left alone")
end sub

sub Test_AddonJson_KeepsAbsentFieldsAbsent()
    Harness_Suite("AddonJson does not invent values for absent fields")
    ' The stores ask "is there a value here" (NeedsMetaFetch's hero fields); an
    ' absent field has to keep answering no, so the pass must not write "" into it.
    meta = ParseJson(FormatJson({ id: "tt1" }))
    NormalizeAddonJson(meta)

    Harness_Ok(meta.description = invalid, "an absent field stays invalid")
    Harness_Ok(not meta.DoesExist("imdbRating"), "no key is added")
end sub

sub Test_AddonJson_LeavesContainersInTextSlotsAlone()
    Harness_Suite("AddonJson leaves a container where a text field is expected")
    ' ToStr on an object throws, so a container under a text field name is left for
    ' the reader's guard, not coerced here.
    meta = ParseJson(FormatJson({ name: { a: 1 } }))
    NormalizeAddonJson(meta)

    Harness_Ok(Type(meta.name) = "roAssociativeArray", "an object name stays an object")
end sub

sub Test_AddonJson_CoercesTextArrayElements()
    Harness_Suite("AddonJson coerces the elements of a listed text array")
    ' extraRequired is compared element-by-element to "skip" by HomeCatalogsTask's
    ' CatalogBrowsable, which has no HasText guard of its own — so a number in it
    ' is the same crash one level down and the element is what gets coerced.
    payload = ParseJson(FormatJson({ extraRequired: [7, "skip"], extraSupported: [9] }))
    NormalizeAddonJson(payload)

    Harness_Equal(payload.extraRequired[0], "7", "a numeric required extra becomes text")
    Harness_Equal(payload.extraRequired[1], "skip", "a text name is left alone")
    Harness_Equal(payload.extraSupported[0], "9", "a numeric supported extra becomes text")
end sub

sub Test_AddonJson_LeavesTypesAndIdPrefixesIntact()
    Harness_Suite("AddonJson does not coerce types/idPrefixes")
    ' These are read only through HasType and MatchesIdPrefixes, and skipping a
    ' non-text entry is what those are specified to do. Coercing the list would
    ' change what they answer (a declared 8 would match a wanted "8") with no raw
    ' read left to protect, so the table deliberately omits them.
    payload = ParseJson(FormatJson({ types: [8, "movie"], idPrefixes: [7, "tt"] }))
    NormalizeAddonJson(payload)

    Harness_Equal(payload.types[0], 8, "a numeric declared type stays a number")
    Harness_Equal(payload.idPrefixes[0], 7, "a numeric id prefix stays a number")
end sub

sub Test_AddonJson_IsIdempotent()
    Harness_Suite("AddonJson is safe to run twice")
    ' It runs at ingress and again over persisted records on Load(), so the second
    ' pass has to be a no-op on what the first produced.
    payload = ParseJson(FormatJson({ name: 4021, genres: [8, "Action"] }))
    NormalizeAddonJson(payload)
    NormalizeAddonJson(payload)

    Harness_Equal(payload.name, "4021", "the coerced name is unchanged by the second pass")
    Harness_Equal(payload.genres[0], "8", "the coerced genre is unchanged")
    Harness_Equal(payload.genres.Count(), 2, "no element is lost or added")
end sub

' The end-to-end shape of the bug this whole arrangement exists for: a meta whose
' imdbRating arrives as the JSON number 8.1, fetched exactly the way DetailsScreen
' fetches it. NeedsMetaFetch walks its hero fields and asks HasValue about each;
' before the boundary pass the imdbRating branch read the raw number, and the
' stores' own guard was the only thing standing between it and the device. The
' interpreter cannot reproduce the abort, so what is asserted is the arrangement
' the device depends on: the value is TEXT by the time the store's readers see it
' (so the loop answers on strings, whatever guard is in place), while the season
' beside it is still a number for the season arithmetic.
sub Test_AddonJson_MetaIngressCoercesTheCrashField()
    Harness_Suite("EpisodesStore.GetMeta normalizes the numeric-rating payload")
    address = "https://v3-cinemeta.strem.io"
    script = [
        {
            method: "GET"
            url: address + "/meta/series/tt1234567.json"
            ok: true
            status: 200
            json: {
                meta: {
                    id: "tt1234567"
                    type: "series"
                    name: "Test"
                    description: "A show"
                    releaseInfo: 2024
                    imdbRating: 8.1
                    background: "https://img.example.com/bg.jpg"
                    poster: "https://img.example.com/p.jpg"
                    videos: [{ id: "tt1234567:1:1", season: 1, episode: 1, name: "Pilot" }]
                }
            }
            error: ""
        }
    ]
    store = EpisodesStore(ScriptedTransport(script))
    result = store.GetMeta(address, "series", "tt1234567")

    Harness_Ok(result.ok, "the fetch succeeds")
    Harness_Equal(result.meta.imdbRating, "8.1", "the rating is text by the time the store reads it")
    Harness_Equal(result.meta.releaseInfo, "2024", "a numeric release year is text too")
    Harness_Ok(store.NeedsMetaFetch(result.meta) = false, "every hero field answers present, so the sparse-meta fetch is not triggered")
    Harness_Equal(result.meta.videos[0].season, 1, "the episode season is still a number")
end sub
