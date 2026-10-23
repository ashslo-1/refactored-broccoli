' WeatherTask — fetch the dashboard's weather line off the UI thread.
'
' Two requests at most: an IP lookup for the TV's approximate location (only
' when no fixed latitude/longitude was configured), then the Open-Meteo
' forecast. Neither needs an API key. The result is the finished line of text,
' { ok, text, error }, so the bar does no parsing on the render thread.
sub init()
    m.top.functionName = "fetchWeather"
end sub

sub fetchWeather()
    try
        http = Transport()
        lat = m.top.latitude
        lon = m.top.longitude
        place = m.top.place
        if lat = "" or lon = ""
            located = http.Get("https://ipapi.co/json/")
            if not located.ok or located.json = invalid
                m.top.result = { ok: false, text: "", error: "location lookup failed: " + located.error }
                return
            end if
            lat = coordText(located.json.latitude)
            lon = coordText(located.json.longitude)
            if place = "" and located.json.city <> invalid then place = located.json.city
            if lat = "" or lon = ""
                m.top.result = { ok: false, text: "", error: "location lookup returned no coordinates" }
                return
            end if
        end if
        forecast = http.Get(DashboardForecastUrl(lat, lon, m.top.celsius))
        if not forecast.ok
            m.top.result = { ok: false, text: "", error: "forecast failed: " + forecast.error }
            return
        end if
        text = DashboardWeatherText(forecast.json, place)
        m.top.result = { ok: text <> "", text: text, error: "" }
    catch e
        m.top.result = { ok: false, text: "", error: e.message }
    end try
end sub

' A JSON coordinate as URL text. Str() pads positive numbers with a leading
' space, hence the Trim.
function coordText(value as dynamic) as string
    t = Type(value)
    if t = "String" or t = "roString" then return value
    if t = "Float" or t = "roFloat" or t = "Double" or t = "roDouble" or t = "Integer" or t = "roInteger"
        return Str(value).Trim()
    end if
    return ""
end function
