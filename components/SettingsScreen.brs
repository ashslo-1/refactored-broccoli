' SettingsScreen — app preferences.
'
' The settings are grouped into SECTIONS: one chip per section along the top,
' the rows of the selected section in the list below. A flat list of
' everything the app can be told to do stops being readable as soon as it
' holds more than one topic, and the topics here are genuinely different — who
' you are signed in as, what language the app speaks, where the streaming
' server lives and whether it answers. Each topic gets its own chip and its
' own short list, so adding a setting is adding a row to a section, never
' renumbering a flat list that other rows depend on.
'
' SectionDefinitions() is the one place the screen's shape is decided. A row
' is {action, title, value}: the action is what OK does, the title is the
' label, the value is the right-hand column. The values come from the live
' stores when the rows are built, so the list shows what is persisted rather
' than what was persisted when the screen was opened.
'
' The rows are PrefRows backed by SettingsStore: streaming server address
' (edited through a system KeyboardDialog), UI language (cycled on OK), plus a
' Test-server row that hearts the configured streaming server so a playback
' dead-end is caught before pressing play. Every value is rebuilt on entry so
' the rows always reflect the persisted values.
'
' A hidden Network-diagnostics row sits behind NETDIAG_REVEAL_TAPS presses of
' the Test-server row. It is TEMPORARY: it exists to locate the intermittent
' outbound-connect failures (status -7) as DNS, radio, or concurrency, and it
' goes away — with NetDiagTask itself — once that is known.
'
' A second hidden row, Device codecs, comes up with the same gesture. It is
' likewise TEMPORARY (see DeviceCapTask.brs): it prints what this Roku reports
' through CanDecodeVideo/CanDecodeAudio, so the codec names the streaming server
' is asked to pass through can be checked against the device before any hint is
' sent. Both rows are diagnostics of the same kind and are revealed together.

' Five consecutive presses of the Test-server row reveal the hidden
' Network-diagnostics row. Test-server is the right host for the gesture: it is
' already the row about connectivity, so a diagnostic living one row below it
' reads as a continuation rather than as a stray debug affordance. The count is
' inlined at its one use because standard BrightScript has no file-scope const
' (that is a BrighterScript feature, and this is a .brs file).

sub init()
    m.title = m.top.FindNode("settingsTitle")
    m.sub = m.top.FindNode("settingsSub")
    m.status = m.top.FindNode("settingsStatus")
    m.chips = m.top.FindNode("settingsChips")
    m.list = m.top.FindNode("settingsList")

    t = Theme()
    m.title.color = t.accent
    m.sub.color = t.textSecondary
    m.status.color = t.accent
    m.chips.focusBitmapBlendColor = t.accentFocus
    m.list.focusBitmapBlendColor = t.accent

    m.list.ObserveField("rowItemSelected", "onRowSelected")
    m.chips.ObserveField("rowItemSelected", "onChipSelected")

    m.rows = []
    m.sections = []
    m.activeSection = 0
    m.selectedRow = -1
    m.languages = ["en", "es", "fr", "de", "it", "pt"]
    m.heartbeatTask = invalid
    ' Component fields outlive OnEnter, so once the diagnostics row is revealed it
    ' stays revealed for the rest of the session instead of vanishing every time
    ' the screen is left and re-entered.
    m.showNetDiag = false
    m.testServerTaps = 0
    m.netDiagTask = invalid
    m.showDeviceCap = false
    m.deviceCapTask = invalid
end sub

function OnEnter(params as object) as void
    CancelTestServer()
    CancelNetDiag()
    CancelDeviceCap()
    ' The sections are rebuilt on entry rather than kept: their rows carry the
    ' live values, and a section built when the screen was opened would show
    ' the state of that moment instead of the persisted one.
    RefreshSections()
    m.status.text = ""
    m.list.SetFocus(true)
end function

function OnExit() as void
    CancelTestServer()
    CancelNetDiag()
    CancelDeviceCap()
end function

function OnBackPressed() as boolean
    return false
end function

sub BlurFocus()
end sub

' The sections, in chip order. Each one is {id, label, rows} and each row is
' {action, title, value}. This is the one place the screen's shape is decided:
' a setting is a row here, and which section it belongs to is a statement
' about what the setting is about rather than about where it happens to sit
' in a list.
'
' The rows are built here rather than kept, because their values come from the
' live stores and change under the screen — a new server address, a
' different language, a session that signed in elsewhere. A section is
' therefore rebuilt on entry, not cached.
function SectionDefinitions() as object
    sections = []
    sections.Push({ id: "general", label: "General", rows: GeneralRows() })
    sections.Push({ id: "server", label: "Server", rows: ServerRows() })
    return sections
