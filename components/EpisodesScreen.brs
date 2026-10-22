' EpisodesScreen — the season/episode browser behind Details' "Episodes".
'
' Same pattern as HomeScreen: a single RowList where each row is a season and
' each tile an episode (landscape EpisodeTile). Roku owns the whole grid physics
' — vertical row scrolling/clipping, horizontal per-row tile scrolling, row
' labels, focus reporting and non-focused-row dimming. The top header tracks the
' focused episode's label and synopsis; OK on a tile pushes stream selection.
'
' Season 0 is Stremio's "specials" bucket (behind-the-scenes extras, not a real
' season), so it is relabelled "Special" and pushed to the end of the list.
'
' Params: { addonAddress, meta, resume } — resume { season, episode } lands the
' list back on the watch-in-progress spot when given.

sub init()
    m.epName = m.top.FindNode("epName")
    m.bgPoster = m.top.FindNode("bgPoster")
    m.epHeaderLine = m.top.FindNode("epHeaderLine")
    m.epDesc = m.top.FindNode("epDesc")
    m.epList = m.top.FindNode("epList")

    t = Theme()
    m.top.FindNode("bgScrim").color = t.scrim
    m.epName.color = t.accent
    m.epDesc.color = t.textSecondary
    ' The header line is one MultiStyleLabel: the untagged episode label uses
    ' "default", the air date wraps in <aired> / <upcoming> for its own color.
    ' System fonts carry their own size, so styles differ by face and color.
    m.epHeaderLine.drawingStyles = {
        default: { fontUri: "font:MediumBoldSystemFont", color: t.accent }
        aired: { fontUri: "font:SmallSystemFont", color: t.accentWarm }
        upcoming: { fontUri: "font:SmallSystemFont", color: t.accentInfo }
    }
    m.epList.focusBitmapBlendColor = t.accentFocus
    m.epList.rowLabelOffset = [0,10]

    m.epList.ObserveField("rowItemFocused", "onItemFocused")
    m.epList.ObserveField("rowItemSelected", "onItemSelected")

    m.seasons = []
    m.seasonEpisodes = []
    ' The language the list was built in — a language change rebuilds it.
    m.textsLanguage = ""
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if key = "options" and press
        if m.epList <> invalid and m.epList.HasFocus()
            if ShowWatchDialog() then return true
        end if
    end if
    return false
end function

function OnEnter(params as object) as void
    ' The language first: the season rows and the episode labels are words, and
    ' a language changed since the last visit makes them wrong.
    RefreshTexts()
    if m.textsLanguage <> TextsLanguage()
        ' The list survives a visit (that is the point of the re-entry path
        ' below), but the words on it do not survive a language change — so the
        ' rows are rebuilt from the series already loaded, with no fetch.
        m.textsLanguage = TextsLanguage()
        if m.seriesMeta <> invalid and m.stores <> invalid then
            BuildList(m.seriesMeta)
            return
        end if
    end if
    ' Re-entry after a push (streams, player, …): params is invalid and the
    ' screen Group was handed focus by the stack. The episode RowList must take
    ' it back, or nothing inside is reachable — the list and its seasons survive,
    ' so no rebuild is needed.
    if params = invalid
        if m.epList <> invalid then m.epList.SetFocus(true)
        ' A pushed screen (streams, player) just popped back: the store's watched
        ' map may have moved while it had focus, so repaint the badge marks in
        ' place — the list nodes themselves survive the trip, no rebuild needed.
        RefreshWatchedMarks()
        return
    end if
    if params.meta = invalid then return
    m.addonAddress = params.addonAddress
    m.meta = params.meta
    m.resume = params.resume

    name = m.meta.name
    if name = invalid then name = ""
    m.epName.text = name

    bg = m.meta.background
    if bg = invalid then bg = ""
    m.bgPoster.uri = bg

    LoadSeries()
end function

' Begin a fresh season-list build: clear the old list, swap the header to a
' loading hint, and fetch the series meta off the UI thread. Re-entry with a new
' series supersedes whatever is still in flight (CancelLoad drops it first).
sub LoadSeries()
    if m.meta = invalid then return
    m.epList.content = CreateObject("roSGNode", "ContentNode")
    m.epList.numRows = 0
    m.seasons = []
    m.seasonEpisodes = []
    m.orderedVideoIds = []
    m.epHeaderLine.text = ""
    m.epDesc.text = Lang("episodes", "loading")

    CancelLoad()
    task = AsyncTask_Launch(m.top, "MetaLoaderTask", "onSeriesLoaded", {
        addonAddress: m.addonAddress
        metaType: "series"
        metaId: m.meta.id
    }, "episodesLoader")
    m.loadTask = task
end sub

' Tear down an in-flight season load (a newer entry supersedes it). STOP is the
' real cancel — merely removing a running Task node does not kill its worker
' thread — and dropping the observer means its result can never land; re-entering
' this screen builds the list afresh anyway.
sub CancelLoad()
    if m.loadTask <> invalid
        task = m.loadTask
        m.loadTask = invalid
        AsyncTask_Reap(task, m.top, true)
    end if
end sub

' The series meta came back. Failure leaves the header with a message and the
' list empty (Back pops); success lays out a row per season.
sub onSeriesLoaded()
    if m.loadTask = invalid then return
    task = m.loadTask
    m.loadTask = invalid
    result = task.result
    AsyncTask_Reap(task, m.top, false)

    if result = invalid or not result.ok or result.meta = invalid
        m.epHeaderLine.text = ""
        m.epDesc.text = Lang("episodes", "loadFailed")
        return
    end if
    m.seriesMeta = result.meta
    BuildList(result.meta)
end sub

' Lay out one RowList row per season from an already-fetched series meta. Each
' episode tile carries a checked badge when LibraryStore says it is watched; the
' full ordered episode-id list is resolved first so the account bitfield decodes
' against the complete list (bit indexes are positions in that ordering).
sub BuildList(meta as object)
    ' This build has two costs that need different answers: the store calls
    ' (the series meta -> ordered ids -> each season's episodes and marks), and
    ' the row/tile nodes plus labels. Gather everything first, then paint, so
    ' the two phases can be timed separately. The UI stays as it is: one row
    ' per season, all at once. This is instrumentation, not a new loading UX.
    '
    ' The clock is the store's ISO stamp — the only clock this codebase has on
    ' a device, and it has second resolution. The split is therefore coarse,
    ' but the total was 7 seconds; whole-second phases will tell us where that
    ' time goes.
    buildStarted = m.stores.time.callFunc("TimeNowIso")
    seriesData = m.stores.episodes.callFunc("EpisodesSeriesData", m.meta.id, meta)
    if seriesData = invalid or seriesData.seasons = invalid or seriesData.seasons.Count() = 0
        m.epHeaderLine.text = ""
        m.epDesc.text = Lang("episodes", "noneFound")
        return
    end if

    m.seasons = seriesData.seasons
    seasonRuns = seriesData.runs
    orderedEpisodes = seriesData.orderedVideoIds
    m.orderedVideoIds = orderedEpisodes
    nowIso = m.stores.time.callFunc("TimeNowIso")

    ' Phase 1: one grouping pass over the series meta, then one series-wide
    ' marks call. The old path sent the whole meta to EpisodesForSeason once
    ' per season, and the whole ordered-id list to LibraryEpisodeMarks once
    ' per season; both copies and the account-bitfield decode repeated 39
    ' times for The Simpsons. These two queries do that work once per series.
    m.seasonEpisodes = []
    for each seasonRun in seasonRuns
        m.seasonEpisodes.Push(seasonRun.episodes)
    end for
    seasonMarks = m.stores.library.callFunc("LibraryEpisodeMarksForSeries", m.meta.id, seasonRuns, orderedEpisodes, nowIso)
    gatherFinished = m.stores.time.callFunc("TimeNowIso")

    ' Phase 2: create the rows, tiles and visible labels from the gathered data.
    content = CreateObject("roSGNode", "ContentNode")
    anyRegular = false
    allDone = true
    for s = 0 to m.seasons.Count() - 1
        season = m.seasons[s]
        episodes = m.seasonEpisodes[s]
        marks = seasonMarks[s].marks
        row = content.CreateChild("ContentNode")
        row.title = SeasonLabel(season)
        for e = 0 to episodes.Count() - 1
            ep = episodes[e]
            item = row.CreateChild("TileContent")
            item.title = EpisodeLabel(season, ep)
            ' StringOf: thumbnails are add-on JSON too, and hdPosterUrl is a typed
            ' string field — a numeric thumbnail would throw on the compare first
            ' and on the assignment next.
            thumbnail = StringOf(ep.thumbnail)
            if thumbnail <> "" then item.hdPosterUrl = thumbnail
            if season <> 0
                mark = MarkAt(marks, e)
                item.watched = mark.watched
                item.aired = mark.aired
                if mark.aired
                    anyRegular = true
                    if not item.watched then allDone = false
                end if
            end if
        end for
    end for

    m.epList.content = content
    m.epList.numRows = m.seasons.Count()
    m.epList.jumpToRowItem = ResumePosition()
    if m.top.screenActive then m.epList.SetFocus(true)
    UpdateHeader(m.epList.jumpToRowItem)
    m.stores.library.callFunc("LibraryMarkAllIfDone", m.meta.id, anyRegular, allDone)

    buildFinished = m.stores.time.callFunc("TimeNowIso")
    print "[episodes] build seasons=" ; m.seasons.Count() ; " episodes=" ; EpisodeCount() ; " gather=" ; BuildElapsed(buildStarted, gatherFinished) ; " paint=" ; BuildElapsed(gatherFinished, buildFinished) ; " total=" ; BuildElapsed(buildStarted, buildFinished)
