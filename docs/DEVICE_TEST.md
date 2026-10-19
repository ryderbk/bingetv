# Xiaomi FX Pro 4K device test

Target: Xiaomi FX Pro 4K 43", Fire OS 8.1.7.4, Android 11/API 30.

## Install

- [ ] Enable Developer Options, ADB debugging and Install unknown apps.
- [ ] `adb connect <ip>:5555`
- [ ] `adb install -r dist\binge-release.apk`
- [ ] Launch Binge from the TV launcher.

## First launch and sites

- [ ] Selector appears without an indefinite spinner.
- [ ] D-pad focuses both default cards and OK opens each site.
- [ ] Edit links saves a custom URL and survives restart.
- [ ] Initial redirects follow through to the final domain.
- [ ] A moved-domain banner offers Yes and No.
- [ ] Quick Menu works before JavaScript loads.
- [ ] Hanging/failed page shows the watchdog actions within 12 seconds.
- [ ] Safe mode loads the plain site.

## Remote key observations

Press each key on **Quick Menu > Remote Test** and fill in the result.

| Key | Expected action | Received | Notes |
| --- | --- | --- | --- |
| D-pad / OK | Focus and select | | |
| Back / Menu / Guide | Navigation | | |
| Play/Pause | Media | | |
| Rewind / Fast-forward | Seek | | |
| Channel +/- / Info / Subtitle | Site action | | |
| Red / Green / Yellow / Blue | Shortcuts | | |
| 0-9 | Number shortcuts | | |

## Playback and diagnostics

- [ ] Play a Widevine-protected title and confirm video/audio.
- [ ] Back exits HTML5 fullscreen before leaving the page.
- [ ] Pause/resume the app with Home and confirm lifecycle recovery.
- [ ] Open Diagnostics and verify WebView package, UA, URL, key pipeline and
  blocker counts.
- [ ] Confirm 100 random D-pad presses never lose the focus ring.
- [ ] Confirm moving across every editor row never opens the keyboard; OK does.
- [ ] Return from Remote Test and Diagnostics and confirm the WebView still
  responds to the remote.
- [ ] Compare Colour check swatches in Movie/Filmmaker picture mode.
- [ ] Re-test INFO, GUIDE and BACK explicitly.
- [ ] Select **Copy report**, then run:

  ```powershell
  adb pull /sdcard/Android/data/com.binge.app/files/diagnostics.txt
  ```

Capture screenshots with `adb exec-out screencap -p > screenshots\device.png`
and filtered logs with:

```powershell
adb logcat -v time -s flutter chromium cr_ InAppWebView BingeKeys AndroidRuntime
```