end function

' Rebuild the sections from the live stores and redraw the screen: the chips
' (whose names do not change, but whose selected one is marked on the
' content) and the list under them. Every change that touches a value goes
' through here, because a section HOLDS the values — not just the labels —
' so redrawing the rows alone would repaint the old ones.
sub RefreshSections()
    m.sections = SectionDefinitions()
    if m.activeSection >= m.sections.Count() then m.activeSection = 0
    BuildChips()
    BuildRows()
end sub

' The General section: the account and the app's language. The account is one
' row either way — what it does changes with the session, and a row that
' appears and disappears is worse to aim at than one that changes its label.
' It is first in the section because it is the handiest action: a guest is
' offered the Stremio login, a stremio user their email + logout.
function GeneralRows() as object
    rows = []
    if m.stores <> invalid and m.stores.auth.callFunc("AuthGetSession") = "stremio"
        rows.Push({
            action: "logout"
            title: "Log out"
            value: SessionValue()
        })
    else
        rows.Push({
            action: "login"
            title: "Log in with Stremio"
            value: "Sign in to sync addons and library"
        })
    end if
    rows.Push({
        action: "language"
        title: "Language"
        value: LanguageValue()
    })
    return rows
end function

' The Server section: where the streaming server is, and whether it answers.
' The two diagnostic rows are appended last and only once the gesture has
' revealed them, so they stay out of the way of the rows people use.
function ServerRows() as object
    rows = []
    rows.Push({
        action: "server"
        title: "Streaming server"
        value: ServerValue()
    })
    rows.Push({
        action: "testServer"
        title: "Test server"
        value: "Check streaming server"
    })
    if m.showNetDiag
        rows.Push({
            action: "netdiag"
            title: "Network diagnostics"
            value: "Probe LAN, plain HTTP and HTTPS with and without a CA bundle"
        })
    end if
    if m.showDeviceCap
        rows.Push({
            action: "devicecap"
            title: "Device codecs"
            value: "Report the codecs this Roku can decode"
        })
    end if
    return rows
end function

' The chip row: one chip per section, in the order the sections are defined.
' The selected chip is marked `active` on its content, and ChipTile paints
' that one in the accent — so the row above and the list below always agree
' about which section is on screen, even when the focus is somewhere else.
sub BuildChips()
    content = CreateObject("roSGNode", "ContentNode")
    row = content.CreateChild("ContentNode")
    for i = 0 to m.sections.Count() - 1
        section = m.sections[i]
        item = row.CreateChild("ChipContent")
        item.title = section.label
        item.width = m.chips.rowItemSize[0][0]
        item.height = m.chips.rowItemSize[0][1]
        item.active = (i = m.activeSection)
    end for
    m.chips.content = content
    m.chips.jumpToRowItem = [0, m.activeSection]
end sub

' The list under the chips: the rows of the selected section and nothing else.
' Rebuilt from the section every time, so the values on screen are the
' persisted ones.
sub BuildRows()
    m.rows = []
    if m.sections.Count() = 0 then
        m.sub.text = ""
        return
    end if
    section = m.sections[m.activeSection]
    for each row in section.rows
        m.rows.Push(row)
    end for

    content = CreateObject("roSGNode", "ContentNode")
    for each row in m.rows
        entry = content.CreateChild("ContentNode")
        item = entry.CreateChild("ContentNode")
        item.title = row.title
        item.description = row.value
    end for
    m.list.content = content
    ' Keep the cursor on the row the user is working on. The list used to jump
    ' back to the first row on every rebuild, which was invisible while the
    ' whole list fitted on the screen and obvious as soon as it did not: the
    ' language row is the second one, so cycling the language threw the
    ' cursor back onto the account row and the next press hit the wrong thing.
    target = 0
    if m.selectedRow >= 0 and m.selectedRow < m.rows.Count() then target = m.selectedRow
    m.list.jumpToRowItem = [0, target]
    UpdateSectionTitle()
end sub

' The subtitle names the section on screen and says what the keys do. It is
' rebuilt with the rows, because a screen whose subtitle says "General" while
' it shows the server rows is worse than no subtitle at all.
'
' It says OK twice on purpose: OK on a chip and OK on a row are different
' presses on different things, and the sentence that blurred them ("OK edits a
' row's value") is what a reader has to un-apply to the chip row.
sub UpdateSectionTitle()
    if m.sections.Count() = 0 then return
    m.sub.text = m.sections[m.activeSection].label + " · OK on a chip switches section, OK on a row edits it, Back returns to Home"
end sub

