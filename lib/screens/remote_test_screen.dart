import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../theme.dart';
import '../services/key_pipeline.dart';
import '../widgets/tv_focusable.dart';

class RemoteTestScreen extends StatefulWidget {
  const RemoteTestScreen({super.key});

  @override
  State<RemoteTestScreen> createState() => _RemoteTestScreenState();
}

class _RemoteTestScreenState extends State<RemoteTestScreen> {
  final _keyPipeline = KeyPipeline.instance;

  final List<Map<String, dynamic>> _events = [];
  final Set<int> _receivedKeyCodes = {};
  String _webViewVersion = 'Detecting...';

  // Remote key reference definitions for Xiaomi XMRM-P5
  static const _keyDefs = [
    {'name': 'UP', 'code': 19},
    {'name': 'DOWN', 'code': 20},
    {'name': 'LEFT', 'code': 21},
    {'name': 'RIGHT', 'code': 22},
    {'name': 'OK', 'code': 23},
    {'name': 'BACK', 'code': 4},
    {'name': 'MENU', 'code': 82},
    {'name': 'PLAY/PAUSE', 'code': 85},
    {'name': 'REWIND', 'code': 89},
    {'name': 'FAST-FWD', 'code': 90},
    {'name': 'INFO', 'code': 165},
    {'name': 'GUIDE', 'code': 172},
    {'name': 'SUBT', 'code': 175},
    {'name': 'CH +', 'code': 166},
    {'name': 'CH -', 'code': 167},
    {'name': 'RED', 'code': 183},
    {'name': 'GREEN', 'code': 184},
    {'name': 'YELLOW', 'code': 185},
    {'name': 'BLUE', 'code': 186},
    {'name': '0-9', 'code': 7},
  ];

  @override
  void initState() {
    super.initState();
    _keyPipeline.addListener(_handleNativeEvent);
    _keyPipeline.setMode(InputMode.remoteTest);
    _loadDiagnostics();
  }

  @override
  void dispose() {
    _keyPipeline.removeListener(_handleNativeEvent);
    _keyPipeline.setMode(InputMode.webPage);
    super.dispose();
  }

  void _handleNativeEvent(Map<String, dynamic> map) {
    if (map.containsKey('keyCode')) {
      final code = (map['keyCode'] as num?)?.toInt() ?? 0;
      if (mounted) {
        setState(() {
          _events.insert(0, {
            ...map,
            'time': DateTime.now().toIso8601String().substring(11, 19),
          });
          if (_events.length > 50) _events.removeLast();
          if (code > 0) _receivedKeyCodes.add(code);
        });
      }
    }
  }

  Future<void> _loadDiagnostics() async {
    try {
      final pkg = await InAppWebViewController.getCurrentWebViewPackage();
      if (mounted) {
        setState(() {
          _webViewVersion = pkg != null
              ? '${pkg.packageName} (${pkg.versionName})'
              : 'System Default WebView';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _webViewVersion = 'Standard WebView (API 30)');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) => Navigator.of(context).pop(),
          ),
        },
        child: Scaffold(
          backgroundColor: bingeBackground,
          body: SafeArea(
            minimum: const EdgeInsets.symmetric(
              horizontal: bingePagePadding,
              vertical: 32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Remote Key Diagnostics',
                          style: TextStyle(
                            color: bingeYellow,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Xiaomi XMRM-P5 Remote Verification (Fire OS 8 / Android 11)',
                          style: TextStyle(color: bingeTextSecondary, fontSize: 16),
                        ),
                      ],
                    ),
                    TvFocusable(
                      autofocus: true,
                      onSelected: () => Navigator.of(context).pop(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      builder: (ctx, focused) => Text(
                        'Back',
                        style: TextStyle(
                          color: focused ? bingeYellow : Colors.white,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: bingeSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: bingeYellow,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'WebView: $_webViewVersion',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Remote buttons',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _keyDefs.map((def) {
                    final code = def['code'] as int;
                    final isReceived =
                        _receivedKeyCodes.contains(code) ||
                        (code == 7 &&
                            _receivedKeyCodes.any((c) => c >= 7 && c <= 16));
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isReceived ? const Color(0xFF3A2E12) : bingeSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isReceived ? bingeYellow : bingeDivider,
                          width: isReceived ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        '${def['name']} ($code)',
                        style: TextStyle(
                          color: isReceived ? bingeYellow : Colors.white60,
                          fontSize: 14,
                          fontWeight: isReceived
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Live Key Log (logcat tag: BingeKeys):',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF07050A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: _events.isEmpty
                        ? const Center(
                            child: Text(
                              'Press any button on the remote to test...',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 18,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _events.length,
                            itemBuilder: (ctx, idx) {
                              final ev = _events[idx];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      '[${ev['time']}] ',
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 14,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    Text(
                                      '${ev['action']} ',
                                      style: TextStyle(
                                        color: ev['action'] == 'DOWN'
                                            ? bingeYellow
                                            : Colors.white60,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      '${ev['keyName']} (code ${ev['keyCode']})',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (ev['repeat'] != null &&
                                        (ev['repeat'] as int) > 0)
                                      Text(
                                        'repeat=${ev['repeat']} ',
                                        style: const TextStyle(
                                          color: bingePurple,
                                          fontSize: 13,
                                        ),
                                      ),
                                    if (ev['isLongPress'] == true)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade900,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Text(
                                          'LONG-PRESS',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
