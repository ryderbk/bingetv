import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/site_store.dart';
import '../services/redirect_policy.dart';
import '../services/key_pipeline.dart';
import '../services/load_state.dart';
import '../services/navigation_history.dart';
import '../theme.dart';
import '../widgets/quick_menu_overlay.dart';
import '../widgets/tv_focusable.dart';
import 'remote_test_screen.dart';
import 'diagnostics_screen.dart';
import 'selector_screen.dart';

class WebScreen extends StatefulWidget {
  const WebScreen({required this.site, super.key});
  final Site site;

  @override
  State<WebScreen> createState() => _WebScreenState();
}

class _WebScreenState extends State<WebScreen> with WidgetsBindingObserver {
  final _keyPipeline = KeyPipeline.instance;
  final _store = SiteStore();

  InAppWebViewController? _controller;
  bool _loading = true;
  bool _slowNotice = false;
  int _progress = 0;
  final _loadTracker = WebLoadTracker();
  Timer? _watchdogTimer;
  String? _error;
  int _blockedRequestCount = 0;
  bool _isOffline = false;
  bool _isQuickMenuOpen = false;
  bool _isCursorMode = false;
  late int _currentPageWidth;
  bool _adBlockEnabled = true;
  String? _pendingBlockedRedirect;
  String? _allowedRedirectUrlOnce;
  final _navigationHistory = NavigationHistory();
  String _webViewVersion = 'Detecting...';
  String _customUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  List<ContentBlocker> _contentBlockers = [];
  UnmodifiableListView<UserScript> _initialUserScripts =
      UnmodifiableListView<UserScript>(const []);

