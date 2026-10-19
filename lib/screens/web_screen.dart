import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/site_store.dart';
import '../theme.dart';
import '../widgets/quick_menu_overlay.dart';
import '../widgets/tv_focusable.dart';
import 'remote_test_screen.dart';

class WebScreen extends StatefulWidget {
  const WebScreen({required this.site, super.key});
  final Site site;

  @override
  State<WebScreen> createState() => _WebScreenState();
}

class _WebScreenState extends State<WebScreen> with WidgetsBindingObserver {
  static const _keyChannel = MethodChannel('com.binge.app/key_pipeline');
  final _store = SiteStore();

  InAppWebViewController? _controller;
  bool _loading = true;
  String? _error;
  bool _isOffline = false;
  bool _isQuickMenuOpen = false;
  bool _isCursorMode = false;
  late int _currentPageWidth;
  bool _adBlockEnabled = true;
  String? _pendingBlockedRedirect;
  String? _allowedRedirectUrlOnce;
  String _webViewVersion = 'Detecting...';
  String _customUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  List<ContentBlocker> _contentBlockers = [];
  UnmodifiableListView<UserScript>? _initialUserScripts;

  // Focus node to take focus away from WebView when overlays are shown
  final _overlayFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _currentPageWidth = widget.site.pageWidth;
    _setupNativeKeyPipeline();
    _initEngineAndSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keyChannel.invokeMethod('setWebScreenActive', {'active': false});
    _keyChannel.setMethodCallHandler(null);
    _overlayFocusNode.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // TV Home pressed or switched
      _controller?.evaluateJavascript(
        source: 'window.__bingeTv && window.__bingeTv.pauseMedia()',
      );
      _controller?.pause();
    } else if (state == AppLifecycleState.resumed) {
      _controller?.resume();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  Future<void> _setupNativeKeyPipeline() async {
    _keyChannel.setMethodCallHandler(_handleNativeKeyCall);
    await _keyChannel.invokeMethod('setWebScreenActive', {'active': true});
  }

  Future<void> _initEngineAndSettings() async {
    // 1. Detect real WebView package version
    try {
      final pkg = await InAppWebViewController.getCurrentWebViewPackage();
      if (pkg != null && pkg.versionName != null) {
        _webViewVersion = '${pkg.packageName} (${pkg.versionName})';
        final match = RegExp(r'^(\d+)').firstMatch(pkg.versionName!);
        final major = match != null ? match.group(1) : '120';
        _customUserAgent =
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$major.0.0.0 Safari/537.36';
      }
    } catch (_) {}

    // 2. Load Ad-Blocker preference & hosts
    _adBlockEnabled = await _store.isAdBlockEnabled();
    final blocklist = await _store.getBlocklist();
    _contentBlockers = blocklist.map((rule) {
      return ContentBlocker(
        trigger: ContentBlockerTrigger(urlFilter: rule),
        action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
      );
    }).toList();

    // 3. Load tv_nav.js and configure document-start user script
    final scriptContent = await rootBundle.loadString('assets/js/tv_nav.js');
    final injectedNavScript =
        '''
window.__bingePageWidth = $_currentPageWidth;
$scriptContent
''';

    _initialUserScripts = UnmodifiableListView([
      UserScript(
        source: injectedNavScript,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        forMainFrameOnly: false,
      ),
    ]);

    if (mounted) setState(() {});
  }

  Future<void> _handleNativeKeyCall(MethodCall call) async {
    if (call.method == 'onRemoteKey') {
      final map = Map<String, dynamic>.from(call.arguments as Map);
      final action = map['action'] as String? ?? '';
      final repeat = (map['repeat'] as num?)?.toInt() ?? 0;
      final isLongPress = map['isLongPress'] as bool? ?? false;

      _processRemoteAction(action, repeat, isLongPress);
    }
  }

  void _processRemoteAction(String action, int repeat, bool isLongPress) {
    // 1. Quick Menu key handler
    if (action == 'Menu') {
      setState(() {
        _isQuickMenuOpen = !_isQuickMenuOpen;
      });
      if (_isQuickMenuOpen) {
        _overlayFocusNode.requestFocus();
      }
      return;
    }

    if (_isQuickMenuOpen) {
      if (action == 'Back') {
        setState(() => _isQuickMenuOpen = false);
      }
      return;
    }

    // 2. Guide key -> return to selector
    if (action == 'Guide') {
      Navigator.of(context).pop();
      return;
    }

    // 3. Color Key shortcuts: Red = Cursor mode, Blue = Reload
    if (action == 'Red') {
      setState(() => _isCursorMode = !_isCursorMode);
      _controller?.evaluateJavascript(
        source:
            'window.__bingeTv && window.__bingeTv.setCursorMode($_isCursorMode)',
      );
      return;
    } else if (action == 'Blue') {
      _controller?.reload();
      return;
    }

    // 4. Overlays active (Error or Offline)
    if (_error != null || _isOffline) {
      if (action == 'Back') {
        Navigator.of(context).pop();
      }
      return;
    }

    // 5. Normal operation: forward key to WebView tv_nav engine
    if (action == 'Back') {
      _handleBackNavigation();
      return;
    }

    _controller?.evaluateJavascript(
      source:
          "window.__bingeTv && window.__bingeTv.key('$action', $repeat, $isLongPress)",
    );
  }

  Future<void> _handleBackNavigation() async {
    if (_controller == null) {
      Navigator.of(context).pop();
      return;
    }

    // Check if web page JS handles back (e.g. dismisses modal or exits fullscreen)
    final jsHandled = await _controller!.evaluateJavascript(
      source:
          'window.__bingeTv ? window.__bingeTv.key("Back", 0, false) : false',
    );
    if (jsHandled == true) return;

    // Check if browser can go back
    if (await _controller!.canGoBack()) {
      await _controller!.goBack();
      return;
    }

    // Return to site selector
    if (mounted) Navigator.of(context).pop();
  }

  String _getRegistrableDomain(String host) {
    final parts = host.toLowerCase().split('.');
    if (parts.length <= 2) return host.toLowerCase();
    if (parts.length >= 3 &&
        [
          'co',
          'com',
          'org',
          'net',
          'edu',
          'gov',
        ].contains(parts[parts.length - 2])) {
      return parts.sublist(parts.length - 3).join('.');
    }
    return parts.sublist(parts.length - 2).join('.');
  }

  bool _isSameRegistrableDomain(Uri a, Uri b) {
    if (a.host.isEmpty || b.host.isEmpty) return false;
    return _getRegistrableDomain(a.host) == _getRegistrableDomain(b.host);
  }

  @override
  Widget build(BuildContext context) {
    final settings = InAppWebViewSettings(
      javaScriptEnabled: true,
      javaScriptCanOpenWindowsAutomatically: false,
      domStorageEnabled: true,
      databaseEnabled: true,
      useWideViewPort: true,
      loadWithOverviewMode: true,
      mediaPlaybackRequiresUserGesture: false,
      supportZoom: false,
      builtInZoomControls: false,
      displayZoomControls: false,
      thirdPartyCookiesEnabled: true,
      preferredContentMode: UserPreferredContentMode.DESKTOP,
      userAgent: _customUserAgent,
      allowsInlineMediaPlayback: true,
      iframeAllowFullscreen: true,
      cacheMode: CacheMode.LOAD_DEFAULT,
      safeBrowsingEnabled: false,
      allowFileAccess: false,
      hardwareAcceleration: true,
      contentBlockers: _adBlockEnabled ? _contentBlockers : [],
      transparentBackground: false,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Black backing layer to prevent any white flash
            const Positioned.fill(child: ColoredBox(color: Colors.black)),

            // WebView
            if (_initialUserScripts != null)
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(widget.site.url)),
                initialSettings: settings,
                initialUserScripts: _initialUserScripts,
                onWebViewCreated: (controller) {
                  _controller = controller;
                  _store.setLastOpenedSite(widget.site.url);
                },
                onLoadStart: (_, uri) {
                  setState(() {
                    _loading = true;
                    _error = null;
                    _isOffline = false;
                  });
                },
                onLoadStop: (controller, uri) async {
                  // Fallback injection for frames and dynamic resets
                  final script = await rootBundle.loadString(
                    'assets/js/tv_nav.js',
                  );
                  await controller.evaluateJavascript(
                    source:
                        '''
if (!window.__bingeTv || !window.__bingeTv.initialized) {
  window.__bingePageWidth = $_currentPageWidth;
  $script
}
''',
                  );
                  if (mounted) setState(() => _loading = false);
                },
                onReceivedError: (_, request, error) {
                  // Defect 3: Only main frame errors show the error overlay!
                  if (request.isForMainFrame ?? false) {
                    setState(() {
                      _loading = false;
                      _error = error.description;
                      _isOffline =
                          error.type ==
                              WebResourceErrorType.CANNOT_CONNECT_TO_HOST ||
                          error.type == WebResourceErrorType.HOST_LOOKUP;
                    });
                    _overlayFocusNode.requestFocus();
                  }
                },
                onReceivedHttpError: (_, request, errorResponse) {
                  // Defect 3: Ignore 4xx/5xx on subresources
                  if ((request.isForMainFrame ?? false) &&
                      (errorResponse.statusCode ?? 0) >= 500) {
                    setState(() {
                      _loading = false;
                      _error =
                          'Server returned error status ${errorResponse.statusCode}.';
                    });
                    _overlayFocusNode.requestFocus();
                  }
                },
                onPermissionRequest: (_, request) async {
                  // Grant only Widevine DRM / EME
                  final granted = <PermissionResourceType>[];
                  if (request.resources.contains(
                    PermissionResourceType.PROTECTED_MEDIA_ID,
                  )) {
                    granted.add(PermissionResourceType.PROTECTED_MEDIA_ID);
                  }
                  return PermissionResponse(
                    resources: granted,
                    action: granted.isNotEmpty
                        ? PermissionResponseAction.GRANT
                        : PermissionResponseAction.DENY,
                  );
                },
                shouldOverrideUrlLoading: (_, navigationAction) async {
                  final uri = navigationAction.request.url;
                  if (uri == null) return NavigationActionPolicy.CANCEL;

                  // Block non-http/https schemes
                  if (!['http', 'https'].contains(uri.scheme.toLowerCase())) {
                    return NavigationActionPolicy.CANCEL;
                  }

                  // Allow explicit one-time override
                  if (_allowedRedirectUrlOnce != null &&
                      uri.toString() == _allowedRedirectUrlOnce) {
                    _allowedRedirectUrlOnce = null;
                    return NavigationActionPolicy.ALLOW;
                  }

                  // Check cross-domain top-level redirect without user gesture
                  final currentUri = await _controller?.getUrl();
                  if (currentUri != null && currentUri.host.isNotEmpty) {
                    final sameDomain = _isSameRegistrableDomain(
                      currentUri,
                      uri,
                    );
                    final isUserGesture = navigationAction.hasGesture ?? false;

                    if (!sameDomain && !isUserGesture) {
                      setState(() => _pendingBlockedRedirect = uri.toString());
                      return NavigationActionPolicy.CANCEL;
                    }
                  }

                  return NavigationActionPolicy.ALLOW;
                },
                onCreateWindow: (_, createWindowAction) async {
                  // Defect 7: Drop unprompted popup windows
                  final targetUri = createWindowAction.request.url;
                  final hasGesture = createWindowAction.hasGesture ?? false;
                  final currentUri = await _controller?.getUrl();

                  if (targetUri != null &&
                      [
                        'http',
                        'https',
                      ].contains(targetUri.scheme.toLowerCase()) &&
                      hasGesture &&
                      currentUri != null &&
                      _isSameRegistrableDomain(currentUri, targetUri)) {
                    await _controller?.loadUrl(
                      urlRequest: URLRequest(url: targetUri),
                    );
                    return true;
                  }
                  return false; // Drop ad popups silently
                },
              ),

            // Loading spinner
            if (_loading && _error == null)
              const Center(
                child: CircularProgressIndicator(
                  color: bingeYellow,
                  strokeWidth: 4,
                ),
              ),

            // Error & Offline Overlay (Defect 2 & Defect 3)
            if (_error != null) _buildThemedErrorOverlay(),

            // Themed Quick Menu Overlay
            if (_isQuickMenuOpen)
              QuickMenuOverlay(
                onResume: () => setState(() => _isQuickMenuOpen = false),
                onReload: () {
                  setState(() => _isQuickMenuOpen = false);
                  _controller?.reload();
                },
                onHome: () => Navigator.of(context).pop(),
                isCursorMode: _isCursorMode,
                onToggleCursorMode: () {
                  setState(() => _isCursorMode = !_isCursorMode);
                  _controller?.evaluateJavascript(
                    source:
                        'window.__bingeTv && window.__bingeTv.setCursorMode($_isCursorMode)',
                  );
                },
                currentPageWidth: _currentPageWidth,
                onSelectPageWidth: (w) async {
                  setState(() => _currentPageWidth = w);
                  await _store.updateSitePageWidth(widget.site.url, w);
                  _controller?.evaluateJavascript(
                    source:
                        'window.__bingeTv && window.__bingeTv.setPageWidth($w)',
                  );
                },
                isAdBlockEnabled: _adBlockEnabled,
                onToggleAdBlock: (val) async {
                  setState(() => _adBlockEnabled = val);
                  await _store.setAdBlockEnabled(val);
                  _controller?.reload();
                },
                pendingBlockedRedirect: _pendingBlockedRedirect,
                onAllowRedirectOnce: () {
                  if (_pendingBlockedRedirect != null) {
                    _allowedRedirectUrlOnce = _pendingBlockedRedirect;
                    _controller?.loadUrl(
                      urlRequest: URLRequest(
                        url: WebUri(_pendingBlockedRedirect!),
                      ),
                    );
                    setState(() {
                      _pendingBlockedRedirect = null;
                      _isQuickMenuOpen = false;
                    });
                  }
                },
                onOpenRemoteTest: () {
                  setState(() => _isQuickMenuOpen = false);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RemoteTestScreen()),
                  );
                },
                webViewVersion: _webViewVersion,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemedErrorOverlay() {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: Focus(
        focusNode: _overlayFocusNode,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isOffline ? Icons.wifi_off : Icons.error_outline,
              color: bingeYellow,
              size: 64,
            ),
            const SizedBox(height: 18),
            Text(
              _isOffline ? 'No Internet Connection' : 'Unable to Load Site',
              style: const TextStyle(
                color: bingeYellow,
                fontSize: 34,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                _error!,
                style: const TextStyle(fontSize: 20, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 20,
              children: [
                TvFocusable(
                  autofocus: true,
                  onSelected: () {
                    setState(() => _error = null);
                    _controller?.reload();
                  },
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  builder: (ctx, focused) => Text(
                    'Retry',
                    style: TextStyle(
                      color: focused ? bingeYellow : Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TvFocusable(
                  onSelected: () => Navigator.of(context).pop(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  builder: (ctx, focused) => Text(
                    'Back to Sites',
                    style: TextStyle(
                      color: focused ? bingeYellow : Colors.white70,
                      fontSize: 22,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
