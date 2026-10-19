import 'package:flutter_test/flutter_test.dart';
import 'package:binge/services/url_normalizer.dart';

void main() {
  group('UrlNormalizer Tests', () {
    test('normalises domain without scheme by prepending https://', () {
      expect(UrlNormalizer.normalize('httpbin.org'), 'https://httpbin.org');
      expect(UrlNormalizer.normalize('bingebang.st'), 'https://bingebang.st');
      expect(UrlNormalizer.normalize('rivestream.ru'), 'https://rivestream.ru');
    });

    test('preserves scheme for HTTP and HTTPS regardless of case', () {
      expect(UrlNormalizer.normalize('HTTP://X.com'), 'http://x.com');
      expect(
        UrlNormalizer.normalize('https://example.com/path?arg=1'),
        'https://example.com/path?arg=1',
      );
      expect(
        UrlNormalizer.normalize('http://mytest.org:8080/'),
        'http://mytest.org:8080/',
      );
    });

    test('trims leading and trailing whitespace properly', () {
      expect(
        UrlNormalizer.normalize('   https://bingebang.st/   '),
        'https://bingebang.st/',
      );
      expect(
        UrlNormalizer.normalize('   httpbin.org   '),
        'https://httpbin.org',
      );
    });

    test('accepts localhost and valid IP addresses', () {
      expect(UrlNormalizer.normalize('localhost'), 'https://localhost');
      expect(
        UrlNormalizer.normalize('localhost:8000'),
        'https://localhost:8000',
      );
      expect(UrlNormalizer.normalize('192.168.1.1'), 'https://192.168.1.1');
      expect(
        UrlNormalizer.normalize('http://127.0.0.1:5000'),
        'http://127.0.0.1:5000',
      );
    });

    test('rejects invalid, empty, or bare inputs without dot or host', () {
      expect(UrlNormalizer.normalize(''), isNull);
      expect(UrlNormalizer.normalize('   '), isNull);
      expect(UrlNormalizer.normalize(null), isNull);
      expect(UrlNormalizer.normalize('justwords'), isNull);
      expect(UrlNormalizer.normalize('ftp://invalid-scheme.com'), isNull);
      expect(UrlNormalizer.normalize('javascript:alert(1)'), isNull);
    });

    test('isValid helper accurately reflects normalisation status', () {
      expect(UrlNormalizer.isValid('httpbin.org'), isTrue);
      expect(UrlNormalizer.isValid('HTTP://X.com'), isTrue);
      expect(UrlNormalizer.isValid('invalid'), isFalse);
      expect(UrlNormalizer.isValid(''), isFalse);
    });
  });
}
