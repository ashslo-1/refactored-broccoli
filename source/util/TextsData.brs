' The device-side half of the UI-language table: TextsStore owns the lookups,
' this file owns the only ReadAsciiFile anywhere near them.
'
' It is here rather than inside TextsStore's constructor because the brs
' interpreter behind `npm test` stages only .bs/.brs sources, so the JSON is
' unreadable there — the store constructor takes the parsed table by value and
' stays deterministic for the tests, and the read lives in this device-only
' loader, called once at the StoreHost's init. A missing or malformed file
' answers an empty English table: Lang() then paints self-diagnosing "section.key"
' placeholders instead of blanking the UI.

' Parse pkg:/source/util/texts.json into the shape TextsStore takes.
function TextsLoadData() as object
    raw = ReadAsciiFile("pkg:/source/util/texts.json")
    data = invalid
    if raw <> "" then data = ParseJson(raw)
    if Type(data) <> "roAssociativeArray" then return {}
    return data
end function
