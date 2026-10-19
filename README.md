# Binge

Binge is a minimal Android TV launcher for streaming websites. It opens each
configured site in a desktop-mode WebView and adds a TV-focused spatial
navigation layer for D-pad remotes.

## Build

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release
```

Debug and release APKs are copied to `dist/` by the delivery workflow. The
release build uses the generated debug signing key so it can be sideloaded
locally; configure a real release keystore before publishing.

## Sideload

```powershell
adb connect <tv-ip>:5555
adb install -r dist\app-release.apk
```

The app is registered with both the standard launcher and Android TV's
Leanback launcher. The TV banner and Binge icon are included in the Android
resources.

## Remote controls

- D-pad arrows: move between selector controls or spatially navigate a site.
- OK/Select/Enter: open a site, activate a focused web control, or focus a
  text field for the TV keyboard.
- Back: close the editor; in a WebView, go back in page history or return to
  the site selector; on the selector, exit the app.
- Menu/Context Menu or `M`: toggle cursor mode for canvas/custom players.
- Media Play/Pause: toggle the main HTML5 video.
- In focus mode, Left/Right seek a focused video by ten seconds.

## Editing links

Choose **Edit links** on the selector, change the name or URL, and choose
**Save**. URLs without a scheme are automatically prefixed with `https://`.
**Reset to defaults** removes the saved list and restores BingeBang and
Rivestream.

## Notes

The app requires network access. The injected navigation script is intentionally
generic because third-party sites can change their markup at any time. A TV
emulator or connected Android TV device is required for end-to-end remote and
video validation.