' OK on a chip: show that section's rows. The focus stays on the chips, so
' another section is one press away and the rows are one press down — the
' same travel Discover uses between its filter chips and its results.
sub onChipSelected()
    data = m.chips.rowItemSelected
    if data = invalid or data.Count() < 2 then return
    index = data[1]
    if index < 0 or index >= m.sections.Count() then return
    if index = m.activeSection then return
    m.activeSection = index
    ' A new section starts at its first row: the old index meant a different
    ' row over there, and keeping it would put the cursor on whatever happens
    ' to sit at that number in the new list.
    m.selectedRow = -1
    BuildChips()
    BuildRows()
end sub

' Focus travel between the sections and the rows under them. Up from the rows
' reaches the chips and Down from the chips comes back; the asterisk key is a
' one-press way up from anywhere in the list. Discover travels the same way
' between its filter chips and its results, and the same question applies to
' both: a screen that owns a secondary focus has to say where the focus is
' allowed to go, or the user is stuck in one of the two places.
function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "up" and m.list.HasFocus() then
        m.chips.SetFocus(true)
        return true
    else if key = "down" and m.chips.HasFocus() then
        m.list.SetFocus(true)
        return true
    else if key = "options" and m.list.HasFocus() then
        m.chips.SetFocus(true)
        return true
    end if
    return false
end function

' The signed-in-account label for the logout row. Prefer the profile email;
' fall back to a neutral label when the fetch that fills it is still running or
' the profile is otherwise absent.
function SessionValue() as string
    if m.stores <> invalid
        user = m.stores.auth.callFunc("AuthGetUser")
        if user <> invalid and user.email <> invalid and user.email <> "" then return user.email
    end if
    return "Signed in with Stremio"
end function

function ServerValue() as string
    if m.stores = invalid then return "—"
    address = m.stores.settings.callFunc("SettingsGetServerAddress")
    if address = "" then return "not set"
    return address
end function

function LanguageValue() as string
    if m.stores <> invalid then return m.stores.settings.callFunc("SettingsGetLanguage")
    return ""
end function

sub onRowSelected()
    data = m.list.rowItemSelected
    if data = invalid or data.Count() < 2 then return
    index = data[0]
    if index < 0 or index >= m.rows.Count() then return
    ' Remembered so a rebuild can put the cursor back on this row.
    m.selectedRow = index
    action = m.rows[index].action
    if action = "login"
        SignIn()
    else if action = "logout"
        SignOut()
    else if action = "server"
        EditServer()
    else if action = "language"
        CycleLanguage()
    else if action = "testServer"
        ' Counted here rather than inside TestServer so every press is counted,
        ' including the presses that TestServer itself declines to act on —
        ' a tap that gets rejected for a missing address is still a tap, and the
        ' gesture should not need the server to be configured to reach.
        m.testServerTaps = m.testServerTaps + 1
        if m.testServerTaps >= 5 and not m.showNetDiag
            m.showNetDiag = true
            m.showDeviceCap = true
            ' The diagnostics are rows of the Server section, and the section
            ' was built before the gesture revealed them — so the section is
            ' rebuilt, not just the list, or the new rows never appear.
            RefreshSections()
            m.status.text = "Diagnostics added below — press one to run."
        end if
        TestServer()
    else if action = "netdiag"
        RunNetDiag()
    else if action = "devicecap"
        RunDeviceCap()
    end if
end sub

' The session actions hand off to the Scene, the only place that owns auth.
' Publishing through pushRequest keeps this screen a pure reporter — the Scene
' runs the link-code flow or the logout confirm/teardown.
sub SignIn()
    m.top.pushRequest = { action: "login" }
end sub

sub SignOut()
    m.top.pushRequest = { action: "logout" }
end sub

' Open the streaming server editor. Empty input clears the address (clearing is
' a deliberate action); anything else is validated by SettingsStore.
sub EditServer()
    dialog = CreateObject("roSGNode", "StandardKeyboardDialog")
    ' A StandardDialog takes its colours from its own palette field and, with
    ' none set, from whatever is higher in the scene graph. Nothing in this app
    ' sets one — the Scene included — so without this the prompt comes up in
    ' Roku's default grey over a themed app. Same palette the exit and support
    ' dialogs already ask for.
    dialog.title = "Streaming server address"
    ' message is an ARRAY of strings on StandardKeyboardDialog. A bare string is
    ' a wrong-typed field set: discarded with a warning, leaving the prompt with
    ' no help text under the title and nothing on screen to explain why.
    dialog.message = ["e.g. http://192.168.1.5:4141 — leave empty and OK to clear"]
    dialog.text = ""
    if m.stores <> invalid then dialog.text = m.stores.settings.callFunc("SettingsGetServerAddress")
    dialog.buttons = ["OK", "Cancel"]
    dialog.observeField("buttonSelected", "onServerChoice")
    ' Caret after the address rather than at 0, so editing it does not start by
    ' arrowing past the whole value. Before the dialog is shown: the internal
    ' edit box is built at CreateObject time, so this is the earliest the setting
    ' can land. See ApplyServerKeyboard.
    ApplyServerKeyboard(dialog)
    m.top.getScene().dialog = dialog
