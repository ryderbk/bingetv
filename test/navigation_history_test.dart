import 'package:flutter_test/flutter_test.dart';
import 'package:binge/services/navigation_history.dart';

void main() {
  test('navigation history stays bounded and keeps newest events', () {
    final history = NavigationHistory(capacity: 2);
    history.add('load-start', url: 'https://example.test/');
    history.add('http-error', statusCode: 503);
    history.add('retry');

    expect(history.events, hasLength(2));
    expect(history.events.first.kind, 'http-error');
    expect(history.events.last.kind, 'retry');
  });

  test('navigation events include useful request details', () {
    final history = NavigationHistory();
    history.add(
      'http-error',
      url: 'https://example.test/',
      statusCode: 503,
      detail: 'server unavailable',
    );

    expect(history.events.single.toString(), contains('http-error'));
    expect(history.events.single.toString(), contains('status=503'));
    expect(history.events.single.toString(), contains('server unavailable'));
  });
}