end sub

' How long one phase took, from two ISO clock readings. The platform's stamp
' has second resolution, so the honest answer is coarse — "under a second" or a
' number of seconds. The series counts say the scale of the work.
function BuildElapsed(started as string, finished as string) as string
    if started = "" or finished = "" then return "unknown (no clock)"
    if started = finished then return "under 1s"
    seconds = IsoSecondOfDay(finished) - IsoSecondOfDay(started)
    if seconds < 0 then seconds = seconds + 86400
    return seconds.ToStr() + "s"
end function

' Seconds since midnight in an ISO stamp ("2026-10-22T04:00:38Z").
' Use GLOBAL Mid, not the string method: the interpreter's method form counts
' from zero while the device's counts from one; this global agrees on both.
function IsoSecondOfDay(iso as string) as integer
    if Len(iso) < 20 then return 0
    hours = Mid(iso, 12, 2).ToInt()
    minutes = Mid(iso, 15, 2).ToInt()
    seconds = Mid(iso, 18, 2).ToInt()
    return hours * 3600 + minutes * 60 + seconds
end function

' How many episodes the build laid out — the number that says whether the
' work was big.
function EpisodeCount() as integer
    total = 0
    for each episodes in m.seasonEpisodes
        if episodes <> invalid then total = total + episodes.Count()
    end for
    return total
