enum WebLoadState { connecting, committed, interactive, idle, failed }

class WebLoadTracker {
  WebLoadState state = WebLoadState.connecting;
  DateTime lastProgress = DateTime.now();

  void started() {
    state = WebLoadState.connecting;
    lastProgress = DateTime.now();
  }

  void progress(int value) {
    lastProgress = DateTime.now();
    if (value >= 30 && state == WebLoadState.connecting) {
      state = WebLoadState.committed;
    }
  }

  void committed() {
    state = WebLoadState.committed;
    lastProgress = DateTime.now();
  }

  void interactive() {
    state = WebLoadState.interactive;
    lastProgress = DateTime.now();
  }

  bool shouldShowBlockingTimeout(DateTime now) =>
      state == WebLoadState.connecting &&
      now.difference(lastProgress) >= const Duration(seconds: 20);
}