end sub

' Configures the dialog's internal VoiceTextEditBox, which StandardKeyboardDialog
' builds for itself and which is therefore reached through the dialog rather than
' owned here. The box exists as soon as the node is created — confirmed on
' device — so this is called inline and needs nothing to wait for.
'
' No try, deliberately. A throw here prints the offending field and line to the
' device console, and the console is where this is read. The previous version
' swallowed the error, which is how a caret fix that never took became
' indistinguishable from one that did.
sub ApplyServerKeyboard(dialog as object) as void
    if dialog = invalid then return
    editor = dialog.textEditBox
    if editor = invalid then return

    ' Dictation mode, and the reason voice came out one letter at a time.
    ' DynamicKeyboard builds its internal edit box with voiceEntryType
    ' "alphanumeric" — letter-by-letter, meant for street addresses — which
    ' beats the node class default of "generic". The dialog's own
    ' keyboardDomain defaults to "generic" too but does not reach this field.
    ' "generic" is full word input, which is what a text prompt wants. First, so
    ' it lands even if the caret write below is the thing being rejected.
    editor.voiceEntryType = "generic"
    ' Caret after the text rather than at 0, so backspace and the left arrow have
    ' something to act on: a caret parked at 0 makes both of them no-ops by
    ' definition while typing still appends, which from the outside is
    ' indistinguishable from a dead keyboard.
    editor.cursorPosition = Len(dialog.text)
end sub

sub onServerChoice()
    dialog = m.top.getScene().dialog
    if dialog <> invalid
        index = dialog.buttonSelected
        chosen = dialog.text
        ' StandardDialog's own dismissal, and the one ConfirmExitDialog already
        ' uses: setting close makes the scene drop the node from the dialog slot
        ' by itself. Both values are read above before anything is torn down.
        dialog.close = true
        if index = 0
            if chosen = invalid or chosen.Trim() = ""
                m.stores.settings.callFunc("SettingsClearServerAddress")
                m.status.text = "Server address cleared."
            else if m.stores.settings.callFunc("SettingsSetServerAddress", chosen)
                m.status.text = "Server address updated."
            else
                m.status.text = "Invalid address — use http://host[:port]"
            end if
            ' Every branch above ends in a write, so the result is the same
            ' question on all of them: did the registry take it? Asked here
            ' rather than after each setter because the store saves itself now
            ' and there is no per-setter answer to check.
            if m.stores.settings.callFunc("SettingsSaveFailed") then m.status.text = m.status.text + " — not saved"
            ReportSaveFault()
            RefreshSections()
        end if
    end if
    m.list.SetFocus(true)
end sub

' Mirrors the store's last write result into the Scene's fault strip, clearing
' it on the next success. The status line says what just happened on this
' screen; the strip is what a refused write looks like from anywhere else in the
' app, including after the user has navigated away — which is the only place a
' setting that did not save can be noticed, since nothing about it is wrong
' until the next launch.
sub ReportSaveFault()
    if m.stores = invalid then return
    failed = m.stores.settings.callFunc("SettingsSaveFailed")
    scene = m.top.getScene()
    if scene <> invalid then scene.callFunc("ReportStoreFault", "settings could not be saved", failed)
end sub

' Cycle the language row's options forward.
sub CycleLanguage() as void
    current = m.stores.settings.callFunc("SettingsGetLanguage")
    index = 0
    for i = 0 to m.languages.Count() - 1
        if m.languages[i] = current then index = i
    end for
    nextLanguage = m.languages[(index + 1) mod m.languages.Count()]
    if m.stores.settings.callFunc("SettingsSetLanguage", nextLanguage)
        ReportSaveFault()
        RefreshSections()
    end if
end sub

' Report the streaming server's reachability through the status line. Verifying
' the address before trying to play a torrent stream turns a 90-second playback
' dead-end into a quick, obvious check. The heartbeat rides the default request
' timeout, so it runs through HeartbeatTask — a dead address costs the worker
' thread, not a frozen Settings screen.
sub TestServer() as void
    if m.stores = invalid then return
    address = m.stores.settings.callFunc("SettingsGetServerAddress")
    if address = ""
        m.status.text = "Set a streaming server address first."
        return
    end if
    if m.heartbeatTask <> invalid then return

    m.status.text = "Testing server…"
    task = AsyncTask_Launch(m.top, "HeartbeatTask", "onTestServerResult", { address: address }, "heartbeatTask")
    m.heartbeatTask = task
