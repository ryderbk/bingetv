import 'package:flutter_test/flutter_test.dart';
import 'package:binge/services/redirect_policy.dart';

void main() {
  test('allows redirects and the initial navigation chain', () {
    expect(
      redirectDecision(
        currentUrl: Uri.parse('https://bingebang.st/'),
        targetUrl: Uri.parse('https://new.example/'),
        isRedirect: true,
        hasGesture: false,
        timeSinceLoad: const Duration(seconds: 30),
        pageCommitted: true,
      ),
      RedirectDecision.allow,
    );
    expect(
      redirectDecision(
        currentUrl: Uri.parse('https://bingebang.st/'),
        targetUrl: Uri.parse('https://new.example/'),
        isRedirect: false,
        hasGesture: false,
        timeSinceLoad: const Duration(seconds: 2),
        pageCommitted: false,
      ),
      RedirectDecision.allow,
    );
  });

  test('blocks a later cross-site navigation without a gesture', () {
    expect(
      redirectDecision(
        currentUrl: Uri.parse('https://bingebang.st/'),
        targetUrl: Uri.parse('https://ad.example/'),
        isRedirect: false,
        hasGesture: false,
        timeSinceLoad: const Duration(seconds: 20),
        pageCommitted: true,
      ),
      RedirectDecision.block,
    );
    expect(
      redirectDecision(
        currentUrl: Uri.parse('https://bingebang.st/'),
        targetUrl: Uri.parse('https://ad.example/'),
        isRedirect: false,
        hasGesture: true,
        timeSinceLoad: const Duration(seconds: 20),
        pageCommitted: true,
      ),
      RedirectDecision.allow,
    );
  });
}
