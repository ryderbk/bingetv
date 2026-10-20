# TV metrics

Live TV measurement is intentionally recorded only from ADB output; it must
not be inferred from the panel's advertised resolution.

## Current status

- Last known live TV connection: unavailable in the current session.
- Last known device from the previous connected session: `192.168.103.213`
- Previous ADB override: `1920x1080`
- Previous physical size: `3840x2160`
- Previous density: `320`

Run `.\tools\tv.ps1 metrics` after reconnecting the TV and update this file
with the reported manufacturer, model, physical size, override size, density,
and Flutter logical viewport.