end sub

' The heartbeat finished. A stale result that landed after CancelTestServer is
' dropped by the m.heartbeatTask guard.
sub onTestServerResult()
    if m.heartbeatTask = invalid then return
    task = m.heartbeatTask
    m.heartbeatTask = invalid
    result = task.result
    AsyncTask_Reap(task, m.top, false)

    if result.alive
        m.status.text = "Server OK."
    else
        m.status.text = "Server unreachable: " + result.error
    end if
end sub

sub CancelTestServer()
    if m.heartbeatTask <> invalid
        task = m.heartbeatTask
        m.heartbeatTask = invalid
        AsyncTask_Reap(task, m.top, true)
    end if
end sub

' TEMPORARY. Launch the four-probe HTTPS diagnostic. The server address is read
' here and handed over rather than read inside the task, because the task is
' scoped to the component and SettingsStore is not — this is the same handoff
' HeartbeatTask's "address" field exists for.
sub RunNetDiag()
    if m.netDiagTask <> invalid then return
    address = ""
    if m.stores <> invalid then address = m.stores.settings.callFunc("SettingsGetServerAddress")

    m.status.text = "Running network diagnostics…"
    m.netDiagTask = AsyncTask_Launch(m.top, "NetDiagTask", "onNetDiagResult", { serverAddress: address }, "netDiagTask")
end sub

' Fires once per probe as well as once at the end, so the summary fills in
' progressively instead of appearing all at once. The done flag is what
' distinguishes the two: an alwaysNotify field with no value can notify before
' the worker has written anything, and reaping on that would pull the task out
' from under a run that is still going. An invalid result is the same case and is
' dropped for the same reason.
'
' Only the compact "A=200 B=301 C=-7 D=200" summary goes on screen. The verdict
' is a full sentence and settingsStatus is a single unfilled line, so the prose
' would be clipped; it is printed to the console instead, where the reader
' already is. C against D is readable from the summary either way.
sub onNetDiagResult()
    if m.netDiagTask = invalid then return
    task = m.netDiagTask
    result = task.result
    if result = invalid then return
    if result.done
        m.netDiagTask = invalid
        AsyncTask_Reap(task, m.top, false)
    end if
    m.status.text = result.summary
end sub

sub CancelNetDiag()
    if m.netDiagTask <> invalid
        task = m.netDiagTask
        m.netDiagTask = invalid
        ' Best effort. STOP and RemoveChild are synchronous on this thread while
        ' the worker checks the flag on its own, so it may or may not see this
        ' before the node goes away. It is worth setting because the flag is
        ' checked BETWEEN probes, and the alternative is a reaped node running
        ' three more five-second transfers against a screen nobody is watching.
        task.cancelRequested = true
        AsyncTask_Reap(task, m.top, true)
    end if
end sub

' TEMPORARY. Launch the device capability probe. Unlike NetDiag there is no
' per-device input to hand over — the task reads roDeviceInfo itself — so the
' launch carries no fields.
sub RunDeviceCap()
    if m.deviceCapTask <> invalid then return
    m.status.text = "Probing device codecs…"
    m.deviceCapTask = AsyncTask_Launch(m.top, "DeviceCapTask", "onDeviceCapResult", {}, "deviceCapTask")
end sub

' The same alwaysNotify / done dance as onNetDiagResult, for the same reason: an
' alwaysNotify field can notify before the worker has written anything, so an
' invalid result is dropped and only done = true reaps the task. The summary is a
' single unfilled line and would clip the per-codec detail, so only the compact
' list goes on screen; the raw replies stay on the console, where the reader is.
sub onDeviceCapResult()
    if m.deviceCapTask = invalid then return
    task = m.deviceCapTask
    result = task.result
    if result = invalid then return
    if result.done
        m.deviceCapTask = invalid
        AsyncTask_Reap(task, m.top, false)
    end if
    m.status.text = result.summary
end sub

sub CancelDeviceCap()
    if m.deviceCapTask <> invalid
        task = m.deviceCapTask
        m.deviceCapTask = invalid
        ' Best effort, as with CancelNetDiag: STOP does not reach a probe already
        ' in flight, but the flag is read between probes, so a cancelled run ends
        ' after the current one rather than finishing the whole sweep.
        task.cancelRequested = true
        AsyncTask_Reap(task, m.top, true)
    end if
end sub
