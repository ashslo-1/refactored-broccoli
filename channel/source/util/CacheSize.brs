' CacheSize — the streaming server's cache size, from the sizes it offers.
'
' The server answers GET /settings with options: an array of option objects,
' one of them { id: "cacheSize", selections: [...] } — each selection carries
' the label the server displays and the value it accepts. The server's own
' unlimited choice is val: null (Infinity in its source, which JSON.stringify
' turns into null), and it round-trips: posting {"cacheSize":null} selects it.
'
' A choice is { value, label } where value invalid means the unlimited one.
' The current value read back from values.cacheSize is a number, or the
' UNLIMITED sentinel -1 for null. The sentinel is a number on purpose: on the
' device, "=" between a LongInteger and a string is a runtime type mismatch,
' so the sentinel has to be comparable with what the server reports.
'
' UNLIMITED is a size no server ever reports, a cache cannot be negative.

function CacheSizeChoices(options as object) as object
    choices = []
    opt = CacheSizeOptionFor(options)
    if opt = invalid then return choices
    if not opt.DoesExist("selections") then return choices
    selections = opt.selections
    if Type(selections) <> "roArray" then return choices
    for each sel in selections
        if Type(sel) = "roAssociativeArray" and sel.DoesExist("val")
            value = sel.val
            if value = invalid
                choices.Push({ value: invalid, label: CacheSizeSelLabel(sel, Chr(8734)) })
            else if CacheSizeIsNumber(value) and value >= 0
                choices.Push({ value: value, label: CacheSizeSelLabel(sel, CacheSizeBytesToLabel(value)) })
            end if
        end if
    end for
    return choices
end function

function CacheSizeOptionFor(options as object) as dynamic
    if options = invalid then return invalid
    if Type(options) = "roArray"
        for each opt in options
            if Type(opt) = "roAssociativeArray" and opt.DoesExist("id") and opt.id = "cacheSize"
                return opt
            end if
        end for
        return invalid
    end if
    if Type(options) = "roAssociativeArray" and options.DoesExist("cacheSize")
        opt = options.cacheSize
        if Type(opt) = "roAssociativeArray" then return opt
        if Type(opt) = "roArray" then return { selections: opt }
    end if
    return invalid
end function

function CacheSizeSelLabel(sel as object, fallback as string) as string
    if sel.DoesExist("name")
        name = sel.name
        if Type(name) = "String" or Type(name) = "roString"
            if name <> "" then return name
        end if
    end if
    return fallback
end function

function CacheSizeIsNumber(v as dynamic) as boolean
    if v = invalid then return false
    t = Type(v)
    return t = "Integer" or t = "LongInteger" or t = "Float" or t = "Double" or t = "roInt" or t = "roFloat" or t = "roDouble" or t = "roLongInteger"
end function

' Bytes to a readable size, for a selection that carries no name of its own.
function CacheSizeBytesToLabel(bytes as dynamic) as string
    if bytes = 0 then return "no caching"
    if bytes >= 1073741824
        label = (bytes / 1073741824.0).ToStr() + " GB"
    else if bytes >= 1048576
        label = (bytes / 1048576.0).ToStr() + " MB"
    else
        label = bytes.ToStr() + " B"
    end if
    return label
end function

' The index of the server's current value among the choices, -1 when it
' matches none — that is when the row says Custom (or Unknown, for absent).
' UNLIMITED (-1, the null size) matches the choice whose value is invalid.
function CacheSizeIndexForValue(choices as object, current as dynamic) as integer
    if choices = invalid or current = invalid then return -1
    if not CacheSizeIsNumber(current) then return -1
    for i = 0 to choices.Count() - 1
        value = choices[i].value
        if value = invalid
            if current < 0 then return i
        else if current >= 0
            if Abs(current - value) < 1 then return i
        end if
    end for
    return -1
end function

' The choice after this one, wrapping round; an index that is not in the list
' starts at the first choice.
function CacheSizeNextIndex(choices as object, currentIndex as integer) as integer
    if choices = invalid or choices.Count() = 0 then return -1
    if currentIndex < 0 or currentIndex >= choices.Count() then return 0
    return (currentIndex + 1) mod choices.Count()
end function

' The POST body for a choice: raw JSON text, because the unlimited choice is
' a JSON null and FormatJson drops invalid values out of an object, so an
' object body cannot carry it.
function CacheSizeBody(choice as object) as string
    if choice.value = invalid
        return "{" + Chr(34) + "cacheSize" + Chr(34) + ":null}"
    end if
    return "{" + Chr(34) + "cacheSize" + Chr(34) + ":" + choice.value.ToStr() + "}"
end function
