# Startup hang diagnosis

## Evidence from the original implementation

The selector rendered a centered spinner while `_loadDataAndCheckAutoOpen`
awaited three SharedPreferences calls without a timeout or error handler. Any
plugin failure left `_loading` true permanently.

The WebScreen had the same failure mode. Its `InAppWebView` was inside
`if (_initialUserScripts != null)`, but that value was assigned only after
`getCurrentWebViewPackage`, SharedPreferences, and `rootBundle.loadString`
completed. An exception therefore prevented the WebView from ever being
created. The only visible widget was the full-screen spinner.

The redirect callback also cancelled cross-registrable-domain navigations
without distinguishing the initial redirect chain, and invalid glob strings
such as `*doubleclick.net*` were passed as regular expressions.

## Fixes applied

* The selector uses built-in sites as an immediate fallback and cancels its
  three-second timeout when initialization completes or the route is disposed.
* The WebView is created immediately with an empty user-script list and safe
  settings. Detected settings are applied asynchronously.
* A top-edge progress bar is driven by `onProgressChanged`; `onLoadStop` is
  not the only way to hide loading.
* A watchdog replaces loading with the themed error/retry surface after 12
  seconds.
* Redirects are allowed during the initial chain and while the page is
  settling. Only later gesture-free cross-site top-level navigations are
  blocked.
* Blocklist entries are validated as Dart regular expressions and invalid
  entries are discarded before InAppWebView receives them.
* Native interception can be disabled while Flutter overlays and routes are
  active, and long-press state is tracked per key code.

## Runtime evidence still requiring a device

The repository does not contain an Android TV AVD snapshot or logcat capture,
so the exact Fire OS WebView package and hybrid/texture-composition result
must be recorded on the Xiaomi FX Pro. Use the checklist in
[DEVICE_TEST.md](DEVICE_TEST.md) and attach filtered logcat plus screenshots
to the release record.
