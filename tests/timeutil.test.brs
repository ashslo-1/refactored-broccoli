' TimeUtil unit tests.
'
' The date helpers are pure calendar logic over strings (NowIso is the only
' platform call, guarded and unused by anything that passes an explicit nowIso),
' so they run fully in the interpreter and cannot diverge from a device.

sub Test_TimeUtil_EpisodeAiredGates()
    Harness_Suite("EpisodeAired gates not-yet-aired episodes")
    time = TimeUtil()
    now = "2026-09-16T00:00:00.000Z"
    past = { released: "2026-08-05T08:00:00.000Z" }
    today = { released: "2026-09-16T08:00:00.000Z" }
    future = { released: "2026-09-30T08:00:00.000Z", name: "TBA " }
    Harness_Ok(time.EpisodeAired(past, now), "past episode aired")
    Harness_Ok(time.EpisodeAired(today, now), "today's episode aired")
    Harness_Ok(not time.EpisodeAired(future, now), "future episode not aired")
    Harness_Ok(not time.EpisodeAired({ firstAired: "2026-10-07T08:00:00.000Z" }, now), "firstAired fallback respected")
    Harness_Ok(time.EpisodeAired({}, now), "no date means aired")
    Harness_Ok(time.EpisodeAired({ released: "2026-08-05" }, now), "bare date aired")
    Harness_Ok(time.EpisodeAired({ released: "rubbish" }, now), "malformed date means aired")
    Harness_Ok(time.EpisodeAired(invalid, now), "invalid episode means aired")
    Harness_Ok(time.EpisodeAired({ released: "1960-01-01T00:00:00.000Z" }, ""), "past episode aired with no clock")
    Harness_Ok(not time.EpisodeAired({ released: "2100-01-01T00:00:00.000Z" }, invalid), "future episode still unaired with invalid clock")
end sub

sub Test_TimeUtil_IsCalendarDateShape()
    Harness_Suite("IsCalendarDate accepts well-formed dates only")
    time = TimeUtil()
    Harness_Ok(time.IsCalendarDate("2026-09-16"), "full YYYY-MM-DD accepted")
    Harness_Ok(not time.IsCalendarDate("2026-09"), "too short rejected")
    Harness_Ok(not time.IsCalendarDate("2026-9-16"), "non-padded month rejected")
    Harness_Ok(not time.IsCalendarDate("2026/09/16"), "non-dash separators rejected")
    Harness_Ok(not time.IsCalendarDate("abcdefghij"), "non-digit characters rejected")
    Harness_Ok(not time.IsCalendarDate(""), "empty rejected")
end sub

sub Test_TimeUtil_NowIsoShape()
    Harness_Suite("NowIso returns an ISO timestamp or empty when the clock is unavailable")
    time = TimeUtil()
    now = time.NowIso()
    Harness_Ok(Type(now) = "String", "NowIso returns a string")
    Harness_Ok(now = "" or now.Len() >= 20, "NowIso is an ISO timestamp or empty")
end sub

sub Test_TimeUtil_AirDatePartsReadsTheDate()
    Harness_Suite("AirDateParts reads released/firstAired and says whether the date is to come")
    time = TimeUtil()
    now = "2026-09-16T00:00:00.000Z"
    past = time.AirDateParts({ released: "2026-08-05" }, now)
    Harness_Equal(past.day, "5", "the day of the month")
    Harness_Equal(past.month, 8, "the month as a number")
    Harness_Equal(past.year, "2026", "the year")
    Harness_Equal(past.upcoming, false, "a past date is not upcoming")
    Harness_Equal(time.AirDateParts({ released: "2026-09-16T08:00:00.000Z" }, now).upcoming, false, "today is not upcoming")
    future = time.AirDateParts({ released: "2026-09-30T08:00:00.000Z" }, now)
    Harness_Equal(future.upcoming, true, "a future date is upcoming")
    Harness_Equal(future.day, "30", "the future day of the month")
    Harness_Equal(time.AirDateParts({ firstAired: "2026-10-07T08:00:00.000Z" }, now).upcoming, true, "firstAired fallback respected")
    Harness_Equal(time.AirDateParts({ released: "2026-01-02T00:00:00.000Z" }, now).month, 1, "leading months read")
    Harness_Equal(time.AirDateParts({ released: "2026-12-31T00:00:00.000Z" }, now).month, 12, "trailing months read")
end sub

sub Test_TimeUtil_AirDatePartsInvalidWhenNoDate()
    Harness_Suite("AirDateParts returns invalid for episodes without a usable date")
    time = TimeUtil()
    now = "2026-09-16T00:00:00.000Z"
    Harness_Equal(time.AirDateParts({}, now), invalid, "no date fields")
    Harness_Equal(time.AirDateParts(invalid, now), invalid, "invalid episode")
    Harness_Equal(time.AirDateParts({ released: "rubbish" }, now), invalid, "malformed date")
    Harness_Equal(time.AirDateParts({ released: "2026" }, now), invalid, "truncated date")
    Harness_Equal(time.AirDateParts({ released: "2026-13-01" }, now), invalid, "impossible month")
    Harness_Equal(time.AirDateParts({ released: "2026-04-32" }, now), invalid, "impossible day")
end sub

sub Test_TimeUtil_AirDatePartsDefaultsToPlatformClock()
    Harness_Suite("AirDateParts uses the store clock when no nowIso is given")
    time = TimeUtil()
    parts = time.AirDateParts({ released: "2026-08-05" })
    Harness_Ok(parts <> invalid, "the date still reads without an explicit now")
    Harness_Ok(parts.known = true or parts.known = false, "and the verdict is a plain yes or no")
    Harness_Ok(parts.upcoming = true or parts.upcoming = false, "and so is the date's own verdict")
end sub

' A date field that arrives as a NUMBER (a bare year is a common add-on shape)
' used to throw Type Mismatch on the `<> ""` comparison, out of whoever asked —
' EpisodesScreen's labels, the library's episode gating, the details hero. A
' number is not a calendar date this can compare, so it reads as "no usable
' date": aired, and no label line. Never a crash, and never a hidden episode.
sub Test_TimeUtil_NonTextDateFields()
    Harness_Suite("TimeUtil survives non-text date fields")
    time = TimeUtil()
    now = "2026-09-16T00:00:00.000Z"

    Harness_Ok(time.EpisodeAired({ released: 2026 }, now), "numeric released: aired, no crash")
    Harness_Ok(time.EpisodeAired({ firstAired: 2026 }, now), "numeric firstAired: aired, no crash")
    Harness_Ok(time.EpisodeAired({ released: [2026] }, now), "container released: aired, no crash")
    Harness_Ok(not time.EpisodeAired({ released: 2026, firstAired: "2026-10-07T08:00:00.000Z" }, now), "a numeric released still falls back to a usable firstAired")

    Harness_Equal(time.AirDateParts({ released: 2026 }, now), invalid, "numeric released: no date")
    Harness_Equal(time.AirDateParts({ firstAired: 2026 }, now), invalid, "numeric firstAired: no date")
    parts = time.AirDateParts({ released: 2026, firstAired: "2026-10-07" }, now)
    Harness_Equal(parts.month, 10, "a numeric released does not shadow a usable firstAired")
    Harness_Equal(parts.upcoming, true, "and the fallback date is still read as to come")
end sub