end function

' Re-paint the episode watched badges in place after a return from a push
' (streams, player): the existing row/tile nodes are kept, so focus and scroll
' survive, and each tile's watched flag is recomputed against the current store
' state. A no-op when nothing flipped; the series-complete check runs anew in
' case the last episode was just finished.
sub RefreshWatchedMarks() as void
    if m.epList = invalid or m.epList.content = invalid then return
    if m.seasons.Count() = 0 or m.seasonEpisodes.Count() = 0 then return
    if m.stores = invalid or m.seriesMeta = invalid then return
    orderedEpisodes = m.stores.episodes.callFunc("EpisodesOrderedVideoIds", m.meta.id, m.seriesMeta)
    anyRegular = false
    allDone = true
    nowIso = m.stores.time.callFunc("TimeNowIso")
    for s = 0 to m.seasons.Count() - 1
        season = m.seasons[s]
        row = m.epList.content.GetChild(s)
        episodes = m.seasonEpisodes[s]
        ' One call for the season, for the same reason as the build above.
        marks = []
        if season <> 0 then marks = m.stores.library.callFunc("LibraryEpisodeMarks", m.meta.id, season, episodes, orderedEpisodes, nowIso)
        for e = 0 to episodes.Count() - 1
            ep = episodes[e]
            item = row.GetChild(e)
            if season <> 0
                mark = MarkAt(marks, e)
                item.watched = mark.watched
                item.aired = mark.aired
                if mark.aired
                    anyRegular = true
                    if not item.watched then allDone = false
                end if
            end if
        end for
    end for
    m.stores.library.callFunc("LibraryMarkAllIfDone", m.meta.id, anyRegular, allDone)
