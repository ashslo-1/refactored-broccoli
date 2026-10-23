' DashboardText — the words the dashboard bar paints: clock, date and the
' weather line. Pure string logic over plain numbers and parsed JSON, so the
' interpreter suite can pin every format without a device clock or a network.
' The bar and the weather task include this file directly; nothing here is
' reached across a component boundary.

' "7:05 PM" in 12-hour mode, "19:05" in 24-hour mode.
function DashboardClockText(hours as integer, minutes as integer, use24 as boolean) as string
    mm = minutes.ToStr()
    if minutes < 10 then mm = "0" + mm
    if use24
        hh = hours.ToStr()
        if hours < 10 then hh = "0" + hh
        return hh + ":" + mm
    end if
    suffix = "AM"
    if hours >= 12 then suffix = "PM"
    h12 = hours mod 12
    if h12 = 0 then h12 = 12
    return h12.ToStr() + ":" + mm + " " + suffix
end function

' "Thursday, October 22". weekday is roDateTime.GetDayOfWeek (0 = Sunday),
' month is 1-based like roDateTime.GetMonth.
function DashboardDateText(weekday as integer, month as integer, day as integer) as string
    days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    if weekday < 0 or weekday > 6 or month < 1 or month > 12 then return ""
    return days[weekday] + ", " + months[month - 1] + " " + day.ToStr()
end function

' Open-Meteo reports conditions as WMO weather codes; fold them into the few
' words that fit on one line of the bar.
function DashboardWeatherLabel(code as integer) as string
    if code = 0 then return "Clear"
    if code <= 2 then return "Partly cloudy"
    if code = 3 then return "Cloudy"
    if code = 45 or code = 48 then return "Fog"
    if code >= 51 and code <= 57 then return "Drizzle"
    if code >= 61 and code <= 67 then return "Rain"
    if code >= 71 and code <= 77 then return "Snow"
    if code >= 80 and code <= 82 then return "Showers"
    if code = 85 or code = 86 then return "Snow showers"
    if code >= 95 then return "Thunderstorm"
    return ""
end function

' The weather line from an Open-Meteo forecast response, e.g.
' "Austin  72° Partly cloudy  H 80° L 61°". Returns "" when the response does
' not carry a current temperature, so the bar shows nothing rather than a
' half-built line. place may be "" when the location came from settings.
function DashboardWeatherText(forecast as dynamic, place as string) as string
    if forecast = invalid or Type(forecast) <> "roAssociativeArray" then return ""
    current = forecast.current
    if current = invalid or Type(current) <> "roAssociativeArray" then return ""
    temp = DashboardRound(current.temperature_2m)
    if temp = invalid then return ""
    parts = []
    if place <> "" then parts.Push(place)
    now = temp.ToStr() + "°"
    code = DashboardRound(current.weather_code)
    if code <> invalid
        label = DashboardWeatherLabel(code)
        if label <> "" then now = now + " " + label
    end if
    parts.Push(now)
    daily = forecast.daily
    if daily <> invalid and Type(daily) = "roAssociativeArray"
        hi = DashboardFirstRounded(daily.temperature_2m_max)
        lo = DashboardFirstRounded(daily.temperature_2m_min)
        if hi <> invalid and lo <> invalid then parts.Push("H " + hi.ToStr() + "° L " + lo.ToStr() + "°")
    end if
    return parts.Join("  ")
end function

' A JSON number rounded to an integer, or invalid for anything that is not a
' number (an add-on-style string, a null, a missing field).
function DashboardRound(value as dynamic) as dynamic
    t = Type(value)
    if t = "Integer" or t = "roInteger" or t = "LongInteger" then return value
    if t = "Float" or t = "roFloat" or t = "Double" or t = "roDouble"
        if value >= 0 then return Int(value + 0.5)
        return -Int(-value + 0.5)
    end if
    return invalid
end function

function DashboardFirstRounded(values as dynamic) as dynamic
    if values = invalid or Type(values) <> "roArray" or values.Count() = 0 then return invalid
    return DashboardRound(values[0])
end function

' The Open-Meteo request for one location. Fahrenheit unless the caller asks
' for Celsius; timezone=auto makes the daily high/low follow the location's day.
function DashboardForecastUrl(latitude as string, longitude as string, celsius as boolean) as string
    unit = "fahrenheit"
    if celsius then unit = "celsius"
    return "https://api.open-meteo.com/v1/forecast?latitude=" + latitude + "&longitude=" + longitude + "&current=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min&temperature_unit=" + unit + "&timezone=auto&forecast_days=1"
end function
