# Engineering decisions

* Keep the WebView visible under a non-blocking progress indicator; never gate
  creation on optional package, preference or asset discovery.
* Treat redirects during the initial load as part of the requested site. A
  later gesture-free cross-site navigation is treated as an ad hijack.
* Use regular expressions for content blockers because that is the
  flutter_inappwebview contract; host-specific patterns avoid broad word
  matches.
* Prefer safe defaults over a silent failure. A user can retry, edit the URL,
  return to sites or enter safe mode from a themed error surface.
* Keep Android key interception opt-in. Flutter owns focus whenever an overlay
  or pushed route is visible.
* Treat a page as committed once meaningful progress is reported. Never cover
  a committed page with a timeout screen merely because ad requests prevent
  100% completion.
* Text editing is an explicit mode transition: a read-only focus row is
  traversable, while the IME-backed `TextField` exists only after OK.

## Colour check

The app's surfaces now use #050308, #0E0B14 and #17122A with hairline borders
instead of large purple glows. A real-TV screenshot comparison is still
required to determine whether any remaining lift is caused by Fire OS picture
mode or Flutter rendering. Use Movie/Filmmaker picture mode when checking true
black before changing renderer settings.