end sub

' The mark for one episode of a run, or an empty one when the run did not
' answer for it. The run always answers (the store pushes one mark per
' episode), so a missing one is a store bug — and it must not take the screen
' down with it: this runs on the render thread, which is the worst place to
' crash.
function MarkAt(marks as object, index as integer) as object
    if marks = invalid then return { aired: false, watched: false }
    if index < 0 or index >= marks.Count() then return { aired: false, watched: false }
    mark = marks[index]
    if mark = invalid then return { aired: false, watched: false }
    return mark
end function

' The month name, in the display language. The names are a list in the table
' (a list is a thing the table can hold), and the store hands the month as a
' number — so the two meet here.
function MonthName(month as integer) as string
    months = LangList("common", "months")
    if months = invalid or month < 1 or month > months.Count() then return month.ToStr()
    return months[month - 1]
end function

function SeasonLabel(season as integer) as string
    if season = 0 then return Lang("episodes", "special")
    return Fill(Lang("episodes", "season"), { number: season.ToStr() })
end function

' "S#E#  name" for a tile — "Special E#  name" for season 0.
'
' ep.name is add-on data: an add-on that answers the episode name with a number
' makes the raw concatenation throw (the same Type Mismatch the detail header
' hit on imdbRating), so the name arrives coerced.
function EpisodeLabel(season as integer, ep as object) as string
    number = ""
    if ep.episode <> invalid then number = ep.episode.ToStr()
    if season = 0
        label = Fill(Lang("episodes", "specialEpisode"), { number: number })
    else
        label = Fill(Lang("common", "episodeMarker"), { season: season.ToStr(), episode: number })
    end if
    if ep.name <> invalid and StringOf(ep.name) <> "" then label = label + "  " + StringOf(ep.name)
    return label
end function

' [seasonRow, itemIndex] for the resume hint's (season, episode), else the first
' cell. Rows follow the store's OrderedSeasons order, so specials live at the end.
function ResumePosition() as object
    if m.resume <> invalid
        for s = 0 to m.seasons.Count() - 1
            if m.seasons[s] <> m.resume.season then continue for
            episodes = m.seasonEpisodes[s]
            for e = 0 to episodes.Count() - 1
                if episodes[e].episode = m.resume.episode then return [s, e]
            end for
            return [s, 0]
        end for
    end if
    return [0, 0]
end function

' rowItemFocused is a [row, itemIndex] pair; drive the header off the focused
' episode.
sub onItemFocused()
    data = m.epList.rowItemFocused
    if data = invalid or data.Count() < 2 then return
    UpdateHeader(data)
end sub

sub onItemSelected()
    data = m.epList.rowItemSelected
    if data = invalid or data.Count() < 2 then return
    entry = EntryAt(data[0], data[1])
    if entry = invalid then return
    PushEpisode(entry.season, entry.ep)
end sub

