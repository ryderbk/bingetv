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
