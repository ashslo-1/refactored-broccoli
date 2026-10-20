' ServerSettingsTask — read or write the streaming server's own settings.
'
' The torrent profile is a property of the SERVER: it is a set of limits for
' the server's BitTorrent engine, and the server keeps them in its settings
' file. This task is the only way the screen touches them — it does the
' request on its own thread and hands the answer back, so a server that is
' not there costs the worker thread rather than a frozen Settings screen.
sub init()
    m.top.functionName = "handleSettings"
end sub

sub handleSettings()
    try
        http = Transport()
        store = ServerSettingsStore(http)
        if m.top.mode = "set"
            m.top.result = store.Set(m.top.address, m.top.values)
        else
            m.top.result = store.Get(m.top.address)
        end if
    catch e
        m.top.result = { ok: false, values: invalid, error: e.message }
    end try
end sub