' The OPTIONS key on a focused regular (non-season-0) episode opens the
' watched-status dialog — season 0 specials are not part of the ordered/
' bitfield list, so they never offer it. Returns true when a dialog was shown.
' The "rest of season" actions are scoped to the focused season's row: they
' cover that season's episodes from its first up to (and including) the focused
' one, so a season can be caught up or reverted without touching any other
' season's marks.
function ShowWatchDialog() as boolean
    if m.meta = invalid or m.orderedVideoIds = invalid or m.orderedVideoIds.Count() = 0 then return false
    if m.stores = invalid then return false
    data = m.epList.rowItemFocused
    if data = invalid or data.Count() < 2 then return false
    row = data[0]
    entry = EntryAt(data[0], data[1])
    if entry = invalid or entry.season = 0 or entry.ep = invalid or entry.ep.episode = invalid then return false

    videoId = m.stores.episodes.callFunc("EpisodesResolveVideoId", m.meta.id, entry.season, entry.ep.episode)
    seasonIds = SeasonVideoIds(row)
    seasonIndex = IndexInIds(seasonIds, videoId)
    if seasonIndex < 0 then return false
    mark = m.stores.library.callFunc("LibraryEpisodeMark", m.meta.id, entry.season, entry.ep, m.orderedVideoIds, m.stores.time.callFunc("TimeNowIso"))

    m.pendingWatchAction = {
        metaId: m.meta.id
        videoId: videoId
        seasonIds: seasonIds
        seasonIndex: seasonIndex
        watched: mark.watched
    }

    stremio = m.stores.auth.callFunc("AuthGetSession") = "stremio"
    syncNote = Lang("episodes", "syncedToAccount")
    if not stremio then syncNote = Lang("episodes", "savedOnDevice")
    ' Both dialogs read alike: a QUESTION on top, and the episode it is about
    ' on the line below it, with the sync note under that. The episode used to
    ' ride in the watched title only — the unwatched one left it out, and the
    ' two titles then described the same action in two different shapes. The
    ' title is a question now (so it can be asked, and so a language can open
    ' it with its own question mark), and the episode is a line.
    episode = EpisodeLabel(entry.season, entry.ep)
    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    if mark.watched
        dialog.title = Lang("episodes", "markUnwatchedTitle")
        dialog.buttons = [Lang("episodes", "markUnwatchedButton"), Lang("episodes", "markSeasonUnwatchedButton"), Lang("common", "cancel")]
    else
        dialog.title = Lang("episodes", "markWatchedTitle")
        dialog.buttons = [Lang("episodes", "markWatchedButton"), Lang("episodes", "markSeasonWatchedButton"), Lang("common", "cancel")]
    end if
    dialog.message = [episode, syncNote]
    dialog.observeField("buttonSelected", "onWatchChoice")
    m.top.getScene().dialog = dialog
    return true
end function

' A dialog button landed. Reset the Scene's dialog slot, apply the chosen edit
' to the store (which publishes the account push and repaints the badges), then
' hand focus back to the list. An unwatched dialog's index = 0 is "mark this
' episode watched", index = 1 is "mark rest of this season watched"; a watched
' dialog's index = 0 is "mark as not watched", index = 1 is "mark rest of this
' season unwatched". Both rest-of-season actions revert their own counterpart.
sub onWatchChoice()
    dialog = m.top.getScene().dialog
    if dialog <> invalid
        index = dialog.buttonSelected
        if index = invalid then index = -1
        m.top.getScene().dialog = invalid
        action = m.pendingWatchAction
        m.pendingWatchAction = invalid
        if action <> invalid
            if action.watched
                if index = 0
                    ApplyWatchChange("unwatch", action)
                else if index = 1
                    ApplyWatchChange("restUnwatched", action)
                end if
            else
                if index = 0
                    ApplyWatchChange("watch", action)
                else if index = 1
                    ApplyWatchChange("restWatched", action)
                end if
            end if
        end if
    end if
    if m.epList <> invalid then m.epList.SetFocus(true)
end sub

' Apply a watched edit: mutate the store's local display layer, publish the
' change so MainScene can push it to the account, then repaint the tiles in
' place (which re-runs the series-complete check for the grid "done" badge).
' "restWatched"/"restUnwatched" operate on the focused season's video id list,
' from its first episode through the focused one.
sub ApplyWatchChange(kind as string, action as object)
    if m.stores = invalid then return
    if kind = "watch"
        m.stores.library.callFunc("LibraryMarkEpisodeWatched", action.metaId, action.videoId)
    else if kind = "restWatched"
        m.stores.library.callFunc("LibraryMarkUpToWatched", action.metaId, action.seasonIds, action.seasonIndex)
    else if kind = "restUnwatched"
        m.stores.library.callFunc("LibraryMarkUpToUnwatched", action.metaId, action.seasonIds, action.seasonIndex)
    else
        m.stores.library.callFunc("LibraryMarkEpisodeUnwatched", action.metaId, action.videoId)
    end if
    m.top.watchedChange = {
        metaId: action.metaId
        videoId: action.videoId
        orderedVideoIds: m.orderedVideoIds
        name: m.meta.name
        metaType: m.meta.type
        poster: m.meta.poster
        posterShape: m.meta.posterShape
    }
    RefreshWatchedMarks()
end sub

