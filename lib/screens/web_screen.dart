import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/site_store.dart';
import '../theme.dart';

class WebScreen extends StatefulWidget {
  const WebScreen({required this.site, super.key});
  final Site site;

  @override
  State<WebScreen> createState() => _WebScreenState();
}

class _WebScreenState extends State<WebScreen> {
  InAppWebViewController? _controller;
  bool _loading = true;
  String? _error;
  final _settings = InAppWebViewSettings(
    javaScriptEnabled: true,
    javaScriptCanOpenWindowsAutomatically: true,
    domStorageEnabled: true,
    useWideViewPort: true,
    loadWithOverviewMode: true,
    mediaPlaybackRequiresUserGesture: false,
    supportZoom: false,
    builtInZoomControls: false,
    displayZoomControls: false,
    thirdPartyCookiesEnabled: true,
    preferredContentMode: UserPreferredContentMode.DESKTOP,
    userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131.0.0.0 Safari/537.36',
    allowsInlineMediaPlayback: true,
    iframeAllowFullscreen: true,
  );

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _injectNavigation() async {
    final script = await rootBundle.loadString('assets/js/tv_nav.js');
    await _controller?.evaluateJavascript(source: script);
  }

  Future<bool> _handleBack() async {
    if (_controller == null) return true;
    if (await _controller!.canGoBack()) {
      await _controller!.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          if (await _handleBack() && context.mounted) Navigator.of(context).pop();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(widget.site.url)),
                initialSettings: _settings,
                onWebViewCreated: (controller) => _controller = controller,
                onLoadStart: (_, _) => setState(() { _loading = true; _error = null; }),
                onLoadStop: (_, _) async { await _injectNavigation(); if (mounted) setState(() => _loading = false); },
                onReceivedError: (_, _, error) => setState(() { _loading = false; _error = error.description; }),
                onReceivedHttpError: (_, _, errorResponse) {
                  if ((errorResponse.statusCode ?? 0) >= 500) setState(() { _loading = false; _error = 'The site returned an error (${errorResponse.statusCode}).'; });
                },
                shouldOverrideUrlLoading: (_, action) async {
                  final uri = action.request.url;
                  if (uri == null || !['http', 'https'].contains(uri.scheme)) return NavigationActionPolicy.CANCEL;
                  return NavigationActionPolicy.ALLOW;
                },
                onCreateWindow: (_, action) async {
                  final uri = action.request.url;
                  if (uri != null && ['http', 'https'].contains(uri.scheme)) await _controller?.loadUrl(urlRequest: URLRequest(url: uri));
                  return true;
                },
              ),
              if (_loading && _error == null) const Center(child: CircularProgressIndicator(color: bingeYellow)),
              if (_error != null)
                _ErrorOverlay(message: _error!, onRetry: () { setState(() => _error = null); _controller?.reload(); }, onBack: () => Navigator.of(context).pop()),
            ],
          ),
        ),
      );
}

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({required this.message, required this.onRetry, required this.onBack});
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Unable to load this site', style: TextStyle(color: bingeYellow, fontSize: 36, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(message, style: const TextStyle(fontSize: 22, color: Colors.white70)),
              const SizedBox(height: 28),
              Wrap(spacing: 16, children: [
                _ActionButton(label: 'Retry', onPressed: onRetry),
                _ActionButton(label: 'Back to sites', onPressed: onBack),
              ]),
            ],
          ),
        ),
      );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: bingeDeepPurple, foregroundColor: bingeYellow, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
        child: Text(label, style: const TextStyle(fontSize: 22)),
      );
}
