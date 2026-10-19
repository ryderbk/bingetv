class UrlNormalizer {
  /// Normalises a user-entered URL:
  /// 1. Trim whitespace.
  /// 2. If no scheme ('://') is present, prepend 'https://'.
  /// 3. Parse and enforce http/https scheme.
  /// 4. Enforce valid host containing a dot (e.g. 'bingebang.st', 'httpbin.org'),
  ///    or 'localhost', or an IP address.
  static String? normalize(String? input) {
    if (input == null) return null;
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final withScheme = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(withScheme);
    if (uri == null) return null;

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null;

    final host = uri.host.trim();
    if (host.isEmpty) return null;

    final isLocalhost = host.toLowerCase() == 'localhost';
    final hasDot = host.contains('.');
    final isIpv4 = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(host);
    final isIpv6 = host.startsWith('[') && host.endsWith(']');

    if (isLocalhost || hasDot || isIpv4 || isIpv6) {
      return uri.toString();
    }
    return null;
  }

  static bool isValid(String? input) => normalize(input) != null;
}
