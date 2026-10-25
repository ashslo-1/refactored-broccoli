# TV dashboard

Custom home screens for Ashton's TVs.

| Folder | TV | What it is | Based on |
| --- | --- | --- | --- |
| `launcher/` | Sony (Google TV / Android TV) | A replacement home screen (launcher) installed over ADB | [LtvLauncher](https://github.com/leanbitlab-org/LtvLauncher), GPL-3.0 |
| `channel/` | TCL Roku TV | A dashboard and Stremio addon client sideloaded in Roku developer mode | [Rokumio](https://github.com/gpratoe/rokumio-client), MIT |
| `tools/` | TCL Roku TV | `deploy.sh` (build and sideload), `ecp.sh` (control the TV over the LAN) | |

Both upstream projects were imported with their history and keep their own
licenses (`launcher/LICENSE`, `channel/LICENSE`).

## Sony launcher

The launcher already has a clock, weather (Open-Meteo), HDMI input
switching, an OLED-safe screensaver and a Home-button fix for Google TV.

**Get the APK:** every push to `launcher/` runs the "Launcher APK" workflow.
Open the run in the Actions tab and download the `tv-dashboard-apk` artifact.

**Install it** from a computer on the same Wi-Fi:

1. On the TV: Settings > System > About, press OK on "Android TV OS build"
   seven times to unlock developer options, then turn on USB debugging (and
   Network debugging if listed) under Settings > System > Developer options.
2. `adb connect <tv-ip>` and accept the prompt on the TV.
3. `adb install app-release.apk`
4. Make it the home screen: Settings > Accessibility > Home Button Fix
   (Google TV) and turn on the TV Dashboard service, so Home opens it.

Stremio installs from the Play Store on the Sony; no custom client is needed.

**Develop:** Flutter 3.24.5. `cd launcher && flutter pub get && flutter test`.

## Roku channel

See `channel/README.md`. Build with `cd channel && npm install && npm run build`,
then sideload with `ROKU_IP=<tv-ip> ROKU_PASS=<dev-password> tools/deploy.sh`.
