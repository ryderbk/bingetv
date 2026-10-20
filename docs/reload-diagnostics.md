# Binge reload and WebView diagnostics

## Confirmed cause addressed

The WebView scheduled a two-second automatic retry for every main-frame HTTP
5xx response. The retry guard was reset by `onLoadStop`, so callback ordering
could make a later failure eligible for another automatic retry. This could
produce repeated reloads against an already failing server.

The automatic retry path has been removed. Main-frame 5xx responses now show a
blocking recovery state with an explicit **Retry** action. Explicit reloads
from the Quick Menu and the Blue remote shortcut remain available.

## Additional stability changes

- Ad-block preference changes no longer force an automatic page reload.
- WebView creation, load start/stop, main-frame errors, HTTP errors, lifecycle
  transitions, and ad-block changes are recorded in a bounded 40-entry history.
- Diagnostics includes the recent history with timestamps, URLs, status codes,
  and event details.
- Existing redirects, cookies, media settings, touch support, and website
  navigation remain unchanged.

## Verification

- `flutter analyze`: passed
- `flutter test`: 31 tests passed
- Debug APK: built successfully
- Release APK: built successfully
- Connected device: `ZN5229TVTG`
- Device display reported by ADB: `720x1604`, density `260`
- Debug APK installed and `com.binge.app/.MainActivity` confirmed focused
- Device smoke screenshot: `../screenshots/binge-tv-smoke.png`

## Remaining external verification

The live BingeBang and Rivestream servers were not replaced with local test
fixtures in this pass, so server-specific desktop rendering, popup behavior,
video playback, and HTTP failure behavior still require an on-device browser
session against those live sites. The app now exposes the relevant navigation
events through Diagnostics for that check.
