' DashboardText unit tests — the clock, date and weather words the dashboard
' bar paints, pinned without a device clock or a network.

sub Test_Dashboard_ClockText()
    Harness_Suite("DashboardClockText formats 12- and 24-hour time")
    Harness_Equal(DashboardClockText(0, 5, false), "12:05 AM", "midnight is 12 AM")
    Harness_Equal(DashboardClockText(12, 0, false), "12:00 PM", "noon is 12 PM")
    Harness_Equal(DashboardClockText(19, 30, false), "7:30 PM", "evening drops to 12-hour")
    Harness_Equal(DashboardClockText(7, 9, true), "07:09", "24-hour pads both fields")
end sub

sub Test_Dashboard_DateText()
    Harness_Suite("DashboardDateText names the day and month")
    Harness_Equal(DashboardDateText(4, 10, 22), "Thursday, October 22", "weekday 4 is Thursday, month is 1-based")
    Harness_Equal(DashboardDateText(0, 1, 1), "Sunday, January 1", "first entries of both tables")
    Harness_Equal(DashboardDateText(7, 1, 1), "", "an out-of-range weekday paints nothing")
end sub

sub Test_Dashboard_WeatherText()
    Harness_Suite("DashboardWeatherText builds the weather line")
    forecast = {
        current: { temperature_2m: 71.6, weather_code: 2 }
        daily: { temperature_2m_max: [80.4], temperature_2m_min: [60.5] }
    }
    Harness_Equal(DashboardWeatherText(forecast, "Austin"), "Austin  72° Partly cloudy  H 80° L 61°", "full line with place, condition and range")
    Harness_Equal(DashboardWeatherText(forecast, ""), "72° Partly cloudy  H 80° L 61°", "no place leaves it out")
    Harness_Equal(DashboardWeatherText({ current: { temperature_2m: -3.6 } }, ""), "-4°", "negative temperatures round away from zero, missing parts are skipped")
    Harness_Equal(DashboardWeatherText({ current: { temperature_2m: "warm" } }, "X"), "", "a non-numeric temperature paints nothing")
    Harness_Equal(DashboardWeatherText(invalid, "X"), "", "no response paints nothing")
    Harness_Equal(DashboardWeatherLabel(95), "Thunderstorm", "thunderstorm code")
    Harness_Equal(DashboardWeatherLabel(4), "", "unknown code has no label")
end sub

sub Test_Dashboard_ForecastUrl()
    Harness_Suite("DashboardForecastUrl asks Open-Meteo for the right units")
    url = DashboardForecastUrl("30.27", "-97.74", false)
    Harness_Ok(url.InStr("latitude=30.27&longitude=-97.74") > 0, "coordinates are in the query")
    Harness_Ok(url.InStr("temperature_unit=fahrenheit") > 0, "Fahrenheit by default")
    Harness_Ok(DashboardForecastUrl("1", "2", true).InStr("temperature_unit=celsius") > 0, "Celsius on request")
end sub
