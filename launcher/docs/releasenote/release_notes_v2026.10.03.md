### 💖 Support Our Work

As an open-source, community-funded project, we operate on a very limited budget. If LTvLauncher helps you daily, please consider supporting us on [GitHub Sponsors](https://github.com/sponsors/LeanBitLab) or [Open Collective](https://opencollective.com/leanbitlab-org). Sharing LTvLauncher with friends and family makes a huge difference!

## 🚀 What's New in v2026.10.03

### 🎨 New Themes (Zero Resource Overhead)
- **Glow Theme**: Features a luminous ambient shadow halo in your active accent color with a radiant 3px accent outline.
- **Squircle Theme**: Delivers a modern 24px continuous superellipse curvature inspired by modern TV design systems.
- **Minimal Theme**: Features a crisp 4px micro-radius with subtle 1.05x zoom and a razor-thin 2px border for a compact, clean look.
- *Zero Resource Overhead*: Implemented entirely via Flutter geometry and layout primitives without adding any image assets, fonts, or dependencies to the APK.

### 🚑 Critical Fixes & Stability
- **Preserve Section Removals Across Restarts (#146)**:
  - Resolved the "phantom app return" issue where apps intentionally removed from sections were forcibly re-added upon TV restart by the orphaned app repair routine.
  - Newly installed apps continue to be automatically placed in default categories.
- **Native Android & Threading Hardening**:
  - Enforced Main Looper and UI thread dispatch across all native event stream handlers and telephony callbacks.
  - Clamped maximum icon decoding dimensions to 512x512 with `OutOfMemoryError` guards to preserve RAM on low-memory TV devices.
  - Fixed screensaver component reference to point to `com.leanbitlab.ltvL/.MainActivity`.
  - Cleared intent selectors on Continue Watching launches and validated URL launch schemes.
- **Dart Runtime & Null Safety**:
  - Added defensive numeric casting across `WatchNextProgram`, `WeatherData`, and `WeatherForecastItem` to prevent `TypeError` exceptions.
  - Added bounds checking for `CategorySort`, `CategoryType`, and `CellularNetworkType` enums during backup restoration and network events.
  - Added fallback protection for malformed accent color hex codes in settings.
  - Registered `PlatformDispatcher.instance.onError` for global async crash prevention.

### ✨ Enhancements & Refinements
- **Optional Category App Count**:
  - Added a toggle under Settings to display or hide the total app count next to category titles (defaults to off for a cleaner UI).
- **Unified Continue Watching Interactions**:
  - Aligned card zoom scales, edge bump feedback, and long-press actions with standard rows.
- **Offline Performance Polish**:
  - Completely eliminated dead background poster fetching from TV provider, relying purely on lightweight app icons and titles for instant loading.

## 📦 Downloads (Choose Your Architecture)

| File | Target Devices | Architecture |
|:---|:---|:---|
| **`LTvLauncher-universal-release.apk`** | All Android TV & Fire TV devices (Universal) | Universal |
| **`LTvLauncher-arm64-v8a-release.apk`** | Chromecast with Google TV, Nvidia Shield, modern 64-bit Android TVs | 64-bit ARM (`arm64-v8a`) |
| **`LTvLauncher-armeabi-v7a-release.apk`** | Fire TV Stick (Lite, 4K, 4K Max), older smart TVs | 32-bit ARM (`armeabi-v7a`) |
