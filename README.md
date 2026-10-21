# Binge

Binge is an Android TV / Fire TV launcher for BingeBang and Rivestream. It
opens each configured link in a desktop-mode WebView and adds D-pad spatial
navigation, cursor mode, media controls, redirect protection, diagnostics and
safe loading fallbacks. The same interface supports touch devices, including
portrait phone layouts and touch editing of configured links.

## Build and test

From the repository root:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release
```

The APKs are copied to `dist\binge-debug.apk` and
`dist\binge-release.apk` by the delivery workflow. A locally built APK can
also be taken from `build\app\outputs\flutter-apk\`.

## Brand assets

Place the authoritative `icon.png` and 16:9 `banner.png` files in the project
root. Run `python tools\make_banner.py` before building Android resources. The
script preserves the supplied artwork without distortion and generates the
launcher density variants, adaptive foreground, and Fire TV banner resources.
The Android launcher may cache an installed icon or banner; uninstalling and
reinstalling is sometimes required to refresh cached launcher artwork.

## Sideload to Fire TV

1. On the TV open **Settings > My Fire TV > About** and select the device name
   seven times to enable Developer Options.
2. Enable **ADB debugging** and **Install unknown apps** for the installer.
3. Find the TV IP address and connect:

   ```powershell
   adb connect <ip>:5555
   adb install -r dist\binge-debug.apk
   ```

4. Launch **Binge** from the Android TV / Fire TV app launcher.

For a connected USB-debugging device, the repository includes a one-command
build, install, and launch script:

```powershell
.\tools\install-device.ps1
```

It automatically finds ADB using the project SDK configuration, checks for an
authorized device, builds the debug APK, installs it while preserving app data,
and launches Binge.

## XMRM-P5 remote map

| Remote key | Binge action |
| --- | --- |
| D-pad / OK | Move focus / activate |
| Back | Close overlay, WebView history, or return to sites |
| Menu | Edit selected site / open Quick Menu |
| Guide | Return to the site selector |
| Red | Toggle cursor mode |
| Blue | Reload the current page |
| Play/Pause | Toggle HTML5 playback |
| Rewind / Fast-forward | Seek |
| Channel +/- | Scroll the website |
| Info / Subtitle | Site navigation actions |
| 0-9 | Number shortcuts |

Home, Voice, Power and volume buttons are handled by Fire OS and are not
delivered to the application.

## Links, safe mode and diagnostics

On the selector, focus either site and press the remote **Menu** button to edit
that site's name and URL. A missing URL scheme is normalized to `https://`. The
Quick Menu remains available without JavaScript and contains reload, home, safe
loading, diagnostics, page width and ad-block controls.

The WebView is created immediately with safe defaults. If startup fails, the
selector falls back to the built-in links. A page that makes no progress for
12 seconds displays Retry, Safe mode, Edit link and Back to sites instead of
leaving a spinner on screen. Safe mode disables the document-start navigation
script and content blockers for troubleshooting.

Open **Quick Menu > Diagnostics** to inspect the WebView package, user agent,
viewport, last URL/error, blocked requests, key pipeline and recent logs.
**Copy report** writes `diagnostics.txt` under the app's external files
directory so it can be retrieved with:

```powershell
adb pull /sdcard/Android/data/com.binge.app/files/diagnostics.txt
```

See [docs/DEVICE_TEST.md](docs/DEVICE_TEST.md) for the physical Xiaomi TV
checklist and [docs/diagnosis.md](docs/diagnosis.md) for the startup-hang
analysis.

If near-black surfaces look lifted on the TV, first select Movie or Filmmaker
picture mode and disable dynamic contrast. Fire OS picture processing can
change perceived blacks independently of Flutter.
