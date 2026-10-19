import 'package:flutter_test/flutter_test.dart';
import 'package:binge/services/load_state.dart';

void main() {
  test('committed pages never become timeout failures', () {
    final tracker = WebLoadTracker();
    tracker.started();
    tracker.progress(85);
    expect(tracker.state, WebLoadState.committed);
    expect(
      tracker.shouldShowBlockingTimeout(
        tracker.lastProgress.add(const Duration(seconds: 30)),
      ),
      isFalse,
    );
  });

  test('connecting pages fail only after twenty seconds without progress', () {
    final tracker = WebLoadTracker();
    tracker.started();
    expect(
      tracker.shouldShowBlockingTimeout(
        tracker.lastProgress.add(const Duration(seconds: 19)),
      ),
      isFalse,
    );
    expect(
      tracker.shouldShowBlockingTimeout(
        tracker.lastProgress.add(const Duration(seconds: 20)),
      ),
      isTrue,
    );
  });
}