  // Focus node to take focus away from WebView when overlays are shown
  final _overlayFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _currentPageWidth = _resolvePageWidth(widget.site.pageWidth);
    _setupNativeKeyPipeline();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_loading) {
        return;
      }

      final now = DateTime.now();
      if (_loadTracker.state != WebLoadState.connecting &&
          now.difference(_loadTracker.lastProgress) >=
              const Duration(seconds: 25)) {
        setState(() {
          _loading = false;
          _slowNotice = true;
        });
      } else if (_loadTracker.shouldShowBlockingTimeout(now)) {
        setState(() {
          _loading = false;
          _error ??= 'The page did not commit within 20 seconds.';
        });
        _keyPipeline.setMode(InputMode.webPage);
        _overlayFocusNode.requestFocus();
      }
    });
    _initEngineAndSettings();
  }

  int _resolvePageWidth(int configuredWidth) {
    if (configuredWidth != 1920) return configuredWidth;
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty || views.first.devicePixelRatio <= 0) {
      return configuredWidth;
    }
    final logicalWidth =
        (views.first.physicalSize.width / views.first.devicePixelRatio).round();
    if (logicalWidth <= 0) return configuredWidth;
    return logicalWidth.clamp(1280, 1920).toInt();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keyPipeline.removeListener(_handlePipelineEvent);
    _keyPipeline.deactivateWebScreen();
    _overlayFocusNode.dispose();
    _watchdogTimer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _navigationHistory.add('lifecycle', detail: state.name);
      // TV Home pressed or switched
      _controller?.evaluateJavascript(
        source: 'window.__bingeTv && window.__bingeTv.pauseMedia()',
      );
      _controller?.pause();
    } else if (state == AppLifecycleState.resumed) {
      _navigationHistory.add('lifecycle', detail: state.name);
      _controller?.resume();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  Future<void> _setupNativeKeyPipeline() async {
    _keyPipeline.addListener(_handlePipelineEvent);
    await MethodChannel(
      'com.binge.app/key_pipeline',
    ).invokeMethod('setWebScreenActive', {'active': true});
    await _keyPipeline.setMode(InputMode.webPage);
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
    _contentBlockers = SiteStore.validBlocklistRules(blocklist).map((rule) {
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

    final userScripts = UnmodifiableListView([
      UserScript(
        source: injectedNavScript,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        forMainFrameOnly: false,
      ),
    ]);

    if (mounted) {
      setState(() => _initialUserScripts = userScripts);
      if (_controller != null) {
        await _controller!.addUserScript(userScript: userScripts.first);
      }
    }
  }

  void _handlePipelineEvent(Map<String, dynamic> map) {
    if (map.containsKey('action')) {
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
      _keyPipeline.setMode(InputMode.webPage);
      _keyPipeline.setMode(
        _isQuickMenuOpen ? InputMode.webOverlay : InputMode.webPage,
      );
      if (_isQuickMenuOpen) {
        _overlayFocusNode.requestFocus();
      }
      return;
    }

    if (_isQuickMenuOpen) {
      if (action == 'Back') {
        setState(() => _isQuickMenuOpen = false);
        _keyPipeline.setMode(InputMode.webPage);
      }
      return;
    }

    // 2. Guide key -> return to selector
    if (action == 'Guide') {
      _returnToSelector();
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
      _keyPipeline.setMode(InputMode.webOverlay);
      if (action == 'Back') {
        _returnToSelector();
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
      _returnToSelector();
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
    if (mounted) _returnToSelector();
  }

  void _returnToSelector() {
    if (!mounted) return;
    _navigationHistory.add('return-to-selector');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const SelectorScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = InAppWebViewSettings(
      javaScriptEnabled: true,
      javaScriptCanOpenWindowsAutomatically: false,
      domStorageEnabled: true,
      databaseEnabled: true,
      useWideViewPort: true,
      loadWithOverviewMode: false,
      initialScale: 100,
      mediaPlaybackRequiresUserGesture: false,
      supportZoom: true,
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
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(widget.site.url)),
              initialSettings: settings,
              initialUserScripts: _initialUserScripts,
              onWebViewCreated: (controller) {
                _controller = controller;
                _navigationHistory.add('webview-created');
                _store.setLastOpenedSite(widget.site.url).catchError((error) {
                  debugPrint('Binge: failed to persist opened site: $error');
                });
              },
              onLoadStart: (_, uri) {
                _navigationHistory.add('load-start', url: uri?.toString());
                _loadTracker.started();
                setState(() {
                  _loading = true;
                  _progress = 0;
                  _slowNotice = false;
                  _error = null;
                  _isOffline = false;
                });
                _keyPipeline.setMode(InputMode.webPage);
              },
              onProgressChanged: (_, progress) {
                if (!mounted) return;
                setState(() {
                  _progress = progress;
                  _loadTracker.progress(progress);
                  if (progress >= 100) _loading = false;
                });
              },
              onLoadStop: (controller, uri) async {
                _navigationHistory.add('load-stop', url: uri?.toString());
                // Fallback injection for frames and dynamic resets
                try {
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
                } catch (error) {
                  debugPrint(
                    'Binge: navigation script fallback failed: $error',
                  );
                }
                if (mounted) {
                  setState(() {
                    _loading = false;
                    _loadTracker.interactive();
                    _progress = 100;
                  });
                  await _keyPipeline.setMode(InputMode.webPage);
                }
              },
              onReceivedError: (_, request, error) {
                // Defect 3: Only main frame errors show the error overlay!
                if (request.isForMainFrame ?? false) {
                  _navigationHistory.add(
                    'load-error',
                    url: request.url.toString(),
                    detail: error.description,
                  );
                  setState(() {
                    _loading = false;
                    _error = error.description;
                    _isOffline =
                        error.type ==
                            WebResourceErrorType.CANNOT_CONNECT_TO_HOST ||
                        error.type == WebResourceErrorType.HOST_LOOKUP;
                  });
                  _overlayFocusNode.requestFocus();
                  _keyPipeline.setMode(InputMode.webOverlay);
                }
              },
              onReceivedHttpError: (_, request, errorResponse) {
                final statusCode = errorResponse.statusCode ?? 0;
                if (request.isForMainFrame ?? false) {
                  _navigationHistory.add(
                    'http-error',
                    url: request.url.toString(),
                    statusCode: statusCode,
                  );
                }
                if ((request.isForMainFrame ?? false) && statusCode >= 500) {
                  setState(() {
                    _loading = false;
                    _error =
                        'Server returned error status $statusCode. Press Retry to try again.';
                  });
                  _overlayFocusNode.requestFocus();
                  _keyPipeline.setMode(InputMode.webOverlay);
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

                // Allow the initial redirect chain, but reject later ad
                // hijacks that leave the committed site without a gesture.
                final currentUri = await _controller?.getUrl();
                final decision = redirectDecision(
                  currentUrl: currentUri,
                  targetUrl: uri,
                  isRedirect: navigationAction.isRedirect ?? false,
                  hasGesture: navigationAction.hasGesture ?? false,
                  timeSinceLoad: DateTime.now().difference(
                    _loadTracker.lastProgress,
                  ),
                  pageCommitted: _loadTracker.state != WebLoadState.connecting,
                );
                if (decision == RedirectDecision.block) {
                  if (mounted) {
                    setState(() {
                      _pendingBlockedRedirect = uri.toString();
                      _blockedRequestCount++;
                    });
                  }
                  return NavigationActionPolicy.CANCEL;
                }

                return NavigationActionPolicy.ALLOW;
              },
              onCreateWindow: (_, createWindowAction) async {
                // Defect 7: Drop unprompted popup windows
                final targetUri = createWindowAction.request.url;
                final hasGesture = createWindowAction.hasGesture ?? false;

                if (targetUri != null &&
                    [
                      'http',
                      'https',
                    ].contains(targetUri.scheme.toLowerCase()) &&
                    hasGesture) {
                  await _controller?.loadUrl(
                    urlRequest: URLRequest(url: targetUri),
                  );
                  return true;
                }
                return false; // Drop ad popups silently
              },
            ),

            // The WebView remains visible while a slim, non-blocking progress
            // indicator communicates startup and navigation progress.
            if (_loading && _error == null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress / 100 : null,
                  minHeight: 4,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(bingeYellow),
                ),
              ),
            if (_slowNotice && _error == null)
              Positioned(
                top: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(color: Color(0xFF17122A)),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      child: Text(
                        'Page is still loading - press Menu for options',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ),

            // Error & Offline Overlay (Defect 2 & Defect 3)
            if (_error != null) _buildThemedErrorOverlay(),

            // Themed Quick Menu Overlay
            if (_isQuickMenuOpen)
              QuickMenuOverlay(
                onResume: () {
                  setState(() => _isQuickMenuOpen = false);
                  _keyPipeline.setMode(InputMode.webPage);
                },
                onReload: () {
                  setState(() => _isQuickMenuOpen = false);
                  _keyPipeline.setMode(InputMode.webPage);
                  _controller?.reload();
                },
                onHome: _returnToSelector,
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
                  _navigationHistory.add(
                    'ad-block-changed',
                    detail: val ? 'enabled' : 'disabled',
                  );
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
                  _keyPipeline.setMode(InputMode.remoteTest);
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (_) => const RemoteTestScreen(),
                        ),
                      )
                      .whenComplete(() {
                        _keyPipeline.setMode(InputMode.webPage);
                      });
                },
                onOpenDiagnostics: () {
                  setState(() => _isQuickMenuOpen = false);
                  _keyPipeline.setMode(InputMode.diagnostics);
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (_) => DiagnosticsScreen(
                            lastUrl: widget.site.url,
                            lastError: _error,
                            blockedRequestCount: _blockedRequestCount,
                            ruleCount: _contentBlockers.length,
                            navigationEvents: _navigationHistory.events,
                          ),
                        ),
                      )
                      .whenComplete(() {
                        _keyPipeline.setMode(InputMode.webPage);
                      });
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
                  onSelected: _returnToSelector,
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
