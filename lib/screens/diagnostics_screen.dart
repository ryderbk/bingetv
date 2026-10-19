import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../theme.dart';
import '../widgets/tv_focusable.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({
    required this.lastUrl,
    required this.lastError,
    required this.blockedRequestCount,
    required this.ruleCount,
    super.key,
  });

  final String? lastUrl;
  final String? lastError;
  final int blockedRequestCount;
  final int ruleCount;

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  static const _channel = MethodChannel('com.binge.app/key_pipeline');
  String _report = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    String webView = 'System WebView';
    try {
      final package = await InAppWebViewController.getCurrentWebViewPackage();
      if (package != null) {
        webView = '${package.packageName} (${package.versionName})';
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _report = _buildReport(webView);
    });
  }

  String _buildReport(String webView) {
    return [
      'Binge diagnostics',
      'WebView: $webView',
      'Last URL: ${widget.lastUrl ?? 'none'}',
      'Last error: ${widget.lastError ?? 'none'}',
      'Blocked requests: ${widget.blockedRequestCount}',
      'Content-blocker rules: ${widget.ruleCount}',
      'Key pipeline: native interception channel enabled',
      'Viewport: WebView reports at runtime; desktop width is site-configured',
    ].join('\n');
  }

  Future<void> _copyReport() async {
    await _channel.invokeMethod('copyDiagnostics', {'report': _report});
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saved diagnostics.txt')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bingeBackground,
      body: SafeArea(
        minimum: const EdgeInsets.symmetric(
          horizontal: bingePagePadding,
          vertical: 36,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Diagnostics',
              style: TextStyle(
                color: bingeYellow,
                fontSize: 34,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: bingeSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _report.isEmpty ? 'Loading...' : _report,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      height: 1.55,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                TvFocusable(
                  autofocus: true,
                  onSelected: _copyReport,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  builder: (_, focused) => Text(
                    'Copy report',
                    style: TextStyle(
                      color: focused ? bingeYellow : Colors.white,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                TvFocusable(
                  onSelected: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ColourCheckScreen(),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  builder: (_, focused) => Text(
                    'Colour check',
                    style: TextStyle(
                      color: focused ? bingeYellow : Colors.white,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                TvFocusable(
                  onSelected: () => Navigator.of(context).pop(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  builder: (_, focused) => Text(
                    'Back',
                    style: TextStyle(
                      color: focused ? bingeYellow : Colors.white,
                      fontSize: 20,
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

class ColourCheckScreen extends StatelessWidget {
  const ColourCheckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const colours = [
      Colors.black,
      Color(0xFF0E0B14),
      Color(0xFF17122A),
      bingeYellow,
      bingePurple,
    ];
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        minimum: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Colour check',
              style: TextStyle(
                color: bingeYellow,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                for (final colour in colours)
                  Expanded(
                    child: Container(
                      height: 180,
                      margin: const EdgeInsets.only(right: 12),
                      color: colour,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < 32; i++)
                    Expanded(
                      child: ColoredBox(
                        color: Color.fromARGB(255, i * 8, i * 8, i * 8),
                      ),
                    ),
                ],
              ),
            ),
            TvFocusable(
              autofocus: true,
              onSelected: () => Navigator.of(context).pop(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              builder: (_, focused) => Text(
                'Back',
                style: TextStyle(
                  color: focused ? bingeYellow : Colors.white,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
