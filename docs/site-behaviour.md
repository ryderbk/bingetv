# Site behaviour snapshot

Checked 2026-10-19 from a desktop HTTP reader:

* `https://bingebang.st/` responded with a normal HTML landing page titled
  “BingeBang - Watch Free Movies & TV Shows Online”. It exposed ordinary
  relative catalogue links and described multiple video servers, subtitles,
  downloads and optional accounts. No redirect or Cloudflare interstitial was
  observed in this fetch.
* `https://rivestream.ru/` responded successfully, but the returned content
  was abbreviated by the reader and did not provide enough detail to classify
  its player behavior.

This is not a substitute for the target Fire TV WebView test. The app keeps
normal desktop user-agent behavior and does not add anti-bot or ad-block
bypass techniques. Record final URLs, HTTP errors, long-lived requests and
player behavior in the physical-device checklist.
