' Helpers — the cross-component value and format helpers.
'
' Charter: a function lives here only when more than one component needs it AND
' its meaning is identical in each. Same-named functions with different meanings
' do NOT belong here: TypeLabel is defined four times over (DetailsScreen says
' singular "Movie", LibraryScreen falls back to "All" as its chip filter,
' DiscoverScreen titlecases free-form types, HomeScreen is plural) and unifying
' those would silently rewrite UI wording. They stay where they are, and this
' file deliberately has no opinion about labels.
'
' Included per component like Theme.bs/TileSize.bs — Roku scopes global
' functions per component, so sharing happens through the script include, never
' by importing.

' Coerce any add-on-supplied value to something a string path can hold.
'
' Add-ons are not obliged to honour the Stremio meta spec's types, and the render
' paths used to assume they did: an imdbRating arriving as the JSON number 8.1
' made `kind + " · ★ " + meta.imdbRating` throw — the interpreter's words are
' "Type Mismatch. Operator '+' can't be applied to 'String' and 'Float'" — and
' the whole header line died with it. The same shape hides wherever an add-on
' value reaches a "+" (EpisodesScreen built an episode label), a string method
' (StreamsScreen called .Trim() on a stream name), or a typed node field.
'
' There is no single native cast for this, which is why the first fix was a
' Type() ladder enumerating "Integer"/"Float"/"String"/"Boolean". That ladder is
' not sound: Type() spells a parsed JSON value differently per runtime — the
' interpreter answers "Integer"/"Float"/"String", while values that arrived
' through ParseJson on a device report the "ro" spellings (the codebase already
' leans on the other spelling at StreamsScreen.brs's roString guard). A ladder
' written against one runtime silently drops the value on the other, which for
' a rating means it quietly disappears rather than crashing.
'
' The runtime's own ToStr() is the cast that does not care: every intrinsic
' implements it, a string comes back as itself, and its number formatting needs
' no padding trimmed (8.1 renders "8.1", 8.0 renders "8", 7 stays "7"). The two
' things it cannot answer are guarded around it:
'   - invalid: ToStr answers the literal "invalid" — never something a field
'     should show — so it returns "" first.
'   - the containers: an associative array has no ToStr value at all and throws.
'     An object where text belongs is not a text, so that is "" too.
function StringOf(value as dynamic) as string
    if value = invalid then return ""
    try
        return value.ToStr()
    catch e
        return ""
    end try
end function

' Runtime echoed straight from the meta JSON — Cinemeta ships plain minutes, so
' no parsing and no "2h 5m" conversion.
'
' This used to be duplicated byte-for-byte in DetailsScreen and StreamsScreen,
' each with a comment apologising for it ("Per-component function scope:
' duplicated from StreamsScreen, since Roku does not share globals across
' components"). An add-on shipping runtime as a string or a float is the same
' coercion as every other field, so it reduces to StringOf.
function FormatRuntime(runtime as dynamic) as string
    return StringOf(runtime).Trim()
end function
