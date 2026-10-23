' DashboardBar — the clock, date and weather block in the top right of Home.
'
' The clock is read from roDateTime in local time on every tick. The weather
' comes from a WeatherTask (network work never runs on the render thread) and
' is refreshed on its own slower timer. Both timers run only between StartBar
' and StopBar, which HomeScreen calls from OnEnter and OnExit.

sub init()
    m.clock = m.top.FindNode("clock")
    m.date = m.top.FindNode("date")
    m.weather = m.top.FindNode("weather")
    m.clockTick = m.top.FindNode("clockTick")
    m.weatherTick = m.top.FindNode("weatherTick")
    m.clockTick.ObserveField("fire", "onClockTick")
    m.weatherTick.ObserveField("fire", "onWeatherTick")

    t = Theme()
    m.clock.color = t.textPrimary
    m.date.color = t.textSecondary
    m.weather.color = t.accentInfo

    m.weatherTask = invalid
    m.weatherFetchedOnce = false
end sub

function StartBar() as void
    paintClock()
    m.clockTick.control = "start"
    m.weatherTick.control = "start"
    ' The first entry fetches right away; later entries wait for the timer, so
    ' hopping between screens does not hammer the forecast service.
    if not m.weatherFetchedOnce then fetchWeather()
end function

function StopBar() as void
    m.clockTick.control = "stop"
    m.weatherTick.control = "stop"
end function

sub onClockTick()
    paintClock()
end sub

sub onWeatherTick()
    fetchWeather()
end sub

sub paintClock()
    now = CreateObject("roDateTime")
    now.ToLocalTime()
    m.clock.text = DashboardClockText(now.GetHours(), now.GetMinutes(), false)
    m.date.text = DashboardDateText(now.GetDayOfWeek(), now.GetMonth(), now.GetDayOfMonth())
end sub

sub fetchWeather()
    if m.weatherTask <> invalid then return
    m.weatherFetchedOnce = true
    m.weatherTask = AsyncTask_Launch(m.top, "WeatherTask", "onWeather", invalid, invalid)
end sub

' A failed fetch keeps the last good line on screen: stale weather beats a
' blank, and the next tick tries again.
sub onWeather(event as object)
    if m.weatherTask = invalid then return
    result = event.GetData()
    ' An alwaysNotify field can fire before the worker has written anything;
    ' only a real result ends the task.
    if result = invalid then return
    task = m.weatherTask
    m.weatherTask = invalid
    AsyncTask_Reap(task, m.top, false)
    if result.ok = true
        m.weather.text = result.text
    else if result.error <> invalid
        print "[dashboard] weather: " + result.error
    end if
end sub
