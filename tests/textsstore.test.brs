' TextsStore — the UI-language table's unit tests.
'
' The store is a pure lookup, so every fixture is a literal table: data in,
' one language slice out. The ReadAsciiFile half of the pipeline is a device
' loader (TextsData.brs) the interpreter never runs — the JSON a device pkg
' carries is not staged for `npm test` — so the loader's contract ("a missing
' or malformed file answers an empty English table") is pinned in the class
' tests below instead, by feeding the constructor what the loader would
' answer in those cases.

sub Test_TextsStore_LanguageSliceComesBackWhole()
    Harness_Suite("TextsStore.ForLanguage answers the language's own slice")
    store = TextsStore({
        en: { settings: { title: "Settings" }, common: { ok: "OK" } }
        es: { settings: { title: "Ajustes" }, common: { ok: "OK" } }
    })
    es = store.ForLanguage("es")
    Harness_Equal(es["settings"]["title"], "Ajustes", "a language's section map comes back untouched")
    Harness_Equal(es["common"]["ok"], "OK", "the slice carries every section, not just the first")
end sub

sub Test_TextsStore_UnknownLanguageFallsBackToEnglish()
    Harness_Suite("TextsStore.ForLanguage answers English for a table it does not carry")
    store = TextsStore({
        en: { settings: { title: "Settings" } }
        es: { settings: { title: "Ajustes" } }
    })
    fr = store.ForLanguage("fr")
    Harness_Equal(fr["settings"]["title"], "Settings", "an untranslated language paints English, not a blank")
end sub

sub Test_TextsStore_EmptyTableKeepsAnEnglishFloor()
    Harness_Suite("TextsStore keeps an English slice even when nothing usable arrives")
    ' What TextsLoadData answers when the JSON is missing (an empty AA) — the
    ' fallback language must exist or Lang() could only ever answer with keys.
    store = TextsStore({})
    en = store.ForLanguage("en")
    Harness_Ok(en <> invalid, "the English floor still answers")
    Harness_Ok(en.Count() = 0, "and it is an empty table the lookup guards walk")
end sub

sub Test_TextsStore_MalformedDataIsDropped()
    Harness_Suite("TextsStore drops slices that are not section maps")
    ' A malformed ParseJson answers invalid on device; a nested bad branch
    ' (a language whose "slice" is a string) is caught the same way here.
    store = TextsStore(invalid)
    en = store.ForLanguage("en")
    Harness_Ok(en <> invalid, "invalid data still builds the English floor")
    store = TextsStore({ en: { settings: { title: "Settings" } }, es: "not-a-table" })
    es = store.ForLanguage("es")
    Harness_Equal(es["settings"]["title"], "Settings", "a dropped slice falls through to English rather than a broken table")
end sub

' The lookup chain: the slices Lang() reads through m._texts / m._textsEn.
' Exercised here rather than through a component, where m would be a node —
' in the interpreter these subs share one function-m, so a test can plant the
' slices Lang() reads and check the fallback order end to end.
sub Test_TextsLang_FallsBackInOrder()
    Harness_Suite("Lang falls back display language -> English -> the key itself")
    en = { settings: { title: "Settings", rowLanguage: "Language" } }
    es = { settings: { title: "Ajustes" } }
    m._texts = es
    m._textsEn = en
    Harness_Equal(Lang("settings", "title"), "Ajustes", "the display language answers first")
    Harness_Equal(Lang("settings", "rowLanguage"), "Language", "a key the display language misses falls to English")
    Harness_Equal(Lang("settings", "absent"), "settings.absent", "a key nobody carries paints its own key, never blank")
    m._texts = invalid
    Harness_Equal(Lang("settings", "title"), "Settings", "a cleared display slice reads English alone")
    m._textsEn = invalid
    Harness_Equal(Lang("no", "table"), "no.table", "an unbound component degrades to the key")
    m._texts = "not-a-table"
    Harness_Equal(Lang("settings", "title"), "settings.title", "a malformed slice is a miss, not a crash")
end sub

' The refresh: the component pulls the display language's slice and the
' English floor out of the store host. The host here is the shape the screen
' sees — one node under every alias, answering over callFunc — so the test
' covers the hop the real one makes.
sub Test_TextsRefreshTexts_PullsBothSlices()
    Harness_Suite("RefreshTexts pulls the display language and the English floor")
    host = { callFunc: function(cmd as string, params = invalid as dynamic) as dynamic
        if cmd = "SettingsGetLanguage" then return "es"
        if cmd = "TextsFor" then
            if params = "es" then return { settings: { title: "Ajustes" } }
            return { settings: { title: "Settings" } }
        end if
        return invalid
    end function }
    m.stores = { settings: host, texts: host }
    RefreshTexts()
    Harness_Equal(Lang("settings", "title"), "Ajustes", "the display language's slice is what Lang reads")
    Harness_Equal(m._textsEn["settings"]["title"], "Settings", "the English floor is pulled alongside it")
    m.stores = invalid
    RefreshTexts()
    Harness_Equal(Lang("settings", "title"), "settings.title", "an unbound component falls to the key, not a crash")
end sub

sub Test_TextsLoadTexts_PullsThroughTheHost()
    Harness_Suite("LoadTexts pulls both slices through a store host")
    host = { callFunc: function(cmd as string, params = invalid as dynamic) as dynamic
        if cmd = "SettingsGetLanguage" then return "es"
        if cmd = "TextsFor" then
            if params = "es" then return { settings: { title: "Ajustes" } }
            return { settings: { title: "Settings" } }
        end if
        return invalid
    end function }
    LoadTexts(host)
    Harness_Equal(Lang("settings", "title"), "Ajustes", "the language the host reports is the one Lang reads")
    Harness_Equal(m._textsEn["settings"]["title"], "Settings", "the English floor came with it")
    LoadTexts(invalid)
    Harness_Equal(Lang("settings", "title"), "settings.title", "no host, no slices — the key, not a crash")
end sub

sub Test_TextsFill_SubstitutesEveryToken()
    Harness_Suite("Fill replaces {token}s, all occurrences, with StringOf coercion")
    Harness_Equal(Fill("Set cache size to {size}…", { size: "1 GB" }), "Set cache size to 1 GB…", "one token, one replacement")
    Harness_Equal(Fill("{subject}: <bold>{codecs}</bold>.", { subject: "This Roku reports", codecs: "AC-3, E-AC-3" }), "This Roku reports: <bold>AC-3, E-AC-3</bold>.", "the codec sentence reads as a sentence")
    Harness_Equal(Fill("a {x} b {x} c", { x: "1" }), "a 1 b 1 c", "every occurrence goes, not only the first")
    Harness_Equal(Fill("plain", { x: "1" }), "plain", "no tokens, no change")
    missing = invalid
    Harness_Equal(Fill("keep {x}.", missing), "keep {x}.", "no values, tokens stay visible")
    Harness_Equal(Fill("n {n} n", { n: 7 }), "n 7 n", "a number goes through StringOf, no type mismatch")
    Harness_Equal(Fill("", { x: "1" }), "", "an empty template is not an error")
end sub
