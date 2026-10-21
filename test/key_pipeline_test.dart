import 'package:flutter_test/flutter_test.dart';
import 'package:binge/services/key_pipeline.dart';

void main() {
  test('only an unobstructed web page enables native interception', () {
    expect(shouldEnableNativeInterception(InputMode.selector), isFalse);
    expect(shouldEnableNativeInterception(InputMode.editor), isFalse);
    expect(shouldEnableNativeInterception(InputMode.webPage), isTrue);
    expect(shouldEnableNativeInterception(InputMode.webOverlay), isFalse);
    expect(shouldEnableNativeInterception(InputMode.diagnostics), isFalse);
    expect(shouldEnableNativeInterception(InputMode.editingText), isFalse);
  });
}
