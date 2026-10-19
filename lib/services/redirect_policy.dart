enum RedirectDecision { allow, block }

RedirectDecision redirectDecision({
  required Uri? currentUrl,
  required Uri targetUrl,
  required bool isRedirect,
  required bool hasGesture,
  required Duration timeSinceLoad,
  required bool pageCommitted,
}) {
  if (!const ['http', 'https'].contains(targetUrl.scheme.toLowerCase())) {
    return RedirectDecision.block;
  }

  // The first navigation and its server redirect chain belong to the saved
  // site, even when the site has moved to another host.
  if (!pageCommitted ||
      isRedirect ||
      hasGesture ||
      timeSinceLoad <= const Duration(seconds: 10)) {
    return RedirectDecision.allow;
  }

  if (currentUrl == null || currentUrl.host.isEmpty) {
    return RedirectDecision.allow;
  }

  final currentHost = currentUrl.host.toLowerCase();
  final targetHost = targetUrl.host.toLowerCase();
  if (currentHost == targetHost || targetHost.endsWith('.$currentHost')) {
    return RedirectDecision.allow;
  }
  return RedirectDecision.block;
}
