import 'dart:async';
import 'package:flutter/services.dart';

enum InputMode {
  selector,
  editor,
  webPage,
  webOverlay,
  diagnostics,
  editingText,
}

bool shouldEnableNativeInterception(InputMode mode) =>
    mode == InputMode.webPage;

typedef RemoteKeyListener = void Function(Map<String, dynamic> event);

class KeyPipeline {
  KeyPipeline._() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static final KeyPipeline instance = KeyPipeline._();
  static const _channel = MethodChannel('com.binge.app/key_pipeline');

  final _listeners = <RemoteKeyListener>{};
  Timer? _heartbeat;
  InputMode _mode = InputMode.selector;
  bool _nativeEnabled = false;

  InputMode get mode => _mode;
  bool get nativeInterceptionEnabled => _nativeEnabled;

  void addListener(RemoteKeyListener listener) => _listeners.add(listener);
  void removeListener(RemoteKeyListener listener) =>
      _listeners.remove(listener);

  Future<void> setMode(InputMode mode) async {
    _mode = mode;
    final enabled = shouldEnableNativeInterception(mode);
    if (enabled == _nativeEnabled) return;
    _nativeEnabled = enabled;
    await _channel.invokeMethod('setNativeInterceptEnabled', {
      'enabled': enabled,
    });
    if (enabled) {
      _heartbeat?.cancel();
      _heartbeat = Timer.periodic(const Duration(seconds: 1), (_) {
        _channel.invokeMethod('nativeInterceptHeartbeat');
      });
      await _channel.invokeMethod('nativeInterceptHeartbeat');
    } else {
      _heartbeat?.cancel();
      _heartbeat = null;
    }
  }

  Future<void> deactivateWebScreen() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    _nativeEnabled = false;
    await _channel.invokeMethod('setWebScreenActive', {'active': false});
    await _channel.invokeMethod('setNativeInterceptEnabled', {
      'enabled': false,
    });
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onRemoteKey') {
      final event = Map<String, dynamic>.from(call.arguments as Map);
      for (final listener in List.of(_listeners)) {
        listener(event);
      }
    }
  }
}
