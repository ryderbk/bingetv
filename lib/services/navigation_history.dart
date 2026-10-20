class NavigationEvent {
  const NavigationEvent({
    required this.timestamp,
    required this.kind,
    this.url,
    this.statusCode,
    this.detail,
  });

  final DateTime timestamp;
  final String kind;
  final String? url;
  final int? statusCode;
  final String? detail;

  @override
  String toString() {
    final time = timestamp.toIso8601String();
    final location = url == null ? '' : ' url=$url';
    final status = statusCode == null ? '' : ' status=$statusCode';
    final message = detail == null ? '' : ' $detail';
    return '$time $kind$location$status$message';
  }
}

class NavigationHistory {
  NavigationHistory({this.capacity = 40});

  final int capacity;
  final List<NavigationEvent> _events = [];

  List<NavigationEvent> get events => List.unmodifiable(_events);

  void add(String kind, {String? url, int? statusCode, String? detail}) {
    _events.add(
      NavigationEvent(
        timestamp: DateTime.now(),
        kind: kind,
        url: url,
        statusCode: statusCode,
        detail: detail,
      ),
    );
    if (_events.length > capacity) {
      _events.removeRange(0, _events.length - capacity);
    }
  }
}