' The watchable video ids of one season row, in display order — the slice of the
' series' ordered list that row owns, so a season-scoped mark lands exactly on
' that season's non-special episodes.
function SeasonVideoIds(row as integer) as object
    ids = []
    if row < 0 or row >= m.seasons.Count() then return ids
    if m.stores = invalid then return ids
    episodes = m.seasonEpisodes[row]
    for each ep in episodes
        if ep <> invalid and ep.episode <> invalid
            ids.Push(m.stores.episodes.callFunc("EpisodesResolveVideoId", m.meta.id, m.seasons[row], ep.episode))
        end if
    end for
    return ids
end function

' The position of a video id in a list (-1 when absent).
function IndexInIds(ids as object, videoId as string) as integer
    if ids = invalid or videoId = "" then return -1
    for i = 0 to ids.Count() - 1
        if ids[i] = videoId then return i
    end for
    return -1
end function

function EntryAt(row as integer, index as integer) as object
    if m.seasons.Count() = 0 then return invalid
    if row < 0 or row >= m.seasons.Count() then return invalid
    episodes = m.seasonEpisodes[row]
    if episodes = invalid or index < 0 or index >= episodes.Count() then return invalid
    return { season: m.seasons[row], ep: episodes[index] }
end function

sub UpdateHeader(position as object)
    if position = invalid or position.Count() < 2 then return
    entry = EntryAt(position[0], position[1])
    if entry = invalid
        m.epHeaderLine.text = ""
        m.epDesc.text = ""
        return
    end if

    text = EpisodeLabel(entry.season, entry.ep)
    airDate = ""
    style = "aired"
    if m.stores <> invalid and entry.ep <> invalid then
        parts = m.stores.time.callFunc("TimeAirDateParts", entry.ep)
        if parts <> invalid then
            ' The store answers WHEN, the screen says it: the words are ours
            ' and the numbers are the store's, and the verdict (upcoming or
            ' aired) comes back as a fact — it used to be read back out of the
            ' English label, which no longer exists.
            dateText = Fill(Lang("common", "dateFormat"), {
                month: MonthName(parts.month)
                day: parts.day
                year: parts.year
            })
            if not parts.known
                airDate = dateText
            else if parts.upcoming
                airDate = Fill(Lang("common", "airDatePremieres"), { date: dateText })
                style = "upcoming"
            else
                airDate = Fill(Lang("common", "airDateAired"), { date: dateText })
            end if
        end if
    end if
    if airDate <> ""
        ' Not-yet-aired episodes flag their upcoming date via <upcoming> (sky
        ' blue); aired ones keep <aired> (warm gold). Tags are our own two style
        ' keys, never episode data.
        text = text + "<" + style + "> - " + airDate + "</" + style + ">"
    end if
    m.epHeaderLine.text = text

    overview = Lang("common", "noSynopsis")
    ep = entry.ep
    ' StringOf for the same reason as the header line above: an add-on overview
    ' can arrive as a number, and it is compared here and then put in a typed
    ' field.
    if ep <> invalid then
        epOverview = StringOf(ep.overview)
        if epOverview <> "" then overview = epOverview
    end if
    m.epDesc.text = overview
end sub

' Episodes push stream selection for "{metaId}:{season}:{episode}" — the same
' play path Details' resume chip uses.
sub PushEpisode(season as integer, ep as object)
    if ep = invalid or ep.episode = invalid then return
    videoId = m.stores.episodes.callFunc("EpisodesResolveVideoId", m.meta.id, season, ep.episode)
    position = 0
    if m.resume <> invalid and m.resume.episode <> invalid and m.resume.episode = ep.episode and m.resume.season <> invalid and m.resume.season = season
        position = m.resume.position
    end if
    m.top.pushRequest = {
        screen: "streamsScreen"
        params: {
            addonAddress: m.addonAddress
            metaType: "series"
            metaId: m.meta.id
            videoId: videoId
            season: season
            episode: ep.episode
            position: position
            name: m.meta.name
            poster: m.meta.poster
            posterShape: m.meta.posterShape
            logo: m.meta.logo
            background: m.meta.background
            episodeName: ep.name
            episodeOverview: ep.overview
        }
    }
end sub

function OnExit() as void
end function

function OnBackPressed() as boolean
    return false
end function

sub BlurFocus()
end sub
